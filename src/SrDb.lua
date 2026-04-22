RollFor = RollFor or {}
local m = RollFor

if m.SrDb then return end

local M = {}

---@class SrEntry
---@field item_id number
---@field item_name string?
---@field item_link string?

---@class SrDb
---@field is_open fun(): boolean
---@field set_open fun( open: boolean )
---@field get_max_srs fun(): number
---@field set_max_srs fun( n: number )
---@field add_sr fun( player_name: string, item_id: number, item_link: string? ): string, string?
---@field remove_sr fun( player_name: string, item_id: number ): boolean, string?
---@field swap_sr fun( player_name: string, old_id: number, new_id: number ): string, string?, string?
---@field get_player_srs fun( player_name: string ): SrEntry[]
---@field get_all_srs fun(): table<string, SrEntry[]>
---@field remove_all_srs_for_player fun( player_name: string )
---@field add_sr_for_player fun( player_name: string, item_id: number, item_link: string? )
---@field is_hard_reserved fun( item_id: number ): boolean
---@field add_hr fun( item_id: number, item_link: string? ): string[]  -- returns displaced player names
---@field remove_hr fun( item_id: number )
---@field get_all_hrs fun(): table<number, string?>
---@field to_softres_data fun(): table
---@field load fun( saved: table? )
---@field save fun(): table

---@param db table  -- a sub-table of RollForDb
function M.new( db )
  -- State
  local open     = true
  local max_srs  = 1
  -- srs: table<player_name, SrEntry[]>
  local srs      = {}
  -- hrs: table<item_id, item_link?>
  local hrs      = {}

  local function item_name_from_link( item_link )
    if not item_link then return nil end
    return string.match( item_link, "|h%[(.-)%]|h" )
  end

  -- ── Persistence ──────────────────────────────────────────────────────────

  local function save()
    -- db IS the RollForDb.whisper_sr subtable; write fields directly into it
    db.open    = open
    db.max_srs = max_srs
    db.srs     = srs
    db.hrs     = hrs
  end

  local function load()
    -- Read initial state from db (populated from SavedVariables)
    open    = db.open    ~= nil and db.open    or true
    max_srs = db.max_srs or 1
    srs     = db.srs     or {}
    hrs     = db.hrs     or {}
  end

  -- ── SR accessors ─────────────────────────────────────────────────────────

  local function is_open() return open end

  local function set_open( value )
    open = value
    save()
  end

  local function get_max_srs() return max_srs end

  local function set_max_srs( n )
    max_srs = n
    save()
  end

  local function get_player_srs( player_name )
    return srs[ player_name ] or {}
  end

  local function get_all_srs() return srs end

  local function find_sr_index( player_name, item_id )
    local entries = srs[ player_name ]
    if not entries then return nil end
    for i, entry in ipairs( entries ) do
      if entry.item_id == item_id then return i end
    end
    return nil
  end

  local function add_sr( player_name, item_id, item_link )
    local entries = srs[ player_name ] or {}
    srs[ player_name ] = entries

    -- Duplicate check
    if find_sr_index( player_name, item_id ) then
      return "duplicate", nil
    end

    -- Cap check
    if #entries >= max_srs then
      return "full", nil
    end

    local name = item_name_from_link( item_link )
    table.insert( entries, { item_id = item_id, item_name = name, item_link = item_link } )
    save()
    return "ok", name
  end

  local function remove_sr( player_name, item_id )
    local idx = find_sr_index( player_name, item_id )
    if not idx then return false, nil end
    local entry = srs[ player_name ][ idx ]
    table.remove( srs[ player_name ], idx )
    if #srs[ player_name ] == 0 then srs[ player_name ] = nil end
    save()
    return true, entry.item_name
  end

  local function clear_all_srs()
    srs = {}
    hrs = {}
    save()
  end

  local function swap_sr( player_name, old_id, new_id )
    local idx = find_sr_index( player_name, old_id )
    if not idx then return "not_found", nil, nil end
    if find_sr_index( player_name, new_id ) then return "duplicate", nil, nil end

    local old_entry = srs[ player_name ][ idx ]
    local new_name  = nil

    -- Try to get the new item name from GetItemInfo
    local info_name = m.api and m.api.GetItemInfo and m.api.GetItemInfo( new_id )
    new_name = info_name or ("item:" .. new_id)

    srs[ player_name ][ idx ] = {
      item_id   = new_id,
      item_name = new_name,
      item_link = nil,  -- we don't have the full link here; will update on next GetItemInfo
    }
    save()
    return "ok", old_entry.item_name, new_name
  end

  local function remove_all_srs_for_player( player_name )
    srs[ player_name ] = nil
    save()
  end

  -- Leader manually adds an SR on behalf of a player
  local function add_sr_for_player( player_name, item_id, item_link )
    local entries = srs[ player_name ] or {}
    srs[ player_name ] = entries
    if find_sr_index( player_name, item_id ) then return end
    local name = item_name_from_link( item_link )
    table.insert( entries, { item_id = item_id, item_name = name, item_link = item_link } )
    save()
  end

  -- ── HR accessors ─────────────────────────────────────────────────────────

  local function is_hard_reserved( item_id )
    return hrs[ item_id ] ~= nil
  end

  -- Returns list of player names whose SRs were displaced
  local function add_hr( item_id, item_link )
    hrs[ item_id ] = item_link or true
    -- Find and evict any SRs for this item
    local displaced = {}
    for player_name, entries in pairs( srs ) do
      local idx = find_sr_index( player_name, item_id )
      if idx then
        table.remove( entries, idx )
        if #entries == 0 then srs[ player_name ] = nil end
        table.insert( displaced, player_name )
      end
    end
    save()
    return displaced
  end

  local function remove_hr( item_id )
    hrs[ item_id ] = nil
    save()
  end

  local function get_all_hrs() return hrs end

  -- ── Export for SoftRes injection ─────────────────────────────────────────
  -- Converts whisper SR state into the format SoftRes.import() expects

  local function to_softres_data()
    local softreserves = {}
    local hardreserves = {}

    for player_name, entries in pairs( srs ) do
      local items = {}
      for _, entry in ipairs( entries ) do
        table.insert( items, { id = entry.item_id } )
      end
      table.insert( softreserves, { name = player_name, items = items } )
    end

    for item_id, _ in pairs( hrs ) do
      table.insert( hardreserves, { id = item_id } )
    end

    return {
      metadata     = { id = "whisper-sr", origin = "whisper" },
      softreserves = softreserves,
      hardreserves = hardreserves,
    }
  end

  -- Load from SavedVariables on startup
  load()

  return {
    is_open                  = is_open,
    set_open                 = set_open,
    get_max_srs              = get_max_srs,
    set_max_srs              = set_max_srs,
    add_sr                   = add_sr,
    remove_sr                = remove_sr,
    clear_all_srs            = clear_all_srs,
    swap_sr                  = swap_sr,
    get_player_srs           = get_player_srs,
    get_all_srs              = get_all_srs,
    remove_all_srs_for_player = remove_all_srs_for_player,
    add_sr_for_player        = add_sr_for_player,
    is_hard_reserved         = is_hard_reserved,
    add_hr                   = add_hr,
    remove_hr                = remove_hr,
    get_all_hrs              = get_all_hrs,
    to_softres_data          = to_softres_data,
    reload                    = load,  -- call after db is repopulated
    save                     = save,
    
  }
end

m.SrDb = M
return M
