--@name Include
--@author INP
--@include https://raw.githubusercontent.com/neostarfall/neostarfall/master/lua/starfall/examples/included.lua as included.txt

local value = require("included.txt") -- Note the include above
printHelloWorld() -- Call global function from included file
print(value) -- Print returned value
