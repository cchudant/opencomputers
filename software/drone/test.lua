
local function moveToBlock(x, y, z)
    drone.moveTo(x + .5, y + .5, z + .5)
end

local home = drone.position

print('moving to there')
moveToBlock(572,141,-501)

drone.sleep(10)

print('moving to home ', table.unpack(home))

drone.moveTo(home)

drone.sleep(10)

print('done?')