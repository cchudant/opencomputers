local port, gpsPort = 20, 46

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
---@type drone.Position
drone.home = { 0, 0, 0 }

---List of previous gps messages, one per station.
drone.gpsMsgs = {}

---@alias drone.Position [number, number, number]

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
    drone.move(x - p[1], y - p[2], z - p[3])
end

---Returns true if the drone is still.
function drone.isStill()
    return (drone.getOffset() < .05 and drone.getVelocity() < .05)
end

local code = ""
local usr = nil
local function userRoutine()
    local f, e = load(code)
    if not f then error(e) end
    f()
    usr = nil
end

local function inv3(M)
    local a, b, c, d, e, f, g, h, i = table.unpack(M)
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

local function calcPoint(stations)
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
local function handleModem(s)
    if s[6] == 'echo' then
        modem.send(s[3], "drone")
    elseif s[6] == 'flash' then
        code = s[7]
        computer.beep(1000, 1)
        usr = nil
    elseif s[6] == 'start' then
        usr = coroutine.create(userRoutine)
    elseif s[6] == "GPS" then
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
        table.insert(drone.gpsMsgs, { st = st, pos = { x, y, z, dist } })
        if #drone.gpsMsgs >= 4 then
            local sts = {}
            for _, el in ipairs(drone.gpsMsgs) do
                table.insert(sts, el.pos)
            end
            local success, result = pcall(calcPoint, sts)
            if success then
                drone.position = result
                drone.gpsUpdatedAt = computer.uptime()
            else
                print('GPS Error: ', result)
            end
        end
    end
end

if modem ~= nil then
    modem.open(port)
    modem.open(gpsPort)
end

computer.beep(1000, 1)
modem.broadcast(port, "drone")

local function main()
    local isErr = false
    local timeout = 10
    while true do
        print('Waiting with timeout: ' .. timeout)
        local s = { computer.pullSignal(timeout) }
        timeout = 10

        print('Got signal:', table.unpack(s))
        if s[1] == "modem_message" then
            handleModem(s)
        end
        if usr then
            print("Resuming coro")
            drone.setLightColor(0x00ff00) -- Green: running

            local e, t = coroutine.resume(usr, table.unpack(s))
            if not e then
                print('Routine error', t)
                drone.setStatusText(tostring(t))
                isErr = true
                usr = nil
            elseif type(t) == 'number' then
                timeout = t
            end
        else
            if isErr then
                drone.setLightColor(0xff0000) -- Red: error
            else
                drone.setLightColor(0xffff00) -- Yellow: waiting
            end
        end
    end
end

local ok,e = pcall(main)
if not ok then
    print(e)
    drone.setStatusText(tostring(e))
    drone.setLightColor(0xff0000) -- Red: error
    drone.sleep(300)
end
