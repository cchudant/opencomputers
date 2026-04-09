while not drone.gpsUpdatedAt do
    drone.setLightColor(0xFFFFFF)
    drone.setStatusText('GPS...')
    drone.sleep(1)
end

while computer.energy() < computer.maxEnergy() * 0.95 do
    drone.setLightColor(0xFFA500)
    drone.setStatusText('CHARGE')
    drone.sleep(1)
end

local ic = inventory_controller
local sides = {
    negy = 0,
    posy = 1,
    negz = 2,
    posz = 3,
    negx = 4,
    posx = 5,
}
drone.stillOffsetAllowed = .4
drone.stillVelocityAllowed = .2

local function dump()
    for i = 1, drone.tankCount() do
        local level = drone.tankLevel(i)
        if level > 0 then
            drone.selectTank(i)
            drone.fill(sides.negy, level)
        end
    end
    for invi = 1, drone.inventorySize() do
        if drone.count(invi) then
            drone.select(invi)
            drone.drop(sides.negy, 64)
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

drone.setLightColor(0x00FF00)
drone.setStatusText(string.format('%s,%s,%s', x, y, z))

local home = drone.position
local mall = { home[1] - 3, home[2], home[3] }
local safe1 = { home[1] - 30, home[2], home[3] }
local safe2 = { home[1] - 30, home[2] - 30, home[3] }

local function moveToBlock(x, y, z)
    if type(x) == 'table' then x, y, z = table.unpack(x) end
    drone.moveTo(x + .5, y + .5, z + .5)
end

local function detToMat(el)
    if not el then return nil end
    if not el.damage or el.damage == 0 then
        return tostring(el.id)
    end
    return el.id .. ':' .. el.damage
end

local lqds = {
    ['2055:10'] = "poison",
    ['2055:11'] = "water",
    ['2055:14'] = "lava",
}

local got = {}

-- Get items.

drone.moveTo(mall)

local i = 1
while true do
    local gotAll = true
    for k, v in pairs(mlist) do
        if not lqds[k] and (got[k] or 0) < v then
            gotAll = false
            if i > 5 then
                print('Missing: ' .. k)
            else
                break
            end
        end
    end
    if gotAll then
        break
    elseif i > 5 then
        drone.sleep(5)
    end

    local mallSlot = 1
    for el in ic.getAllStacks(sides.posz) do
        local elId = detToMat(el)
        local needed = (mlist[elId] or 0) - (got[elId] or 0)

        if elId and needed > 0 then
            local sucked = ic.suckFromSlot(sides.posz, mallSlot, math.min(needed, 64, el.size))
            if sucked then
                -- we don't know how many we sucked, recompute it. (necessary for inter-drone race conditions)
                local cnt = 0
                for invi = 1, drone.inventorySize() do
                    local item = ic.getStackInInternalSlot(invi)
                    if detToMat(item) == elId then
                        cnt = cnt + item.size
                    end
                end
                got[elId] = cnt
            end
        end

        mallSlot = mallSlot + 1
    end

    i = i + 1
end

local tSts = {}
for _ = 1, drone.tankCount() do
    table.insert(tSts, { lqd = nil, cnt = 0 })
end

drone.moveRel(-2, 0, 0)

for _ = 1, 3 do
    drone.moveRel(-1, 0, 0)

    local flds = tank_controller.getFluidInTank(sides.posz)
    if #flds > 0 then
        local el = flds[1]
        for mat, lqdN in pairs(lqds) do
            if lqdN == el.name then
                local need = (mlist[mat] or 0) - (got[mat] or 0)
                -- find empty/tank with same fluid
                for tI, sts in ipairs(tSts) do
                    if need <= 0 then break end
                    if not sts.lqd or sts.lqd == lqdN then
                        drone.selectTank(tI)
                        local tkn = math.min(drone.tankSpace(tI), need * 1000)
                        drone.drain(sides.posz, tkn)
                        need = need - tkn
                        sts.lqd = lqdN
                        sts.cnt = sts.cnt + tkn
                    end
                end
            end
        end
    end
end

local acl = drone.getAcceleration()
drone.setAcceleration(999999)
drone.moveTo(safe1)
drone.moveTo(safe2)
drone.setAcceleration(acl)

moveToBlock(x, y + 16, z)

local j = 1
for dx = 0, xlen - 1 do
    for dz = 0, zlen - 1 do
        local b = blocks[j]

        if b ~= '0' then
            moveToBlock(x + dx, y + 1, z + dz)

            local placed = false

            if drone.detect(sides.negy) then
                placed = true
            elseif lqds[b] then
                for tankI, sts in ipairs(tSts) do
                    if sts.lqd == lqds[b] and sts.cnt > 0 then
                        drone.selectTank(tankI)
                        drone.fill(sides.negy, 1000)
                        sts.cnt = sts.cnt - 1000
                        placed = true
                        break
                    end
                end
            else
                for invI = 1, drone.inventorySize() do
                    if detToMat(ic.getStackInInternalSlot(invI)) == b then
                        drone.select(invI)
                        local res, err = drone.place(sides.negy)
                        if not res then
                            print('Could not place', err)
                        end
                        placed = true
                        break
                    end
                end
            end

            if not placed then
                print('Not placed: missing ' .. b)
            end
        end
        j = j + 1
    end
end

drone.setAcceleration(999999)
drone.moveTo(safe2)
drone.moveTo(safe1)
drone.setAcceleration(acl)
drone.moveTo(home)
dump()
