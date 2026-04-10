drone.moveRel(-2, 0, 0)

drone.gpsUpdatedAt = nil
drone.gpsMsgs = {}

while not drone.gpsUpdatedAt do
    drone.setLightColor(0xFFFFFF)
    drone.setStatusText('GPS...')
    drone.sleep(1)
end
drone.setLightColor(0x00FF00)

local x, y, z = 584.5, 141.5, -488.5

drone.moveTo(x, y, z)
