RollFor = RollFor or {}
local m = RollFor

if m.OptionsGuiElements then return end

---@class ScrollFrame: Frame
---@field SetScrollChild fun( parent: Frame, scroll_child: Frame )
---@field content Frame

---@class ChildFrame: Frame

---@class InputFrame
---@field GetChecked fun(): boolean
---@field disable fun()
---@field enable fun()

---@class ConfigFrame: Frame
---@field input InputFrame

---@class OptionsGuiElements
---@field create_gui_entry fun( title: string, frames: table, populate: function )
---@field entry_update fun()
---@field create_backdrop fun( f: table, insert: number?, legacy: boolean?, transp: number?, backdropSetting: table? )
---@field create_scroll_frame fun( parent: Frame, name: string? ): ScrollFrame
---@field create_scroll_child fun( parent: ScrollFrame, name: string? ): ChildFrame
---@field create_tab_frame fun( parent: table, title: string ): Frame
---@field create_area fun( parent: table, title: string, func: function ): Frame
---@field create_config fun( caption: string, setting: any, widget: string, tooltip: string?, ufunc: function?, options: table? ): ConfigFrame
local M = {}

local function get_perfect_pixel()
  if M.pixel then return M.pixel end

  local scale = m.api.GetCVar( "uiScale" )
  local resolution = m.api.GetCVar( "gxResolution" )
  local _, _, _, screenheight = string.find( resolution, "(.+)x(.+)" )

  M.pixel = 768 / screenheight / scale
  M.pixel = M.pixel > 1 and 1 or M.pixel

  return M.pixel
end

function M.set_all_points_offset( frame, parent, offset )
  frame:SetPoint( "TOPLEFT", parent, "TOPLEFT", offset, -offset )
  frame:SetPoint( "BOTTOMRIGHT", parent, "BOTTOMRIGHT", -offset, offset )
end

function M.create_gui_entry( title, frames, populate )
  if not frames[ title ] then
    frames[ title ] = M.create_tab_frame( frames, title )
    frames[ title ].area = M.create_area( frames, title, populate )
  end
end

function M.entry_update()
  local focus = m.api.GetMouseFocus()
  if (focus and focus.value) then
    return
  end

  if m.api.MouseIsOver( this ) and not this.over then
    this.tex:Show()
    this.over = true
    if this:GetParent():GetParent():GetParent():GetParent():GetParent().show_help then
      if this.tooltip then
        this:GetParent().tooltip = this
        m.api.GameTooltip:SetOwner( this, "ANCHOR_TOPLEFT" )
        m.api.GameTooltip:SetText( this.tooltip )
        m.api.GameTooltip:Show()
      end
    end
  elseif not m.api.MouseIsOver( this ) and this.over then
    this.tex:Hide()
    this.over = nil
    if m.api.GameTooltip:IsShown() and this:GetParent().tooltip == this then
      m.api.GameTooltip:Hide()
    end
  end
end

function M.create_backdrop( f, inset, legacy, transp, backdropSetting )
  if not f then return end

  local border = get_perfect_pixel()
  if inset then border = inset end

  local br, bg, bb, ba = 0, 0, 0, 1
  local dr, dg, db, da = 0.2, 0.2, 0.2, 1
  local backdrop = {
    bgFile = "Interface\\BUTTONS\\WHITE8X8",
    tile = false,
    tileSize = 0,
    edgeFile = "Interface\\BUTTONS\\WHITE8X8",
    edgeSize = M.pixel,
    insets = { left = -M.pixel, right = -M.pixel, top = -M.pixel, bottom = -M.pixel },
  }

  if transp and transp < tonumber( ba ) then ba = transp end

  if legacy then
    if backdropSetting then f:SetBackdrop( backdropSetting ) end
    f:SetBackdrop( backdrop )
    f:SetBackdropColor( br, bg, bb, ba )
    f:SetBackdropBorderColor( dr, dg, db, da )
  else
    if not f.backdrop then
      if f:GetBackdrop() then f:SetBackdrop( nil ) end

      local b = m.api.CreateFrame( "Frame", nil, f )
      local level = f:GetFrameLevel()
      if level < 1 then
        b:SetFrameLevel( level )
      else
        b:SetFrameLevel( level - 1 )
      end

      f.backdrop = b
    end

    f.backdrop:SetPoint( "TOPLEFT", f, "TOPLEFT", -border, border )
    f.backdrop:SetPoint( "BOTTOMRIGHT", f, "BOTTOMRIGHT", border, -border )
    f.backdrop:SetBackdrop( backdrop )
    f.backdrop:SetBackdropColor( br, bg, bb, ba )
    f.backdrop:SetBackdropBorderColor( dr, dg, db, da )
  end
