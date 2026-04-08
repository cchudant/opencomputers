-- Originated from https://gist.github.com/Dudblockman/72fc410c88124d212e470fb481852492,
-- heavily modified.
-- The original had its coroutine handling done very differently, I fixed it to the proper way
-- of doing it, among other things.

local port, gpsPort = 20, 46
local isErr = false

for add, typ in pairs(component.list()) do
    if _ENV[typ] == nil then
        _ENV[typ] = component.proxy(add)
    end
end

function print(...)
    local a = table.pack(...)
    local m = ""
    for i = 1, a.n do
        if i > 1 then m = m .. '\t' end
        m = m .. (tostring(a[i]) or '<unknown>')
    end
    modem.broadcast(port, "log", m)
end

---@type drone.Position
drone.position = { 0, 0, 0 }

---List of previous gps messages, one per station.
drone.gpsMsgs = {}

---@alias drone.Position [number, number, number]

local rawpull = computer.pullSignal
function computer.pullSignal(timeout)
    local deadline = computer.uptime() +
        (type(timeout) == "number" and timeout or math.huge)
    repeat
        print('yielding')
        local signal = table.pack(coroutine.yield(deadline - computer.uptime()))
        if signal.n > 0 then
            return table.unpack(signal, 1, signal.n)
        end
    until computer.uptime() >= deadline
end

---@param timeout number?
function drone.sleep(timeout)
    computer.pullSignal(timeout)
end

---Move the drone relative to the current location.
---@overload fun(x: number, y: number, z: number)
---@overload fun(pos: drone.Position)
function drone.moveRel(x, y, z)
    if type(x) == "table" then
        x, y, z = table.unpack(x)
    end
    local p = drone.position
    drone.moving = true
    drone.gpsMsgs = {} -- Clear gps messages.
    component.invoke(drone.address, "move", x, y, z)
    while not drone.isStill() do
        drone.sleep(0.1) -- Wait for drone to be still.
    end
    drone.position = { p[1] + x, p[2] + y, p[3] + z }
    drone.moving = false
end

---Move to a position.
---@overload fun(x: number, y: number, z: number)
---@overload fun(pos: drone.Position)
function drone.moveTo(x, y, z)
    if type(x) == "table" then
        x, y, z = table.unpack(x)
    end
    local p = drone.position
    drone.moveRel(x - p[1], y - p[2], z - p[3])
end

---Returns true if the drone is still.
function drone.isStill()
    return drone.getOffset() < .05 and drone.getVelocity() < .05
end

local code = ""
local usr = nil
local function userRoutine(...)
    isErr = false
    local f, e = load(code, '=droneScript.lua')
    if not f then error(e) end
    f(...)
    usr = nil
end

local function inv3(M)
    local a, b, c, d, e, f, g, h, i = table.unpack(M)
    local det = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g)
    if det == 0 then
        error('ambiguous')
    end
    local id = 1 / det
    return {
        (e * i - f * h) * id, (c * h - b * i) * id, (b * f - c * e) * id,
        (f * g - d * i) * id, (a * i - c * g) * id, (c * d - a * f) * id,
        (d * h - e * g) * id, (b * g - a * h) * id, (a * e - b * d) * id
    }
end

local function calcPoint(s)
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
local function handleModem(s)
    if s[6] == 'echo' then
        local status = 'idle'
        if usr then status = 'running' end
        modem.send(s[3], port, 'status', status)
    elseif s[6] == 'run' and not usr then
        code = s[7]
        usr = coroutine.create(function() return userRoutine(table.unpack(s, 8)) end)
        print('User code started.')
    elseif s[6] == 'GPS' then
        local _, _, st, _, dist, _, x, y, z = table.unpack(s)
        if drone.moving then
            return
        end

        local i = 1 -- List remove if
        while i < #drone.gpsMsgs do
            if drone.gpsMsgs[i].st == st then
                table.remove(drone.gpsMsgs, i)
            else
                i = i + 1
            end
        end
        table.insert(drone.gpsMsgs, 1, { st = st, pos = { x, y, z, dist } })
        if #drone.gpsMsgs >= 4 then
            while #drone.gpsMsgs > 4 do
                table.remove(drone.gpsMsgs, #drone.gpsMsgs)
            end
            local sts = {}
            for j = 1, 4 do
                table.insert(sts, drone.gpsMsgs[j].pos)
            end
            local ok, r = pcall(calcPoint, sts)
            if ok then
                drone.position = { r[1] + .5, r[2] + .5, r[3] + .5 }
                drone.gpsUpdatedAt = computer.uptime()
                print('GPS position: ', table.unpack(drone.position))
            else
                print('GPS Error: ', r)
            end
        end
    end
end

if modem ~= nil then
    modem.open(port)
    modem.open(gpsPort)
end

computer.beep(1000, 0.5)
modem.broadcast(port, 'started')


local function main()
    local lastGpsPing
    local timeout = 5
    while true do
        if isErr then
            drone.setLightColor(0xff0000) -- Red: error
        else
            drone.setLightColor(0xffff00) -- Yellow: waiting
        end

        local ts = computer.uptime()
        if not drone.moving and
            (not drone.gpsUpdatedAt or ts > drone.gpsUpdatedAt + 30) and (not lastGpsPing or ts > lastGpsPing + 5) then
            modem.broadcast(gpsPort, 'PING')
            print('pinged')
            lastGpsPing = ts
            timeout = math.min(timeout, 3)
        end

        print('pull signal??', timeout)
        local s = { rawpull(timeout) }
        timeout = 5

        if s[1] == "modem_message" then
            handleModem(s)
        end
        if usr then
            print("Resuming coro")
            drone.setLightColor(0x00ff00) -- Green: running

            local ok, t = coroutine.resume(usr, table.unpack(s))
            print("Coro returned", ok, t)
            if not ok then
                print('Routine error', t)
                computer.beep(500, 0.5)
                drone.setStatusText(tostring(t))
                isErr = true
                usr = nil
            elseif type(t) == 'number' then
                timeout = t
            end
        end
    end
end

local ok, e = pcall(main)
if not ok then
    print(e)
    drone.setStatusText(tostring(e))
    drone.setLightColor(0xff0000) -- Red: error
    computer.beep(500, 0.5)
    drone.sleep(300)
end
