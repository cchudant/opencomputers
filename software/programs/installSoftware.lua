local os = require('os')

local cmd = "/software/install.lua"
for _, el in ipairs({ ... }) do
    cmd = cmd .. " " .. el
end

os.execute(cmd)
