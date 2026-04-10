local droneControl = require('.software.apis.droneControl')
local component = require('component')
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

local slotGoodEeprom = 15
local slotEmptyEeproms = 14
local slotScrench = 13
-- Temp slot outside of crafting grid.
local slotTemp = 4

---copy eeprom by taking flashed eeprom and crafting with an unflashed eeprom, then place both back in flashed eeprom slot
local function copy_eeprom()
    print('copy eeprom')
    os.sleep(3)
    robot.select(slotGoodEeprom)
    os.sleep(3)
    robot.transferTo(1, 1)
    os.sleep(3)
    robot.select(slotEmptyEeproms)
    os.sleep(3)
    robot.transferTo(2, 1)
    os.sleep(3)
    cr.craft(1)
    os.sleep(3)
    robot.select(1)
    os.sleep(3)
    robot.transferTo(slotGoodEeprom, 2)
end

---take in drone, craft with a flashed eeprom, then if doing so returned an eeprom move drone from grid, clear eeprom, move to unflashed
---eeprom slot, then put drone back in slot 1
local function add_eeprom()
    print('add eeprom')
    robot.select(1)
    os.sleep(3)
    inv.suckFromSlot(sides.down, 1, 1)
    os.sleep(3)
    robot.select(slotGoodEeprom)
    os.sleep(3)
    robot.transferTo(2, 1)
    os.sleep(3)
    cr.craft(1)

    if inv.getStackInInternalSlot(1) ~= nil then
        print('heya')
        os.sleep(3)
        robot.select(1)
        os.sleep(3)
        robot.transferTo(slotTemp, 1)
        os.sleep(3)
        cr.craft(1)
        os.sleep(3)
        robot.transferTo(slotEmptyEeproms, 1)
        os.sleep(3)
        robot.select(slotTemp)
        robot.transferTo(1, 1)
        robot.select(1)
    end
end

--place and activate drone, then send signal for drones nearby to move to waiting area
local function deploy()
    print('deploy')
    os.sleep(3)
    robot.place(sides.front)
    os.sleep(3)
    robot.use(sides.front, true)
    os.sleep(2)
    droneControl.run(nil, '/software/drone/unmunch.lua')
end

local args = ...

if args == 'munch' then
    inv.select(slotScrench)
    inv.equip()

    inv.select(1)
    while inv.use(sides.front, true) do
        inv.dropDown()
    end

    inv.select(slotScrench)
    -- unequip
    inv.equip()
    inv.select(1)
elseif args == 'unmunch' then
    -- Messages only travel two blocks.
    component.getPrimary('modem').setStrength(2)

    while inv.getStackInSlot(sides.down, 1) do
        if inv.getStackInInternalSlot(slotGoodEeprom) ~= nil then
            copy_eeprom()
            add_eeprom()
            deploy()
        else
            print("Out of EEPROMs!")
            break
        end
    end
else
    showUsage()
end
