local args = ...
local function unserialize(data)
    local result, reason = load("return " .. data, "=data", nil, { math = { huge = math.huge } })
    if not result then
        return nil, reason
    end
    local ok, output = pcall(result)
    if not ok then
        return nil, output
    end
    return output
end

local x, y, z, xlen, _, zlen, blocks, matlist = table.unpack(unserialize(args) --[[@as table]])

local home = drone.position
local mall = { home[1] - 3, home[2], home[3] }
local safepoint1 = { home[1] - 30, home[2], home[3] }
local safepoint2 = { home[1] - 30, home[2] - 30, home[3] }

local sides = {
    negy = 0,
    posy = 1,
    negz = 2,
    posz = 3,
    negx = 4,
    posx = 5,
}

local function moveToBlock(x, y, z)
    if type(x) == 'table' then x, y, z = table.unpack(x) end
    drone.moveTo(x + .5, y + .5, z + .5)
end

local function itemDetailToMat(el)
    if not el then return nil end
    if not el.damage or el.damage == 0 then
        return el.id
    end
    return el.id .. ':' .. el.damage
end

local liquids = {
    ['2055:10'] = "poison",
    ['2055:11'] = "water",
    ['2055:14'] = "lava",
}

local got = {}
local i = 1

-- Get items.

drone.moveTo(mall)

while true do
    local gotAll = true
    for k, v in pairs(matlist) do
        if not liquids[k] and (got[k] or 0) < v then
            gotAll = false
            if i > 5 then
                print('Missing: ' .. k)
                drone.sleep(10)
            end
            break
        end
    end
    if gotAll then
        print('Got everything from mall!')
        break
    end

    for el in inventory_controller.getAllStacks(sides.posz) do
        local elId = itemDetailToMat(el)
        local needed = (matlist[elId] or 0) - (got[elId] or 0)
        if not elId then break end
        print('Checking', elId, needed)

        if elId and needed > 0 and inventory_controller.suckFromSlot(sides.posz, math.min(needed, 64)) then
            -- we don't know how many we sucked, recompute it.

            local count = 0
            for invi = 1, drone.inventorySize() do
                local item = inventory_controller.getStackInInternalSlot(invi)
                if itemDetailToMat(item) == elId then
                    count = count + item.size
                end
            end
            print('Got', elId, count)
            got[elId] = count
        end
    end

    i = i + 1
end

-- Liquids

local tankStatus = {}
for _ = 1, drone.tankCount do
    table.insert(tankStatus, { liquid = nil, count = 0 })
end

drone.moveRel(-3, 0, 0)

for _ = 1, 3 do
    drone.moveRel(-1, 0, 0)

    local el = tank_controller.getFluidInTank(sides.posz)
    if #el > 0 then
        for mat, liquidName in pairs(liquids) do
            if liquidName == el.name then
                local needed = (matlist[mat] or 0) - (got[mat] or 0)
                -- find empty/tank with same fluid
                for tankI, status in ipairs(tankStatus) do
                    if needed <= 0 then break end
                    if not status.liquid or status.liquid == liquidName then
                        drone.selectTank(tankI)
                        local taken = math.min(drone.tankSpace(tankI), needed * 1000)
                        drone.drain(sides.posz, taken)
                        needed = needed - taken
                        status.liquid = liquidName
                        status.count = status.count + taken
                    end
                end
            end
        end
    end
end

for tankI, status in ipairs(tankStatus) do
    print('Tank status: ', tankI, status.liquid, status.count)
end

-- drone.moveTo(safepoint1)
-- drone.moveTo(safepoint2)

-- moveToBlock(x, y + 16, z)
-- local i = 1
-- for dx = 0, xlen do
--     for dz = 0, zlen do
--         local block = blocks[i]

--         if block ~= '0' then
--             moveToBlock(x + dx, y + 1, z + dz)
--             local placed = false

--             if liquids[block] then
--                 -- find liquid to place
--                 for tankI, status in tankStatus do
--                     if status.liquid == liquids[block] and status.count > 0 then
--                         drone.selectTank(tankI)
--                         drone.fill(sides.negz, 1000)
--                         status.count = status.count - 1000
--                         placed = true
--                         break
--                     end
--                 end
--             else
--                 -- find block to place
--                 for invi = 1, drone.inventorySize() do
--                     if itemDetailToMat(inventory_controller.getStackInInternalSlot(invi)) == block then
--                         drone.select(invi)
--                         local res, err = drone.place(sides.negy)
--                         if not res then
--                             print('Could not place', err)
--                         end
--                         placed = true
--                     end
--                 end
--             end

--             if not placed then
--                 print('Not placed: missing ' .. block)
--             end
--         end
--         i = i + 1
--     end
-- end

-- moveToBlock(x, y + 16, z)
-- drone.moveTo(safepoint2)
-- drone.moveTo(safepoint1)
-- drone.moveTo(home)
