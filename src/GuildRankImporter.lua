RollFor = RollFor or {}
local m = RollFor

if m.GuildRankImporter then return end

local M = {}

---@class GuildRankImporter
---@field get_rank_names fun(): table     -- ordered list of { index, name } entries
---@field get_player_ranks fun(): table   -- { [playerName] = rankIndex } for all guild members
---@field request_refresh fun()           -- fires GuildRoster() to populate client cache

--- Scan GuildControlGetRankName across a range of indices, return all non-empty results.
local function scan_rank_names( start, stop )
  local names = {}
  for i = start, stop do
    local name = m.api.GuildControlGetRankName( i )
    if name and name ~= "" then
      table.insert( names, { index = i, name = name } )
    end
  end
  return names
end

--- Try 0-based then 1-based indexing, use whichever returns more results.
local function get_rank_names_from_control()
  local zero_based = scan_rank_names( 0, 15 )
  local one_based  = scan_rank_names( 1, 15 )
  -- Prefer the set that starts at a lower index (more complete)
  if #zero_based > 0 and ( #one_based == 0 or zero_based[1].index < one_based[1].index ) then
    return zero_based
  end
  return one_based
end

--- Fallback: derive distinct rank entries by scanning roster members.
--- Use when GuildControlGetRankName returns nothing.
local function get_rank_names_from_roster()
  local seen  = {}
  local names = {}
  local count = m.api.GetNumGuildMembers and m.api.GetNumGuildMembers() or 0

  for i = 1, count do
    local _, rank_name, rank_index = m.api.GetGuildRosterInfo( i )
    if rank_index and rank_name and not seen[ rank_index ] then
      seen[ rank_index ] = true
      table.insert( names, { index = rank_index, name = rank_name } )
    end
  end

  table.sort( names, function( a, b ) return a.index < b.index end )
  return names
end

--- Public: try GuildControlGetRankName first, fall back to roster scan.
local function get_rank_names()
  local names = get_rank_names_from_control()
  if #names == 0 then
    names = get_rank_names_from_roster()
  end
  return names
end

--- Returns { [playerName] = rankIndex } for every guild member.
local function get_player_ranks()
  local result = {}
  local count  = m.api.GetNumGuildMembers and m.api.GetNumGuildMembers() or 0

  for i = 1, count do
    local name, _, rank_index = m.api.GetGuildRosterInfo( i )
    if name then
      name = string.match( name, "^([^%-]+)" ) or name
      result[ name ] = rank_index
    end
  end

  return result
end

--- Requests an async guild roster refresh from the server.
local function request_refresh()
  if m.api.GuildRoster then
    m.api.GuildRoster()
  end
end

---@return GuildRankImporter
function M.new()
  return {
    get_rank_names   = get_rank_names,
    get_player_ranks = get_player_ranks,
    request_refresh  = request_refresh,
  }
end

m.GuildRankImporter = M
return M