end

function M.create_scroll_frame( parent, name )
  local f = m.api.CreateFrame( "ScrollFrame", name, parent )

  f.slider = m.api.CreateFrame( "Slider", nil, f )
  f.slider:SetOrientation( 'VERTICAL' )
  f.slider:SetPoint( "TOPLEFT", f, "TOPRIGHT", m.classic and -13 or -7, 0 )
  f.slider:SetPoint( "BOTTOMRIGHT", 0, 0 )
  f.slider:SetThumbTexture( "Interface\\BUTTONS\\WHITE8X8" )
  f.slider.thumb = f.slider:GetThumbTexture()
  f.slider.thumb:SetHeight( 50 )
  f.slider.thumb:SetTexture( .125, .624, .976, .5 )

  f.slider:SetScript( "OnValueChanged", function()
    f:SetVerticalScroll( this:GetValue() )
    f.update_scroll_state()
  end )

  f.update_scroll_state = function()
    f.slider:SetMinMaxValues( 0, f:GetVerticalScrollRange() )
    f.slider:SetValue( f:GetVerticalScroll() )

    local r = f:GetHeight() + f:GetVerticalScrollRange()
    local v = f:GetHeight()
    local ratio = v / r

    if ratio < 1 then
      local size = math.floor( v * ratio )
      f.slider.thumb:SetHeight( size )
      f.slider:Show()
    else
      f.slider:Hide()
    end
  end

  f.scroll = function( self, step )
    step = step or 0

    local current = f:GetVerticalScroll()
    local max = f:GetVerticalScrollRange()
    local new = current - step

    if new >= max then
      f:SetVerticalScroll( max )
    elseif new <= 0 then
      f:SetVerticalScroll( 0 )
    else
      f:SetVerticalScroll( new )
    end

    f:update_scroll_state()
  end

  f:EnableMouseWheel( 1 )
  f:SetScript( "OnMouseWheel", function()
    this:scroll( arg1 * 10 )
  end )

  return f
end

function M.create_scroll_child( parent, name )
  local f = m.api.CreateFrame( "Frame", name, parent )

  -- dummy values required
  f:SetWidth( 1 )
  f:SetHeight( 1 )
  f:SetAllPoints( parent )

  parent:SetScrollChild( f )

  f:SetScript( "OnUpdate", function()
    this:GetParent():update_scroll_state()
  end )

  return f
end

function M.create_tab_frame( parent, title )
  if not parent.tab_area.count then parent.tab_area.count = 0 end

  local f = m.api.CreateFrame( "Button", nil, parent.tab_area )
  f:SetPoint( "TOPLEFT", parent.tab_area, "TOPLEFT", parent.tab_area.count * 65, 0 )
  f:SetPoint( "BOTTOMRIGHT", parent.tab_area, "TOPLEFT", (parent.tab_area.count + 1) * 65, -20 )
  f.parent = parent

  f:SetScript( "OnClick", function()
    if this.area:IsShown() then
      return
    else
      for id, name in pairs( this.parent ) do
        if type( name ) == "table" and name.area and id ~= "parent" then
          name.area:Hide()
        end
      end
      this.area:Show()
    end
  end )

  f.bg = f:CreateTexture( nil, "BACKGROUND" )
  f.bg:SetAllPoints()

  f.text = f:CreateFontString( nil, "LOW", "GameFontWhite" )
  f.text:SetAllPoints()
  f.text:SetText( title )

  parent.tab_area.count = parent.tab_area.count + 1

  return f
