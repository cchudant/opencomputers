local component = require('component')
local inv = component.inventory_controller
local export = component.me_exportbus
local sides = require('sides')
local me = component.me_interface

---table to register whether an inventory slot already has a registered item to save time on inventory/database checks
local isregistered = {}

---register table of databases. should always register in same order. if it doesn't, wipe databases
local databases = {}
local dbs = component.list('database')
table.sort(dbs)
for k, v in pairs(dbs) do
    table.insert(databases, component.proxy(k))
end

---wipe all databases. called before entering main loop if run with arg 'clean'
local function clear_db()
    for k, v in pairs(databases) do
        for i = 1, 81 do
            v.clear(i)
        end
    end
end

---convert inventory slot into a corresponding database and slot
local function masterdbslot(slot)
    local dbslot = slot
    local db = 1
    while dbslot > 81 do
        dbslot = dbslot - 81
        db = db + 1
    end
    return db, dbslot
end

---fetch data from databases
local function get_masterdb(slot)
    local db, dbslot = masterdbslot(slot)
    return databases[db].get(dbslot)
end

---store data in databases
local function store_masterdb(slot)
    local db, dbslot = masterdbslot(slot)
    inv.store(sides.up, slot, databases[db].address, dbslot)
    print("Storing Data")
end

---loop through all slots in connected inventory. if the slot has a registered item, skip it. if it doesn't but does have an
---item in the slot, check database to see if it has an item stored. if not, store it and mark the slot as registered
local function registerinventory()
    for i = 1, inv.getInventorySize(sides.up) do
        if not isregistered[i] then
            if inv.getStackInSlot(sides.up, i) then
                if not get_masterdb(i) then
                    store_masterdb(i)
                end
                isregistered[i] = true
            end
        end
    end
end

---configure export bus to export the requested item
local function setexport(slot)
    print("Attempting to Export...")
    local db, dbslot = masterdbslot(slot)
    export.setExportConfiguration(sides.north, databases[db].address, dbslot)
end

---retrieve the id number and damage number of the ItemStack in the given slot
local function attr(db, dbslot)
    local entry = databases[db].get(dbslot)
    local idnum = entry.id
    local damagenum = entry.damage
    return idnum, damagenum
end

---check the ME network to see if there is at least 1000 of the desired item. if there is not, try to request 10000.
---if the item is not in ME and not craftable, print an error.
local function check_me(slot)
    local db, dbslot = masterdbslot(slot)
    local idnum, damagenum = attr(db, dbslot)
    local invcheck = me.getItemsInNetwork({ id = idnum, damage = damagenum })
    if #invcheck ~= 0 then
        if invcheck[1].size < 1000 then
            if not me.getCraftables({ id = idnum, damage = damagenum }) then
                print("Unable to request " .. databases[db].get(dbslot).label)
            else
                local status = me.getCraftables({ id = idnum, damage = damagenum })[1].request(10000)
                print("Requested", idnum, damagenum)
                while not status.isDone() and not status.isCanceled() do
                    os.sleep(5)
                end
            end
        end
    else
        print("Item not found in ME:" .. databases[db].get(dbslot).label)
    end
    return
end

---loop through inventory slots that have been registered and if there is less than a stack of their item, push a stack into that slot
---@returns true if it did any work
local function fillinventory()
    local didWork = false
    local didWorkThisRound
    local firstRound = true
    repeat
        didWorkThisRound = false
        for i = 1, inv.getInventorySize(sides.up) do
            if isregistered[i] then
                local items = inv.getStackInSlot(sides.up, i)

                if items == nil or items.size < 64 then
                    if firstRound then
                        -- only check on first round
                        check_me(i)
                    end
                    setexport(i)
                    if export.exportIntoSlot(sides.north, i) then
                        while export.exportIntoSlot(sides.north, i) do
                        end
                        didWorkThisRound = true
                    end
                end
            end
        end
        firstRound = false
        didWork = didWork or didWorkThisRound
        -- repeat all of it until nothing left to do
    until not didWorkThisRound
    return didWork
end

---wipe all databases if clean arg is given
if ... == 'clean' then
    clear_db()
end

---register slots, fill slots, wait 5s
while true do
    print("Registering Inventory")
    registerinventory()
    print("Filling Inventory")
    local didWork = fillinventory()
    if not didWork then
        os.sleep(5)
    end
end
