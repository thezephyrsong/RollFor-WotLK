RollFor = RollFor or {}
local m = RollFor

if m.SrListener then return end

local M = {}

---@class SrListener
---@field on_chat_msg_whisper fun( message: string, sender: string )

---@param player_info PlayerInfo
---@param softres SoftRes
function M.new( player_info, softres )
  local function whisper( player_name, text )
    m.api.SendChatMessage( text, "WHISPER", nil, player_name )
  end

  local function am_i_the_leader()
    return player_info.is_leader() or player_info.is_master_looter()
  end

  local function on_chat_msg_whisper( message, sender )
    if not am_i_the_leader() then return end
    if not string.find( message, "^%!SR %?" ) then return end

    local items = softres.get_player_items( sender )

    if #items == 0 then
      whisper( sender, "You have no soft reserves." )
      return
    end

    local names = {}
    for _, entry in ipairs( items ) do
      local link = m.fetch_item_link( entry.item_id, entry.quality )
      table.insert( names, link or ("item:" .. entry.item_id) )
    end

    whisper( sender, string.format( "Your SRs: %s", table.concat( names, ", " ) ) )
  end

  return {
    on_chat_msg_whisper = on_chat_msg_whisper,
  }
end

m.SrListener = M
return M
