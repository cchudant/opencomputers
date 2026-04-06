local flashPort, gpsPort = 20, 46

for add, typ in pairs(component.list()) do
    if _ENV[typ] == nil then
        _ENV[typ] = component.proxy(add)
    end
end

function print(...)
    local args = table.pack(...)
    local msg = ""
    for i = 1, args.n do
        if i > 1 then msg = msg .. '\t' end
        msg = msg .. (tostring(args[i]) or '<unknown>')
    end
    modem.broadcast(flashPort, "log", msg)
end

---@type drone.Position
drone.position = { 0, 0, 0 }
---@type drone.Position
drone.home = { 0, 0, 0 }

---List of previous gps messages, one per station.
drone.gpsMessages = {}

---@alias drone.Position [number, number, number]

---@param timeout number?
function drone.sleep(timeout)
    computer.pullSignal(timeout)
end

---Move the drone relative to the current location.
---@overload fun(x: number, y: number, z: number)
---@overload fun(pos: drone.Position)
function drone.moveRel(...)
    local arg = { ... }
    if type(arg[1]) == "table" then
        arg = arg[1]
    end
    local pos = drone.position
    drone.moving = true
    drone.gpsMessages = {} -- Clear gps messages.
    component.invoke(drone.address, "move", arg[1], arg[2], arg[3])
    while not drone.isStill() do
        drone.sleep(0.1) -- Wait for drone to be still.
    end
    drone.position = { pos[1] + arg[1], pos[2] + arg[2], pos[3] + arg[3] }
    drone.moving = false
end

---Move to a position.
---@overload fun(x: number, y: number, z: number)
---@overload fun(pos: drone.Position)
function drone.moveTo(...)
    local arg = { ... }
    if type(arg[1]) == "table" then
        arg = arg[1]
    end
    local pos = drone.position
    drone.move(arg[1] - pos[1], arg[2] - pos[2], arg[3] - pos[3])
end

---Returns true if the drone is still.
function drone.isStill()
    return (drone.getOffset() < .05 and drone.getVelocity() < .05)
end

local userCode = ""
local usr = nil
local function userRoutine()
    local func, err = load(userCode)
    if not func then error(err) end
    func()
    usr = nil
end

local modemHandlers = {}
function modemHandlers.echo(signal)
    modem.send(signal[3], "drone")
end

function modemHandlers.flash(signal)
    userCode = signal[7]
    computer.beep(1000, 1)
    usr = nil
end

function modemHandlers.start(_)
    usr = coroutine.create(userRoutine)
end

local function inv3(matrix)
    local a, b, c, d, e, f, g, h, i = table.unpack(matrix)
    local det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    if det == 0 then
        return {}
    end
    local id = 1 / det
    return {
        (e * i - f * h) * id, (c * h - b * i) * id, (b * f - c * e) * id,
        (f * g - d * i) * id, (a * i - c * g) * id, (c * d - a * f) * id,
        (d * h - e * g) * id, (b * g - a * h) * id, (a * e - b * d) * id
    }
end

local function calculatePoint(stations)
    local s = stations
    local M = {}
    for i = 2, 4 do
        for j = 1, 3 do
            M[(i - 2) * 3 + j] = 2 * (s[i][j] - s[1][j])
        end
    end
    local Mi = inv3(M)
    local v = { 0, 0, 0 }
    for i = 1, 3 do
        local m = -1
        for j = 4, 1, -1 do
            v[i] = v[i] + m * (s[i + 1][j] * s[i + 1][j] - s[1][j] * s[1][j])
            m = 1
        end
    end
    local v2 = {}
    for i = 1, 9, 3 do
        table.insert(v2, v[1] * Mi[i] + v[2] * Mi[i + 1] + v[3] * Mi[i + 2])
    end
    return v2
end

function modemHandlers.gps(signal)
    local _, _, station, _, distance, _, x, y, z = table.unpack(signal)
    local timestamp = computer.uptime()

    if drone.moving then
        return
    end

    local i = 1 -- List remove if
    while i < #drone.gpsMessages do
        if drone.gpsMessages[i].station == station then
            table.remove(drone.gpsMessages, i)
        else
            i = i + 1
        end
    end
    table.insert(drone.gpsMessages, { station = station, ts = timestamp, pos = { x, y, z, distance } })
    if #drone.gpsMessages >= 4 then
        local stations = {}
        for _, el in ipairs(drone.gpsMessages) do
            table.insert(stations, el.pos)
        end
        local success, result = pcall(calculatePoint, stations)
        if success then
            drone.position = result
            drone.gpsUpdatedAt = computer.uptime()
        else
            print('GPS Error: ', result)
        end
    end
end

local function handleModem(signal)
    if signal[4] == flashPort then
        if modemHandlers[signal[6]] then
            modemHandlers[signal[6]](signal)
        end
    elseif signal[6] == "GPS" then
        modemHandlers["gps"](signal)
    end
end

if modem ~= nil then
    modem.open(flashPort)
    modem.open(gpsPort)
end

computer.beep(1000, 1)
modem.broadcast(flashPort, "drone")

local errored = false
local timeout = 10
while true do
    print('Waiting with timeout: ' .. timeout)
    local signal = { computer.pullSignal(timeout) }
    timeout = 10

    print('Got signal:', table.unpack(signal))
    if signal[1] == "modem_message" then
        handleModem(signal)
    end
    if usr then
        print("Resuming coro")
        drone.setLightColor(0x00ff00) -- Green: running

        local ret = { coroutine.resume(usr, table.unpack(signal)) }
        if not ret[1] then
            print('Routine error', ret[2])
            errored = true
            usr = nil
        elseif type(ret[2]) == 'number' then
            timeout = ret[2]
        end
    else
        if errored then
            drone.setLightColor(0xff0000) -- Red: error
        else
            drone.setLightColor(0xffff00) -- Yellow: waiting
        end
    end
end
