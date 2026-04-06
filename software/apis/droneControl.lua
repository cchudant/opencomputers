local io = require('io')
local component = require('component')
local event = require('event')
local util = require('.software.apis.util')
local term = require('term')

local modem = component.modem
local eeprom = component.eeprom

local goodColors = {
    0xe6194B,
    0xf58231,
    0xbfef45,
    0x3cb44b,
    0x4363d8,
    0x911eb4,
    0xf032e6,
    0x808000,
    0x469990
}

local function writeWithColor(text, color)
    local reset
    if term.gpu then
        reset = term.gpu().getForeground()
        term.gpu().setForeground(color)
    end
    _G.io.stdout:write(text)
    _G.io.stdout:flush()
    if term.gpu then
        term.gpu().setForeground(reset)
    end
end

local gray = 0xa9a9a9;

local flashPort = 20

local droneControl = {}

function droneControl.flashEeprom()
    local file = io.open('/software/drone/compiled', 'r') --[[@as file*]]
    local buffer = file:read('a')
    file:close()

    -- print('Size before minification: ' .. buffer:len() .. ' bytes')
    -- -- this minification is dumb and doesnt always work. oh well.
    -- buffer = buffer:gsub('[-][-][^\n]+', ''):gsub('\\s+', ' ')

    -- print('Size after minification: ' .. buffer:len() .. ' bytes')

    if not eeprom then
        print('No eeprom found.')
    else
        print('Size: ' .. buffer:len() .. ' / ' .. eeprom.getSize())
        eeprom.set(buffer)
        eeprom.setLabel('Drone EEPROM')
        print("Done!")
    end
end

function droneControl.logDrones()
    modem.open(flashPort)
    modem.broadcast(flashPort, 'echo')
    print('Listening.')
    while true do
        local ev = { event.pull('modem_message') }
        local addr = ev[3]
        local color = goodColors[(tonumber(string.sub(addr, -6), 16) % (#goodColors - 1) + 1)]
        local shortAddr = string.sub(addr, 1, 6)
        if ev[6] == 'drone' then
            writeWithColor("[", gray)
            writeWithColor(shortAddr, color)
            writeWithColor(" online]\n", gray)
        elseif ev[6] == 'log' then
            writeWithColor(shortAddr, color)
            writeWithColor(": " .. ev[7] .. "\n", gray)
        end
    end
end

return droneControl
