-- Relative require in same directory
-- Global, because I don't want to declare it in every. single. file.
function _Require_relative(PATH, file, up)
    up = up or 0
    print('up: '..up)
    local path, match
    path, _     = ( (PATH):gsub("\\",".") ):gsub("/",".")
    path, match = path:gsub("(.*)%..*$", "%1" )
    for i = 1, up do
        path, match = path:gsub("%.(%w+)$", '')
    end
    --path = match == 0 and '.'..file or path
    --print('path: '..table.concat({path, file}, "."))
	return require(table.concat({path, file}, "."))
end

local Dewall = _Require_relative(...,'DeWallua.DeWallua')
return Dewall