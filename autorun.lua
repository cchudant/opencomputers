
local fs = require('filesystem')
local inet = require('internet')

local repoPrefix = 'https://raw.githubusercontent.com/cchudant/opencomputers/master/'

local function splitParent(path)
    local file = string.gmatch('/' .. path, '/([^/]+)$')()
    local dir = path:sub(1, -file:len() - 2)
    return dir, file
end

local function mkdirs(path)
    if path == '' then return end
    local dir, _filename = splitParent(path)
    mkdirs(dir)
    fs.makeDirectory(path)
end

local function downloadFile(path, dest)
    local filePath = dest .. path
    local dir, _filename = splitParent(filePath)
    mkdirs(dir)

    local req = inet.request(repoPrefix .. path, 'w')
    local file = fs.open(filePath)
    for chunk in req do
        file:write(chunk)
    end
    file:close()



end

local dest = '/home/testdl/'

downloadFile('manifest.txt', dest)

    
