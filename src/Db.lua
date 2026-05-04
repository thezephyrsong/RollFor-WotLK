RollFor = RollFor or {}
local m = RollFor

if m.Db then return end

local M = {}

function M.new( db )
  return function( module_name )
    db[ module_name ] = db[ module_name ] or {}

    local proxy = {}
    local mt = {
      __index = function( _, key )
        -- Add this check to allow accessing the underlying table directly
        if key == "raw" then return db[ module_name ] end
        return db[ module_name ][ key ]
      end,
      __newindex = function( _, key, value )
        db[ module_name ][ key ] = value
      end
    }

    setmetatable( proxy, mt )
    return proxy
  end
end
m.Db = M
return M
