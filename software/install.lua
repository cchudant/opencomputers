local fs = require('filesystem')
local inet = require('internet')
local io = require('io')
local shell = require('shell')

local args, ops = shell.parse(...)

local function showUsage()
    print('Install a github repo and set it as upstream.')
    print('Usage:')
    print('* `install` -- install from default repo and branch')
    print('* `install [branch]` -- choose a branch')
    print('* `install [repo] [branch]` -- choose a repo and branch')
    print('Example: `install xxx/yyy dev` will install github.com/xxx/yyy branch dev')
end

for k, _v in pairs(ops) do
    print('Unknown option: --' .. k)
    showUsage()
    return
end

if #args > 2 then
    showUsage()
    return
end

local repo, branch = args[1], args[2]
if not branch then
    branch = repo
    repo = nil
end

local repoPrefix
branch = branch or 'main'
if repo == nil then
    local file = io.open('/software/upstream', 'r')
    if file then
        repoPrefix = string.gsub(file:read(), "%s+", "")
        file:close()
    end
end

repo = repo or 'cchudant/opencomputers'

if not repoPrefix then
    repoPrefix = 'https://raw.githubusercontent.com/' .. repo .. '/' .. branch .. '/'
end

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

    print("Downloading " .. filePath .. "...")
    local req = inet.request(repoPrefix .. path)
    local file = io.open(filePath, 'w') --[[@as file*]]
    for chunk in req do
        file:write(chunk)
    end
    file:close()
end

mkdirs('/software')

local upstream = io.open('/software/upstream', 'w') --[[@as file*]]
upstream:write(repoPrefix)
upstream:close()

print('Installing from ' .. repoPrefix)

local dest = '/'

downloadFile('manifest.txt', dest)
local file = io.open(dest .. 'manifest.txt', 'r') --[[@as file*]]
for line in file:lines() do
    downloadFile(line, dest)
end

local shrcAddition = "require('shell').setPath(shell.getPath()..':/software/programs')"

local shrcFile = io.open('/home/.shrc', 'r')
local isAlreadyAdded = false
if shrcFile then
    for line in shrcFile:lines() do
        if line == shrcAddition then
            isAlreadyAdded = true
            return
        end
    end
    shrcFile:close()
end

if not isAlreadyAdded then
    shrcFile = io.open('/home/.shrc', 'a') --[[@as file*]]
    shrcFile:write('\n' .. shrcAddition .. '\n')
    shrcFile:close()
end

print('Done! You may need to reboot your system.')
