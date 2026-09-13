RollFor = RollFor or {}
local m = RollFor

if m.DragonUiLootFrameSkin then return end

local M = {}

local gui = m.GuiElements

local item_height = 28
local footer_height = 0
local header_height = 40

local dragonui_rock_texture = "Interface\\AddOns\\DragonUI\\Textures\\UI\\ui-background-rock"
local dragonui_layout_name = "NoPortraitFrameTemplate"

-- Manual fallback for the two side edges - NineSliceUtils' own LeftEdge/RightEdge
-- setup wasn't rendering them even with valid corner anchors and the right draw
-- layer. Traced it to the actual pixels: uiframemetalvertical2x.blp is a 512x32
-- sheet holding two thin vertical lines (~10px each) surrounded by mostly
-- transparent padding - the earlier attempt cropped the full ~150px-wide region
-- DragonUI's atlas declares for each edge (mostly that empty padding) and
-- stretched it across the frame's height, diluting the thin line to invisible.
-- The line itself is a clean, solid-color 32px-tall tile meant to be repeated
-- top to bottom, not stretched - cropped tightly around just the line here and
-- tiled by stacking copies (rather than relying on SetVertTile's texcoord-repeat
-- behavior, which is harder to verify without live testing).
local dragonui_vertical_edge_texture = "Interface\\AddOns\\DragonUI\\Textures\\UI\\uiframemetalvertical2x"
local dragonui_left_edge_texcoords = { 22 / 512, 36 / 512, 0, 1 }
local dragonui_right_edge_texcoords = { 285 / 512, 299 / 512, 0, 1 }
local edge_tile_height = 32
local edge_tile_width = 6
local max_edge_tiles = 14 -- covers up to ~450px tall, generous headroom over the 92-300px this window realistically uses

-- DragonUI's own native loot window never shrinks below 92px, even for a
-- single item, and applies its full NoPortraitFrameTemplate (75px corners) to
-- that one panel - that floor height, not anything about the corner art
-- itself, is what keeps its corners from overlapping.
local body_min_height = 92

-- RollFor's header and body are two separate frames (header is the
-- draggable handle, body is the resizable item list) - DragonUI's own loot
-- window is one single panel. Splitting the same full nineslice layout across
-- both, top pieces on header and everything else on body, is how we get one
-- continuous-looking border out of two physically separate frames instead of
-- two competing rounded boxes stacked on each other.
---@param base_layout_name string
---@param keys string[]
local function partial_dragonui_layout( base_layout_name, keys )
  local base = _G.NineSliceUtils and _G.NineSliceUtils.GetLayout and _G.NineSliceUtils.GetLayout( base_layout_name )
  if not base then return nil end

  local partial = {}
  for _, key in ipairs( keys ) do
    if base[ key ] then partial[ key ] = base[ key ] end
  end

  return partial
end

local header_piece_keys = { "TopLeftCorner", "TopRightCorner", "TopEdge" }

