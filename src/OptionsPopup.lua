RollFor = RollFor or {}
local m = RollFor

if m.OptionsPopup then return end

local info = m.pretty_print
local blue = m.colors.blue

---@type OptionsGuiElements
local e = m.OptionsGuiElements

---@class OptionsPopup
---@field show fun( area: string )
---@field hide fun()
---@field toggle fun()

local M = m.Module.new( "OptionsPopup" )

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 150 }

---@param popup_builder PopupBuilder
---@param awarded_loot AwardedLoot
---@param version_broadcast VersionBroadcast
---@param event_bus EventBus
---@param confirm_popup ConfirmPopup
---@param group_roster GroupRoster
---@param db table
---@param config_db table
---@param config Config
function M.new( popup_builder, awarded_loot, version_broadcast, event_bus, confirm_popup, group_roster, db, config_db, config )
  ---@type Frame
  local popup
  local frames = {}

  local function on_drag_stop()
    if not popup then return end

    if m.is_frame_out_of_bounds( popup ) then
      popup:position( db.point or M.center_point )
      return
    end

    local anchor = popup:get_anchor_point()
    db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
  end

  local function create_popup()
    M.debug.add( "Create popup" )

    local function notify()
      if this:GetObjectType() == "CheckButton" then
        config.notify_subscribers( this:GetParent().config, this:GetChecked() )
      else
        config.notify_subscribers( this:GetParent().config )
      end
    end

    local frame = popup_builder
        :name( "RollForOptionsFrame" )
        :width( 400 )
        :height( 350 )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :sound()
        :movable()
        :on_drag_stop( on_drag_stop )
        :esc()
        :self_centered_anchor()
        :build()

    if not m.classic then
      frame:backdrop_color( 0, 0, 0, .85 )
      frame:border_color( .2, .2, .2, 1 )
    end

    local title_bar = m.GuiElements.titlebar( frame, blue( "RollFor" ) )
    title_bar.title:SetJustifyH( "LEFT" )

    local help_btn = m.GuiElements.tiny_button( frame, "?", "Click this icon and then hover over a field for more information.", "#E6CC40" )
    help_btn:SetPoint( "RIGHT", title_bar.close_btn, "LEFT", m.classic and -4 or -5, 0 )
    help_btn:SetScript( "OnClick", function()
      this.active = not this.active
      if m.classic then
        if this.active then
          this:LockHighlight()
        else
          this:UnlockHighlight()
        end
      end
      this:GetParent().show_help = this.active
    end )

    frames.tab_area = m.api.CreateFrame( "Frame", "area", frame )
    frames.tab_area:SetPoint( "TOPLEFT", title_bar, "BOTTOMLEFT", 7, m.classic and 4 or 0 )
    frames.tab_area:SetPoint( "BOTTOMRIGHT", -7, m.classic and 9 or 7 )
    frames.tab_area.config_db = config_db
    e.create_backdrop( frames.tab_area )

    e.create_gui_entry( "About", frames, function()
      this.title = this:CreateFontString( "Status", "LOW", "GameFontWhite" )
      this.title:SetFont( "FONTS\\FRIZQT__.TTF", 18 )
      this.title:SetPoint( "TOPLEFT", 0, -20 )
      this.title:SetPoint( "RIGHT", this.parent, "RIGHT", 0, 0 )
      this.title:SetJustifyH( "CENTER" )
      this.title:SetText( blue( "RollFor" ) )

      this.versionc = this:CreateFontString( "Status", "LOW", "GameFontWhite" )
      this.versionc:SetPoint( "TOPLEFT", 140, -50 )
      this.versionc:SetWidth( 100 )
      this.versionc:SetJustifyH( "LEFT" )
      this.versionc:SetText( "Version:" )

      this.version = this:CreateFontString( "Status", "LOW", "GameFontWhite" )
      this.version:SetPoint( "TOPRIGHT", 240, -50 )
      this.version:SetWidth( 100 )
      this.version:SetJustifyH( "RIGHT" )
      this.version:SetText( m.get_addon_version().str )

      local new_version = version_broadcast.new_version_available()
      if new_version and m.is_new_version( m.get_addon_version().str, new_version ) then
        this.newversion = this:CreateFontString( "Status", "LOW", "GameFontWhite" )
        this.newversion:SetPoint( "TOPLEFT", 0, -70 )
        this.newversion:SetPoint( "RIGHT", this.parent, "RIGHT", 0, 0 )
        this.newversion:SetJustifyH( "CENTER" )
        this.newversion:SetText( string.format( "New version (%s) is available!", m.colors.highlight( string.format( "v%s", new_version ) ) ) )
      end

      this.info = this:CreateFontString( "Status", "LOW", "GameFontWhite" )
      this.info:SetPoint( "TOPLEFT", 0, -90 )
      this.info:SetPoint( "RIGHT", this.parent, "RIGHT", 0, 0 )
      this.info:SetJustifyH( "CENTER" )
      this.info:SetText( "Check the minimap icon for new commands.\n\nBe a responsible Master Looter.\n\nHappy rolling! o7" )

      this.changelog_title = this:CreateFontString( "Status", "LOW", "GameFontWhite" )
      this.changelog_title:SetPoint( "TOPLEFT", 8, -169 )
      this.changelog_title:SetPoint( "RIGHT", this.parent, "RIGHT", 0, 0 )
      this.changelog_title:SetJustifyH( "LEFT" )
      this.changelog_title:SetText( "Changelog:" )

      this.changelog = e.create_scroll_frame( this.parent )
      e.create_backdrop( this.changelog, 3 )
      this.changelog:SetPoint( "TOPLEFT", this.parent, "TOPLEFT", 10, -186 )
      this.changelog:SetPoint( "BOTTOMRIGHT", this.parent, "BOTTOMRIGHT", -10, 10 )

      this.changelog.content = e.create_scroll_child( this.changelog )
      this.changelog.content.parent = this.changelog

      local changelog = {
        { ver = "4.8.1", text = "Add new MC bosses to boss list. Refactor keybindings" },
        { ver = "4.8.0", text = "Added +1 handling" },
        { ver = "4.7.13", text = "Add option to show player roles in rolling popup." },
        { ver = "4.7.13", text = "Fix wrong zone name for Temple of Ahn'Qiraj." },
        { ver = "4.7.12", text = "Fix trade bug outside raid. Fix minor bug in options window." },
        { ver = "4.7.11", text = "Fix bug in winners popup." },
        { ver = "4.7.10", text = "/src a[nnounce] command now supports /src aw for raid warning." },
        { ver = "4.7.9", text = "Made auto name matcher case insensitive. Tiny improvement to tooltip reader." },
        { ver = "4.7.8", text = "Adjust positioning of client roll popup so it aligns to bottom" },
        { ver = "4.7.7", text = "Add key bindings to toggle options, winners and SR import windows" },
        { ver = "4.7.7", text = "Add changelog to options window" },
        { ver = "4.7.7", text = "Add client settings to options window" },
        { ver = "4.7.7", text = "Add client option to auto-roll on SR items" },
        { ver = "4.7.7", text = "Add Emerald Sanctum bosses to boss list" },
        { ver = "4.7.7", text = "New options for quick awarding items" },
        { ver = "4.7.7", text = "/src announce will announce SR link and players who are missing SR" },
        { ver = "4.7.6", text = "Refactoring of some GUI elements" },
        { ver = "4.7.5", text = "New options GUI" },
        { ver = "4.7.4", text = "Add option to modify rolltype in winners window" },
        { ver = "4.7.3", text = "Fix rare class colorization bug caused by other addons" },
        { ver = "4.7.2", text = "New option to position loot frame at cursor" },
        { ver = "4.7.1", text = "New option to automatically disable tmog roll on trash loot" },
        { ver = "4.7.0", text = "Add roll popup for clients" },
        { ver = "4.6.9", text = "New options to auto announce classes on items with class restrictions" },
        { ver = "4.6.8", text = "New winners GUI to display awarded items" },
        { ver = "4.6.8", text = "Track raid trades so correct winner is displayed in winners window" }
      }

      local last_ver
      for i, entry in ipairs( changelog ) do
        if last_ver ~= entry.ver then
          local ver = this.changelog.content:CreateFontString( "Status", "LOW", "GameFontWhite" )
          ver:SetJustifyH( "LEFT" )
          ver:SetPoint( "TOPLEFT", this.changelog.content, "TOPLEFT", 0, -(i - 1) * 14 )
          ver:SetText( entry.ver )
        end

        local text = this.changelog.content:CreateFontString( "Status", "LOW", "GameFontWhite" )
        text:SetJustifyH( "LEFT" )
        text:SetPoint( "TOPLEFT", this.changelog.content, "TOPLEFT", 30, -(i - 1) * 14 )
        text:SetPoint( "RIGHT", this.changelog.content, "LEFT", 350, 0 )
        text:SetText( entry.text )
        last_ver = entry.ver
      end
    end )

    e.create_gui_entry( "General", frames, function()
      e.create_config( "General settings", nil, "header" )
      e.create_config( "Classic look", "classic_look", "checkbox", "Toggle classic look. Requires /reload", function()
        event_bus.notify( "config_change_requires_ui_reload", { key = "classic_look" } )
      end )
      e.create_config( "Master loot warning", "show_ml_warning", "checkbox", "Show a warning if no master looter is set when targeting a boss.", notify )
      e.create_config( "Auto raid-roll", "auto_raid_roll", "checkbox", "Automatically do a raid-roll if no one rolls for an item.", notify )
      e.create_config( "Auto group loot", "auto_group_loot", "checkbox", "Automatically sets loot mode back to group loot after boss is looted.", notify )
      e.create_config( "Auto master loot", "auto_master_loot", "checkbox", "Automatically sets loot mode to master looter when a boss is targeted.", notify )

      e.create_config( "Minimap", "", "header" )
      e.create_config( "Hide minimap icon", "minimap_button_hidden", "checkbox", nil, notify )
      e.create_config( "Lock minimap icon", "minimap_button_locked", "checkbox", nil, notify )

      e.create_config( "Awards data", nil, "header" )
      e.create_config( "Always keep awards data", "keep_award_data", "checkbox",
        "Stops the addon from clearing award data when you join a new group/raid and on disconnect." )
      e.create_config( "Reset awards data", nil, "button", "Clears all the award data", function()
        if confirm_popup.is_visible() then
          confirm_popup.hide()
          return
        end

        confirm_popup.show( { "This will clear the current winners data.", "Are you sure?" }, function( value )
          if value then
            awarded_loot.clear( true )
          end
        end )
      end )
    end )

    e.create_gui_entry( "Looting", frames, function()
      e.create_config( "Loot settings", nil, "header" )
      e.create_config( "Master loot frame rows", "master_loot_frame_rows", "number|min=5|max=20", "Value must be between 5 and 20 rows.", notify )
      e.create_config( "Auto-loot", "auto_loot", "checkbox", "Auto-loot items below loot thresold. BoP items will not be auto looted." )
      e.create_config( "Auto-loot coins with SuperWow", "superwow_auto_loot_coins", "checkbox", "Automatically loot coins (requires SuperWow mod)." )
      e.create_config( "Auto-loot messages", "auto_loot_messages", "checkbox", "Display auto-looted items in your private chat." )
      e.create_config( "Announce auto-looted items", "auto_loot_announce", "checkbox", "Announce auto-looted items above loot quality threshold to party/raid." )

      e.create_config( "Quick award", nil, "header" )
      this.enable_quick_award_shift = e.create_config( "Enable quick award to self", "enable_quick_award_shift", "checkbox",
        "Enable quick award to self when shift-clicking on \"...\" button.",
        function( value )
          if value or config_db[ "enable_quick_award_ctrl" ] then
            this:GetParent():GetParent().disable_quick_award_confirm.input.enable()
            if config_db[ "disable_quick_award_confirm" ] then
              this:GetParent():GetParent().disable_quick_award_confirm_bop.input.enable()
            end
          else
            this:GetParent():GetParent().disable_quick_award_confirm.input.disable()
            if not config_db[ "disable_quick_award_confirm" ] or not config_db[ "enable_quick_award_ctrl" ] then
              this:GetParent():GetParent().disable_quick_award_confirm_bop.input.disable()
            end
          end
        end )

      this.enable_quick_award_ctrl = e.create_config( "Enable quick award to selected player", "enable_quick_award_ctrl", "checkbox",
        "Enable quick award to selected player when ctrl-clicking on \"...\" button.", function( value )
          if value then
            this:GetParent():GetParent().disable_quick_award_confirm.input.enable()
            this:GetParent():GetParent().quick_award_ctrl.input.enable()
            if config_db[ "disable_quick_award_confirm" ] then
              this:GetParent():GetParent().disable_quick_award_confirm_bop.input.enable()
            end
          else
            this:GetParent():GetParent().quick_award_ctrl.input.disable()
            if not config_db[ "enable_quick_award_shift" ] then
              this:GetParent():GetParent().disable_quick_award_confirm.input.disable()
            end
            if not config_db[ "disable_quick_award_confirm" ] or not config_db[ "enable_quick_award_shift" ] then
              this:GetParent():GetParent().disable_quick_award_confirm_bop.input.disable()
            end
          end
        end )

      this.quick_award_ctrl = e.create_config( "Award Ctrl-click to the following player", "quick_award_ctrl", "text|width=70",
        "Specify which player should receive loot when ctrl-clicking \"...\" button.", function( value )
          if this.disabled then return end
          if group_roster.is_player_in_my_group( value ) then
            this:SetTextColor( 0.1254, 0.6235, 0.9764, 1 )
          else
            this:SetTextColor( 1, .3, .3, 1 )
          end
          config_db[ "quick_award_ctrl" ] = value
        end )

      this.disable_quick_award_confirm = e.create_config( "Disable confirmation popup on quick award", "disable_quick_award_confirm", "checkbox",
        "Disable confirmation popup when using ctrl/shift click to quick assign loot", function( value )
          if value then
            this:GetParent():GetParent().disable_quick_award_confirm_bop.input.enable()
          else
            this:GetParent():GetParent().disable_quick_award_confirm_bop.input.disable()
          end
        end )
      this.disable_quick_award_confirm_bop = e.create_config( "Allow BoP items to be quick awarded without confirmation (|cffff0000CAUTION!|r)",
        "disable_quick_award_confirm_bop", "checkbox", "Allow Bind on Pickup items to be quick awarded without confirmation popup. Not recommended!!" )

      if not this.disable_quick_award_confirm.input:GetChecked() then
        this.disable_quick_award_confirm_bop.input.disable()
      end

      if not this.enable_quick_award_ctrl.input:GetChecked() then
        this.quick_award_ctrl.input.disable()
      end

      if not this.enable_quick_award_ctrl.input:GetChecked() and not this.enable_quick_award_shift.input:GetChecked() then
        this.disable_quick_award_confirm.input.disable()
        this.disable_quick_award_confirm_bop.input.disable()
      end

      e.create_config( "Loot window", nil, "header" )
      e.create_config( "Enable loot window on mouse cursor", "loot_frame_cursor", "checkbox", "Display loot window at cursor when looting.", function()
        config.notify_subscribers( 'reset_loot_frame' )
      end )
      e.create_config( "Reset loot frame position", nil, "button", nil, function()
        info( "Loot frame position has been reset." )
        config.notify_subscribers( "reset_loot_frame" )
      end )
    end )

    e.create_gui_entry( "Rolling", frames, function()
      e.create_config( "Roll settings", nil, "header" )
      e.create_config( "Default rolling time", "default_rolling_time_seconds", "number|min=4|max=15", "Value must be between 4 and 15 seconds." )
      this.handle_plus_ones = e.create_config( "Handle +1's on MS rolls", "handle_plus_ones", "checkbox", nil, function( value )
        if value then
          this:GetParent():GetParent().plus_one_prompt.input.enable()
        else
          this:GetParent():GetParent().plus_one_prompt.input.disable()
        end
      end )
      this.plus_one_prompt = e.create_config("Always prompt for +1's", "plus_one_prompt", "checkbox" )
      if not this.handle_plus_ones.input:GetChecked() then
        this.plus_one_prompt.input.disable()
      end
      e.create_config( "Rolling popup lock", "rolling_popup_lock", "checkbox", "Locks the rolling popup position.", notify )
      e.create_config( "Show Raid roll again button", "raid_roll_again", "checkbox", nil, notify )
      e.create_config( "Show player roles", "show_player_roles", "checkbox", "Show player roles in rolling popup" )
      e.create_config( "MainSpec rolling threshold", "ms_roll_threshold", "number" )
      e.create_config( "OffSpec rolling threshold", "os_roll_threshold", "number" )
      this.tmog_rolling_enabled = e.create_config( "Enable transmog rolling", "tmog_rolling_enabled", "checkbox", nil, function( value )
        if value then
          this:GetParent():GetParent().tmog_roll_threshold.input.enable()
          this:GetParent():GetParent().auto_tmog.input.enable()
        else
          this:GetParent():GetParent().tmog_roll_threshold.input.disable()
          this:GetParent():GetParent().auto_tmog.input.disable()
        end
      end )
      this.tmog_roll_threshold = e.create_config( "Transmog rolling threshold", "tmog_roll_threshold", "number" )
      this.auto_tmog = e.create_config( "Disable transmog roll on trash loot", "auto_tmog", "checkbox", "Automatically disable tmog roll on trash loot." )

      if not this.tmog_rolling_enabled.input:GetChecked() then
        this.tmog_roll_threshold.input.disable()
        this.auto_tmog.input.disable()
      end

      e.create_config( "Announce class restriction on items", "auto_class_announce", "checkbox",
        "Roll message will display classes that can roll on items with class restrictions." )
      e.create_config( "Reset rolling popup position", "", "button", nil, function()
        info( "Rolling popup position has been reset." )
        config.notify_subscribers( "reset_rolling_popup" )
      end )
    end )

    e.create_gui_entry( "Client", frames, function()
      e.create_config( "Client settings", nil, "header" )
      e.create_config( "Show roll popup", "client_show_roll_popup", "dropdown", "Select when to show the roll popup.", nil, {
        { text = "Off",      value = "Off" },
        { text = "Always",   value = "Always" },
        { text = "Eligible", value = "Eligible" }
      } )
      e.create_config( "Auto roll on SR items", "client_auto_roll_sr", "checkbox", "Automatically roll on SR items." )
      e.create_config( "Hide popup when rolling is complete", "client_auto_hide_popup", "checkbox", "Automatically hide roll popup when rolling is completed." )
      --      e.create_config( "Track awarded items", "client_track_awards", "checkbox", "Will track all awarded items so you can view them in winners popup." )
    end )

    return frame
  end

  local function refresh()
    M.debug.add( "refresh" )
    for id, frame in pairs( frames ) do
      if type( frame ) == "table" and frame.area then
        frame.area:Hide()
        if frame.area.scroll.content.setup then
          for _, child in ipairs( { frame.area.scroll.content:GetChildren() } ) do
            if child.config and child.input then
              if child.input:GetFrameType() == "CheckButton" then
                child.input:SetChecked( config_db[ child.config ] )
              elseif child.input:GetFrameType() == "EditBox" then
                child.input:SetText( config_db[ child.config ] )
              elseif child.input:GetFrameType() == "Button" and child.input.dropdown then
                child.input.label:SetText( config_db[ child.config ] )
              end
            end
          end
        end
      end
    end
  end

  local function show( area )
    M.debug.add( "show" )
    if not popup then
      popup = create_popup()
    else
      refresh()
    end

    popup:Show()
    if not area or area == "" then area = frames.active_area or "About" end
    frames[ area ].area:Show()
  end

  local function hide()
    M.debug.add( "hide" )

    if popup then
      popup:Hide()
    end
  end

  local function toggle()
    M.debug.add( "toggle" )
    if popup and popup:IsVisible() then
      hide()
    else
      show()
    end
  end

  ---@type OptionsPopup
  return {
    show = show,
    hide = hide,
    toggle = toggle
  }
end

m.OptionsPopup = M
return M
