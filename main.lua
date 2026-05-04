RollFor = RollFor or {}
local m = RollFor

---@diagnostic disable-next-line: undefined-global
local lib_stub = LibStub
local version = m.get_addon_version()

local M = {}

local getn = m.getn
local info = m.pretty_print
local hl, white, grey, green, red = m.colors.highlight, m.colors.white, m.colors.grey, m.colors.green, m.colors.red
local RollSlashCommand = m.Types.RollSlashCommand
local RollType = m.Types.RollType
local RollingStrategy = m.Types.RollingStrategy

local function clear_data()
  M.softres_gui.clear()
  M.name_matcher.clear( true )
  M.softres.clear( true )
  M.minimap_button.set_icon( M.minimap_button.ColorType.White )
  M.winner_tracker.clear()
end

local function update_minimap_icon()
  local result = M.softres_check.check_softres( true )

  if result == M.softres_check.ResultType.NoItemsFound then
    M.minimap_button.set_icon( M.minimap_button.ColorType.White )
  elseif result == M.softres_check.ResultType.SomeoneIsNotSoftRessing then
    M.minimap_button.set_icon( M.minimap_button.ColorType.Orange )
  elseif result == M.softres_check.ResultType.FoundOutdatedData then
    M.minimap_button.set_icon( M.minimap_button.ColorType.Red )
  else
    M.minimap_button.set_icon( M.minimap_button.ColorType.Green )
  end
end

local function on_softres_status_changed()
  update_minimap_icon()
end

local function on_raid_trade( giver_name, recipient_name, item_name )
  local item_id = M.dropped_loot.get_dropped_item_id( item_name )

  if item_id then
    local quality, _ = m.get_item_quality_and_texture( m.api, item_id )
    local item_link = m.fetch_item_link( item_id, quality )

    M.loot_award_callback.on_loot_awarded( item_id, item_link, recipient_name, nil, true )
    if item_id and M.awarded_loot.has_item_been_awarded( giver_name, item_id ) then
      info( string.format( "%s traded %s to %s.", hl( giver_name ), item_link, hl( recipient_name ) ) )
      M.awarded_loot.unaward( giver_name, item_id )
    end
  end
end

local function trade_complete_callback( recipient_name, items_given, items_received )
  if not M.api().IsInGroup() then return end

  for i = 1, getn( items_given ) do
    local item = items_given[ i ]
    if item then
      local item_id = M.item_utils.get_item_id( item.link )
      local item_name = item_id and M.dropped_loot.get_dropped_item_name( item_id )

      if item_id and item_name then
        M.loot_award_callback.on_loot_awarded( item_id, item.link, recipient_name )
      end
    end
  end

  for i = 1, getn( items_received ) do
    local item = items_received[ i ]

    if item then
      local item_id = M.item_utils.get_item_id( item.link )

      if item_id and M.awarded_loot.has_item_been_awarded( recipient_name, item_id ) then
        M.unaward_item( recipient_name, item_id, item.link )
      end
    end
  end
end

