RollFor = RollFor or {}
local m = RollFor

if m.Client then return end

---@class Client
---@field on_message fun( data: string, sender: string )

local M = m.Module.new( "Client" )

local IU = m.ItemUtils ---@type ItemUtils
local RT = m.Types.RollType
local RS = m.Types.RollingStrategy
local S = m.Types.RollingStatus

local getn = m.getn

---@param ace_timer AceTimer
---@param player_info PlayerInfo
---@param rolling_popup RollingPopup
---@param config Config
function M.new( ace_timer, player_info, rolling_popup, config )
  local roll_tracker ---@type RollTracker
  local roll_threshold = {}
  local show_rolling = false
  local player_can_roll = false
  local chunked_messages = {}
  local var_names = {
    i = "item",
    t = "type",
    l = "link",
    tx = "texture",
    q = "quality",
    ic = "item_count",
    s = "seconds",
    sl = "seconds_left",
    st = "strategy_type",
    pn = "player_name",
    pc = "player_class",
    rt = "roll_type",
    pl = "plus_ones",
    r = "roll",
    n = "name",
    c = "class",
    th = "roll_threshold",
    sr = "softressing_players",
    ro = "rolls",
    p = "players",
    cl = "classes",
    tm = "tmog"
  }
  setmetatable( var_names, { __index = function( _, key ) return key end } );

  rolling_popup:align_bottom()

  local function parse_table( str )
    local function parse_inner( pos )
      local tbl = {}
      local key
      local i = 1

      while pos <= string.len( str ) do
        local char = string.sub( str, pos, pos )

        if char == "{" then
          local newTable, newPos = parse_inner( pos + 1 )
          if key then
            tbl[ var_names[ key ] ] = newTable
            key = nil
          else
            tbl[ i ] = newTable
            i = i + 1
          end
          pos = newPos
        elseif char == "}" then
          return tbl, pos
        elseif char == "[" then
          local _, newPos, extracted_key = string.find( str, '%["*(.-)"*%]', pos )
          key = tonumber( extracted_key ) and tonumber( extracted_key ) or extracted_key
          pos = newPos
        elseif char == "=" then
        elseif char == "," then
          key = nil
        else
          local _, newPos, raw_value = string.find( str, '([^,%]}]+)', pos )
          if raw_value then
            local value = tonumber( raw_value ) and tonumber( raw_value ) or raw_value
            if key then
              tbl[ var_names[ key ] ] = value
              key = nil
            else
              tbl[ i ] = value
              i = i + 1
            end
            pos = newPos
          end
        end
        pos = pos + 1
      end
      return tbl, pos
    end

    local final_table = parse_inner( 1 )
    return final_table[ 1 ]
  end

  ---@param item_id number
  ---@param name string
  ---@param quality number
  local function item_link( item_id, name, quality )
    if not item_id then return end

    local id = tonumber( item_id )
    if not id or id == 0 then return end

    local details = string.format( "item:%d:0:0:0", id )

    return string.format( "%s|H%s|h[%s]|h|r", m.api.ITEM_QUALITY_COLORS[ quality or 0 ].hex, details, name )
  end

  local function close_rolling()
    rolling_popup.hide()
    show_rolling = false
  end

  ---@param strategy_type RollingStrategyType
  local function roll_buttons( strategy_type )
    local buttons = {}

    if player_can_roll then
      if strategy_type == RS.NormalRoll then
        table.insert( buttons, { type = "MSRoll", callback = function() m.api.RandomRoll( 1, roll_threshold[ RT.MainSpec ] ) end } )
        table.insert( buttons, { type = "OSRoll", callback = function() m.api.RandomRoll( 1, roll_threshold[ RT.OffSpec ] ) end } )
        if roll_threshold[ RT.Transmog ] > 0 then
          table.insert( buttons, { type = "TMOGRoll", callback = function() m.api.RandomRoll( 1, roll_threshold[ RT.Transmog ] ) end } )
        end
      elseif strategy_type == RS.SoftResRoll or strategy_type == RS.TieRoll then
        table.insert( buttons, { type = "Roll", callback = function() m.api.RandomRoll( 1, 100 ) end } )
      end
    end

    table.insert( buttons, { type = "Close", callback = function() close_rolling() end } )

    return buttons
  end

  local function tie_content()
    if not roll_tracker then
      M.debug.add( "roll_tracker not initialized" )
      return
    end
    local tracker_data = roll_tracker.get()
    local first_iteration = tracker_data.iterations[ 1 ]
    local waiting = tracker_data.status.type == "Waiting" or false

    local tie_iterations = {}
    for i, iteration in ipairs( tracker_data.iterations ) do
      if i > 1 then
        table.insert( tie_iterations,
          ---@type TieIteration
          {
            tied_roll = iteration.tied_roll,
            rolls = iteration.rolls
          }
        )
      end
    end

    ---@type RollingPopupTieData
    local rolling_popup_data = {
      ---@type RollingPopupRollData
      roll_data = {
        item_link = tracker_data.item.link,
        item_tooltip_link = IU.get_tooltip_link( tracker_data.item.link ),
        item_texture = tracker_data.item.texture,
        item_count = tracker_data.item_count,
        rolls = first_iteration.rolls,
        winners = tracker_data.winners,
        strategy_type = first_iteration.rolling_strategy,
        buttons = roll_buttons( RS.TieRoll ),
        waiting_for_rolls = waiting or false,
        type = "Roll"
      },
      tie_iterations = tie_iterations,
      type = "Tie"
    }

    rolling_popup:show()
    rolling_popup:refresh( rolling_popup_data )
  end

  ---@param type string?
  ---@param awarded string?
  local function roll_content( type, awarded )
    if not roll_tracker then
      M.debug.add( "roll_tracker not initialized" )
      return
    end
    local tracker_data, current_iteration = roll_tracker.get()
    local strategy_type = current_iteration and current_iteration.rolling_strategy
    local waiting_for_rolls = tracker_data.status.type == "Waiting" or false
    local seconds = not waiting_for_rolls and tracker_data.status.seconds_left or nil

    if strategy_type == "TieRoll" then
      tie_content()
      return
    end

    ---@type RollingPopupRollData
    local rolling_popup_data = {
      item_link = tracker_data.item.link,
      item_tooltip_link = IU.get_tooltip_link( tracker_data.item.link ),
      item_texture = tracker_data.item.texture,
      item_count = tracker_data.item_count,
      seconds_left = seconds,
      rolls = current_iteration.rolls,
      winners = tracker_data.winners,
      awarded = awarded or nil,
      buttons = roll_buttons( strategy_type ),
      strategy_type = strategy_type,
      waiting_for_rolls = waiting_for_rolls,
      type = type and type or "Roll"
    }

    rolling_popup:show()
    --local p = rolling_popup:get_anchor_point()
    --print(m.dump(p) )
    --if p and p.point == "TOPLEFT" then
    if 1==3 then
      
      
      --print("adjust point")
      --local point = {
   --     point = "BOTTOM",
   --     relative_point = "CENTER",
   --     x = 0,
    --    y = -50
    --  }
      --rolling_popup.get_frame():position( point )
      --p= rolling_popup:get_frame():get_anchor_point()
      --print(m.dump(p))
    end


    rolling_popup:refresh( rolling_popup_data )
    --local p1,r,p2,x,y = rolling_popup:get_frame():GetPoint()
    --print(p1 .. "," .. p2 .. "," .. y)

    local color = m.get_popup_border_color( tracker_data.item.quality )
    rolling_popup:border_color( color )
  end

  local function on_command( command, data )
    if command == "START_ROLL" then
      if getn( data.softressing_players ) == 0 then
        data.strategy_type = RS.NormalRoll
        player_can_roll = true
      elseif m.find( player_info.get_name(), data.softressing_players, 'name' ) then
        player_can_roll = true
        if config.client_auto_roll_sr() then
          m.api.RandomRoll( 1, data.roll_threshold.ms )
        end
      else
        player_can_roll = false
      end

      if data.item.classes and getn( data.item.classes ) > 0 then
        if m.find( player_info.get_class(), data.item.classes ) then
          player_can_roll = true
        else
          player_can_roll = false
        end
      end

      if not player_can_roll and config.client_show_roll_popup() ~= "Always" then
        show_rolling = false
        rolling_popup.hide()
        return
      end

      show_rolling = true

      roll_threshold.MainSpec = data.roll_threshold.ms
      roll_threshold.OffSpec = data.roll_threshold.os
      roll_threshold.Transmog = data.roll_threshold.tmog

      data.item.texture = "Interface\\Icons\\" .. data.item.texture
      data.item.name = string.gsub( data.item.name, "_", " " )
      data.item.link = item_link( data.item.id, data.item.name, data.item.quality )

      roll_tracker = m.RollTracker.new( data.item )
      roll_tracker.start( data.strategy_type, data.item_count, data.seconds, nil, data.softressing_players )

      if getn( data.softressing_players ) == 1 then
        roll_tracker.finish( {} )
        roll_tracker.add_winners( data.softressing_players )
      end

      roll_content()
    elseif command == "ENABLE_ROLL_POPUP" then
      config.enable_client_roll_popup()
    end

    if show_rolling then
      if command == "ROLL" then
        if not data.player_name then
          M.debug.add ( "No player_name on roll" )
          return
        end

        roll_tracker.add( data.player_name, data.player_class, data.player_role, data.roll_type, data.roll, data.plus_ones or 0 )
        if data.player_name == player_info.get_name() then
          player_can_roll = false
        end

        roll_content()
      elseif command == "TICK" then
        if not roll_tracker then
          M.debug.add( "roll_tracker not initialized" )
          return
        end
        local tracker_data = roll_tracker.get()
        if tracker_data.status.type == S.Finished or tracker_data.status.type == S.Canceled then
          return
        end

        roll_tracker.tick( data.seconds_left )

        if data.seconds_left == 1 then
          roll_tracker.waiting_for_rolls()
          ace_timer.ScheduleTimer( M, function()
            on_command( "TICK", { seconds_left = 0 } )
          end, 2 )
        end

        roll_content()
      elseif command == "FINISH" then
        roll_tracker.finish( {} )
        roll_tracker.add_winners( data )

        player_can_roll = false

        roll_content()
      elseif command == "CANCEL_ROLL" then
        roll_tracker.rolling_canceled()
        player_can_roll = false

        if config.client_auto_hide_popup() then
          show_rolling = false
          rolling_popup.hide()
        else
          roll_content( "RollingCanceled" )
        end
      elseif command == "TIE" then
        roll_tracker.tie( data.players, data.roll_type, data.roll )
        tie_content()
      elseif command == "TIESTART" then
        roll_tracker.tie_start()

        local tracker_data = roll_tracker.get()
        local last_iteration = tracker_data.iterations[ getn( tracker_data.iterations ) ]

        if m.find( player_info.get_name(), last_iteration.rolls, 'player_name' ) then
          player_can_roll = true
        end

        tie_content()
      elseif command == "AWARDED" then
        if data.player_name == player_info.get_name() then
          m.api.PlaySound( "RaidWarning" )
          m.api.PlaySound( "PVPTHROUGHQUEUE" )
        end

        if config.client_auto_hide_popup() then
          show_rolling = false
          rolling_popup.hide()
        else
          roll_content( "Awarded", data )
        end
      end
    end
  end

  local function on_message( data_str, sender )
    local command = string.match( data_str, "^(.-)::" )
    if sender == player_info.get_name() then return end
    if config.client_show_roll_popup() == "Off" and command ~= "ENABLE_ROLL_POPUP" then return end

    data_str = string.gsub( data_str, "^.-::", "" )

    if command == "CHUNK" then
      local chunk_num, total_chunks, chunk_content = string.match( data_str, "^(%d+)::(%d+)::(.+)$" )
      chunked_messages[ sender ] = chunked_messages[ sender ] or {}

      local sender_chunks = chunked_messages[ sender ]
      sender_chunks[ tonumber( chunk_num ) ] = chunk_content

      M.debug.add( (string.format( "Got chunk %d of %d", tonumber( chunk_num ), tonumber( total_chunks ) )) )

      if getn( sender_chunks ) == tonumber( total_chunks ) then
        data_str = table.concat( sender_chunks )
        command = string.match( data_str, "^(.-)::" )
        data_str = string.gsub( data_str, "^.-::", "" )

        chunked_messages[ sender ] = nil
      else
        return
      end
    end

    local data = data_str ~= "" and parse_table( data_str ) or {}

    M.debug.add( string.format( "Received command %s", command ) )
    on_command( command, data )
  end

  ---@type Client
  return {
    on_message = on_message
  }
end

m.Client = M
return M
