RollFor = RollFor or {}
local m = RollFor

if m.RankManager then return end

local M = {}

local info = m.pretty_print
local hl   = m.colors.hl
local grey = m.colors.grey

--- Rank priority constants.  Lower number = higher priority in rolls.
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

--- db layout:
---   db.guild_rank_map  = { [rankIndex] = Rank.Veteran|Member|Trial|nil }
---   db.player_ranks    = { [playerName] = Rank.Veteran|Member|Trial }

---@param db table               -- persistent SavedVariables subtable ("rank_manager")
---@param guild_rank_importer GuildRankImporter
function M.new( db, guild_rank_importer )
  -- Ensure sub-tables exist
  if not db.guild_rank_map then db.guild_rank_map = {} end
  if not db.player_ranks   then db.player_ranks   = {} end

  -- Cache the last-fetched guild player→rankIndex map so lookups are O(1)
  local guild_player_cache = {}

  local function refresh_guild_cache()
    guild_player_cache = guild_rank_importer.get_player_ranks()
  end

  --- Resolve the effective rank for a player.
  --- Priority: manual override → guild rank mapping → Trial (default for non-guild).
  local function get_player_rank( player_name )
    -- 1. Manual override always wins
    local override = db.player_ranks[ player_name ]
    if override then return override end

    -- 2. Try guild rank mapping
    local guild_rank_index = guild_player_cache[ player_name ]
    if guild_rank_index ~= nil then
      local mapped = db.guild_rank_map[ guild_rank_index ]
      if mapped then return mapped end
    end

    -- 3. Default: non-guild members are Trial
    return M.Rank.Trial
  end

  --- Set a manual override rank for a player.
  local function set_player_rank( player_name, rank )
    db.player_ranks[ player_name ] = rank
  end

  --- Remove the manual override for a player (they revert to guild-rank logic).
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

  --- Print current rank for a player.
  local function print_player_rank( player_name )
    local rank = get_player_rank( player_name )
    local override = db.player_ranks[ player_name ] and " (manual override)" or ""
    info( string.format( "%s rank: %s%s", hl( player_name ), hl( M.rank_name( rank ) ), grey( override ) ) )
  end

  --- Print all manual overrides.
  local function print_all_overrides()
    local count = 0
    for name, rank in pairs( db.player_ranks ) do
      info( string.format( "  %s: %s", hl( name ), M.rank_name( rank ) ) )
      count = count + 1
    end
    if count == 0 then info( "No manual rank overrides set." ) end
  end

  --- Print the current guild rank → priority mapping.
  local function print_guild_map()
    local rank_names = guild_rank_importer.get_rank_names()
    if #rank_names == 0 then
      info( "Not in a guild or guild data not loaded yet." )
      return
    end
    info( "Guild rank mapping:" )
    for _, entry in ipairs( rank_names ) do
      local mapped = db.guild_rank_map[ entry.index ]
      local mapped_str = mapped and hl( M.rank_name( mapped ) ) or grey( "unmapped (Trial)" )
      info( string.format( "  [%d] %s → %s", entry.index, entry.name, mapped_str ) )
    end
  end

  --- Handle /rfrank slash command.
  ---   /rfrank                       – show help
  ---   /rfrank map <guildRankIndex> <veteran|member|trial>
  ---   /rfrank set <PlayerName> <veteran|member|trial>
  ---   /rfrank clear <PlayerName>
  ---   /rfrank list                  – show all overrides
  ---   /rfrank guild                 – show guild rank map
  ---   /rfrank <PlayerName>          – show rank for player
  local function on_command( args )
    local cmd, a, b = string.match( args or "", "^(%S*)%s*(%S*)%s*(%S*)$" )
    cmd = string.lower( cmd or "" )

    if cmd == "" or cmd == "help" then
      info( "RollFor Rank commands:" )
      info( string.format( "%s – show this help", hl( "/rfrank" ) ) )
      info( string.format( "%s – show guild rank → priority map", hl( "/rfrank guild" ) ) )
      info( string.format( "%s – list manual overrides", hl( "/rfrank list" ) ) )
      info( string.format( "%s %s %s – map guild rank index to priority", hl( "/rfrank map" ), grey( "<index>" ), grey( "<veteran|member|trial>" ) ) )
      info( string.format( "%s %s %s – set manual rank for player", hl( "/rfrank set" ), grey( "<name>" ), grey( "<veteran|member|trial>" ) ) )
      info( string.format( "%s %s – clear manual rank for player", hl( "/rfrank clear" ), grey( "<name>" ) ) )
      return
    end

    if cmd == "guild" then
      print_guild_map()
      return
    end

    if cmd == "list" then
      print_all_overrides()
      return
    end

    if cmd == "map" then
      local idx = tonumber( a )
      local rank = M.rank_from_string( b )
      if not idx or not rank then
        info( string.format( "Usage: %s %s %s", hl( "/rfrank map" ), grey( "<index>" ), grey( "<veteran|member|trial>" ) ) )
        return
      end
      set_guild_rank_map( idx, rank )
      info( string.format( "Guild rank [%d] mapped to %s.", idx, hl( M.rank_name( rank ) ) ) )
      return
    end

    if cmd == "set" then
      local player_name = a
      local rank = M.rank_from_string( b )
      if player_name == "" or not rank then
        info( string.format( "Usage: %s %s %s", hl( "/rfrank set" ), grey( "<name>" ), grey( "<veteran|member|trial>" ) ) )
        return
      end
      set_player_rank( player_name, rank )
      info( string.format( "%s manually set to %s.", hl( player_name ), hl( M.rank_name( rank ) ) ) )
      return
    end

    if cmd == "clear" then
      local player_name = a
      if player_name == "" then
        info( string.format( "Usage: %s %s", hl( "/rfrank clear" ), grey( "<name>" ) ) )
        return
      end
      clear_player_rank( player_name )
      info( string.format( "Manual rank override cleared for %s.", hl( player_name ) ) )
      return
    end

    -- Fallback: treat cmd as a player name
    if cmd ~= "" then
      -- Capitalise first letter to match WoW naming
      local name = string.upper( string.sub( cmd, 1, 1 ) ) .. string.sub( cmd, 2 )
      print_player_rank( name )
      return
    end

    info( "Unknown rank command. Type /rfrank for help." )
  end

  return {
    get_player_rank      = get_player_rank,
    set_player_rank      = set_player_rank,
    clear_player_rank    = clear_player_rank,
    set_guild_rank_map   = set_guild_rank_map,
    get_guild_rank_map   = get_guild_rank_map,
    get_player_overrides = get_player_overrides,
    refresh_guild_cache  = refresh_guild_cache,
    on_command           = on_command,
    Rank                 = M.Rank,
    rank_name            = M.rank_name,
    rank_from_string     = M.rank_from_string,
  }
end

m.RankManager = M
return M
