local droneControl = require('.software.apis.droneControl')
local sides = require('sides')
local robot = require('robot')
local inv = component.inventory_controller
local cr = component.crafting
local modem = component.modem
modem.setStrength(1)


local function showUsage()
    print('droneMuncher')
    print('Usage:')
    print('* droneMuncher munch - will order every waiting drone to get munched.')
    print('* droneMuncher unmunch - will deploy drones')
end

---copy eeprom by taking flashed eeprom and crafting with an unflashed eeprom, then place both back in flashed eeprom slot
local function copy_eeprom()
    robot.select(15)
    robot.transferTo(1, 1)
    robot.select(16)
    robot.transferTo(2, 1)
    cr.craft(1)
    robot.select(1)
    robot.transferTo(15, 2)
end

---take in drone, craft with a flashed eeprom, then if doing so returned an eeprom move drone from grid, clear eeprom, move to unflashed
---eeprom slot, then put drone back in slot 1
local function add_eeprom()
    robot.select(1)
    inv.suckFromSlot(sides.down, 1, 1)
    robot.select(15)
    robot.transferTo(2, 1)
    cr.craft(1)
    robot.select(1)
end

--place and activate drone, then send signal for drones nearby to move to waiting area
local function deploy()
    robot.place(sides.front)
    robot.use(sides.front, true)
    os.sleep(1)
    droneControl.run(nil, '/software/drone/unmunch.lua')
end

local args = ...

if args == 'munch' then
    
elseif args == 'unmunch' then
    while inv.getStackInSlot(sides.down, 1) do
        if inv.getStackInInternalSlot(16) ~= nil then
            copy_eeprom()
            os.sleep(2)
            add_eeprom()
            os.sleep(2)
            deploy()
            os.sleep(2)
        else
            print("Out of EEPROMs!")
            break
        end
    end
else
    showUsage()
end