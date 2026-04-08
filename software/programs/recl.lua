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

schem:nextChunk()
schem:nextChunk()
schem:nextChunk()
local chunk = schem:nextChunk()
if not chunk then error('no chunk') end

local x, y, z, xlen, ylen, zlen, blocks, matlist = chunk.cx * 16 + schemX, schemY, chunk.cz * 16 + schemZ,
    chunk.lenx, chunk.leny, chunk.lenz, chunk.blocks, chunk.materials

local droneArgs = { x, y, z, xlen, ylen, zlen, blocks, matlist }

print('Run /software/drone/schemPlacer.lua', serialization.serialize(droneArgs))

droneControl.run(
    nil, '/software/drone/schemPlacer.lua',
    serialization.serialize(droneArgs)
)

print('Sent.')

schem:close()
