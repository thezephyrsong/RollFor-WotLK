RollFor = RollFor or {}
local m = RollFor

local getn = m.getn

if m.WinnersPopupGui then return end

---@class HeaderFrame: Frame
---@field dropdown Frame

---@class HeadersFrame: Frame
---@field player_name_header HeaderFrame
---@field item_id_header HeaderFrame
---@field winning_roll_header HeaderFrame
---@field roll_type_header HeaderFrame

---@class ScrollFrame: Frame
---@field name string?

---@class WinnersPopupGui
---@field headers fun( parent: Frame, on_click: function ): HeadersFrame
---@field winner fun( parent: Frame): Frame
---@field create_scroll_frame fun( parent: Frame, name: string ): ScrollFrame
local M = {}
local _G = getfenv( 0 )

function M.headers( parent, on_click )
  ---@class HeadersFrame
  local frame = m.api.CreateFrame( "Frame", nil, parent )
  frame:SetWidth( 250 )
  frame:SetHeight( 14 )
  frame:SetFrameStrata( "DIALOG" )
  frame:SetFrameLevel( parent:GetFrameLevel() + 1 )
  frame:EnableMouse( true )

  ---@diagnostic disable-next-line: undefined-global
  local font_file = pfUI and pfUI.version and pfUI.font_default or "FONTS\\ARIALN.TTF"
  local font_size = 11

  local headers = {
    { text = "Player", name = "player_name",  width = 74 },
    { text = "Item",   name = "item_id",      width = 150 },
    { text = "Roll",   name = "winning_roll", width = 25 },
    { text = "Type",   name = "roll_type",    width = 25 }
  }

  for _, v in pairs( headers ) do
    local header = m.GuiElements.create_text_in_container( "Button", frame, v.width, nil, v.text )
    header.inner:SetFont( font_file, font_size )
    header.sort = v.name
    header:SetHeight( 14 )
    header.inner:SetPoint( v.name == "winning_roll" and "RIGHT" or "LEFT", v.name == "winning_roll" and -5 or 2, 0 )
    header:SetBackdrop( {
      bgFile = "Interface/Buttons/WHITE8x8",
      tile = true,
      tileSize = 22,
    } )
    header:SetBackdropColor( 0.125, 0.624, 0.976, 0.4 )
    header:SetScript( "OnClick", function()
      on_click( header )
    end )
    frame[ v.name .. "_header" ] = header
  end

  frame.player_name_header:SetPoint( "LEFT", frame, "LEFT", 0, 0 )
  frame.roll_type_header:SetPoint( "RIGHT", frame, "RIGHT", 0, 0 )
  frame.winning_roll_header:SetPoint( "RIGHT", frame.roll_type_header, "LEFT", -1, 0 )
  frame.item_id_header:SetPoint( "LEFT", frame.player_name_header, "RIGHT", 1, 0 )
  frame.item_id_header:SetPoint( "RIGHT", frame.winning_roll_header, "LEFT", -1, 0 )

  return frame
end

function M.roll_type_dropdown()
  if not M.roll_type_dropdown_frame then
    local items_data = {}
    for roll_type in pairs( m.Types.RollType ) do
      table.insert( items_data, { text = m.roll_type_color( roll_type, m.roll_type_abbrev( roll_type ) ), value = roll_type, type = "checkbox" })
    end
    M.roll_type_dropdown_frame = m.GuiElements.dropdown( nil, nil, items_data )
  end

  local row = this:GetParent()
  M.roll_type_dropdown_frame:SetPoint( "TOPLEFT", row, "BOTTOMLEFT", row:GetWidth() - 27, 0 )
  M.roll_type_dropdown_frame:Show()

  local on_update_item = this.inner.on_update_item
  for _, cb in ipairs( M.roll_type_dropdown_frame.items ) do
    cb.checkbox:SetChecked( cb.value == this.inner.value )

    cb.on_select = function( setting, value )
      if not value then setting = "NA" end
      on_update_item( setting )
      M.roll_type_dropdown_frame:Hide()
    end
  end
