drone.moveRel(2, 0, 0)

while not drone.gpsUpdatedAt do
    drone.setLightColor(0xFFFFFF)
    drone.setStatusText('GPS...')
    drone.sleep(1)
end

drone.moveTo(584.5, -141.5, 489.5)
