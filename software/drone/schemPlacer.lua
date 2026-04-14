drone.gpsUpdatedAt = nil
drone.gpsMsgs = {}
drone.setAcceleration(9999999)

while not drone.gpsUpdatedAt do
    drone.setLightColor(0xFFFFFF)
    drone.setStatusText('GPS...')
    drone.sleep(1)
end
drone.setLightColor(0x00FF00)

local home = { 584.5, 141.5, -488.5 }

drone.moveTo(home)

local mall = { home[1] - 4, home[2], home[3] }
local safe1 = { home[1] - 30, home[2], home[3] }
local safe2 = { home[1] - 30, home[2] - 30, home[3] }

while computer.energy() < computer.maxEnergy() * 0.95 do
    drone.setLightColor(0xFFA500)
    drone.setStatusText('CHARGE')
    drone.sleep(1)
end
drone.setLightColor(0x00FF00)

local ic = inventory_controller
local sides = {
    negy = 0,
    posy = 1,
    negz = 2,
    posz = 3,
    negx = 4,
    posx = 5,
}

local function dump()
    for i = 1, drone.tankCount() do
        local level = drone.tankLevel(i)
        if level > 0 then
            drone.selectTank(i)
            drone.fill(sides.posz, level)
        end
    end
    for invi = 1, drone.inventorySize() do
        if drone.count(invi) then
            drone.select(invi)
            drone.drop(sides.posz, 64)
        end
    end
    drone.select(1)
end
dump()

local args = ...
---@return any, any
local function unser(data)
    local rs, re = load("return " .. data, "=data", nil, {})
    if not rs then
        return nil, re
    end
    local ok, o = pcall(rs)
    if not ok then
        return nil, o
    end
    return o
end

local x, y, z, xlen, _, zlen, blocks, mlist = table.unpack(unser(args))

drone.setStatusText(string.format('%s\n%s', x, z))

local function moveToBlock(x, y, z)
    if type(x) == 'table' then x, y, z = table.unpack(x) end
    drone.moveTo(x + .5, y + .5, z + .5)
end

local function mat(el)
    if not el then return nil end
    if not el.damage or el.damage == 0 then
        return tostring(el.id)
    end
    return el.id .. ':' .. el.damage
end

local stock = {
    "2289",
    "3",
    "1",
    "2",
    "2055:8"
}

local lqds = {
    ['2055:10'] = "poison",
    ['2055:11'] = "water",
    ['2055:14'] = "lava",
    ['2055:15'] = "oil",
}

local got = {}

local function recompGot(m)
    got[m] = 0
    for i = 1, drone.inventorySize() do
        local item = ic.getStackInInternalSlot(i)
        if mat(item) == m then
            got[m] = got[m] + item.size
        end
    end
end
local function hasRoom(m)
    for i = 1, drone.inventorySize() do
        local item = ic.getStackInInternalSlot(i)
        if not item or (mat(item) == m and item.size < item.maxSize) then
            return true
        end
    end
    return false
end

-- Outer loop: dump, do groceries, then place, come back.
local didSmth = true
local notEnoughSpace = false
while didSmth or notEnoughSpace do
    didSmth = false
    notEnoughSpace = false

    -- Do groceries: get batch items

    drone.moveTo(mall)
    repeat
        local gotAll = true
        for _, m in ipairs(stock) do
            local n = (mlist[m] or 0) - (got[m] or 0)
            if n > 0 and not lqds[m] and m ~= '0' then
                if not hasRoom(m) then
                    notEnoughSpace = true
                else
                    gotAll = false
                    for i = 1, ic.getInventorySize(sides.posz) do
                        local it = ic.getStackInSlot(sides.posz, i)
                        if m == mat(it) and ic.suckFromSlot(sides.posz, i, math.min(n, 64, it.size)) then
                            -- we don't know how many we sucked, recompute it. (necessary for inter-drone race conditions)
                            recompGot(m)
                        end
                    end
                end
            end
        end
    until gotAll

    -- Next, the other items.

    drone.moveRel(1, 0, 0)
    repeat
        local gotAll = true
        for _, m in ipairs(mlist) do
            local n = (mlist[m] or 0) - (got[m] or 0)
            if n > 0 and not lqds[m] and m ~= '0' then
                if not hasRoom(m) then
                    notEnoughSpace = true
                else
                    gotAll = false
                    for i = 1, ic.getInventorySize(sides.posz) do
                        local it = ic.getStackInSlot(sides.posz, i)
                        if m == mat(it) and ic.suckFromSlot(sides.posz, i, math.min(n, 64, it.size)) then
                            -- we don't know how many we sucked, recompute it. (necessary for inter-drone race conditions)
                            recompGot(m)
                        end
                    end
                end
            end
        end
    until gotAll

    -- Get liquids from mall.

    drone.moveRel(-1, 0, 0)
    local tSts = {} -- Tank statuses
    for _ = 1, drone.tankCount() do
        table.insert(tSts, { lqd = nil, cnt = 0 })
    end

    for _ = 1, 4 do
        drone.moveRel(-1, 0, 0)
        local flds = tank_controller.getFluidInTank(sides.posz)

        for m, n in pairs(lqds) do
            if flds and flds[1] and n == flds[1].name then
                -- find empty/tank with same fluid
                for tI, sts in ipairs(tSts) do
                    if not sts.lqd or sts.lqd == n then
                        drone.selectTank(tI)
                        local tkn = math.min(math.floor(drone.tankSpace(tI) / 1000), (mlist[m] or 0) - (got[m] or 0))
                        drone.drain(sides.posz, tkn * 1000)
                        got[m] = (got[m] or 0) + tkn
                        sts.lqd = n
                        sts.cnt = sts.cnt + tkn * 1000
                    end
                end
                if (mlist[m] or 0) - (got[m] or 0) > 0 then
                    notEnoughSpace = true
                end
            end
        end
    end

    -- We're ready!

    -- Go to location.

    drone.moveTo(safe1)
    drone.moveTo(safe2)

    moveToBlock(x, y + 16, z)

    local placeLqds = false -- place liquids after blocks
    local continue
    repeat
        continue = false
        local j = 1
        for dx = 0, xlen - 1 do
            for dz = 0, zlen - 1 do
                local b = blocks[j]

                if b ~= '0' and lqds[b] and placeLqds then
                    for tankI, sts in ipairs(tSts) do
                        if sts.lqd == lqds[b] and sts.cnt > 0 then
                            drone.selectTank(tankI)
                            moveToBlock(x + dx, y + 1, z + dz)
                            drone.fill(sides.negy, 1000)
                            sts.cnt = sts.cnt - 1000
                            continue = true
                            blocks[j] = '0'
                            mlist[b] = mlist[b] - 1
                            didSmth = true
                            break
                        end
                    end
                elseif b ~= '0' then
                    for invI = 1, drone.inventorySize() do
                        if mat(ic.getStackInInternalSlot(invI)) == b then
                            drone.select(invI)
                            moveToBlock(x + dx, y + 1, z + dz)
                            if drone.place(sides.negy) or drone.detect(sides.negy) then
                                continue = true
                                blocks[j] = '0'
                                mlist[b] = mlist[b] - 1
                                didSmth = true
                            end
                            break
                        end
                    end
                end
                j = j + 1
            end
        end
        if not placeLqds and not continue then
            placeLqds = true
            continue = true
        end
    until not continue -- nothing could be placed

    drone.moveRel(0, 5, 0)
    drone.moveTo(safe2)
    drone.moveTo(safe1)
    drone.moveTo(home)
    dump()
    got = {}
end

modem.broadcast(732, 'schemPlacerFinished', x, y, z)
