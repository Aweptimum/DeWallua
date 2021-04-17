-- Create API table
local Stable = {}

-- Initialize table stack
Stable.stack = {}

-- Alias table.insert/table.remove to push/pop
local push, pop = table.insert, table.remove

-- Clear tables for re-use once they serve their purpose
-- Iterate through keys and set all to nil
function Stable:clean(table)
    for key, _ in pairs(table) do
        table[key] = nil
    end
end

-- Add n tables to the stack
-- This can be useful for allocating tables ahead of time
-- Front-loading table creation means less overhead incurred in the future (if done right)
function Stable:pad(n)
    for i = 1, n do
        push( self.stack, {} )
    end
end

-- Clean a table and push it to the stack
function Stable:stow(table)
	self:clean(table)
	push( self.stack, table )
end

-- Clean a nested table and push it to the stack
function Stable:stow_nested(table)
    -- Check for nested tables
    for key, value in pairs(table) do
        if type(value) == "table" then
            self:stow_nested(value)
        end
    end

    self:stow(table)
end

-- Pop a table from the stack or return a new one if the stack is empty
function Stable:fetch()
	if #self.stack == 0 then
		self:stow({})
	end
	return pop( self.stack )
end

-- Pop n tables from the stack
function Stable:fetch_n(n)
    n = n or 1
    if n >= 1 then
        return self:fetch(), self:fetch_n(n-1)
    end
end

-- Burn this baby down to the ground
function Stable:burn()
    for i = 1, #self.stack do
        self.stack[i] = nil
    end
end
return Stable