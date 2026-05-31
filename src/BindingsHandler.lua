RollFor = RollFor or {}
local m = RollFor

if m.KeyBindings then return end

local M = {}

BINDING_HEADER_ROLLFOR = "RollFor"

---@class KeyBindings
---@field options_toggle fun()
---@field softres_toggle fun()
---@field winners_toggle fun( data: table)
---@field import fun()

function M.new( main )
  local function options_toggle()
    main.options_popup.toggle()
  end

  local function softres_toggle()
    main.softres_gui.toggle()
  end

  local function winners_toggle()
    main.winners_popup.toggle()
  end

  local function import( data )
    math.huge = 1e99
    ---@diagnostic disable-next-line: undefined-global
    local json = LibStub( "Json-0.1.2" )
    local success, json_data = pcall( function() return json.encode( data ) end )

    if success then
      local softres_data = m.encode_base64( json_data )

      main.import_encoded_softres_data( softres_data, function()
        local softres_check = main.softres_check
        local result = softres_check.check_softres()

        if result ~= softres_check.ResultType.NoItemsFound then
          main.softres.persist( softres_data )
          main.dropped_loot_announce.reset()
          main.softres_gui.load( softres_data )
        end
      end )
    else
      m.error( "Encoding of SR data failed" )
    end
  end

  ---@type KeyBindings
  return {
    options_toggle = options_toggle,
    softres_toggle = softres_toggle,
    winners_toggle = winners_toggle,
    import = import,
  }
end

m.KeyBindings = M
return M