-- Row rendering, sizing and interaction are identical to the Modern skin -
-- only the outer frame (header/body) styling differs, using DragonUI's
-- NineSliceUtils + retail-style background when DragonUI is installed.
-- Falls back to a plain look on its own if DragonUI isn't found.
---@param frame_builder FrameBuilderFactory
function M.new( frame_builder )
  ---@param parent Frame
  local function dropped_item( parent )
    local container = m.create_loot_button( m.api, parent )

    local w = item_height - 4
    local h = item_height - 4
    local spacing = 6
    local bind_spacing = 3
    local mouse_down = false
    local icon_zoom = 2

    local item

    container:SetHeight( h )
    container.name = gui.create_text_in_container( "Frame", container, 20, "LEFT", nil, "text", "GameFontNormal" )
    container.name.text:SetJustifyH( "LEFT" )
    container.name.text:SetTextColor( 1, 1, 1 )
    container.index = gui.create_text_in_container( "Frame", container, 20, "CENTER", nil, "text" )
    container.index:SetPoint( "LEFT", 1, 0 )
    container.index:SetWidth( 16 )
    container.index:SetHeight( h )
    container.icon = gui.create_icon_in_container( "Button", container, w, h, icon_zoom )
    container.icon:SetPoint( "LEFT", container.index, "RIGHT", 2, 0 )
    container.icon:EnableMouse( false )
    container.quantity = gui.create_text_in_container( "Frame", container.icon, 20, "CENTER", nil, "text", "NumberFontNormalSmall" )
    container.quantity:SetPoint( "BOTTOMRIGHT", 1, -2 )
    container.quantity:SetHeight( 16 )
    container.bind = gui.create_text_in_container( "Frame", container, 15, "LEFT", nil, "text" )
    container.bind:SetPoint( "LEFT", container.icon, "RIGHT", 5, 0 )
    container.comment = gui.create_text_in_container( "Button", container, 20, "CENTER", nil, "text" )
    container.comment:SetPoint( "RIGHT", -4, 0 )
    container.comment:SetHeight( 16 )

    local function resize()
      container.icon:Show()

      local index_width = container.index:GetWidth() + 1
      local icon_width = container.icon:GetWidth() + spacing
      local bind_width = item.bind and (container.bind:GetWidth() + bind_spacing) or 0
      local text_width = container.name.text:GetStringWidth() + spacing + 1
      local comment_width = container.comment:IsVisible() and container.comment:GetWidth() + spacing or 0

      local total_width = index_width + icon_width + bind_width + text_width + comment_width

      container:SetWidth( total_width )
      container:SetPoint( "LEFT", 0, 0 )
      container:SetPoint( "RIGHT", 0, 0 )
    end

    local function get_color( multiplier )
      local mult = multiplier or 1
      local color = m.api.ITEM_QUALITY_COLORS[ item.quality or 0 ]
      return color.r * mult, color.g * mult, color.b * mult
    end

    local function hovered_color()
      if not item then return end
      if item.is_selected then return end
      local r, g, b = get_color()
      container:SetBackdropColor( r, g, b, 0.3 )
    end

    local function clicked_color()
      local r, g, b = get_color()
      container:SetBackdropColor( r, g, b, 0.4 )
    end

    local function selected_color()
      if not item then return end
      local r, g, b = get_color()
      container:SetBackdropColor( r, g, b, 0.3 )
    end

    local function not_hovered_color()
      if not item or item.is_selected then return end
      -- 0 alpha here (not a small black tint like Modern uses) - a black
      -- overlay at rest stacks on top of body's own rock-texture tint and
      -- darkens every row relative to the gaps between them.
      container:SetBackdropColor( 0, 0, 0, 0 )
    end

    local function update()
      if not item then return end

      if not item.is_enabled then
        container:SetAlpha( 0.6 )
        return
      end

      if item.is_selected then
        selected_color()
      else
        not_hovered_color()
      end

      container:SetAlpha( 1 )
    end

    ---@param v LootFrameItem
    container.SetItem = function( _, v )
      item = v
      container.index.text:SetText( v.index )
      container.icon.texture:SetTexture( v.texture )
      container.name.text:SetText( m.colorize_item_by_quality( v.name, v.quality ) )

      if v.bind then
        container.bind.text:SetText( v.bind )
        container.bind:SetWidth( container.bind.text:GetStringWidth() )
        container.bind:Show()
        container.name:SetPoint( "LEFT", container.bind, "RIGHT", bind_spacing, 0 )
      else
        container.bind:Hide()
        container.name:SetPoint( "LEFT", container.icon, "RIGHT", spacing, 0 )
      end

      if v.comment then
        container.comment.text:SetText( v.comment )
        container.comment:Show()
        container.name:SetPoint( "RIGHT", container.comment, "LEFT", 0, 0 )
      else
        container.comment:Hide()
        container.name:SetPoint( "RIGHT", container, "RIGHT", 0, 0 )
      end

      if v.quantity and v.quantity > 1 then
        container.quantity:Show()
        container.quantity.text:SetText( v.quantity )
        container.quantity:SetWidth( container.quantity.text:GetStringWidth() )
      else
        container.quantity:Hide()
      end

      local function modifier_fn()
        if m.is_ctrl_key_down() then
          m.api.DressUpItemLink( v.link )
          return
        end

        if m.is_shift_key_down() then
          m.link_item_in_chat( v.link )
          return
        end
      end

      container:SetScript( "OnClick", v.is_enabled and not v.is_selected and v.click_fn or modifier_fn )
      container.comment:SetScript( "OnClick", v.is_enabled and not v.is_selected and v.click_fn or modifier_fn )

      if m.vanilla then
        -- Fucking hell this took forever to figure out. Fuck you Blizzard.
        -- For looting to work in vanilla, the frame must be of a "LootButton" type and
        -- then it comes with the SetSlot function that we need to use to set the slot.
        -- This will probably be a pain in the ass when porting.
        container:SetSlot( v.slot or 0 )
      end

      update()
      resize()
    end

    local function on_enter( self )
      if m.vanilla then self = this end

      if not item then return end
      if item.tooltip_link then
        m.api.GameTooltip:SetOwner( self, "ANCHOR_RIGHT" )
        m.api.GameTooltip:SetHyperlink( item.tooltip_link )
        m.api.GameTooltip:Show()
      end

      if not item.is_enabled then return end
      hovered_color()
    end

    container:SetBackdrop( {
      bgFile = "Interface/Buttons/WHITE8x8",
      tile = false,
      tileSize = 0,
    } )

    not_hovered_color()

    local function on_leave()
      m.api.GameTooltip:Hide()
      mouse_down = false
      not_hovered_color()
    end

    container.comment:SetScript( "OnEnter", function( self )
      if not item then return end
      if item.comment_tooltip then
        if m.vanilla then self = this end

        self.tooltip_scale = m.api.GameTooltip:GetScale()
        m.api.GameTooltip:SetOwner( self, "ANCHOR_RIGHT" )

        local result = ""

        for _, line in ipairs( item.comment_tooltip ) do
          if result ~= "" then result = result .. "\n" end
          result = result .. line
        end

        m.api.GameTooltip:AddLine( result, 1, 1, 1 )
        m.api.GameTooltip:SetScale( 0.9 )
        m.api.GameTooltip:Show()
      end

      if not item.is_enabled then return end
      hovered_color()
    end )

    container.comment:SetScript( "OnLeave", function( self )
      if m.vanilla then self = this end

      m.api.GameTooltip:Hide()
      m.api.GameTooltip:SetScale( self.tooltip_scale or 1 )
      mouse_down = false

      not_hovered_color()
    end )

    container:SetScript( "OnEnter", on_enter )
    container:SetScript( "OnLeave", on_leave )

    local function on_mouse_down()
      if not item then return end
      if not item.is_enabled or item.is_selected then return end

      mouse_down = true
      clicked_color()
    end

    local function on_mouse_up()
      if not item then return end
      if not item.is_enabled or item.is_selected then return end

      if not mouse_down then return end
      hovered_color()
    end

    container:SetScript( "OnMouseUp", on_mouse_up )
    container:SetScript( "OnMouseDown", on_mouse_down )

    container:SetScript( "OnShow", function()
      mouse_down = false
    end )

    return container
  end

  ---@param on_drag_stop function
  ---@param on_show function
  ---@param on_hide function
  local function header( on_drag_stop, on_show, on_hide )
    local dragonui_found = _G.NineSliceUtils and _G.NineSliceUtils.ApplyLayout and true or false

    local frame = frame_builder.new()
        :name( "RollForLootFrameHeader" )
        :parent( m.api.UIParent )
        :width( 380 )
        :height( header_height )
        :sound()
        :gui_elements( gui )
        :frame_style( "None" )
        :movable()
        :gui_elements( m.GuiElements )
        :on_show( on_show )
        :on_hide( on_hide )
        :on_drag_stop( on_drag_stop )
        :hidden()
        :build()

    frame:SetBackdrop( {
      bgFile = dragonui_found and dragonui_rock_texture or "Interface/Buttons/WHITE8x8",
      tile = false,
      tileSize = 0,
    } )
    frame:SetBackdropColor( 1, 1, 1, 0.8 )

    if dragonui_found then
      local top_layout = partial_dragonui_layout( dragonui_layout_name, header_piece_keys )
      if top_layout and next( top_layout ) then
        _G.NineSliceUtils.ApplyLayout( frame, top_layout )
      end

      -- The driver (LootFrame.lua) adds the title via frame.add_line( "text", ... )
      -- after this function returns. That text is created on WoW's "ARTWORK" draw
      -- layer (GuiElements.text), which sits below the nineslice pieces' layer -
      -- without this it renders correctly but invisibly, hidden behind the corner
      -- art. Wrap add_line to bump just the text line above it once it's created.
      local native_add_line = frame.add_line
      frame.add_line = function( line_type, modify_fn, padding )
        local line = native_add_line( line_type, modify_fn, padding )
        if line_type == "text" and line and line.frame and line.frame.SetDrawLayer then
          line.frame:SetDrawLayer( "OVERLAY", 7 )
          -- The driver centers this text in the header frame (LootFrame.lua's
          -- update_boss_name_frame), which sits a bit low relative to where the
          -- corner art's rounded shape actually reads as "the cap" - nudge it up
          -- rather than touching the shared driver's positioning. Using
          -- GetPoint/SetPoint instead of AdjustPointsOffset since that method
          -- isn't guaranteed to exist on this client.
          local point, relative_to, relative_point, x, y = line.frame:GetPoint( 1 )
          if point then
            line.frame:ClearAllPoints()
            line.frame:SetPoint( point, relative_to, relative_point, x or 0, (y or 0) + 8 )
          end
        end
        return line
      end
    end

    return frame
  end

  ---@param parent Frame
  local function body( parent )
    local dragonui_found = _G.NineSliceUtils and _G.NineSliceUtils.ApplyLayout and true or false

    local frame = frame_builder.new()
        :name( "RollForLootFrame" )
        :parent( parent )
        :width( 280 )
        :height( 100 )
        :gui_elements( { dropped_item = dropped_item } )
        :frame_style( "None" )
        :movable()
        :build()

    frame:SetBackdrop( {
      bgFile = dragonui_found and dragonui_rock_texture or "Interface/Buttons/WHITE8x8",
      tile = false,
      tileSize = 0,
    } )
    -- Non-black tint: SetBackdropColor multiplies the bgFile's RGB, so (0,0,0)
    -- would erase the rock texture's detail entirely, not just dim it.
    frame:SetBackdropColor( 1, 1, 1, 0.8 )

    -- LootFrame.lua's driver calls body_frame:SetHeight( item_count * item_height + 1 )
    -- directly, with no minimum - for 1-3 items that lands well under the 92px floor
    -- DragonUI's own corners need. Clamp it here rather than touching the shared driver
    -- (which Classic/Modern also go through and shouldn't have their tight-fit sizing
    -- changed). Also drives how many of the tiled side-edge segments (below) are shown,
    -- since the driver can grow this frame after creation as items are added.
    local left_edge_tiles = {}
    local right_edge_tiles = {}

    local native_set_height = frame.SetHeight
    frame.SetHeight = function( self, height )
      local clamped = math.max( height, body_min_height )
      native_set_height( self, clamped )

      -- Round DOWN to full tiles, then size+crop one extra partial tile to fill
      -- whatever's left over exactly - rounding up instead (like this used to)
      -- let the last tile's full 32px extend past the frame's actual bottom
      -- edge, which is the dangling overshoot below the corners.
      local full_tiles = math.min( max_edge_tiles, math.floor( clamped / edge_tile_height ) )
      local remainder = clamped - (full_tiles * edge_tile_height)

      for i = 1, max_edge_tiles do
        local left_tile = left_edge_tiles[ i ]
        local right_tile = right_edge_tiles[ i ]

        if i <= full_tiles then
          if left_tile then
            left_tile:SetHeight( edge_tile_height )
            left_tile:SetTexCoord( unpack( dragonui_left_edge_texcoords ) )
            left_tile:Show()
          end
          if right_tile then
            right_tile:SetHeight( edge_tile_height )
            right_tile:SetTexCoord( unpack( dragonui_right_edge_texcoords ) )
            right_tile:Show()
          end
        elseif i == full_tiles + 1 and remainder > 1 then
          local l, r, t, b = unpack( dragonui_left_edge_texcoords )
          local cropped_b = t + (b - t) * (remainder / edge_tile_height)
          if left_tile then
            left_tile:SetHeight( remainder )
            left_tile:SetTexCoord( l, r, t, cropped_b )
            left_tile:Show()
          end

          local rl, rr, rt, rb = unpack( dragonui_right_edge_texcoords )
          local cropped_rb = rt + (rb - rt) * (remainder / edge_tile_height)
          if right_tile then
            right_tile:SetHeight( remainder )
            right_tile:SetTexCoord( rl, rr, rt, cropped_rb )
            right_tile:Show()
          end
        else
          if left_tile then left_tile:Hide() end
          if right_tile then right_tile:Hide() end
        end
      end
    end

    if dragonui_found then
      -- LeftEdge/RightEdge anchor between the TOP and BOTTOM corners on this
      -- same frame (see nineSliceSetup's relativePieces) - a partial layout
      -- missing the top corners breaks that anchor entirely, which was the
      -- first bug here. Apply the full layout so Center/BottomLeftCorner/etc
      -- position correctly, hide the top pieces since header already shows
      -- those - but NineSliceUtils' own LeftEdge/RightEdge still weren't
      -- rendering even with valid anchors, so those two get hidden too and
      -- replaced with hand-drawn tiled textures below instead of chasing why.
      local layout = _G.NineSliceUtils.GetLayout( dragonui_layout_name )
      if layout then
        _G.NineSliceUtils.ApplyLayout( frame, layout )
        for _, key in ipairs( header_piece_keys ) do
          if frame[ key ] then frame[ key ]:Hide() end
        end
        if frame.LeftEdge then frame.LeftEdge:Hide() end
        if frame.RightEdge then frame.RightEdge:Hide() end
      end

      for i = 1, max_edge_tiles do
        local y = -(i - 1) * edge_tile_height

        local left_tile = frame:CreateTexture( nil, "OVERLAY" )
        left_tile:SetTexture( dragonui_vertical_edge_texture )
        left_tile:SetTexCoord( unpack( dragonui_left_edge_texcoords ) )
        left_tile:SetWidth( edge_tile_width )
        left_tile:SetHeight( edge_tile_height )
        left_tile:SetPoint( "TOPLEFT", frame, "TOPLEFT", -2, y )
        left_tile:Hide()
        left_edge_tiles[ i ] = left_tile

        local right_tile = frame:CreateTexture( nil, "OVERLAY" )
        right_tile:SetTexture( dragonui_vertical_edge_texture )
        right_tile:SetTexCoord( unpack( dragonui_right_edge_texcoords ) )
        right_tile:SetWidth( edge_tile_width )
        right_tile:SetHeight( edge_tile_height )
        right_tile:SetPoint( "TOPRIGHT", frame, "TOPRIGHT", 2, y )
        right_tile:Hide()
        right_edge_tiles[ i ] = right_tile
      end

      -- frame:SetHeight was called during :build() before these tiles existed, so the
      -- initial show/hide pass never ran on them - trigger it once now.
      frame:SetHeight( frame:GetHeight() )
    end

    frame:ClearAllPoints()
    frame:SetPoint( "TOP", parent, "BOTTOM", 0, 0 )

    return frame
  end

  local function footer()
  end

  local function get_item_height()
    return item_height
  end

  local function get_footer_height()
    return footer_height
  end

  ---@type LootFrameSkin
  return {
    header = header,
    body = body,
    dropped_item = dropped_item,
    footer = footer,
    get_item_height = get_item_height,
    get_footer_height = get_footer_height
  }
end

m.DragonUiLootFrameSkin = M
return M