end

function M.winner( parent )
  M.winner_rows = M.winner_rows and M.winner_rows + 1 or 1
  local frame = m.api.CreateFrame( "Button", "RollForWinnerRow" .. M.winner_rows, parent )
  frame:SetHeight( 14 )
  frame:SetPoint( "LEFT", parent, "LEFT", 0, 0 )
  frame:SetPoint( "RIGHT", parent, "RIGHT", 0, 0 )
  frame:SetFrameStrata( "DIALOG" )
  frame:SetFrameLevel( parent:GetFrameLevel() + 1 )
  frame:SetBackdrop( {
    bgFile = "Interface/Buttons/WHITE8x8",
    tile = true,
    tileSize = 22,
  } )

  local function blue_hover( a )
    frame:SetBackdropColor( 0.125, 0.624, 0.976, a )
  end

  blue_hover( 0 )
  frame:SetScript( "OnEnter", function() blue_hover( .2 ) end )
  frame:SetScript( "OnLeave", function() blue_hover( 0 ) end )

  ---@diagnostic disable-next-line: undefined-global
  local font_file = pfUI and pfUI.version and pfUI.font_default or "FONTS\\ARIALN.TTF"
  local font_size = 11

  local player_name = m.GuiElements.create_text_in_container( "Frame", frame, 74, "LEFT", "dummy" )
  player_name.inner:SetFont( font_file, font_size )
  player_name.inner:SetJustifyH( "LEFT" )
  player_name:SetPoint( "LEFT", frame, "LEFT", 2, 0 )
  player_name:SetHeight( 14 )
  frame.player_name = player_name.inner

  local roll_type = m.GuiElements.create_text_in_container( "Frame", frame, 25, nil, "dummy" )
  roll_type.inner:SetFont( font_file, font_size )
  roll_type.inner:SetJustifyH( "LEFT" )
  roll_type.inner:SetPoint( "LEFT", 5, 0 )
  roll_type:SetPoint( "RIGHT", 0, 0 )
  roll_type:SetHeight( 14 )
  roll_type:EnableMouse()
  roll_type:SetScript( "onMouseUp", function()
    if arg1 == "RightButton" then
      if M.roll_type_dropdown_frame and M.roll_type_dropdown_frame:IsVisible() then
        M.roll_type_dropdown_frame:Hide()
      else
        M.roll_type_dropdown()
      end
    end
  end )
  frame.roll_type = roll_type.inner

  local winning_roll = m.GuiElements.create_text_in_container( "Frame", frame, 25, nil, "dummy" )
  winning_roll.inner:SetFont( font_file, font_size )
  winning_roll.inner:SetJustifyH( "RIGHT" )
  winning_roll.inner:SetPoint( "RIGHT", -5, 0 )
  winning_roll:SetPoint( "RIGHT", roll_type, "LEFT", -1, 0 )
  winning_roll:SetHeight( 14 )
  frame.winning_roll = winning_roll.inner

  local item_link = m.GuiElements.create_text_in_container( "Button", frame, 1, "LEFT", "dummy" )
  item_link.inner:SetFont( font_file, font_size )
  item_link.inner:SetJustifyH( "LEFT" )
  item_link.inner:SetPoint( "LEFT", 0, 0 )
  item_link.inner:SetPoint( "RIGHT", 0, 0 )
  item_link.inner:SetHeight( 14 )
  item_link:SetPoint( "LEFT", player_name, "RIGHT", 1, 0 )
  item_link:SetPoint( "RIGHT", winning_roll, "LEFT", -1, 0 )
  item_link:SetHeight( 14 )
  frame.item_link = item_link

  frame.SetItem = function( _, item_link_text )
    item_link.inner:SetText( item_link_text )

    local tooltip_link = m.ItemUtils.get_tooltip_link( item_link_text )

    item_link:SetScript( "OnEnter", function()
      blue_hover( 0.2 )
    end )

    item_link:SetScript( "OnLeave", function()
      blue_hover( 0 )
    end )

    item_link:SetScript( "OnClick", function()
      if not tooltip_link then return end

      if m.is_ctrl_key_down() then
        m.api.DressUpItemLink( item_link_text )
      elseif m.is_shift_key_down() then
        m.link_item_in_chat( item_link_text )
      else
        m.api.SetItemRef( tooltip_link, tooltip_link, "LeftButton" )
      end
    end )
  end

  return frame
