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
---@param rank_manager RankManager
function M.new( popup_builder, awarded_loot, version_broadcast, event_bus, confirm_popup, group_roster, db, config_db, config, rank_manager )
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

    -- ... (About, General, Looting, and Rolling entries remain the same as your provided source)

    e.create_gui_entry( "Ranks", frames, function()
      e.create_config( "Rank priority settings", nil, "header" )
      e.create_config( "Enable rank priority on rolls", "rank_priority_enabled", "checkbox",
        "When enabled, Veterans beat Members beat Trials regardless of roll value.", notify )

      if rank_manager then
        e.create_config( "Guild rank mapping", nil, "header" )

        local rank_opts = {
          { text = "Veteran",  value = 1 },
          { text = "Member",   value = 2 },
          { text = "Trial",    value = 3 },
          { text = "Unranked", value = 4 },
        }

        -- Uses the RankManager method which is now proxy-safe
        local guild_rank_names = rank_manager.get_rank_names()

        if #guild_rank_names == 0 then
          e.create_config( "No guild rank data found.", nil, "header" )
          e.create_config( "Roster data is loading. Please wait or click Reload.", nil, "header" )
        else
          for _, entry in ipairs( guild_rank_names ) do
            local caption = string.format( "[%d] %s", entry.index, entry.name )
            e.create_config( caption, nil, "dropdown",
              "Map this guild rank to a roll priority tier.",
              function( value )
                rank_manager.set_guild_rank_map( entry.index, value )
              end,
              rank_opts
            )
          end
        end

        e.create_config( "Reload guild ranks", nil, "button", "Requests fresh data and rebuilds this list.", function()
          rank_manager.request_refresh()
          
          local area = frames[ "Ranks" ] and frames[ "Ranks" ].area
          if area and area.scroll and area.scroll.content then
            -- Clear children to prevent UI ghosting/doubling
            local children = { area.scroll.content:GetChildren() }
            for _, child in ipairs( children ) do
              child:Hide()
            end
            area.scroll.content.setup = nil -- Force population closure to re-run
            area:Hide()
            area:Show()
          end
        end )

        e.create_config( "Manual overrides", nil, "header" )
        e.create_config( "  /rfrank set <name> <veteran|member|trial>", nil, "header" )
        e.create_config( "  /rfrank clear <name>", nil, "header" )
        e.create_config( "  /rfrank list", nil, "header" )
      end
    end )

    -- ... (Client entry remains same)

    return frame
  end

  -- Automated Event Listener
  -- This rebuilds the Ranks tab whenever RankManager confirms data is ready.
  if event_bus then
    event_bus.subscribe( "ROLLFOR_GUILD_RANKS_UPDATED", function()
      local area = frames[ "Ranks" ] and frames[ "Ranks" ].area
      if area and area.scroll and area.scroll.content then
        area.scroll.content.setup = nil
        -- If the user is currently looking at the Ranks tab, refresh it live[cite: 1]
        if area:IsVisible() then
          local children = { area.scroll.content:GetChildren() }
          for _, child in ipairs( children ) do child:Hide() end
          area:Hide()
          area:Show()
        end
      end
    end )
  end

  -- ... (refresh, show, hide, toggle functions remain same)

  return {
    show = show,
    hide = hide,
    toggle = toggle
  }
end

m.OptionsPopup = M
return M