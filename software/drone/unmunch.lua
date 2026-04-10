drone.moveRel(-2, 0, 0)

while not drone.gpsUpdatedAt do
    drone.setLightColor(0xFFFFFF)
    drone.setStatusText('GPS...')
    drone.sleep(1)
end

local x, y, z = 584.5, 141.5, -488.5

drone.moveTo(x, y, z)
