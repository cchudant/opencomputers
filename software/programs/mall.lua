local component=require('component')
local inv=component.inventory_controller
local export=component.me_exportbus
local sides=require('sides')
local me=component.me_interface

---table to register whether an inventory slot already has a registered item to save time on inventory/database checks
local isregistered={}

---register table of databases. should always register in same order. if it doesn't, wipe databases
local databases={}
for k,v in pairs(component.list('database')) do
    table.insert(databases, component.proxy(k))
end

local function masterdbslot(slot)
    local dbslot=slot
    local db=1
    while dbslot>81 do
        dbslot=dbslot-81
        db=db+1
    end
    return db, dbslot
end

local function clear_db()
    for k,v in pairs(databases) do
        for i=1,81 do
            v.clear(i)
        end
    end
end

local function get_masterdb(slot)
    local db,dbslot = masterdbslot(slot)
    return databases[db].get(dbslot)
end

local function store_masterdb(slot)
    local db,dbslot = masterdbslot(slot)
    inv.store(sides.up, slot, databases[db].address, dbslot)
    print("Storing Data")
    return
end

local function registerinventory()
    for i=1,inv.getInventorySize(sides.up) do
        if not isregistered[i] then
            if inv.getStackInSlot(sides.up, i) then
                if not get_masterdb(i) then
                    store_masterdb(i)
                end
                isregistered[i]=true
            end
        end
    end
    return
end

local function setexport(slot)
    print("Attempting to Export...")
    local db,dbslot = masterdbslot(slot)
    export.setExportConfiguration(sides.north, databases[db].address, dbslot)
    return
end

local function attr(db, dbslot)
    local entry = databases[db].get(dbslot)
    local idnum = entry.id
    local damagenum = entry.damage
    return idnum, damagenum
end

local function check_me(slot)
    local db,dbslot = masterdbslot(slot)
    local idnum, damagenum=attr(db, dbslot)
    local invcheck=me.getItemsInNetwork({id=idnum, damage=damagenum})
    if #invcheck~=0 then
        if invcheck[1].size < 1000 then
            if not me.getCraftables({id=idnum, damage=damagenum}) then
                print("Unable to request "..databases[db].get(dbslot).label)
            else
                local status=me.getCraftables({id=idnum, damage=damagenum})[1].request(10000)
                while not status.isDone() and not status.isCanceled() do
                    os.sleep(5)
                end
            end
        end
    else
        print("Item not found in ME:"..databases[db].get(dbslot).label)
    end
    return
end

local function fillinventory()
    for i=1, inv.getInventorySize(sides.up) do
        if isregistered[i] then
            local items = inv.getStackInSlot(sides.up, i)
            
            if inv.getStackInSlot(sides.up, i) == nil or inv.getStackInSlot(sides.up, i).size < 64 then
                check_me(i)
                setexport(i)
                export.exportIntoSlot(sides.north, i)
            end
        end
    end
    return
end

if ... == 'clean' then
    clear_db()
end

while true do
    print("Registering Inventory")
    registerinventory()
    print("Filling Inventory")
    fillinventory()
    os.sleep(5)
end