local function create_components()
  ---@type AceTimer
  M.ace_timer = lib_stub( "AceTimer-3.0" )

  local db = m.Db.new( M.char_db )

  ---@type EventBus
  M.config_event_bus = m.EventBus.new()

  ---@type Config
  M.config = m.Config.new( db( "config" ), M.config_event_bus )

  local classic = M.config.classic_look()
  local popup_bottom_margin, popup_bottom_button_margin = classic and 37 or 24, classic and 14 or 7
  local popup_side_margin = classic and 50 or 35
  local popup_builder_factory = classic and m.PopupBuilder.classic or m.PopupBuilder.modern

  local function popup_builder( bottom_margin, side_margin )
    return popup_builder_factory( m.FrameBuilder, bottom_margin or popup_bottom_margin, popup_bottom_button_margin, side_margin or popup_side_margin )
  end

  M.ui_reload_popup = m.UiReloadPopup.new( popup_builder( classic and 37 or 27 ), M.config )
  M.confirm_popup = m.ConfirmPopup.new( popup_builder( classic and 37 or 27 ), M.config )

  M.api = function() return m.api end
  M.player_info = m.PlayerInfo.new( M.api() )
  M.group_roster = m.GroupRoster.new( M.api(), M.player_info )
  M.chat_api = m.ChatApi.new()
  M.chat = m.Chat.new( M.chat_api, M.group_roster, M.player_info )

  M.present_softres = function( softres ) return m.SoftResPresentPlayersDecorator.new( M.group_roster, softres ) end
  M.absent_softres = function( softres ) return m.SoftResAbsentPlayersDecorator.new( M.group_roster, softres ) end

  M.item_utils = m.ItemUtils
  M.tooltip_reader = m.TooltipReader.new( M.api() )
  M.version_broadcast = m.VersionBroadcast.new( db( "version_broadcast" ), M.player_info, version.str )
  M.awarded_loot = m.AwardedLoot.new( db( "awarded_loot" ), M.group_roster, M.config )

  M.softres_db = db( "softres" )
  M.unfiltered_softres = m.SoftRes.new( M.softres_db )

  M.name_matcher = m.NameManualMatcher.new(
    db( "name_matcher" ), M.api,
    M.absent_softres( M.unfiltered_softres ),
    m.NameAutoMatcher.new( M.group_roster, M.unfiltered_softres, 0.57, 0.4 ),
    on_softres_status_changed
  )

  M.matched_name_softres = m.SoftResMatchedNameDecorator.new( M.name_matcher, M.unfiltered_softres )
  M.awarded_loot_softres = m.SoftResAwardedLootDecorator.new( M.awarded_loot, M.matched_name_softres )
  M.softres = M.present_softres( M.awarded_loot_softres )

  M.dropped_loot = m.DroppedLoot.new( db( "dropped_loot" ) )
  M.softres_check = m.SoftResCheck.new( M.matched_name_softres, M.group_roster, M.name_matcher, M.ace_timer,
    M.absent_softres, db( "softres_check" ) )

  M.winner_tracker = m.WinnerTracker.new( db( "winner_tracker" ) )
  M.loot_facade = m.LootFacade.new( m.EventFrame.new( m.api ), m.api )
  M.raw_loot_list = m.LootList.new( M.loot_facade, M.item_utils, M.tooltip_reader, m.BossList.zones, nil )
  M.loot_list = m.SoftResLootListDecorator.new( M.raw_loot_list, M.softres )
  M.master_loot_candidates = m.MasterLootCandidates.new( M.api(), M.group_roster, M.raw_loot_list )
  M.player_selection_frame = m.MasterLootCandidateSelectionFrame.new( m.FrameBuilder, M.config )

  M.rolling_popup = m.RollingPopup.new(
    popup_builder(),
    m.RollingPopupContentTransformer.new( M.config ),
    db( "rolling_popup" ),
    M.config
  )

  M.loot_frame = m.LootFrame.new(
    M.config.classic_look() and m.OgLootFrameSkin.new( m.FrameBuilder ) or m.ModernLootFrameSkin.new( m.FrameBuilder ),
    db( "loot_frame" ),
    M.config
  )

  M.loot_award_popup = m.LootAwardPopup.new(
    popup_builder( classic and 38 or 30, classic and 65 or 55 ),
    M.config,
    M.rolling_popup
  )

  --- CIRCULAR DEPENDENCY FIX SEQUENCE ---[cite: 3]
  
  -- 1. Create LootAwardCallback first with nil for controller[cite: 3]
  M.loot_award_callback = m.LootAwardCallback.new( M.awarded_loot, nil, M.winner_tracker, M.group_roster, M.softres, M.confirm_popup, M.config )

  -- 2. Create RollController and pass in the callback as the 9th argument[cite: 1, 3]
  M.roll_controller = m.RollController.new(
    M.master_loot_candidates,
    M.softres,
    M.loot_list,
    M.config,
    M.rolling_popup,
    M.loot_award_popup,
    M.player_selection_frame,
    M.player_info,
    M.loot_award_callback
  )

  -- 3. Link the controller back to the callback using the setter[cite: 3]
  M.loot_award_callback.set_roll_controller( M.roll_controller )

  -----------------------------------------

  M.master_loot = m.MasterLoot.new( M.master_loot_candidates, M.loot_award_callback, M.loot_list, M.roll_controller )
  M.auto_loot = m.AutoLoot.new( M.loot_list, M.api, db( "auto_loot" ), M.config, M.player_info )
  M.dropped_loot_announce = m.DroppedLootAnnounce.new( M.loot_list, M.chat, M.dropped_loot, M.softres, M.winner_tracker, M.player_info, M.auto_loot, M.config )
  M.winners_popup = m.WinnersPopup.new( popup_builder(), m.FrameBuilder, db( "winners_popup" ), M.awarded_loot, M.roll_controller, M.confirm_popup, M.config )
  M.options_popup = m.OptionsPopup.new( popup_builder(), M.awarded_loot, M.version_broadcast, M.config_event_bus, M.confirm_popup, M.group_roster, db( "options_popup" ), db( "config" ), M.config, M.rank_manager )

  M.softres_gui = m.SoftResGui.new( M.api, M.import_encoded_softres_data, M.softres_check, M.softres, clear_data, M.dropped_loot_announce.reset, M.ace_timer, M.group_roster, M.unfiltered_softres )
  M.sr_listener = m.SrListener.new( M.player_info, M.unfiltered_softres )
  M.trade_tracker = m.TradeTracker.new( M.ace_timer, M.chat, trade_complete_callback )
  M.usage_printer = m.UsagePrinter.new( M.chat )

  M.minimap_button = m.MinimapButton.new( M.api, db( "minimap_button" ), M.softres_gui.toggle, M.winners_popup.toggle, M.options_popup.toggle, M.softres_check, M.config )
  M.master_loot_warning = m.MasterLootWarning.new( M.api, M.config, m.BossList.zones, M.player_info )
  M.new_group_event = m.NewGroupEvent.new( M.group_roster )
  M.auto_group_loot = m.AutoGroupLoot.new( M.loot_list, M.config, m.BossList.zones, M.player_info )
  M.auto_master_loot = m.AutoMasterLoot.new( M.config, m.BossList.zones, M.player_info )
  M.softres_roll_gui_data = m.SoftResRollGuiData.new( M.softres, M.group_roster )
  M.tie_roll_gui_data = m.TieRollGuiData.new( M.group_roster )
  M.welcome_popup = m.WelcomePopup.new( m.FrameBuilder, M.ace_timer, db( "welcome_popup" ) )
  M.roll_for_ad = m.RollForAd.new( M.player_info )

  M.guild_rank_importer = m.GuildRankImporter.new()
  M.rank_manager = m.RankManager.new( db( "rank_manager" ), M.guild_rank_importer )
  M.rolling_strategy_factory = m.RollingStrategyFactory.new( M.group_roster, M.loot_list, M.master_loot_candidates, M.chat, M.ace_timer, M.winner_tracker, M.config, M.softres, M.player_info, M.awarded_loot, M.rank_manager )
  M.rolling_logic = m.RollingLogic.new( M.chat, M.ace_timer, M.roll_controller, M.rolling_strategy_factory, M.master_loot_candidates, M.winner_tracker, M.config )

  M.loot_controller = m.LootController.new( M.player_info, M.loot_facade, M.loot_list, M.loot_frame, M.roll_controller, M.softres, M.rolling_logic, M.chat )
  M.args_parser = m.ArgsParser.new( m.ItemUtils, M.config )
  M.roll_result_announcer = m.RollResultAnnouncer.new( M.chat, M.roll_controller, M.softres, M.config )

  M.loot_facade_listener = m.LootFacadeListener.new( M.loot_facade, M.auto_loot, M.dropped_loot_announce, M.master_loot, M.auto_group_loot, M.roll_controller, M.player_info )

  M.client_broadcast = m.ClientBroadcast.new( M.roll_controller, M.softres, M.config )
  M.client = m.Client.new( M.ace_timer, M.player_info, M.rolling_popup, M.config )
  M.sandbox = m.Sandbox.new()
