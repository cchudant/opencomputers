local chunksizeX, chunksizeY, chunksizeZ = 16, 1, 16

local schematic = {}

---@class schematic.Chunk
---@field cx number
---@field cy number
---@field cz number
---@field lenx number
---@field leny number
---@field lenz number
---@field materials { [string]: number }
---@field blocks string[]
schematic.Chunk = {}
schematic.Chunk.__index = schematic.Chunk

---@class schematic.Schematic
---@field file file*
---@field xlength number
---@field ylength number
---@field zlength number
---@field nMats number
---@field palette { [string]: number }
---@field revPalette { [number]: string }
---@field nonEmptyChunks { [string]: true }
---@field nChunksX number
---@field nChunksY number
---@field nChunksZ number
---@field nextChunkX number
---@field nextChunkY number
---@field nextChunkZ number
schematic.Schematic = {}
schematic.Schematic.__index = schematic.Schematic

function schematic.Schematic.load(filename)
    local file = io.open(filename, 'rb') --[[@as file*]]

    local xlength, ylength, zlength, nMats = string.unpack('>I4>I4>I4>I1', file:read(4 * 3 + 1))

    -- Material key to palette id
    local palette = {}
    -- Palette id to material key
    local revPalette = {}

    -- Read material list

    for matId = 0, nMats - 1 do
        local strlen = string.unpack('>I4', file:read(4))
        local matkey = file:read(strlen)
        palette[matkey] = matId
        revPalette[matId] = matkey
    end

    local nChunksX = math.ceil(xlength / chunksizeX)
    local nChunksY = math.ceil(ylength / chunksizeY)
    local nChunksZ = math.ceil(zlength / chunksizeZ)

    local function forEachChunk(func)
        for cy = 0, nChunksY - 1 do
            local leny = chunksizeY
            if cy == nChunksY - 1 then leny = (ylength - 1) % chunksizeY + 1 end

            for cz = 0, nChunksZ - 1 do
                local lenz = chunksizeZ
                if cz == nChunksZ - 1 then lenz = (zlength - 1) % chunksizeZ + 1 end

                for cx = 0, nChunksX - 1 do
                    local lenx = chunksizeX
                    if cx == nChunksX - 1 then lenx = (xlength - 1) % chunksizeX + 1 end

                    func(cx, cy, cz, lenx, leny, lenz)
                end
            end
        end
    end

    -- Read chunk map

    -- Chunk x,y,z to boolean
    local nonEmptyChunks = {}
    local bitIndex = -1
    local currByte = 0

    local function readNextBitmapBit()
        if bitIndex == -1 then
            bitIndex = 7
            currByte = string.unpack('>I1', file:read(1))
        end
        local val = ((currByte >> bitIndex) & 1) == 1
        bitIndex = bitIndex - 1
        return val
    end

    local function readChunkMap(cx, cy, cz, lenx, leny, lenz)
        local empty = readNextBitmapBit()
        if not empty then nonEmptyChunks[string.format('%s,%s,%s', cx, cy, cz)] = true end

    end

    forEachChunk(readChunkMap)

    return setmetatable({
        file = file,
        xlength = xlength,
        ylength = ylength,
        zlength = zlength,
        nMats = nMats,
        palette = palette,
        revPalette = revPalette,
        nonEmptyChunks = nonEmptyChunks,
        nChunksX = nChunksX,
        nChunksY = nChunksY,
        nChunksZ = nChunksZ,
        nextChunkX = 0,
        nextChunkY = 0,
        nextChunkZ = 0,
    }, schematic.Schematic)
end

function schematic.Schematic:close()
    self.file:close()
end

---@return schematic.Chunk?
function schematic.Schematic:nextChunk()
    local cx, cy, cz, lenx, leny, lenz
    repeat
        -- Check exhaustion
        if self.nextChunkY >= self.nChunksY then
            return nil
        end

        cx, cy, cz = self.nextChunkX, self.nextChunkY, self.nextChunkZ

        lenx = cx == self.nChunksX - 1 and (self.xlength - 1) % chunksizeX + 1 or chunksizeX
        leny = cy == self.nChunksY - 1 and (self.ylength - 1) % chunksizeY + 1 or chunksizeY
        lenz = cz == self.nChunksZ - 1 and (self.zlength - 1) % chunksizeZ + 1 or chunksizeZ

        -- Advance for next call
        self.nextChunkX = self.nextChunkX + 1
        if self.nextChunkX >= self.nChunksX then
            self.nextChunkX = 0
            self.nextChunkZ = self.nextChunkZ + 1
            if self.nextChunkZ >= self.nChunksZ then
                self.nextChunkZ = 0
                self.nextChunkY = self.nextChunkY + 1
            end
        end
    until self.nonEmptyChunks[string.format('%s,%s,%s', cx, cy, cz)]

    local chunkBuf = self.file:read(lenx * leny * lenz)
    local materials = {}

    local i = 1
    local blocks = {}
    for _ = 0, lenx - 1 do
        for _ = 0, leny - 1 do
            for _ = 0, lenz - 1 do
                local mat = self.revPalette[string.byte(chunkBuf, i)]
                table.insert(blocks, mat)
                materials[mat] = (materials[mat] or 0) + 1
                i = i + 1
            end
        end
    end

    return setmetatable({
        cx = cx,
        cy = cy,
        cz = cz,
        lenx = lenx,
        leny = leny,
        lenz = lenz,
        materials = materials,
        blocks = blocks,
    }, schematic.Chunk)
end

---@return fun(): schematic.Chunk?
function schematic.Schematic:chunks()
    return function()
        return self:nextChunk()
    end
end

return schematic
