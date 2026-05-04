RollFor = RollFor or {}
local m = RollFor

if m.Config then return end

local info = m.pretty_print
local print_header = m.print_header
local hl = m.colors.hl
local blue = m.colors.blue
local grey = m.colors.grey
local RollType = m.Types.RollType

local M = {}

---@alias Expansion
---| "Vanilla"
---| "BCC"

---@alias Config table

---@param db table
---@param event_bus EventBus
function M.new( db, event_bus )
  local callbacks = {}
  local toggles = {
    [ "auto_loot" ] = { cmd = "auto-loot", display = "Auto-loot", help = "toggle auto-loot" },
    [ "handle_plus_ones"] = { cmd = "Handle-plus-ones", display = "handle-plus-ones", help = "Toggle +1 handling for main-spec rolls." },
    [ "plus_one_prompt"] = { cmd = "plus-one-prompt", display = "Plus-one-prompt", help = "Prompt the user for whether the award should give a +1" },
    [ "superwow_auto_loot_coins" ] = { cmd = "superwow-auto-loot-coins", display = "Auto-loot coins with SuperWoW", help = "toggle auto-loot coins with SuperWoW" },
    [ "auto_loot_messages" ] = { cmd = "auto-loot-messages", display = "Auto-loot messages", help = "toggle auto-loot messages" },
    [ "auto_loot_announce" ] = { cmd = "auto-loot-announce", display = "Announce auto-looted items", help = "toggle announcements of auto-loot items" },
    [ "auto_class_announce" ] = { cmd = "auto-class-announce", display = "Announce class restriction on items", help = "toggle announcing of class restriction on items" },
    [ "auto_tmog" ] = { cmd = "auto-tmog", display = "Disable transmog roll on trash loot", help = "toggle transmog roll on trash loot" },
    [ "show_ml_warning" ] = { cmd = "ml", display = "Master loot warning", help = "toggle master loot warning" },
    [ "auto_raid_roll" ] = { cmd = "auto-rr", display = "Auto raid-roll", help = "toggle auto raid-roll" },
    [ "auto_group_loot" ] = { cmd = "auto-group-loot", display = "Auto group loot", help = "toggle auto group loot" },
    [ "auto_master_loot" ] = { cmd = "auto-master-loot", display = "Auto master loot", help = "toggle auto master loot" },
    [ "rolling_popup_lock" ] = { cmd = "rolling-popup-lock", display = "Rolling popup lock", help = "toggle rolling popup lock" },
    [ "raid_roll_again" ] = { cmd = "raid-roll-again", display = string.format( "%s button", hl( "Raid roll again" ) ), help = string.format( "toggle %s button", hl( "Raid roll again" ) ) },
    [ "show_open_roll_button" ] = { cmd = "show-open-roll-button", display = string.format( "%s button", hl( "Open Roll" ) ), help = string.format( "toggle %s button in rolling popup", hl( "Open Roll" ) ) },
    [ "show_player_roles"] = { cmd = "show-player-roles", display = "Show player roles", help="toggle player roles showing in rolling popup" },
    [ "loot_frame_cursor" ] = { cmd = "loot-frame-cursor", display = "Display loot frame at cursor position", help = "toggle displaying loot frame at cursor position" },
    [ "classic_look" ] = { cmd = "classic-look", display = "Classic look", help = "toggle classic look", requires_reload = true },
    [ "client_auto_hide_popup" ] = { cmd = "auto-hide", display = "Hide popup when rolling is complete", help = "toggle hiding of roll popup", client = true },
    [ "client_auto_roll_sr" ] = { cmd = "auto-roll-sr", display = "Auto roll on SR items", help = "automatically roll on SR items", client = true },
    [ "enable_quick_award_shift" ] = { cmd = "enable-quick-award-shift", display = "Enable Shift-click on award other button", help = "Enable Shift-click on award other button award to self" },
    [ "enable_quick_award_ctrl" ] = { cmd = "enable-quick-award-ctrl", display = "Enable Ctrl-click on award other button", help = "Enable Ctrl-click on award others button to award pre-selected player" },
    [ "disable_quick_award_confirm" ] = { cmd = "disable-quick-award-confirm", display = "Disable confirmation on quick award", help = "disable confirmation on quick award (shift/ctrl click)" },
    [ "disable_quick_award_confirm_bop" ] = { cmd = "disable-quick-award-confirm-bop", display = "Allow BOP items to be quick awarded without confirmation", help = "allow BOP items to be quick looted without confirmation popup" },
    [ "announce_sr_on_loot" ] = { cmd = "announce-sr-on-loot", display = "Announce SR status when item drops", help = "announce whether a dropped item is soft-ressed when it is looted" },
  }

  local function notify_subscribers( event, value )
    if not callbacks[ event ] then return end

    for _, callback in ipairs( callbacks[ event ] ) do
      callback( value )
    end
  end

  local function init()
    if not db.ms_roll_threshold then db.ms_roll_threshold = 100 end
    if not db.os_roll_threshold then db.os_roll_threshold = 99 end
    if not db.tmog_roll_threshold then db.tmog_roll_threshold = 98 end
    if not db.superwow_auto_loot_coins then db.superwow_auto_loot_coins = true end
    if db.tmog_rolling_enabled == nil then db.tmog_rolling_enabled = true end
    if db.auto_tmog == nil then db.auto_tmog = false end
    if db.show_ml_warning == nil then db.show_ml_warning = false end
    if db.default_rolling_time_seconds == nil then db.default_rolling_time_seconds = 8 end
    if db.master_loot_frame_rows == nil then db.master_loot_frame_rows = 5 end
    if db.auto_master_loot == nil then db.auto_master_loot = true end
    if db.auto_loot == nil then db.auto_loot = true end
    if db.handle_plus_ones == nil then db.handle_plus_ones = false end
    if db.plus_one_prompt == nil then db.plus_one_prompt = false end
    if db.auto_loot_announce == nil then db.auto_loot_announce = true end
    if db.announce_sr_on_loot == nil then db.announce_sr_on_loot = true end
    if db.loot_frame_cursor == nil then db.loot_frame_cursor = false end
    if db.show_open_roll_button == nil then db.show_open_roll_button = false end
    if db.client_show_roll_popup == nil then db.client_show_roll_popup = "Off" end
    if db.client_auto_hide_popup == nil then db.client_auto_hide_popup = false end
    if db.quick_award_ctrl == nil then db.quick_award_ctrl = "Disabled" end
    if not db.award_filter then
      db.award_filter = {
        item_quality = { Uncommon = 1, Rare = 1, Epic = 1, Legendary = 1 },
        winning_roll = {},
        roll_type = { MainSpec = 1, OffSpec = 1, Transmog = 1, SoftRes = 1, RR = 1 }
      }
    end
    m.classic = db.classic_look
  end

  local function print( toggle_key )
    local toggle = toggles[ toggle_key ]
    if not toggle then return end

    local value = toggle.negate and not db[ toggle_key ] or db[ toggle_key ]
    info( string.format( "%s is %s.", toggles[ toggle_key ].display, value and m.msg.enabled or m.msg.disabled ) )
    notify_subscribers( toggle_key, value )
  end

  local function toggle( toggle_key )
    return function()
      if db[ toggle_key ] then
        db[ toggle_key ] = false
      else
        db[ toggle_key ] = true
      end

      print( toggle_key )

      if toggles[ toggle_key ].requires_reload then
        event_bus.notify( "config_change_requires_ui_reload", { key = toggle_key } )
      end
    end
  end

  local function reset_rolling_popup()
    info( "Rolling popup position has been reset." )
    notify_subscribers( "reset_rolling_popup" )
  end

  local function reset_loot_frame()
    info( "Loot frame position has been reset." )
    notify_subscribers( "reset_loot_frame" )
  end

  local function print_roll_thresholds()
    local ms_threshold = db.ms_roll_threshold
    local os_threshold = db.os_roll_threshold
    local tmog_threshold = db.tmog_roll_threshold
    local tmog_info = string.format( ", %s %s", hl( "TMOG" ), tmog_threshold ) or ""

    info( string.format( "Roll thresholds: %s %s, %s %s%s", hl( "MS" ), ms_threshold, hl( "OS" ), os_threshold, tmog_info ) )
  end

  local function print_transmog_rolling_setting( show_threshold )
    if m.bcc or m.wotlk then return end  -- Transmog rolling is Vanilla-only
    local tmog_rolling_enabled = db.tmog_rolling_enabled
    local threshold = show_threshold and tmog_rolling_enabled and string.format( " (%s)", hl( db.tmog_roll_threshold ) ) or ""
    info( string.format( "Transmog rolling is %s%s.", tmog_rolling_enabled and m.msg.enabled or m.msg.disabled, threshold ) )
  end

  local function print_default_rolling_time()
    info( string.format( "Default rolling time: %s seconds", hl( db.default_rolling_time_seconds ) ) )
  end

  local function print_master_loot_frame_rows()
    info( string.format( "Master loot frame rows: %s", hl( db.master_loot_frame_rows ) ) )
  end

  local function print_settings()
    print_header( "RollFor Configuration" )
    print_default_rolling_time()
    print_master_loot_frame_rows()
    print_roll_thresholds()
    print_transmog_rolling_setting()

    for toggle_key, setting in pairs( toggles ) do
      if not setting.hidden and not setting.client then
        print( toggle_key )
      end
    end

    m.print( string.format( "For more info, type: %s", hl( "/rf config help" ) ) )
  end

  local function print_client_roll()
    info( string.format( "Show roll popup: %s", hl( db.client_show_roll_popup ) ) )
  end

  local function print_client_settings()
    print_header( "RollFor Client Configuration" )
    print_client_roll()

    for toggle_key, setting in pairs( toggles ) do
      if not setting.hidden and setting.client then
        print( toggle_key )
      end
    end

    m.print( string.format( "For more info, type: %s", hl( "/rf config client help" ) ) )
  end

  local function print_client_help()
    local v = function( name ) return string.format( "%s%s%s", hl( "<" ), grey( name ), hl( ">" ) ) end
    local function rfc( cmd ) return string.format( "%s%s", blue( "/rf config client" ), cmd and string.format( " %s", hl( cmd ) ) or "" ) end

    print_header( "RollFor Client Configuration Help" )
    m.print( string.format( "%s - show configuration", rfc() ) )
    m.print( string.format( "%s %s - set when to show roll popup", rfc( "show-roll" ), v( "Off|Always|Eligible" ) ) )

    for _, setting in pairs( toggles ) do
      if not setting.hidden and setting.client then
        m.print( string.format( "%s - %s", rfc( setting.cmd ), setting.help ) )
      end
    end
  end

  local function configure_default_rolling_time( args )
    if args == "config default-rolling-time" then
      print_default_rolling_time()
      return
    end

    for value in string.gmatch( args, "config default%-rolling%-time (%d+)" ) do
      local v = tonumber( value )

      if v < 4 then
        info( string.format( "Default rolling time must be at least %s seconds.", hl( "4" ) ) )
        return
      end

      if v > 15 then
        info( string.format( "Default rolling time must be at most %s seconds.", hl( "15" ) ) )
        return
      end

      db.default_rolling_time_seconds = v
      print_default_rolling_time()
      return
    end

    info( string.format( "Usage: %s <seconds>", hl( "/rf config default-rolling-time" ) ) )
  end

  local function configure_master_loot_frame_rows( args )
    if args == "config master-loot-frame-rows" then
      print_master_loot_frame_rows()
      return
    end

    for value in string.gmatch( args, "config master%-loot%-frame%-rows (%d+)" ) do
      local v = tonumber( value )

      if v < 5 then
        info( string.format( "Master loot frame rows must be at least %s.", hl( "5" ) ) )
        return
      end

      db.master_loot_frame_rows = v
      print_master_loot_frame_rows()
      notify_subscribers( "master_loot_frame_rows" )
      return
    end

    info( string.format( "Usage: %s <rows>", hl( "/rf config master-loot-frame-rows" ) ) )
  end

  local function configure_ms_threshold( args )
    for value in string.gmatch( args, "config ms (%d+)" ) do
      db.ms_roll_threshold = tonumber( value )
      print_roll_thresholds()
      return
    end

    info( string.format( "Usage: %s <threshold>", hl( "/rf config ms" ) ) )
  end

  local function configure_os_threshold( args )
    for value in string.gmatch( args, "config os (%d+)" ) do
      db.os_roll_threshold = tonumber( value )
      print_roll_thresholds()
      return
    end

    info( string.format( "Usage: %s <threshold>", hl( "/rf config os" ) ) )
  end

  local function configure_tmog_threshold( args )
    if args == "config tmog" then
      db.tmog_rolling_enabled = not db.tmog_rolling_enabled
      print_transmog_rolling_setting( true )
      return
    end

    for value in string.gmatch( args, "config tmog (%d+)" ) do
      db.tmog_roll_threshold = tonumber( value )
      print_roll_thresholds()
      return
    end

    info( string.format( "Usage: %s <threshold>", hl( "/rf config tmog" ) ) )
  end

  local function configure_client_roll( args )
    for value in string.gmatch( args, "config client show%-roll (%a+)" ) do
      if ({ off = true, always = true, eligible = true })[ string.lower( value ) ] then
        db.client_show_roll_popup = string.upper( string.sub( value, 1, 1 ) ) .. string.lower( string.sub( value, 2 ) )
        print_client_roll()
        return
      end
    end

    print_client_roll()
    info( string.format( "Usage: %s <Off|Always|Eligible>", hl( "/rf config client show-roll" ) ) )
  end

  local function print_help()
    local v = function( name ) return string.format( "%s%s%s", hl( "<" ), grey( name ), hl( ">" ) ) end
    local function rfc( cmd ) return string.format( "%s%s", blue( "/rf config" ), cmd and string.format( " %s", hl( cmd ) ) or "" ) end

    print_header( "RollFor Configuration Help" )
    m.print( string.format( "%s - show configuration", rfc() ) )
    m.print( string.format( "%s - toggle minimap icon", rfc( "minimap" ) ) )
    m.print( string.format( "%s - lock/unlock minimap icon", rfc( "minimap lock" ) ) )
    m.print( string.format( "%s - show default rolling time", rfc( "default-rolling-time" ) ) )
    m.print( string.format( "%s - show master loot frame rows", rfc( "master-loot-frame-rows" ) ) )
    m.print( string.format( "%s %s - set default rolling time", rfc( "default-rolling-time" ), v( "seconds" ) ) )
    m.print( string.format( "%s - show MS rolling threshold ", rfc( "ms" ) ) )
    m.print( string.format( "%s %s - set MS rolling threshold ", rfc( "ms" ), v( "threshold" ) ) )
    m.print( string.format( "%s - show OS rolling threshold ", rfc( "os" ) ) )
    m.print( string.format( "%s %s - set OS rolling threshold ", rfc( "os" ), v( "threshold" ) ) )

    if m.vanilla then  -- TMOG rolling is Vanilla-only; not available on BCC or WotLK
      m.print( string.format( "%s - toggle TMOG rolling", rfc( "tmog" ) ) )
      m.print( string.format( "%s %s - set TMOG rolling threshold", rfc( "tmog" ), v( "threshold" ) ) )
    end

    for _, setting in pairs( toggles ) do
      if not setting.hidden and not setting.client then
        m.print( string.format( "%s - %s", rfc( setting.cmd ), setting.help ) )
      end
    end

    m.print( string.format( "%s - reset rolling popup position", rfc( "reset-rolling-popup" ) ) )
    m.print( string.format( "%s - reset loot frame position", rfc( "reset-loot-frame" ) ) )
    m.print( string.format( "%s - show client configuration", rfc( "client" ) ) )
  end

  local function lock_minimap_button()
    db.minimap_button_locked = true
    info( string.format( "Minimap button is %s.", m.msg.locked ) )
    notify_subscribers( "minimap_button_locked", true )
  end

  local function unlock_minimap_button()
    db.minimap_button_locked = false
    info( string.format( "Minimap button is %s.", m.msg.unlocked ) )
    notify_subscribers( "minimap_button_locked", false )
  end

  local function hide_minimap_button()
    db.minimap_button_hidden = true
    notify_subscribers( "minimap_button_hidden", true )
  end

  local function show_minimap_button()
    db.minimap_button_hidden = false
    notify_subscribers( "minimap_button_hidden", false )
  end

  local function on_command( args )
    if args == "config" then
      print_settings()
      return
    end

    if args == "config help" then
      print_help()
      return
    end

    if args == "config client" then
      print_client_settings()
      return
    end

    if args == "config client help" then
      print_client_help()
      return
    end

    if string.find( args, "^config client show%-roll" ) then
      configure_client_roll( args )
      return
    end

    for toggle_key, setting in pairs( toggles ) do
      if args == string.format( "config client %s", setting.cmd ) and setting.client then
        toggle( toggle_key )()
        return
      elseif args == string.format( "config %s", setting.cmd ) and not setting.client then
        toggle( toggle_key )()
        return
      end
    end

    if args == "config reset-rolling-popup" then
      reset_rolling_popup()
      return
    end

    if args == "config reset-loot-frame" then
      reset_loot_frame()
      return
    end

    if args == "config minimap" then
      if db.minimap_button_hidden then
        show_minimap_button()
      else
        hide_minimap_button()
      end

      return
    end

    if args == "config minimap lock" then
      if db.minimap_button_locked then
        unlock_minimap_button()
      else
        lock_minimap_button()
      end

      return
    end

    if string.find( args, "^config ms" ) then
      configure_ms_threshold( args )
      return
    end

    if string.find( args, "^config os" ) then
      configure_os_threshold( args )
      return
    end

    if string.find( args, "^config tmog" ) then
      configure_tmog_threshold( args )
      return
    end

    if string.find( args, "^config default%-rolling%-time" ) then
      configure_default_rolling_time( args )
      return
    end

    if string.find( args, "^config master%-loot%-frame%-rows" ) then
      configure_master_loot_frame_rows( args )
      return
    end

    print_help()
  end

  local function subscribe( event, callback )
    callbacks[ event ] = callbacks[ event ] or {}
    table.insert( callbacks[ event ], callback )
  end

  local function roll_threshold( roll_type )
    local threshold = (roll_type == RollType.MainSpec or roll_type == RollType.SoftRes) and db.ms_roll_threshold or
        roll_type == RollType.OffSpec and db.os_roll_threshold or
        db.tmog_roll_threshold
    local threshold_str = string.format( "/roll%s", threshold == 100 and "" or string.format( " %s", threshold ) )

    return {
      value = threshold,
      str = threshold_str
    }
  end

  local function enable_client_roll_popup()
    if db.client_show_roll_popup == "Off" then
      db.client_show_roll_popup = "Eligible"
      info( string.format( "Show roll popup has been set to %s by lootmaster.", hl( db.client_show_roll_popup ) ) )
    end
  end

  init()

  ---@param setting_key string
  ---@param expansion Expansion?
  ---@param not_available_value any?
  local function get( setting_key, expansion, not_available_value )
    if expansion and (expansion == "Vanilla" and (m.bcc or m.wotlk) or expansion == "BCC" and m.vanilla) then
      return function()
        return not_available_value
      end
    end

    return function()
      return db[ setting_key ]
    end
  end

  local function printfn( setting_key ) return function() print( setting_key ) end end

  local config = {
    configure_ms_threshold = configure_ms_threshold,
    configure_os_threshold = configure_os_threshold,
    configure_tmog_threshold = configure_tmog_threshold,
    hide_minimap_button = hide_minimap_button,
    lock_minimap_button = lock_minimap_button,
    minimap_button_hidden = get( "minimap_button_hidden" ),
    minimap_button_locked = get( "minimap_button_locked" ),
    ms_roll_threshold = get( "ms_roll_threshold" ),
    on_command = on_command,
    os_roll_threshold = get( "os_roll_threshold" ),
    print = print,
    print_help = print_help,
    print_raid_roll_settings = printfn( "auto_raid_roll" ),
    reset_rolling_popup = reset_rolling_popup,
    reset_loot_frame = reset_loot_frame,
    roll_threshold = roll_threshold,
    show_minimap_button = show_minimap_button,
    subscribe = subscribe,
    tmog_roll_threshold = get( "tmog_roll_threshold" ),
    tmog_rolling_enabled = get( "tmog_rolling_enabled", "Vanilla", false ),
    unlock_minimap_button = unlock_minimap_button,
    default_rolling_time_seconds = get( "default_rolling_time_seconds" ),
    master_loot_frame_rows = get( "master_loot_frame_rows" ),
    configure_master_loot_frame_rows = configure_master_loot_frame_rows,
    client_show_roll_popup = get( "client_show_roll_popup" ),
    client_auto_hide_popup = get( "client_auto_hide_popup" ),
    enable_client_roll_popup = enable_client_roll_popup,
    award_filter = get( "award_filter" ),
    keep_award_data = get( "keep_award_data" ),
    quick_award_ctrl = get( "quick_award_ctrl" ),
    notify_subscribers = notify_subscribers
  }

  for toggle_key, _ in pairs( toggles ) do
    config[ toggle_key ] = get( toggle_key )
    config[ "toggle_" .. toggle_key ] = toggle( toggle_key )
  end

  return config
end

m.Config = M
return M