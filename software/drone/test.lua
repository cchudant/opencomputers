
print("pos:", table.unpack(drone.position))

drone.sleep(10)

print("2 pos:", table.unpack(drone.position))

drone.moveRel(0, 5, 0)

print("0,5,0 pos:", table.unpack(drone.position))

drone.moveRel(0, -5, 0)

print("origin pos:", table.unpack(drone.position))

drone.sleep(10)

print("0,0,-5 pos:", table.unpack(drone.position))

drone.moveRel(0, 0, -5)

print("origin pos:", table.unpack(drone.position))

drone.moveRel(0, 0, 5)
