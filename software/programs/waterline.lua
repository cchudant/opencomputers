local component = require('component')
local me = component.me_controller

---set minimums for each tier of water, in order
local minimumstock={5000000, 2000000, 2000000, 1000000, 1000000, 1000000, 1000000, 1000000}

---register waterline units and return table of tier and proxy for machine of that tier
local function register_units()
    local unitstable={}
    for address in component.list('gt_machine') do
        local module = component.proxy(address)
        local name = module.getName()
        local tier
        if string.find(name, "clarifier") then
            tier=1
        end
        if string.find(name, "ozonation") then
            tier=2
        end
        if string.find(name, "flocculator") then
            tier=3
        end
        if string.find(name, "phadjustment") then
            tier=4
        end
        if string.find(name, "plasmaheater") then
            tier=5
        end
        if string.find(name, "uvtreatment") then
            tier=6
        end
        if string.find(name, "degasifier") then
            tier=7
        end
        if string.find(name, "extractor") then
            tier=8
        end
        if tier then
            unitstable[tier]=module
        end
    end
    return unitstable
end

---poll fluid amounts for each water type from ME
local function poll_fluids()
    local networkfluids = me.getFluidsInNetwork()
    local waters = {}
    for i=1,8 do
        for _, fluid in pairs(networkfluids) do
            if string.find(fluid.label, "Grade "..i) then
                waters[i] = fluid.amount
            end
        end
    end

    ---if there  is no water, add entry with amount of 0 for that tier to avoid nils
    for i=1,8 do
        if not waters[i] then
            waters[i]=0
        end
    end
    return waters
end


local waterline = register_units()
local water_stocks = poll_fluids()
local nextactive = 0
local waitingforwork=false
local lastactive=0

while true do

    if nextactive==0 then
        ---first check for water types that are under the minimum, starting from tier 1
        for i=1,8 do
            if water_stocks[i]<minimumstock[i] then
                nextactive = i
                break
            end
        end
        
        ---if no water is below minimum, even out water types by checking each tier from the top and see if the previous tier is farther above minimum
        if nextactive == 0 then
            for i=1,7 do
                x=9-i
                if water_stocks[x]-minimumstock[x] < water_stocks[x-1]-minimumstock[x-1] then
                    nextactive=x
                    break
                end
            end
        end

        ---if nothing else has been found based on previous priorities, make t1 water
        if nextactive == 0 then
            nextactive = 1
        end
    end

    ---if the next craft is not queued yet, queue it by turning on power to that machine--it won't actually start until the next waterline cycle
    if not waitingforwork then
        waterline[nextactive].setWorkAllowed(true)
        waitingforwork=true
        print("Requesting Tier "..nextactive.." water.")

    ---if next craft is queued, check to see if it has actually started the craft yet. if so, clear variables to allow queueing of following craft
    else
        if waterline[nextactive].isMachineActive() then
            print("Making Tier "..nextactive.." water.")
            waterline[nextactive].setWorkAllowed(false)
            waitingforwork=false
            lastactive=nextactive
            nextactive=0
            water_stocks = poll_fluids()
        end
    end
    ---if the next craft is same as the current, sleep 120s to avoid constantly queuing and then clearing. otherwise sleep for 10s.
    if lastactive==nextactive then
        os.sleep(120)
    else
        os.sleep(10)
    end
end