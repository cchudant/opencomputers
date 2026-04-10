local io = require('io')
local component = require('component')
local event = require('event')
local term = require('term')
local computer = require('computer')

local function newNonce()
    return math.random(1, 10000000)
end

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

local dronePort = 20

local droneControl = {}

function droneControl.makeEeprom()
    local file = io.open('/software/drone/compiled', 'r') --[[@as file*]]
    local buffer = file:read('a')
    file:close()

    -- print('Size before minification: ' .. buffer:len() .. ' bytes')
    -- -- this minification is dumb and doesnt always work. oh well.
    -- buffer = buffer:gsub('[-][-][^\n]+', ''):gsub('\\s+', ' ')

    -- print('Size after minification: ' .. buffer:len() .. ' bytes')

    local eeprom = component.eeprom
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
    if term.gpu then
        term.gpu().setResolution(term.gpu().maxResolution())
    end
    local modem = component.modem
    modem.open(dronePort)
    modem.broadcast(dronePort, 'status', 1)
    print('Listening.')
    while true do
        local ev = { event.pull('modem_message') }
        local addr = ev[3]
        local color = goodColors[(tonumber(string.sub(addr, -6), 16) % (#goodColors - 1) + 1)]
        local shortAddr = string.sub(addr, 1, 6)
        if ev[6] == 'started' then
            writeWithColor("[", gray)
            writeWithColor(shortAddr, color)
            writeWithColor(" started]\n", gray)
        elseif ev[6] == 'status' then
            writeWithColor("[", gray)
            writeWithColor(shortAddr, color)
            writeWithColor(" status: " .. ev[7] .. "]\n", gray)
        elseif ev[6] == 'log' then
            writeWithColor(shortAddr, color)
            writeWithColor(": " .. ev[7] .. "\n", gray)
        end
    end
end

---@overload fun(droneAddr: string|nil, path: string, ...) run a program on a drone or all drones
function droneControl.run(droneAddr, path, ...)
    local file = io.open(path, 'r')

    local modem = component.modem
    if not file then
        error('File not found: "' .. path .. '"')
    end
    -- perform basic minification (without losing line numbers!)
    local content = file:read('a'):gsub("[ ]+", " "):gsub("[ ]*[-][-][^\n]*\n", "\n"):gsub("\n ", "\n")
    file:close()
    if droneAddr then
        modem.send(droneAddr, dronePort, 'run', content, ...)
    else
        modem.broadcast(dronePort, 'run', content, ...)
    end
end

---@param n nil|number
---@return string[] addresses
function droneControl.getWaitingDrones(timeout, n)
    local found = {}
    local deadline = computer.uptime() + timeout
    local nonce = newNonce()
    local modem = component.modem
    modem.open(dronePort)
    modem.broadcast(dronePort, 'status', nonce)
    while computer.uptime() <= deadline and not (n and #found >= n) do
        local tout = deadline - computer.uptime()
        local ev = { event.pull(tout, 'modem_message') }
        if ev[6] == 'status' and ev[7] == 'idle' and ev[8] == nonce then
            table.insert(found, ev[3])
        end
    end
    return found
end

return droneControl