end

local function subscribe_for_component_events()
  M.config.subscribe( "show_ml_warning", function( enabled )
    if enabled then
      M.master_loot_warning.on_player_target_changed()
    else
      M.master_loot_warning.hide()
    end
  end )

  M.new_group_event.subscribe( function()
    M.awarded_loot.clear()
    M.dropped_loot.clear()
  end )

  M.config_event_bus.subscribe( "config_change_requires_ui_reload", function()
    M.ui_reload_popup.show()
  end )
end

function M.import_softres_data( softres_data )
  M.unfiltered_softres.import( softres_data )
  M.name_matcher.auto_match()
end

function M.import_encoded_softres_data( data, data_loaded_callback )
  local sr = m.SoftRes
  local softres_data = sr.decode( data )

  if not softres_data and data and string.len( data ) > 0 then
    info( "Could not load soft-res data!", m.colors.red )
    return
  elseif not softres_data then
    M.minimap_button.set_icon( M.minimap_button.ColorType.White )
    return
  end

  M.import_softres_data( softres_data )

  info( "Soft-res data loaded successfully!" )
  if data_loaded_callback then data_loaded_callback( softres_data ) end

  update_minimap_icon()
end

local function on_roll_command( roll_slash_command )
  return function( args )
    if M.rolling_logic.is_rolling() then
      M.chat.info( "Rolling is in progress." )
      return
    end

    if string.find( args, "^debug" ) then
      m.DebugBuffer.on_command( args )
      return
    end

    if string.find( args, "^config" ) then
      M.config.on_command( args )
      return
    end

    if args == "versioncheck guild" then
      M.version_broadcast.guild_version_request()
      return
    end

    if not M.api().IsInGroup() then
      M.chat.info( "Not in a group." )
      return
    end

    if args == "versioncheck" then
      M.version_broadcast.group_version_request()
      return
    end

    if string.find( args, "^client enable" ) and M.player_info.is_master_looter() then
      M.client_broadcast.enable_roll_popup()
      return
    end

    local item, count, seconds, message = M.args_parser.parse( args )

    if not item then
      M.usage_printer.print_usage( roll_slash_command )
      return
    end

    local strategy_type = m.Types.slash_command_to_strategy_type( roll_slash_command )

    if not strategy_type then
      info( string.format( "Unsupported command: %s", hl( roll_slash_command and roll_slash_command.slash_command or "?" ) ) )
      return
    end

    if M.softres.is_item_hardressed( item.id ) then
      M.roll_controller.preview( item, count )
      return
    end

    M.roll_controller.start( strategy_type, item, count, seconds, message )
  end
