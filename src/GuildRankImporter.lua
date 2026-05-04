RollFor = RollFor or {}
local m = RollFor

if m.GuildRankImporter then return end

local M = {}

---@class GuildRankImporter
---@field get_rank_names fun(): string[]   -- ordered list of guild rank names (index 0-based from GM)
---@field get_player_ranks fun(): table    -- { [playerName] = rankIndex } for all guild members

--- Returns an ordered list of rank names from the guild (0 = GM).
--- WotLK: GuildControlGetRankName(index) where index is 0-based.
--- Returns nil when index is out of range.
local function get_rank_names()
  local names = {}
  local i = 0

  while true do
    local name = m.api.GuildControlGetRankName( i )
    if not name or name == "" then break end
    table.insert( names, { index = i, name = name } )
    i = i + 1
    if i > 20 then break end  -- safety cap
  end

  return names
end

--- Refreshes the guild roster cache and returns { [playerName] = rankIndex }.
--- Callers should fire GuildRoster() before calling this if they need fresh data.
local function get_player_ranks()
  local result = {}
  local count = m.api.GetNumGuildMembers and m.api.GetNumGuildMembers() or 0

  for i = 1, count do
    local name, _, rankIndex = m.api.GetGuildRosterInfo( i )
    if name then
      -- Strip realm suffix if present (e.g. "Player-ServerName")
      name = string.match( name, "^([^%-]+)" ) or name
      result[ name ] = rankIndex
    end
  end

  return result
end

--- Requests an async guild roster refresh from the server.
--- Results won't be available until GUILD_ROSTER_UPDATE fires.
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
