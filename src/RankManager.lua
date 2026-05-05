RollFor = RollFor or {}
local m = RollFor

if m.RankManager then return end

local M = {}

local info = m.pretty_print
local hl   = m.colors.hl
local grey = m.colors.grey

--- Rank priority constants. Lower number = higher priority in rolls.
M.Rank = {
  Veteran  = 1,
  Member   = 2,
  Trial    = 3,
  Unranked = 4,
}

local RANK_NAMES = {
  [ M.Rank.Veteran  ] = "Veteran",
  [ M.Rank.Member   ] = "Member",
  [ M.Rank.Trial    ] = "Trial",
  [ M.Rank.Unranked ] = "Unranked",
}

local RANK_BY_NAME = {}
for k, v in pairs( RANK_NAMES ) do RANK_BY_NAME[ string.lower( v ) ] = k end

---@param rank number
---@return string
function M.rank_name( rank )
  return RANK_NAMES[ rank ] or "Unranked"
end

---@param name string
---@return number|nil
function M.rank_from_string( name )
  return RANK_BY_NAME[ string.lower( name or "" ) ]
end

---@param db table -- persistent SavedVariables subtable ("rank_manager")
---@param guild_rank_importer GuildRankImporter
---@param event_bus EventBus
function M.new( db, guild_rank_importer, event_bus )
  -- Ensure sub-tables exist in the database
  if not db.guild_rank_map then db.guild_rank_map = {} end
  if not db.player_ranks   then db.player_ranks   = {} end

  -- Cache the last-fetched guild player→rankIndex map
  local guild_player_cache = {}

  local function refresh_guild_cache()
    guild_player_cache = guild_rank_importer.get_player_ranks()
  end

  -- Automatically refresh cache and notify UI when the roster updates
  if event_bus then
    event_bus.subscribe( "GUILD_ROSTER_UPDATE", function()
      refresh_guild_cache()
      event_bus.notify( "ROLLFOR_GUILD_RANKS_UPDATED" )
    end )
  end

  --- Resolve the effective rank for a player.
  local function get_player_rank( player_name )
    -- 1. Manual override wins
    local override = db.player_ranks[ player_name ]
    if override then return override end

    -- 2. Try guild rank mapping (1-based indices on 3.3.5a)
    local guild_rank_index = guild_player_cache[ player_name ]
    if guild_rank_index ~= nil then
      local mapped = db.guild_rank_map[ guild_rank_index ]
      if mapped then return mapped end
    end

    -- 3. Default for non-guild/unmapped
    return M.Rank.Trial
  end

  --- Set a manual override rank for a player.
  local function set_player_rank( player_name, rank )
    db.player_ranks[ player_name ] = rank
  end

  --- Remove the manual override for a player.
  local function clear_player_rank( player_name )
    db.player_ranks[ player_name ] = nil
  end

  --- Map a guild rank index to a priority rank.
  local function set_guild_rank_map( rank_index, rank )
    db.guild_rank_map[ rank_index ] = rank
  end

  local function get_guild_rank_map()
    return db.guild_rank_map
  end

  local function get_player_overrides()
    return db.player_ranks
  end

  --- Returns rank names for UI population.
  local function get_rank_names()
    return guild_rank_importer.get_rank_names()
  end

  --- Print current rank for a player.
  local function print_player_rank( player_name )
    local rank = get_player_rank( player_name )
    local override = db.player_ranks[ player_name ] and " (manual override)" or ""
    info( string.format( "%s rank: %s%s", hl( player_name ), hl( M.rank_name( rank ) ), grey( override ) ) )
  end

  --- Print all manual overrides using raw table access.
  local function print_all_overrides()
    local count = 0
    local raw_overrides = get_player_overrides()
    for name, rank in pairs( raw_overrides ) do
      info( string.format( "  %s: %s", hl( name ), M.rank_name( rank ) ) )
      count = count + 1
    end
    if count == 0 then info( "No manual rank overrides set." ) end
  end

  --- Print the current guild rank mapping.
  local function print_guild_map()
    local rank_names = get_rank_names()
    if #rank_names == 0 then
      info( "Not in a guild or guild data not loaded yet." )
      return
    end
    info( "Guild rank mapping:" )
    local raw_map = get_guild_rank_map()
    for _, entry in ipairs( rank_names ) do
      local mapped = raw_map[ entry.index ]
      local mapped_str = mapped and hl( M.rank_name( mapped ) ) or grey( "unmapped (Trial)" )
      info( string.format( "  [%d] %s → %s", entry.index, entry.name, mapped_str ) )
    end
  end

  --- Slash command handler.
  local function on_command( args )
    local cmd, a, b = string.match( args or "", "^(%S*)%s*(%S*)%s*(%S*)$" )
    cmd = string.lower( cmd or "" )

    if cmd == "" or cmd == "help" then
      info( "RollFor Rank commands:" )
      info( string.format( "%s – show guild map", hl( "/rfrank guild" ) ) )
      info( string.format( "%s – list overrides", hl( "/rfrank list" ) ) )
      info( string.format( "%s %s %s – map index to priority", hl( "/rfrank map" ), grey( "<index>" ), grey( "<veteran|member|trial>" ) ) )
      info( string.format( "%s %s %s – set manual rank", hl( "/rfrank set" ), grey( "<name>" ), grey( "<veteran|member|trial>" ) ) )
      info( string.format( "%s %s – clear manual rank", hl( "/rfrank clear" ), grey( "<name>" ) ) )
      return
    end

    if cmd == "guild" then print_guild_map() return end
    if cmd == "list" then print_all_overrides() return end

    if cmd == "map" then
      local idx = tonumber( a )
      local rank = M.rank_from_string( b )
      if not idx or not rank then return end
      set_guild_rank_map( idx, rank )
      info( string.format( "Rank [%d] mapped to %s.", idx, hl( M.rank_name( rank ) ) ) )
      return
    end

    if cmd == "set" then
      local player_name = a
      local rank = M.rank_from_string( b )
      if player_name == "" or not rank then return end
      set_player_rank( player_name, rank )
      info( string.format( "%s set to %s.", hl( player_name ), hl( M.rank_name( rank ) ) ) )
      return
    end

    if cmd == "clear" then
      if a == "" then return end
      clear_player_rank( a )
      info( string.format( "Override cleared for %s.", hl( a ) ) )
      return
    end

    if cmd ~= "" then
      local name = string.upper( string.sub( cmd, 1, 1 ) ) .. string.sub( cmd, 2 )
      print_player_rank( name )
    end
  end

  return {
    get_player_rank      = get_player_rank,
    set_player_rank      = set_player_rank,
    clear_player_rank    = clear_player_rank,
    set_guild_rank_map   = set_guild_rank_map,
    get_guild_rank_map   = get_guild_rank_map,
    get_player_overrides = get_player_overrides,
    refresh_guild_cache  = refresh_guild_cache,
    get_rank_names       = get_rank_names,
    request_refresh      = guild_rank_importer.request_refresh,
    on_command           = on_command,
    Rank                 = M.Rank,
    rank_name            = M.rank_name,
    rank_from_string     = M.rank_from_string,
  }
end

m.RankManager = M
return M