end

local function on_show_sorted_rolls_command( args )
  if M.rolling_logic.is_rolling() then
    info( "Rolling is in progress." )
    return
  end

  if args then
    for limit in string.gmatch( args, "(%d+)" ) do
      M.rolling_logic.show_sorted_rolls( tonumber( limit ) )
      return
    end
  end

  M.rolling_logic.show_sorted_rolls( 5 )
end

local function is_rolling_check( f )
  return function( ... )
    if not M.rolling_logic.is_rolling() then
      M.chat.info( "Rolling not in progress." )
      return
    end

    f( unpack( arg ) )
  end
end

local function in_group_check( f )
  return m.in_group_check( M.api(), M.chat, f )
end

local function setup_storage()
  if RollForDb and RollForDb.global and RollForDb.global.version then
    RollForDb = nil
  end

  RollForDb = RollForDb or {}
  RollForCharDb = RollForCharDb or {}

  M.db = RollForDb
  M.char_db = RollForCharDb

  if not M.db.version then
    M.db.version = version.str
  end
end

local function on_softres_command( args )
  if args == "init" then
    clear_data()
  end
  M.softres_gui.toggle()
end

local function on_check_softres_command( args )
  if string.find( args, "^a" ) then
    local use_raid_warning = string.find( args, "w" ) and true or false
    local result, players = M.softres_check.check_softres( true )

    if result == M.softres_check.ResultType.SomeoneIsNotSoftRessing and m.raid_id then
      local msg = string.format( "https://raidres.fly.dev/res/%s", m.raid_id )
      if getn( players ) < 10 then
        msg = msg .. " - "
        for i = 1, getn( players ) do
          local separator = i == 1 and "" or ", "
          local player_name = players[ i ].name
          local grouped_player = M.group_roster.find_player( player_name )
          local next = grouped_player and m.colorize_player_by_class( grouped_player.name, grouped_player.class ) or player_name
          msg = msg .. separator .. next
        end
        msg = string.gsub(msg, "^(.*),%s*(.*)$", "%1 and %2")
        msg = msg .. " missing SR"
      end
      M.chat.announce( msg, use_raid_warning )
    else
      m.pretty_print("No soft-res items found.")
    end
  else
    M.softres_check.check_softres()
  end
end

local function on_roll( player_name, roll, min, max )
  local player = M.group_roster.find_player( player_name )
  if not player then
    m.err( string.format( "Player %s could not be found.", hl( player_name ) ) )
    return
  end
  M.rolling_logic.on_roll( player, roll, min, max )
end

local function on_loot_method_changed()
  M.master_loot_warning.on_party_loot_method_changed()
