-- Modified from https://github.com/DOOBW/OC-GPS.

local args = { ... }
local gps = require('.software.apis.gps')
local component = require('component')

local channel = 46
local x, y, z = nil, nil, nil
local command = args[1]

local function usage()
    print('Usage:')
    print('gps locate')
    print('gps host [<x> <y> <z>]')
    os.exit()
end

if command == 'locate' then
    gps.locate(2, true)
elseif command == 'host' then
    if component.isAvailable('tablet') then
        print('Tablets cannot act as GPS hosts.')
        return
    end
    if #args >= 4 then
        x = tonumber(args[2])
        y = tonumber(args[3])
        z = tonumber(args[4])
        if x == nil or y == nil or z == nil then
            usage()
        end
        print('Position is ' .. x .. ', ' .. y .. ', ' .. z)
    else
        x, y, z = gps.locate(2, true)
        if x == nil then
            print('Run \"gps host <x> <y> <z>\" to set position manually')
            os.exit()
        end
    end
    -- local event = require('event')
    local modem = component.modem
    if modem.isWireless() then
        print('Serving GPS requests')
    else
        print('No modem attached')
        os.exit()
    end
    -- local term = require('term')
    modem.open(channel)
    -- local served = 0
    while true do
        -- local e = { event.pull('modem_message') }
        os.sleep(5)
        -- if e[6] == 'PING' then
        modem.broadcast(channel, 'GPS', x, y, z)
        -- served = served + 1
        -- if served > 1 then
        --     local x_, y_ = term.getCursor()
        --     term.setCursor(x_, y_ - 1)
        -- end
        -- print(served .. ' GPS Requests served')
        -- end
    end
else
    usage()
end
