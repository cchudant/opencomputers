local shell = require('shell')
local droneControl = require('.software.apis.droneControl')
local schematic = require('.software.apis.schematic')
local serialization = require('serialization')
local sides = require('sides')
local component = require('component')

local args, ops = shell.parse(...)

local function showUsage()
    print('Run reclamation master task.')
    print('Usage:')
    print('* recl - deploy reclamation drones')
    print('* recl --checkMatList - check material list against the inventory in front')
end

local action = 'deploy'

local schemFilePath = '/home/reclamation4_y10.data'

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
}

if action == 'checkMatList' then
    local ic = component.getPrimary('inventory_controller')
    local schem = schematic.Schematic.load(schemFilePath)

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
    for k, _ in pairs(schem.palette) do
        if not got[k] and not lqds[k] then
            if nMissing == 0 then
                print('Missing:')
            end
            print('- ' .. k)
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
    local schem = schematic.Schematic.load(schemFilePath)

    local schemX, schemY, schemZ = 192, 10, -880

    local done = false
    local chunk
    while not done do
        chunk = chunk or schem:nextChunk()
        if not chunk then
            done = true
            break
        end
        local drones = droneControl.getWaitingDrones( --[[timeout sec]] 3)
        for _, droneAddr in ipairs(drones) do
            local x, y, z, xlen, ylen, zlen, blocks, matlist =
                chunk.cx * schematic.chunkSizeX + schemX,
                schemY,
                chunk.cz * schematic.chunkSizeZ + schemZ,
                chunk.lenx, chunk.leny, chunk.lenz, chunk.blocks, chunk.materials

            local droneArgs = { x, y, z, xlen, ylen, zlen, blocks, matlist }

            print('Run /software/drone/schemPlacer.lua', serialization.serialize(droneArgs))

            droneControl.run(
                droneAddr, '/software/drone/schemPlacer.lua',
                serialization.serialize(droneArgs)
            )

            chunk = nil
        end
    end

    print('All done.')

    schem:close()
end
