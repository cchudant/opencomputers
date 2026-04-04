local component = require('component')
local event = require('event')
local serialization = require('serialization')

local modem = component.modem

modem.open(18)

local function newNonce()
    return math.random(1, 100000)
end

local function send(method, data, nonce)
    if nonce == nil then
        nonce = newNonce()
    end
    modem.broadcast(18, serialization.serialize({
        method = method,
        nonce = nonce,
        data = data,
    }))
end

local function waitReceive(methodFilter, nonce)
    while true do
        local _, _localAddr, _remoteAddr, port, _distance, data = event.pull('modem_message')
        if port == 18 and type(data) == "string" then
            local got = serialization.unserialize(data)
            if got ~= nil and type(got['method']) == 'string' and type(got['nonce']) == 'number'
                and (methodFilter == nil or got['method'] == methodFilter)
                and (nonce == nil or got['nonce'] == nonce)
            then
                return got['data'], got['method'], got['nonce']
            end
        end
    end
end


while true do
    local data, method, nonce = waitReceive()

    print("Got RPC " .. method)

    if method == 'status' then
        local statuses = {}
        for i, addr in ipairs(data) do
            local status = component.proxy(addr).status()
            table.insert(statuses, status)
        end

        send('statusRep', statuses, nonce)
    elseif method == 'assemble' then
        local addr = data
        component.proxy(addr).start()
        send('assembleRep', nil, nonce)
    end
end
