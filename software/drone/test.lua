
local function moveToBlock(x, y, z)
    drone.moveTo(x + .5, y + .5, z + .5)
end

print('current pos: ', table.unpack(drone.position))
local home = drone.position

print('moving to there')
moveToBlock(572,141,-501)
print('current pos: ', table.unpack(drone.position))

drone.sleep(3)

print('current pos: ', table.unpack(drone.position))
print('moving to home ', table.unpack(home))

drone.moveTo(home)

print('current pos: ', table.unpack(drone.position))

drone.sleep(3)

print('done?')