end

local function on_master_looter_changed( player_name )
  if M.player_info.get_name() == player_name and m.is_master_loot() then
    M.ace_timer.ScheduleTimer( M, M.config.print_raid_roll_settings, 0.1 )
  end
end

function M.on_chat_msg_system( message )
  for player_name, roll, min, max in string.gmatch( message, "([^%s]+) rolls (%d+) %((%d+)%-(%d+)%)" ) do
    on_roll( player_name, tonumber( roll ), tonumber( min ), tonumber( max ) )
    return
  end

  if string.find( message, "^Looting changed to" ) then
    on_loot_method_changed()
    return
  end

  for player_name in string.gmatch( message, "(.-) is now the loot master%." ) do
    on_master_looter_changed( player_name )
    return
  end

  for giver_name, item_name, recipient_name in string.gmatch( message, "([^%s]+) trades item (.+) to ([^%s]+)%." ) do
    on_raid_trade( giver_name, recipient_name, item_name )
    return
  end
end

local function show_how_to_roll()
  M.chat.announce( "How to roll:" )
  local ms = M.config.ms_roll_threshold() ~= 100 and string.format( " (%s)", M.config.ms_roll_threshold() or "100" ) or ""
  local sr = M.softres.get_all_rollers()
  local sr_count = getn( sr )
  M.chat.announce( string.format( "For main-spec%s, type: /roll%s", sr_count > 0 and " and soft-res" or "", ms ) )
  M.chat.announce( string.format( "For off-spec, type: /roll %s", M.config.os_roll_threshold() ) )
  if M.config.tmog_rolling_enabled() then
    M.chat.announce( string.format( "For transmog, type: /roll %s", M.config.tmog_roll_threshold() ) )
  end
end

local function on_reset_dropped_loot_announce_command()
  M.dropped_loot_announce.reset()
end

local function plus_ones_command( args )
  local loot = M.awarded_loot.get_winners()
  local players = {}
  for _, award in ipairs(loot) do
    if award ~= nil then
      if not players[award.player_name] then players[award.player_name] = { award }
      else table.insert(players[award.player_name], award) end
    end
  end

  if args == "" then
    local plus_ones_exist = false
    for player_name, awards in pairs(players) do
      local plus_ones = m.filter(awards, (function(a) return a.plus_one end))
      if getn(plus_ones) > 0 then
        plus_ones_exist = true
        local item_list = table.concat(m.map(plus_ones, (function (a) return a.item_link end)), " ")
        local colored_player_name = m.colorize_player_by_class( player_name, awards[1].player_class ) or grey( player_name )
        M.chat.info( colored_player_name .. green(" MS +" .. getn(plus_ones)) .. ": " .. item_list)
      end
    end
    if not plus_ones_exist then M.chat.info("There are no +1's yet") end
  else
    local action, player_name, item_link = string.match(args, "^(%S+) (%S+) (|%w+|Hitem.+|r)$")
    local item_id = item_link and M.item_utils.get_item_id( item_link )
    local group_players = M.group_roster.get_all_players_in_my_group()
    local player = player_name and m.filter(group_players, (function (p) return string.lower(p.name) == string.lower(player_name) end))[1]
    if action == "add" and player and item_id then
      local roll_data = { player_name = player.name, player_class = player.class, roll_type = RollType.MainSpec, roll = 0, plus_ones = 0 }
      M.awarded_loot.award( player.name, item_id, roll_data, RollingStrategy.NormalRoll, item_link, player.class, nil, true)
    elseif (action == "rm" or action == "remove") and player and item_id then
      M.unaward_item( player.name, item_id, item_link )
    end
  end
end

