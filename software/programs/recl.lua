local shell = require('shell')
local droneControl = require('.software.apis.droneControl')
local schematic = require('.software.apis.schematic')
local serialization = require('serialization')
local sides = require('sides')
local component = require('component')
local thread = require('thread')
local io = require('io')
local event = require('event')

local args, ops = shell.parse(...)

local function showUsage()
    print('Run reclamation master task.')
    print('Usage:')
    print('* recl - deploy reclamation drones')
    print('* recl --checkMatList - check material list against the inventory in front')
end

local action = 'deploy'

local schemFilePath = '/home/reclamation5_y11.data'
local schemX, schemY, schemZ = 192, 11, -880

if type(ops['checkMatList']) == 'boolean' then
    action = 'checkMatList'
    ops['checkMatList'] = nil
end

for k, _v in pairs(ops) do
    print('Unknown option: --' .. k)
    showUsage()
    return
end

if #args > 0 then
    showUsage()
    return
end

local lqds = {
    ['2055:10'] = "poison",
    ['2055:11'] = "water",
    ['2055:14'] = "lava",
    ['2055:15'] = "oil",
}

local substitutions = {
    -- cave vines
    ['2480'] = '0',
    ['2480:1'] = '0',
    ['2479'] = '0',
    -- glow lichen
    ['2478'] = '0',
    -- etfuturem deepslate redstone ore to gt
    ['2303'] = '2711:810',
    -- thaumcraft node to white hempcrete (sentinel)
    ['411'] = '2055:0',
}

if action == 'checkMatList' then
    local ic = component.getPrimary('inventory_controller')
    local schem = schematic.Schematic.load(schemFilePath, substitutions)

    local got = {}
    local function detToMat(el)
        if not el then return nil end
        if not el.damage or el.damage == 0 then
            return tostring(el.id)
        end
        return el.id .. ':' .. el.damage
    end

    for el in ic.getAllStacks(sides.front) do
        local mat = detToMat(el)
        if mat then got[mat] = true end
    end

    local nMissing = 0
    for _, mat in ipairs(schem.materials) do
        if mat ~= '0' and not got[mat] and not lqds[mat] then
            if nMissing == 0 then
                print('Missing:')
            end
            print('- ' .. mat)
            nMissing = nMissing + 1
        end
    end

    if nMissing == 0 then
        print('No material missing! Congratz!')
    else
        print('Missing ' .. nMissing .. ' materials.')
    end

    schem:close()
else
    local doneChunksFile = io.open('/home/doneChunks', 'r')
    local doneChunks = {}

    if doneChunksFile then
        for line in doneChunksFile:lines() do
            doneChunks[line] = true
        end

        doneChunksFile:close()
    end

    doneChunksFile = io.open('/home/doneChunks', 'a') --[[@as file*]]

    local function markDone(x, y, z)
        local key = string.format('%s,%s,%s', x, y, z)

        table.insert(doneChunks, key)
        doneChunksFile:write(key, '\n')
        doneChunksFile:flush()
        print('Chunk at ' .. key .. ' marked as done.')
    end

    local function dispatch()
        component.getPrimary('modem').setStrength(20)
        local schem = schematic.Schematic.load(schemFilePath, substitutions)


        local i = 1
        local drones = {}

        for chunk in schem:chunks() do
            local x, y, z, xlen, ylen, zlen, blocks, matlist =
                chunk.cx * schematic.chunkSizeX + schemX,
                schemY,
                chunk.cz * schematic.chunkSizeZ + schemZ,
                chunk.lenx, chunk.leny, chunk.lenz, chunk.blocks, chunk.materials

            if not doneChunks[string.format('%s,%s,%s', x, y, z)] then
                while #drones < 1 do
                    print('Checking for drones...')
                    drones = droneControl.getWaitingDrones( --[[timeout sec]] 5, --[[num]] nil, --[[maxDistance]] 2.5)
                end

                local droneAddr = table.remove(drones)

                local droneArgs = { x, y, z, xlen, ylen, zlen, blocks, matlist }

                print('Dispatch [' .. i .. '] ' ..
                    droneAddr .. ': ' .. x .. ',' .. y .. ',' .. z .. ' ' .. xlen .. 'x' .. ylen .. 'x' .. zlen)

                droneControl.run(
                    droneAddr, '/software/drone/schemPlacer.lua',
                    serialization.serialize(droneArgs)
                )
            end
            i = i + 1
        end

        print('All done.')

        schem:close()
    end

    local function receiveDoneMessages()
        component.getPrimary('modem').open(732)
        while true do
            local ev = { event.pull('modem_message') }
            if ev[6] == 'schemPlacerFinished' then
                local x, y, z = table.unpack(ev, 7)
                markDone(x, y, z)
            end
        end
    end

    local t1, t2 = thread.create(dispatch), thread.create(receiveDoneMessages)

    thread.waitForAny({ t1, t2 })

    t1:kill()
    t2:kill()

    doneChunksFile:close()
end
