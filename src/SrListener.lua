RollFor = RollFor or {}
local m = RollFor

if m.SrListener then return end

local M = {}

---@class SrListener
---@field on_chat_msg_whisper fun( message: string, sender: string )

---@param player_info PlayerInfo
---@param sr_db SrDb
---@param group_roster GroupRoster
function M.new( player_info, sr_db, group_roster )
  local function whisper( player_name, text )
    m.api.SendChatMessage( text, "WHISPER", nil, player_name )
  end

  local function am_i_the_leader()
    return player_info.is_leader() or player_info.is_master_looter()
  end

  local function extract_item_id( message )
    local item_id = string.match( message, "|Hitem:(%d+):" )
    return item_id and tonumber( item_id )
  end

  local function extract_two_item_ids( message )
    local ids = {}
    for item_id in string.gmatch( message, "|Hitem:(%d+):" ) do
      table.insert( ids, tonumber( item_id ) )
      if #ids == 2 then break end
    end
    return ids[ 1 ], ids[ 2 ]
  end

  local function item_link_from_message( message )
    -- Extract the full item link e.g. |cff...|Hitem:...|h[Name]|h|r
    return string.match( message, "|c%x+|Hitem:%d+[^|]*|h%[.-%]|h|r" )
  end

  local function format_sr_list( player_name )
    local items = sr_db.get_player_srs( player_name )
    local max   = sr_db.get_max_srs()
    local used  = #items

    if used == 0 then
      return string.format( "You have no soft reserves. (%d/%d used)", used, max )
    end

    local names = {}
    for _, entry in ipairs( items ) do
      table.insert( names, entry.item_name or ("item:" .. entry.item_id) )
    end

    return string.format(
      "Your SRs: %s (%d/%d used)",
      table.concat( names, ", " ),
      used,
      max
    )
  end

  local function on_chat_msg_whisper( message, sender )
    if not am_i_the_leader() then return end

    -- Only respond to messages starting with !SR
    if not string.find( message, "^%!SR" ) then return end

    -- !SR ? — status query
    if string.find( message, "^%!SR %?" ) then
      whisper( sender, format_sr_list( sender ) )
      return
    end

    -- !SR cancel [item link]
    if string.find( message, "^%!SR cancel" ) then
      local item_id = extract_item_id( message )
      if not item_id then
        whisper( sender, "Please link a valid item to cancel." )
        return
      end

      local removed, item_name = sr_db.remove_sr( sender, item_id )
      if removed then
        whisper( sender, string.format( "Your SR for [%s] has been cancelled.", item_name or ("item:" .. item_id) ) )
      else
        whisper( sender, "You don't have that item reserved." )
      end
      return
    end

    -- !SR swap [item link] [item link]
    if string.find( message, "^%!SR swap" ) then
      local old_id, new_id = extract_two_item_ids( message )
      if not old_id or not new_id then
        whisper( sender, "Usage: !SR swap [current item] [new item]" )
        return
      end

      if sr_db.is_hard_reserved( new_id ) then
        whisper( sender, "That item is hard reserved." )
        return
      end

      local swapped, old_name, new_name = sr_db.swap_sr( sender, old_id, new_id )
      if swapped == "ok" then
        local max  = sr_db.get_max_srs()
        local used = #sr_db.get_player_srs( sender )
        whisper( sender, string.format(
          "Swapped [%s] for [%s]. (%d/%d used)",
          old_name or ("item:" .. old_id),
          new_name or ("item:" .. new_id),
          used, max
        ) )
      elseif swapped == "not_found" then
        whisper( sender, "You don't have that item reserved." )
      elseif swapped == "duplicate" then
        whisper( sender, "You already have that item reserved." )
      else
        whisper( sender, "Could not complete the swap." )
      end
      return
    end

    -- !SR [item link] — add a new SR
    local item_id   = extract_item_id( message )
    local item_link = item_link_from_message( message )

    if not item_id then
      whisper( sender, "Please link a valid item to soft reserve." )
      return
    end

    if not sr_db.is_open() then
      whisper( sender, "SR is currently closed." )
      return
    end

    if sr_db.is_hard_reserved( item_id ) then
      whisper( sender, "That item is hard reserved." )
      return
    end

    local result, reason = sr_db.add_sr( sender, item_id, item_link )

    if result == "full" then
      local max = sr_db.get_max_srs()
      whisper( sender, string.format( "You have used all your SR slots (%d/%d).", max, max ) )
    elseif result == "duplicate" then
      -- Already reserved — silent, just re-confirm status
    end
    -- Success is silent per spec
  end

  return {
    on_chat_msg_whisper = on_chat_msg_whisper,
  }
end

m.SrListener = M
return M
