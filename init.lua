DEWALL_PATH = string.gsub( ..., "init", "")

local dewall_path = table.concat({DEWALL_PATH, 'DeWallua'})
print (dewall_path)
local Dewall = require(dewall_path)
return Dewall