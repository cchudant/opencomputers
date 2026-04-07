local droneControl = require('.software.apis.droneControl')

local arg = ...

local function showUsage()
    print('Control drones')
    print('Usage:')
    print('* drone eeprom - flash the eprom image to the current eeprom')
    print('* drone log - listen to drone events, log their outpout')
    print('* drone flash [droneAddr] <dronescript path> - flash a drone with a new script')
    print('* drone start [droneAddr] - start a drone')
end

if arg[1] == 'eeprom' then
    droneControl.makeEeprom()
elseif arg[1] == 'log' then
    droneControl.logDrones()
elseif arg[1] == 'flash' then
    if not arg[2] then
        showUsage()
    end
    droneControl.flash(arg[2], arg[3])
elseif arg[1] == 'flash' then
    droneControl.start(arg[2])
else
    showUsage()
end
