local nbt = require('tools.nbt')

local file = io.open('./tools/reclamation5_y12.nbt') --[[@as file*]]
local content = file:read('a')
file:close()
local tag = nbt.decode(content, 'tag') --[[@as table]]

local blocksArr = tag:getValue()['Blocks']:getValue()
local dataArr = tag:getValue()['Data']:getValue()
local addBlocksArr = tag:getValue()['AddBlocks']:getValue()

local xlength = tag:getValue()['Width']:getValue()
local ylength = tag:getValue()['Height']:getValue()
local zlength = tag:getValue()['Length']:getValue()

local tileEntities = tag:getValue()['TileEntities']:getValue()
local tileEntityMap = {}
for i, el in ipairs(tileEntities) do
    local id = el:getValue().id:getValue()
    local x, y, z = el:getValue().x:getValue(), el:getValue().y:getValue(), el:getValue().z:getValue()
    if id ~= 'GT_TileEntity_Ores' then
        print('Unsupported tileentity: ' .. id)
        print(el, i)
    else
        local m = el:getValue().m:getValue()
        tileEntityMap[string.format('%s,%s,%s', x, y, z)] = m
    end
end

local chunkSizeX, chunkSizeY, chunkSizeZ = 8, 1, 16

local function toUnsignedByte(b)
    if b < 0 then
        b = b + 256
    end
    return b
end

local palette = {}
local materialList = {}

local outFile = io.open('./tools/reclamation5_y12.data', 'w+b') --[[@as file*]]

outFile:write(string.pack('>I4>I4>I4', xlength, ylength, zlength))

local function getBlock(x, y, z)
    -- beware of 1-based indices
    local index = y * zlength + z * xlength + x
    local blockId = toUnsignedByte(blocksArr[index + 1])
    local dataVal = toUnsignedByte(dataArr[index + 1])
    local addBlockId = toUnsignedByte(addBlocksArr[math.floor(index / 2) + 1])
    if index % 2 == 0 then
        addBlockId = (addBlockId >> 4) & 0xF
    else
        addBlockId = addBlockId & 0xF
    end
    local fullblockid = (addBlockId << 8) | blockId

    local te = tileEntityMap[string.format('%s,%s,%s', x, y, z)]

    if te then
        return fullblockid, te % 1000
    end

    -- print('Block at ' .. x .. ',' .. y .. ',' .. z .. ': ' .. fullblockid .. ':' .. dataVal .. ' TE: ' .. (te or 'none'))
    return fullblockid, dataVal, te
end

local function isChunkEmpty(cx, cy, cz, lenx, leny, lenz)
    local coriginx, coriginy, coriginz = cx * chunkSizeX, cy * chunkSizeY, cz * chunkSizeZ

    for rx = 0, lenx - 1 do
        for ry = 0, leny - 1 do
            for rz = 0, lenz - 1 do
                local id, _data, _extra = getBlock(coriginx + rx, coriginy + ry, coriginz + rz)

                if id ~= 0 then
                    return false
                end
            end
        end
    end
    return true
end

local nChunksX = math.ceil(xlength / chunkSizeX)
local nChunksY = math.ceil(ylength / chunkSizeY)
local nChunksZ = math.ceil(zlength / chunkSizeZ)

local function forEachChunk(func)
    for cy = 0, nChunksY - 1 do
        local leny = chunkSizeY
        if cy == nChunksY - 1 then leny = (ylength - 1) % chunkSizeY + 1 end

        for cz = 0, nChunksZ - 1 do
            local lenz = chunkSizeZ
            if cz == nChunksZ - 1 then lenz = (zlength - 1) % chunkSizeZ + 1 end

            for cx = 0, nChunksX - 1 do
                local lenx = chunkSizeX
                if cx == nChunksX - 1 then lenx = (xlength - 1) % chunkSizeX + 1 end

                func(cx, cy, cz, lenx, leny, lenz)
            end
        end
    end
end

local function populateMatList(cx, cy, cz, lenx, leny, lenz)
    print('Chunk: ' .. cx .. ' ' .. cy .. ' ' .. cz .. ' with size ' .. lenx .. 'x' .. leny .. 'x' .. lenz)

    local coriginx, coriginy, coriginz = cx * chunkSizeX, cy * chunkSizeY, cz * chunkSizeZ

    for rx = 0, lenx - 1 do
        for ry = 0, leny - 1 do
            for rz = 0, lenz - 1 do
                local id, data, extra = getBlock(coriginx + rx, coriginy + ry, coriginz + rz)

                local key = tostring(id)
                if data ~= 0 then key = key .. ':' .. data end
                if extra then key = key .. '/' .. extra end

                materialList[key] = (materialList[key] or 0) + 1
                palette[key] = true
            end
        end
    end
end

forEachChunk(populateMatList)

local matls = {}
for k, v in pairs(materialList) do
    table.insert(matls, { k, v })
end

table.sort(matls, function(a, b)
    return a[2] > b[2]
end)

outFile:write(string.pack('>I1', #matls))

local nextMatId = 0

print('Material list:')
for _, el in ipairs(matls) do
    local k, v = table.unpack(el)
    print(k, v)
    palette[k] = nextMatId
    outFile:write(string.pack('>I4', k:len()))
    outFile:write(k)
    nextMatId = nextMatId + 1
end

local emptyChunks = {}
local bitIndex = 0
local currByte = 0

local function writeNextChunkPresenceBit(bool)
    local bit = 0
    if bool then bit = 1 end
    currByte = currByte << 1 | bit

    if bitIndex == 7 then
        print(currByte)
        outFile:write(string.pack('>I1', currByte))
        currByte = 0
        bitIndex = 0
    else
        bitIndex = bitIndex + 1
    end
end

local function finishWritingChunkPresence()
    while bitIndex > 0 do
        writeNextChunkPresenceBit(true)
    end
end

local function writeChunkPresence(cx, cy, cz, lenx, leny, lenz)
    local empty = isChunkEmpty(cx, cy, cz, lenx, leny, lenz)
    print('Chunk: ' ..
    cx .. ' ' .. cy .. ' ' .. cz .. ' with size ' .. lenx .. 'x' .. leny .. 'x' .. lenz .. ': ' .. tostring(empty))

    emptyChunks[string.format('%s,%s,%s', cx, cy, cz)] = empty

    writeNextChunkPresenceBit(empty)
end

forEachChunk(writeChunkPresence)
finishWritingChunkPresence()

local function writeOneChunk(cx, cy, cz, lenx, leny, lenz)
    print('Chunk: ' .. cx .. ' ' .. cy .. ' ' .. cz .. ' with size ' .. lenx .. 'x' .. leny .. 'x' .. lenz)

    if emptyChunks[string.format('%s,%s,%s', cx, cy, cz)] then
        print('..skipped..')
        return
    end

    local coriginx, coriginy, coriginz = cx * chunkSizeX, cy * chunkSizeY, cz * chunkSizeZ

    for rx = 0, lenx - 1 do
        for ry = 0, leny - 1 do
            for rz = 0, lenz - 1 do
                local id, data, extra = getBlock(coriginx + rx, coriginy + ry, coriginz + rz)

                local key = tostring(id)
                if data ~= 0 then key = key .. ':' .. data end
                if extra then key = key .. '/' .. extra end

                local paletteId = palette[key]
                if not paletteId then error('mat not found', paletteId) end

                outFile:write(string.pack('>I1', paletteId))
            end
        end
    end
end

forEachChunk(writeOneChunk)

outFile:close()
