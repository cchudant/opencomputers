local io = require('io')
local component = require('component')
local util = require('.software.apis.util')

local flash = {}
flash.libs = {
    "/software/apis/util.lua",
}

local function injectLibs()
    local buffer = ''
    for _, path in ipairs(flash.libs) do
        local module = path:gsub('/', '.'):gsub('.lua$', '')
        local file = io.open(path, 'r')
        if not file then error(string.format('file not found: %s')) end

        local content = file:read("a"):gsub('--.+', ''):gsub('\\s+', '')

        buffer = buffer .. 'do\n'
            .. 'local res, err = load([[\n' .. content .. '\n'
            .. ']], "=" .. path, "bt", _G)\n'
            .. 'if err then return nil, err end\n'
            .. 'require.loaded["' .. module .. '"] = res'
            .. 'end'

        file:close()
    end
    return buffer
end

local buffer = ''

local libsInjected = false

local file = io.open('/software/drone/eeprom.lua', 'r') --[[@as file*]]
for line in file:lines() do
    if not libsInjected and util.stringStartsWith(line, '--[[ // include libs // ]]--') then
        buffer = buffer .. injectLibs() .. '\n'
        libsInjected = true
    else
        buffer = buffer .. line
    end
end
file:close()

component.eeprom.set(buffer)
print("Done!")
