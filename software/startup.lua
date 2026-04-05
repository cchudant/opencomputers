local shell = require('shell')
local package = require('package')
shell.setPath(shell.getPath()..':/software/programs')
package.path = package.path .. ';/?.lua'