local droneControl = require('.software.apis.droneControl')
local component = require('component')
local sides = require('sides')
local robot = require('robot')
local shell = require('shell')
local inv = component.inventory_controller
local cr = component.crafting

local args, ops = shell.parse(...)

local eepromItemName = 'OpenComputers:eeprom'
local screnchItemName = 'OpenComputers:wrench'

local function showUsage()
    print('droneMuncher')
    print('Usage:')
    print('* droneMuncher munch - will order every waiting drone to get munched.')
    print('* droneMuncher unmunch [amount] [--flash] - will deploy drones')
end

local slotGoodEeprom = 16
local slotEmptyEeproms = 15
local slotScrench = 14
-- Temp slot outside of crafting grid.
local slotTemp = 4

---copy eeprom by taking flashed eeprom and crafting with an unflashed eeprom, then place both back in flashed eeprom slot
local function copy_eeprom()
    local emptyEeproms = inv.getStackInInternalSlot(slotEmptyEeproms)
    if not emptyEeproms or emptyEeproms.name ~= eepromItemName then
        robot.select(slotEmptyEeproms)
        print("Please put empty eeproms in the selected slot. (slot " .. slotEmptyEeproms .. ")")
        os.exit(1)
    end

    robot.select(slotGoodEeprom)
    robot.transferTo(1, 1)
    robot.select(slotEmptyEeproms)
    robot.transferTo(2, 1)
    cr.craft(1)
    robot.select(1)
    robot.transferTo(slotGoodEeprom, 2)
end

---take in drone, craft with a flashed eeprom, then if doing so returned an eeprom move drone from grid, clear eeprom, move to unflashed
---eeprom slot, then put drone back in slot 1
local function add_eeprom()
    robot.select(1)
    inv.suckFromSlot(sides.down, 1, 1)
    robot.select(slotGoodEeprom)
    robot.transferTo(2, 1)
    cr.craft(1)

    -- In case there was already an eeprom in the drone, it will be returned to us
    -- in slot 2.
    if inv.getStackInInternalSlot(2) ~= nil then
        robot.transferTo(slotTemp, 1)
        cr.craft(1)
        robot.transferTo(slotEmptyEeproms, 1)
        robot.select(slotTemp)
        robot.transferTo(1, 1)
        robot.select(1)
    end
end

--place and activate drone, then send signal for drones nearby to move to waiting area
local function deploy()
    robot.select(1)
    inv.equip()
    while not robot.use(sides.front) do end
    os.sleep(1)
    while not robot.use(sides.front, true) do end
    os.sleep(3)
    droneControl.run(nil, '/software/drone/unmunch.lua')
end

if args[1] == 'munch' then
    component.getPrimary('modem').setStrength(20)
    robot.select(slotScrench)

    local item = inv.getStackInInternalSlot(slotScrench)
    if not item or item.name ~= screnchItemName then
        print("Please put a scrench in the selected slot. (slot " .. slotScrench .. ")")
        os.exit(1)
    end

    droneControl.run(nil, '/software/drone/munch.lua')
    print('Waiting...')
    os.sleep(5)

    inv.equip()

    robot.select(1)
    local munched = 0
    while robot.use(sides.front, true) do
        robot.dropDown()
        munched = munched + 1
    end

    robot.select(slotScrench)
    -- unequip
    inv.equip()
    robot.select(1)
    print('Done! Drones munched: ' .. munched)
elseif args[1] == 'unmunch' then
    -- Messages only travel two blocks.
    component.getPrimary('modem').setStrength(2)

    local flash = ops['flash']

    local amount
    if args[2] then
        amount = tonumber(args[2])
        if not amount then
            showUsage()
            return
        end
    end
    
    local deployed = 0

    while (not amount or deployed < amount) and inv.getStackInSlot(sides.down, 1) do
        if flash then
            local goodEeproms = inv.getStackInInternalSlot(slotGoodEeprom)
            if not goodEeproms or goodEeproms.name ~= eepromItemName then
                robot.select(slotGoodEeprom)
                print("Please put the eeprom to flash in the selected slot. (slot " .. slotGoodEeprom .. ")")
                os.exit(1)
            end

            if goodEeproms.size < 2 then
                copy_eeprom()
            end

            add_eeprom()
        else
            robot.select(1)
            inv.suckFromSlot(sides.down, 1, 1)
        end
        deploy()

        deployed = deployed + 1
    end

    print('Done! Drones unmunched: ' .. deployed)
else
    showUsage()
end