end

function M.create_area( parent, title, func )
  local f = m.api.CreateFrame( "Frame", nil, parent.tab_area )
  f:SetPoint( "TOPLEFT", parent.tab_area, "TOPLEFT", 0, -20 )
  f:SetPoint( "BOTTOMRIGHT", parent.tab_area, "BOTTOMRIGHT", 0, 0 )
  f:Hide()

  f.button = parent[ title ]
  f.bg = f:CreateTexture( nil, "BACKGROUND" )
  f.bg:SetTexture( 1, 1, 1, .05 )
  f.bg:SetAllPoints()

  f:SetScript( "OnShow", function()
    parent.active_area = title
    this.indexed = true
    this.button.text:SetTextColor( 0.1254, 0.6235, 0.9764, 1 )
    this.button.bg:SetTexture( 1, 1, 1, 1 )
    this.button.bg:SetGradientAlpha( "VERTICAL", 1, 1, 1, .05, 0, 0, 0, 0 )
  end )

  f:SetScript( "OnHide", function()
    this.button.text:SetTextColor( 1, 1, 1, 1 )
    this.button.bg:SetTexture( 0, 0, 0, 0 )
  end )

  if func then
    f.scroll = M.create_scroll_frame( f )
    M.set_all_points_offset( f.scroll, f, 2 )

    ---@class ChildFrame
    f.scroll.content = M.create_scroll_child( f.scroll )
    f.scroll.content.parent = f.scroll
    f.scroll.content:SetScript( "OnShow", function()
      this.parent:UpdateScrollChildRect()
      if not this.setup then
        func()
        this.setup = true
      end
    end )
  end

  return f
end

