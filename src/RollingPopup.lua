RollFor = RollFor or {}
local m = RollFor

if m.RollingPopup then return end

local getn = m.getn
local c = m.colorize_player_by_class
local blue = m.colors.blue
local RollType = m.Types.RollType

local button_defaults = {
  width = 80,
  height = 24,
  scale = 0.76
}

---@alias RollingPopupData RollingPopupPreviewData|RollingPopupRaidRollData|RollingPopupRollData|RollingPopupRollingCanceledData|RollingPopupRaidRollingData|RollingPopupTieData|RollingPopupAwardedData

---@class RollingPopup
---@field show fun()
---@field refresh fun( _, content: RollingPopupData )
---@field hide fun()
---@field border_color fun( _, color: RgbaColor )
---@field backdrop_color fun( _, color: RgbaColor )
---@field get_frame fun(): table
---@field ping fun()
---@field get_anchor_point fun(): Point?
---@field align_bottom fun()

local M = m.Module.new( "RollingPopup" )

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 150 }

---@param popup_builder PopupBuilder
---@param content_transformer RollingPopupContentTransformer
---@param db table
---@param config Config
function M.new( popup_builder, content_transformer, db, config )
  ---@type Popup?
  local popup
  local options = {}
  db.point = db.point or M.center_point

  local top_padding = config.classic_look() and 14 or 8
  local on_hide ---@type fun()?

  ---@param frame_name string?
  ---@param close_button_callback fun()?
  local function toggle_esc( frame_name, close_button_callback )
    if not frame_name then return end

    ---@diagnostic disable-next-line: undefined-global
    local f = UISpecialFrames

    local function disable_esc()
      ---@diagnostic disable-next-line: undefined-global
      for i, v in ipairs( f ) do
        if v == frame_name then table.remove( f, i ) end
      end
    end

    local function enable_esc()
      disable_esc()
      table.insert( f, frame_name )
    end

    if close_button_callback then
      on_hide = close_button_callback
      enable_esc()
    else
      on_hide = nil
      disable_esc()
    end
  end

  local function create_popup()
    local function on_drag_stop()
      if not popup then return end

      if m.is_frame_out_of_bounds( popup ) then
        db.point = options.point or M.center_point
        popup:position( db.point )
        return
      end

      if options.point then
        local scale = m.api.UIParent:GetEffectiveScale()
        local center_x, center_y = m.api.UIParent:GetCenter()
        local offset_x = (popup:GetLeft() + (popup:GetWidth() / 2)) - (center_x * scale)
        local offset_y = popup:GetBottom() - (center_y * scale)

        db.point = { point = options.point.point, relative_point = options.point.relative_point, x = offset_x, y = offset_y }
        popup:position( db.point )
        return
      end

      local anchor = popup:get_anchor_point()
      db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
    end

    local function get_point()
      if popup and m.is_frame_out_of_bounds( popup ) then
        return options.point or M.center_point
      elseif db.point then
        return db.point
      else
        return options.point or M.center_point
      end
    end

    local builder = popup_builder
        :name( "RollForRollingFrame" )
        :width( 180 )
        :height( 100 )
        :point( get_point() )
        :sound()
        :gui_elements( m.GuiElements )
        :movable()
        :on_drag_stop( on_drag_stop )
        :on_hide( function()
          if on_hide then
            on_hide()
          end
        end )

    if not options.point then
      builder:self_centered_anchor()
    end

    local result = builder:build()

    if config.rolling_popup_lock() then
      result:lock()
    else
      result:unlock()
    end

    config.subscribe( "rolling_popup_lock", function( enabled )
      if enabled then
        result:lock()
      else
        result:unlock()
      end
    end )

    config.subscribe( "reset_rolling_popup", function()
      db.point = nil
      if result then result:position( M.center_point ) end
    end )

    return result
  end

  ---@param buttons RollingPopupButtonWithCallback[]
  ---@return fun()?
  local function find_close_button_callback( buttons )
    for _, button in ipairs( buttons or {} ) do
      if button.type == "Close" then
        return button.callback
      end
    end
  end

  ---@param data RollingPopupData
  local function refresh( _, data )
    M.debug.add( string.format( "refresh( type: %s )", data.type or "nil" ) )
    M.debug.add( string.format( "buttons: %s", data.buttons and m.prettify_table( data.buttons, function( b ) return b.type end ) or "nil" ) )

    if not popup then popup = create_popup() end
    popup:clear()

    local close_button_callback = find_close_button_callback( data.buttons )
    toggle_esc( popup:GetName(), close_button_callback )

    for _, v in ipairs( content_transformer.transform( data ) ) do
      popup.add_line( v.type, function( type, frame, lines )
        if type == "item_link_with_icon" then
          frame:SetItem( v, v.link and m.ItemUtils.get_tooltip_link( v.link ) )
        elseif type == "text" then
          frame:SetText( v.value )
        elseif type == "icon_text" then
          frame:SetText( v.value )
        elseif type == "roll" then
          local roll_type_text = m.roll_type_abbrev( v.roll_type )
          if v.roll_type == RollType.MainSpec and v.plus_ones > 0 then
            roll_type_text = roll_type_text .. " +" .. v.plus_ones
          end
          frame.roll_type:SetText( m.roll_type_color( v.roll_type, roll_type_text ) )

          local show_player_roles = config.show_player_roles()
          frame:SetWidth( config.show_player_roles() and 200 or 170 )

          local player_role = show_player_roles and v.player_role and string.format( " (%s)", string.gsub( v.player_role, v.player_class, "" ) ) or ""
          frame.player_name:SetText( string.format( "%s%s", c( v.player_name, v.player_class ), player_role ) )

          if v.roll then
            frame.roll:SetText( blue( v.roll ) )
            frame.icon:Hide()
          else
            frame.roll:SetText( "" )
            frame.icon:Show()
          end
        elseif type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:ClearAllPoints() -- This fixes a strange visual bug in BCC. Frame is either without label or misaligned without this.
          frame:SetScale( v.scale or button_defaults.scale )

          local f = v.on_click and close_button_callback and v.on_click == close_button_callback and function()
            on_hide = nil
            close_button_callback()
          end or v.on_click or function() end

          frame:SetScript( "OnClick", f )

          if v.disabled then
            frame:Disable()
          else
            frame:Enable()
          end
        elseif type == "award_button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )

          if v.disabled then
            frame:Disable()
          else
            frame:Enable()
          end
        elseif type == "info" then
          frame.tooltip_info = v.value
          frame:ClearAllPoints()
          frame:SetPoint( "TOPRIGHT", v.anchor, "TOPRIGHT", -5, -5 )
        elseif type == "empty_line" then
          frame:SetHeight( v.height or 4 )
        end

        if type ~= "button" then
          local count = getn( lines )

          if count == 0 then
            local y = -top_padding - (v.padding or 0)
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", popup, "TOP", 0, y )
          else
            local line_anchor = lines[ count ].frame
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", line_anchor, "BOTTOM", 0, v.padding and -v.padding or 0 )
          end
        end
      end, v.padding )
    end
  end

  local function show()
    M.debug.add( "show" )

    if not popup then
      popup = create_popup()
    else
      popup:clear()
    end

    popup:Show()
  end

  local function hide()
    M.debug.add( "hide" )

    if popup then
      on_hide = nil
      popup:Hide()
    end
  end

  ---@param color RgbaColor
  local function border_color( _, color )
    if not popup then
      popup = create_popup()
    end

    local col = config.classic_look() and m.brighten( color, 0.5 ) or color
    popup:border_color( col.r, col.g, col.b, col.a )
  end

  ---@param color RgbaColor
  local function backdrop_color( _, color )
    if not popup then
      popup = create_popup()
    end

    popup:backdrop_color( color.r, color.g, color.b, color.a )
  end

  local function get_frame()
    if not popup then
      create_popup()
    end

    return popup
  end

  local function ping()
    if m.vanilla then
      m.api.PlaySound( "igMainMenuOpen" )
    else
      m.api.PlaySound( m.api.SOUNDKIT.IG_MAINMENU_OPEN )
    end
  end

  local function get_anchor_point()
    return popup and popup.get_anchor_point()
  end

  local function align_bottom()
    options.point = { point = "BOTTOM", relative_point = "CENTER", x = 0, y = 0 }
    if db.point and db.point.point ~= "BOTTOM" then
      db.point = options.point
    end
  end

  ---@type RollingPopup
  return {
    show = show,
    refresh = refresh,
    hide = hide,
    border_color = border_color,
    backdrop_color = backdrop_color,
    get_frame = get_frame,
    ping = ping,
    get_anchor_point = get_anchor_point,
    align_bottom = align_bottom
  }
end

m.RollingPopup = M
return M
