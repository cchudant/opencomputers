local droneControl = require('.software.apis.droneControl')
local shell = require('shell')

local args, ops = shell.parse(...)

local function showUsage()
    print('Control drones')
    print('Usage:')
    print('* drone eeprom - flash the eprom image to the current eeprom')
    print('* drone log - listen to drone events, log their outpout')
    print('* drone run <dronescript path> [args...] - run all waiting drone with a script')
    print('* drone run --addr <droneAddr> <dronescript path> [args...] - run a drone with a script')
end

if args[1] == 'eeprom' and #args == 1 then
    for k, _v in pairs(ops) do
        print('Unknown option: --' .. k)
        showUsage()
        return
    end

    droneControl.makeEeprom()
elseif args[1] == 'log' and #args == 1 then
    for k, _v in pairs(ops) do
        print('Unknown option: --' .. k)
        showUsage()
        return
    end

    droneControl.logDrones()
elseif args[1] == 'run' and #args >= 2 then

    local droneAddr = ops['addr']
    ops['addr'] = nil

    for k, _v in pairs(ops) do
        print('Unknown option: --' .. k)
        showUsage()
        return
    end

    droneControl.run(droneAddr, ops[3], table.unpack(ops[4]))
else
    showUsage()
end