local function setup_slash_commands()
  SLASH_RF1 = RollSlashCommand.NormalRoll
  M.api().SlashCmdList[ "RF" ] = on_roll_command( RollSlashCommand.NormalRoll )
  SLASH_ARF1 = RollSlashCommand.NoSoftResRoll
  M.api().SlashCmdList[ "ARF" ] = in_group_check( on_roll_command( RollSlashCommand.NoSoftResRoll ) )
  SLASH_RR1 = RollSlashCommand.RaidRoll
  M.api().SlashCmdList[ "RR" ] = in_group_check( on_roll_command( RollSlashCommand.RaidRoll ) )
  SLASH_IRR1 = RollSlashCommand.InstaRaidRoll
  M.api().SlashCmdList[ "IRR" ] = in_group_check( on_roll_command( RollSlashCommand.InstaRaidRoll ) )
  SLASH_HTR1 = "/htr"
  M.api().SlashCmdList[ "HTR" ] = in_group_check( show_how_to_roll )
  SLASH_CR1 = "/cr"
  M.api().SlashCmdList[ "CR" ] = is_rolling_check( M.roll_controller.cancel_rolling )
  SLASH_FR1 = "/fr"
  M.api().SlashCmdList[ "FR" ] = is_rolling_check( M.roll_controller.finish_rolling_early )
  SLASH_SSR1 = "/ssr"
  M.api().SlashCmdList[ "SSR" ] = on_show_sorted_rolls_command
  SLASH_RFR1 = "/rfr"
  M.api().SlashCmdList[ "RFR" ] = on_reset_dropped_loot_announce_command
  SLASH_SR1 = "/sr"
  M.api().SlashCmdList[ "SR" ] = on_softres_command
  SLASH_SRS1 = "/srs"
  M.api().SlashCmdList[ "SRS" ] = M.softres_check.show_softres
  SLASH_SRC1 = "/src"
  M.api().SlashCmdList[ "SRC" ] = on_check_softres_command
  SLASH_SRO1 = "/sro"
  M.api().SlashCmdList[ "SRO" ] = M.name_matcher.manual_match
  SLASH_RFW1 = "/rfw"
  M.api().SlashCmdList[ "RFW" ] = M.winners_popup.show
  SLASH_RFO1 = "/rfo"
  M.api().SlashCmdList[ "RFO" ] = M.options_popup.show
  SLASH_RFT1 = "/rft"
  M.api().SlashCmdList[ "RFT" ] = M.sandbox.run
  SLASH_PL1 = "/pl"
  M.api().SlashCmdList[ "PL"] = plus_ones_command
  SLASH_RFRANK1 = "/rfrank"
  M.api().SlashCmdList[ "RFRANK" ] = function( args ) M.rank_manager.on_command( args ) end
end

function M.on_guild_roster_update()
  if M.rank_manager then M.rank_manager.refresh_guild_cache() end
end

function M.on_player_login()
  setup_storage()
  create_components()
  subscribe_for_component_events()
  setup_slash_commands()

  if C_ChatInfo and C_ChatInfo.RegisterAddonMessagePrefix then C_ChatInfo.RegisterAddonMessagePrefix("RollFor")
  elseif RegisterAddonMessagePrefix then RegisterAddonMessagePrefix("RollFor") end

  info( string.format( "Loaded (%s).", hl( string.format( "v%s", version.str ) ) ) )
  M.version_broadcast.broadcast()
  M.import_encoded_softres_data( M.softres_db.data )
  M.softres_gui.load( M.softres_db.data )

  -- Kick off an async guild roster fetch so rank data is ready when the Ranks tab is opened.
  if M.rank_manager then M.rank_manager.request_refresh() end

  if M.welcome_popup.should_show() then M.welcome_popup.show() end
  LootFrame:UnregisterAllEvents()
end

function M.unaward_item( player_name, item_id, item_link )
  M.awarded_loot.unaward( player_name, item_id )
  info( string.format( "%s returned %s.", hl( player_name ), item_link ) )
end

function M.on_group_changed()
  M.name_matcher.auto_match()
  update_minimap_icon()
end

function M.on_chat_msg_addon( name, message, _, sender )
  if name ~= "RollFor" or not message then return end
  for ver in string.gmatch( message, "VERSION::(.*)" ) do M.version_broadcast.on_version( ver ) return end
  for channel, requesting_player_name in string.gmatch( message, "VERSION_REQUEST::(.-)::(.*)" ) do M.version_broadcast.on_version_request( channel, requesting_player_name ) return end
  for requesting_player_name, channel, their_name, their_class, their_version in string.gmatch( message, "VERSION_RESPONSE::(.-)::(.-)::(.-)::(.-)::(.*)" ) do
    M.version_broadcast.on_version_response( requesting_player_name, channel, their_name, their_class, their_version )
    return
  end
  for data in string.gmatch( message, "ROLL::(.*)" ) do M.client.on_message( data, sender ) return end
end

m.key_bindings = m.KeyBindings.new( M )
m.EventHandler.handle_events( M )
return M