function M.create_config( caption, setting, widget, tooltip, ufunc, options )
  local function parse_options()
    local w = string.sub( widget, 1, (string.find( widget, "|", nil, true ) or 0) - 1 )
    local opt = {}
    for key, value in string.gmatch( widget, ("|(%a+)=([^|]+)") ) do
      opt[ key ] = tonumber( value ) or value
    end

    return w, opt
  end

  this.object_count = this.object_count == nil and 0 or this.object_count + 1

  local config_db = this:GetParent():GetParent():GetParent().config_db
  local frame = m.api.CreateFrame( "Frame", nil, this )
  frame:SetWidth( this:GetParent():GetWidth() - 22 )
  frame:SetHeight( 22 )
  frame:SetPoint( "TOPLEFT", this, "TOPLEFT", 5, (this.object_count * -23) - 5 )
  frame.config = setting
  frame.tooltip = tooltip

  if not options then
    widget, options = parse_options()
  end

  if not widget or (widget and widget ~= "button") then
    if widget ~= "header" then
      frame:SetScript( "OnUpdate", M.entry_update )
      frame.tex = frame:CreateTexture( nil, "BACKGROUND" )
      frame.tex:SetTexture( 1, 1, 1, .05 )
      frame.tex:SetAllPoints()
      frame.tex:Hide()
    end

    frame.caption = frame:CreateFontString( "Status", "LOW", "GameFontWhite" )
    frame.caption:SetPoint( "LEFT", frame, "LEFT", 3, 1 )
    frame.caption:SetJustifyH( "LEFT" )
    frame.caption:SetText( caption )
  end

  if widget == "header" then
    frame:SetBackdrop( nil )
    if not this.first_header then
      this.first_header = true
      frame:SetHeight( 20 )
    else
      frame:SetHeight( 40 )
      this.object_count = this.object_count + 1
    end
    frame.caption:SetJustifyH( "LEFT" )
    frame.caption:SetJustifyV( "BOTTOM" )
    frame.caption:SetTextColor( 0.1254, 0.6235, 0.9764, 1 )
    frame.caption:SetAllPoints( frame )
  end

  if setting then
    if not widget or widget == "number" or widget == "text" then
      frame.input = m.api.CreateFrame( "EditBox", nil, frame )
      M.create_backdrop( frame.input, nil, true )
      frame.input:SetTextInsets( 5, 5, 5, 5 )
      frame.input:SetTextColor( 0.1254, 0.6235, 0.9764, 1 )
      frame.input:SetJustifyH( "RIGHT" )
      frame.input:SetWidth( options.width and options.width or 50 )
      frame.input:SetHeight( 18 )
      frame.input:SetPoint( "RIGHT", -3, 0 )
      frame.input:SetFontObject( "GameFontNormal" )
      frame.input:SetAutoFocus( false )
      frame.input:SetText( config_db[ setting ] )
      frame.input:SetScript( "OnEscapePressed", function()
        this:ClearFocus()
      end )

      frame.input.disable = function()
        frame.input.disabled = true
        frame.input:EnableKeyboard( false )
        frame.input:EnableMouse( false )
        frame.input:SetTextColor( .5, .5, .5, 1 )
        frame.caption:SetTextColor( .5, .5, .5, 1 )
      end
      frame.input.enable = function()
        frame.input.disabled = false
        frame.input:EnableKeyboard( true )
        frame.input:EnableMouse( true )
        frame.input:SetTextColor( 0.1254, 0.6235, 0.9764, 1 )
        frame.caption:SetTextColor( 1, 1, 1, 1 )
      end
    end

    if widget == "text" then
      frame.input:SetScript( "OnEditFocusGained", function()
        frame.input:HighlightText()
      end )
      frame.input:SetScript( "OnTextChanged", function()
        local v = this:GetText()
        if ufunc then
          ufunc( v )
        else
          config_db[ setting ] = v
        end
      end )
    end

    if not widget or widget == "number" then
      frame.input:SetScript( "OnTextChanged", function()
        local v = tonumber( this:GetText() )
        local valid = v and ((not options.min or v >= options.min) and (not options.max or v <= options.max))

        if valid then
          if config_db[ setting ] ~= v then
            config_db[ setting ] = v
            if ufunc then ufunc( v ) end
          end
          this:SetTextColor( 0.1254, 0.6235, 0.9764, 1 )
        else
          this:SetTextColor( 1, .3, .3, 1 )
        end
      end )
    end

    if widget == "checkbox" then
      frame.input = m.api.CreateFrame( "CheckButton", nil, frame, "UICheckButtonTemplate" )
      frame.input:SetNormalTexture( "" )
      frame.input:SetPushedTexture( "" )
      frame.input:SetHighlightTexture( "" )
      M.create_backdrop( frame.input, nil, true )
      frame.input:SetWidth( 14 )
      frame.input:SetHeight( 14 )
      frame.input:SetPoint( "RIGHT", -3, 1 )

      frame.input.disable = function()
        frame.input.disabled = true
        frame.input:EnableMouse( false )
        local tex = frame.input:GetCheckedTexture()
        tex:SetVertexColor( .5, .5, .5, 1 )
        frame.caption:SetTextColor( .5, .5, .5, 1 )
      end
      frame.input.enable = function()
        frame.input.disabled = false
        frame.input:EnableMouse( true )
        local tex = frame.input:GetCheckedTexture()
        tex:SetVertexColor( 1, 1, 1, 1 )
        frame.caption:SetTextColor( 1, 1, 1, 1 )
      end

      frame.input:SetScript( "OnClick", function()
        if this:GetChecked() then
          config_db[ setting ] = true
        else
          config_db[ setting ] = false
        end

        if ufunc then ufunc( this:GetChecked() ) end
      end )

      if config_db[ setting ] == true then frame.input:SetChecked() end
    end

    if widget == "dropdown" then
      frame.input = M.dropdown_input( frame, options, config_db[ setting ], function( value, text )
        frame.input.label:SetText( text )
        config_db[ setting ] = value
        if ufunc then ufunc( value ) end
      end )
      frame.input:SetPoint( "RIGHT", -3, 0 )
    end
  end

  if widget == "button" then
    frame.button = m.api.CreateFrame( "Button", nil, frame, "UIPanelButtonTemplate" )
    M.create_backdrop( frame.button, nil, true )
    frame.button:SetNormalTexture( "" )
    frame.button:SetHighlightTexture( "" )
    frame.button:SetPushedTexture( "" )
    frame.button:SetDisabledTexture( "" )
    frame.button:SetText( caption )
    local w = frame.button:GetTextWidth() + 10
    frame.button:SetWidth( w )
    frame.button:SetHeight( 20 )
    frame.button:SetPoint( "TOPLEFT", (this:GetParent():GetWidth() / 2 - w / 2 - 10), -5 )
    frame.button:SetTextColor( 1, 1, 1, 1 )
    frame.button:SetScript( "OnClick", ufunc )
    frame.button:SetScript( "OnEnter", function()
      this:SetBackdropBorderColor( 0.1254, 0.6235, 0.9764, 1 )
      if this:GetParent():GetParent():GetParent():GetParent():GetParent():GetParent().show_help then
        if this:GetParent().tooltip then
          m.api.GameTooltip:SetOwner( this, "ANCHOR_TOPLEFT" )
          m.api.GameTooltip:SetText( this:GetParent().tooltip )
          m.api.GameTooltip:Show()
        end
      end
    end )
    frame.button:SetScript( "OnLeave", function()
      this:SetBackdropBorderColor( .2, .2, .2, 1 )
      if m.api.GameTooltip:IsShown() then
        m.api.GameTooltip:Hide()
      end
    end )
  end

  return frame