end

function M.create_scroll_frame( parent, name )
  local f = m.api.CreateFrame( "ScrollFrame", name, parent, "FauxScrollFrameTemplate" )

  if m.classic then
    local scroll_bar = _G[ name .. "ScrollBar" ]
    scroll_bar:SetPoint( "TOPLEFT", name, "TOPRIGHT", 1, -16 )
  else
    local scroll_bar = _G[ name .. "ScrollBar" ]
    scroll_bar:SetWidth( 12 )
    scroll_bar:SetBackdrop( {
      bgFile = "Interface\\Buttons\\WHITE8X8",
      edgeFile = "Interface\\Buttons\\WHITE8X8",
      tile = false,
      tileSize = 0,
      edgeSize = 0.5,
      insets = { left = 0, right = 0, top = 0, bottom = 0 }
    } )
    scroll_bar:SetBackdropColor( 0, 0, 0, 0.8 )
    scroll_bar:SetBackdropBorderColor( .2, .2, .2, 1 )
    scroll_bar:SetPoint( "TOPLEFT", name, "TOPRIGHT", 3, -13.5 )
    scroll_bar:SetPoint( "BOTTOMLEFT", name, "BOTTOMRIGHT", 6, 14 )

    local thumb = _G[ name .. "ScrollBarThumbTexture" ]
    thumb:SetTexture( "Interface\\Buttons\\WHITE8X8" )
    thumb:SetVertexColor( .8, .8, .8, .8 )
    thumb:SetWidth( 12 )
    thumb:SetHeight( 10 )

    for i, button in { _G[ name .. "ScrollBarScrollUpButton" ], _G[ name .. "ScrollBarScrollDownButton" ] } do
      for _, tex in { "Normal", "Highlight", "Pushed", "Disabled" } do
        local texture = button[ "Get" .. tex .. "Texture" ]( button )
        texture:SetTexture( "Interface\\AddOns\\RollFor\\assets\\arrow-" .. (i == 1 and "up" or "down") .. ".tga" )
        texture:SetTexCoord( 0, 1, 0, 1 )
        texture:SetVertexColor( .8, .8, .8, .8 )
        texture:SetAlpha( .8 )
        texture:SetPoint( "TOPLEFT", 2, -1 )
        texture:SetPoint( "BOTTOMRIGHT", -2, 1 )
      end

      button:SetWidth( 12 )
      button:SetHeight( 12 )
      button:SetBackdrop( {
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 0.5,
        insets = { left = 0, right = 0, top = 0, bottom = 0 }
      } )
      button:SetBackdropColor( 0, 0, 0, 1 )
      button:SetBackdropBorderColor( .2, .2, .2, 1 )
      button:GetDisabledTexture():SetAlpha( 0.4 )

      if i == 1 then
        button:SetPoint( "BOTTOM", scroll_bar, "TOP", 0, 2 )
      else
        button:SetPoint( "TOP", scroll_bar, "BOTTOM", 0, -2 )
      end

      button:SetScript( "OnEnter", function()
        this:SetBackdropBorderColor( .125, .624, .976, .5 )
      end )
      button:SetScript( "OnLeave", function()
        this:SetBackdropBorderColor( .2, .2, .2, 1 )
      end )
    end
  end

  return f
end

m.WinnersPopupGui = M
return M
