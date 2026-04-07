
local function moveToBlock(x, y, z)
    drone.moveTo(x + .5, y + .5, z + .5)
end

local home = drone.position

moveToBlock(572,141,-501)

drone.sleep(10)
drone.moveTo(home)
