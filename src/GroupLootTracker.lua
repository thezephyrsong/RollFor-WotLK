RollFor = RollFor or {}
local m = RollFor

if m.GroupLootTracker then return end

-- I passively watch CHAT_MSG_LOOT for Blizzard's own group-loot Need/Greed/
-- Disenchant winner announcements (the built-in popup, only relevant when the
-- group's loot method is "Group Loot" rather than Master Loot) and record the
-- winner into AwardedLoot -- the same history SR/MS/OS awards live in.
--
-- I deliberately do NOT go through LootAwardCallback/RollController: those own
-- the live-rolling UI and master-loot distribution, and the item here has
-- already been handed to the winner by the game itself. All I do is record it.
local M = m.Module.new( "GroupLootTracker" )

local RT = m.Types.RollType
local item_utils = m.ItemUtils

---@class GroupLootTracker
---@field on_chat_msg_loot fun( message: string )

---@param player_name string
---@return string
local function strip_realm_suffix( player_name )
  return string.match( player_name, "^([^%-]+)" ) or player_name
end

---@param awarded_loot AwardedLoot
function M.new( awarded_loot )
  ---@param message string
  ---@return string?, string?
  local function parse_winner( message )
    -- Expected shape: "Playername wins: |cff.....|Hitem:1234:...|h[Item Name]|h|r."
    -- Item hyperlinks don't normally contain a literal period, so we try the
    -- strict form (trailing period) first and fall back to no-trailing-period
    -- in case this server's wording differs slightly.
    local winner_name, item_link = string.match( message, "^([^%s]+) wins: (.+)%.$" )
    if winner_name and item_link then return winner_name, item_link end

    return string.match( message, "^([^%s]+) wins: (.+)$" )
  end

  ---@param message string
  local function on_chat_msg_loot( message )
    local winner_name, item_link = parse_winner( message )

    if not winner_name or not item_link then
      -- Not a roll-winner line (could be a plain "You receive loot:" message,
      -- or this server phrases the win message differently). Log it so a
      -- mismatched pattern is discoverable instead of silently doing nothing.
      M.debug.add( string.format( "unmatched CHAT_MSG_LOOT: %s", message ) )
      return
    end

    local item_id = item_utils.get_item_id( item_link )

    if not item_id then
      M.debug.add( string.format( "GroupLootTracker: could not resolve item_id from link: %s", item_link ) )
      return
    end

    local base_name = strip_realm_suffix( winner_name )

    M.debug.add( string.format( "award( %s, %s )", base_name, item_id ) )
    awarded_loot.award( base_name, item_id, { roll_type = RT.GroupLoot }, nil, item_link, nil, nil, false )
  end

  ---@type GroupLootTracker
  return {
    on_chat_msg_loot = on_chat_msg_loot
  }
end

m.GroupLootTracker = M
return M
