local shell = require('shell')
local droneControl = require('.software.apis.droneControl')
local schematic = require('.software.apis.schematic')
local serialization = require('serialization')

local args, ops = shell.parse(...)

local function showUsage()
    print('Run reclamation master task.')
    print('Usage: reclamationMaster')
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

local schem = schematic.Schematic.load('/home/reclamation4_y10.data')

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