end

function M.dropdown_input( parent, items_data, selected, on_select )
  local frame = m.api.CreateFrame( "Button", nil, parent )
  M.create_backdrop( frame, nil, true )
  frame:SetWidth( 80 )
  frame:SetHeight( 18 )

  frame.label = frame:CreateFontString( nil, "ARTWORK", "GameFontNormal" )
  frame.label:SetTextColor( 0.1254, 0.6235, 0.9764, 1 )
  frame.label:SetJustifyH( "RIGHT" )
  frame.label:SetText( selected )
  frame.label:SetPoint( "RIGHT", -18, 0 )

  frame.button = m.api.CreateFrame( "Frame", nil, frame )
  M.create_backdrop( frame.button, nil, true )
  frame.button:SetWidth( 12 )
  frame.button:SetHeight( 12 )
  frame.button:SetPoint( "RIGHT", -1, 0 )

  local icon = frame.button:CreateTexture()
  icon:SetTexture( "Interface\\AddOns\\RollFor\\assets\\arrow-down.tga", "ARTWORK" )
  icon:SetWidth( 6 )
  icon:SetHeight( 6 )
  icon:SetPoint( "CENTER", 0, 0 )

  frame.dropdown = m.GuiElements.dropdown( frame, "LeftButton", items_data, on_select )
  frame.dropdown:SetPoint( "TOPLEFT", frame, "BOTTOMLEFT", 0, -2 )
  frame.dropdown:SetPoint( "TOPRIGHT", frame, "BOTTOMRIGHT", 0, -2 )

  frame:SetScript( "OnEnter", function()
    frame.button:SetBackdropBorderColor( 0.1254, 0.6235, 0.9764, 1 )
  end )
  frame:SetScript( "OnLeave", function()
    frame.button:SetBackdropBorderColor( .2, .2, .2, 1 )
  end )

  return frame
end

m.OptionsGuiElements = M
return M
