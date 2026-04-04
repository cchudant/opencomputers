local component = require('component')
local event = require('event')
local sides = require('sides')
local robot = require('robot')
local serialization = require('serialization')

-- All assemblers from left to right. (aka. right to left from robot POV)
local mapping = {
    "ea6eb93d-c089-4366-aa8d-6900ef702db5",
    "12ee1cd5-a218-4041-83fb-226cb30ef433",
    "8d53de12-3ade-494b-a34b-79224f0c9911",
    "8c91e20f-46ce-47f3-a901-ce70aeb69d9f",
    "cfebe06e-9abf-4936-b16d-9ae8500d0c18",
    "3a69dad4-aeeb-443a-9a1e-b46c98603be5",
}

local inv = component.inventory_controller
local rs = component.redstone
local modem = component.modem

modem.open(18)

local function newNonce()
    return math.random(1, 100000)
end

local function send(method, data, nonce)
    if nonce == nil then
        nonce = newNonce()
    end
    modem.broadcast(18, serialization.serialize({
        method = method,
        nonce = nonce,
        data = data,
    }))
end

local function waitReceive(methodFilter, nonce)
    while true do
        local _, _localAddr, _remoteAddr, port, _distance, data = event.pull('modem_message')
        if port == 18 and type(data) == "string" then
            local got = serialization.unserialize(data)
            if got ~= nil and type(got['method']) == 'string' and type(got['nonce']) == 'number'
                and (methodFilter == nil or got['method'] == methodFilter)
                and (nonce == nil or got['nonce'] == nonce)
            then
                return got['data'], got['method'], got['nonce']
            end
        end
    end
end

local function sendRoundtrip(method, data)
    local nonce = newNonce()
    send(method, data, nonce)

    local ret = waitReceive(method .. 'Rep', nonce)
    return ret
end

local oppositeSide = {
    [sides.bottom] = sides.top,
    [sides.top] = sides.bottom,
    [sides.back] = sides.front,
    [sides.front] = sides.back,
    [sides.right] = sides.left,
    [sides.left] = sides.right,
}

local function travel(side, number)
    if number < 1 then
        side = oppositeSide[side]
        number = -number
    end
    if number == 0 then return end

    if side == sides.right then
        robot.turnRight()
        for _ = 1, number do
            while not robot.forward() do end
        end
        robot.turnLeft()
    elseif side == sides.left then
        robot.turnLeft()
        for _ = 1, number do
            while not robot.forward() do end
        end
        robot.turnRight()
    elseif side == sides.front then
        for _ = 1, number do
            while not robot.forward() do end
        end
    elseif side == sides.back then
        for _ = 1, number do
            while not robot.back() do end
        end
    elseif side == sides.top then
        for _ = 1, number do
            while not robot.up() do end
        end
    elseif side == sides.down then
        for _ = 1, number do
            while not robot.down() do end
        end
    end
end


---@type { [number]: boolean }
local running = {}

while true do
    print("Checking assemblers status...")

    local statuses = sendRoundtrip("status", mapping)

    local idleIndex
    local completedIndex
    for i, status in ipairs(statuses) do
        if status == "idle" and running[i] then
            completedIndex = i
            break
        elseif status == "idle" then
            idleIndex = i
            break
        end
    end

    if completedIndex ~= nil then
        -- get the completed recipe

        local completedAddr = mapping[completedIndex]
        print("Getting completed: index=" .. completedIndex .. " " .. " addr=" .. completedAddr)

        running[completedIndex] = nil

        travel(sides.left, completedIndex - 1)
        robot.select(1)
        robot.suck(64)
        travel(sides.right, completedIndex - 1)

        robot.dropUp()

    elseif rs.getInput(sides.right) == 15 and idleIndex ~= nil then
        -- start new recipe

        local idleAddr = mapping[idleIndex]
        print("Starting assembley: index=" .. idleIndex .. " " .. " addr=" .. idleAddr)

        local recipesize = 0
        for i = 1, inv.getInventorySize(sides.down) do
            local got = inv.getStackInSlot(sides.down, i)
            if got ~= nil then
                recipesize = recipesize + got.size
            end
        end
        robot.select(1)
        for _ = 1, recipesize do
            robot.suckDown(1)
        end

        travel(sides.left, idleIndex - 1)

        print("Giving components...")

        for i = 1, robot.inventorySize() do
            if robot.count(i) > 0 then
                robot.select(i)
                robot.drop()
            end
        end

        send('assemble', idleAddr)
        running[idleIndex] = true
        print("Sent assembly request.")

        travel(sides.right, idleIndex - 1)
    else
        print("Waiting.")

        -- event.pullMultiple('redstone_changed', 'modem_message')
        os.sleep(2)
    end
end
