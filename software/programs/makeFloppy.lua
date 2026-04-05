local shell = require('shell')
local component = require('component')
local util = require('.software.apis.util')
local filesystem = require('filesystem')

local args, ops = shell.parse(...)

local function showUsage()
    print('Make an installation floppy disk.')
    print('Usage:')
    print('* `makeFloppy` -- use the connected disk drive')
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

local diskDrives = util.objectKeys(component.list('disk_drive'))

if #diskDrives == 0 then
    print("Error: No disk drive connected to the computer.")
    return
elseif #diskDrives > 1 then
    print("Error: There are " .. #diskDrives .. " disk drives currently connected to the computer. This program only supports one.")
    return
end

local diskDriveAddr = diskDrives[1]
local fsAddr, err = component.proxy(diskDriveAddr).media()

if not fsAddr then
    print("Error getting floppy address: " .. err)
    return
end

local mountPoint
for fs, mntPoint in filesystem.mounts() do
    if fs.address == fsAddr then
        mountPoint = mntPoint
        break
    end
end
if not mountPoint then
    print("Could not find mount point for filesystem address " .. fsAddr)
    return
end

filesystem.copy('/software/install.lua', mountPoint .. '/autorun.lua')

print('Installed to ' .. fsAddr)
