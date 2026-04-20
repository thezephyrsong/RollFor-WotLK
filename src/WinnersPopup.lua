RollFor = RollFor or {}
local m = RollFor

if m.WinnersPopup then return end

local c = m.colorize_player_by_class
local r = m.roll_type_color
local getn = m.getn
local filter = m.filter
local _G = getfenv( 0 )

---@class WinnersPopup
---@field show fun()
---@field hide fun()
---@field toggle fun()

local M = m.Module.new( "WinnersPopup" )

ROW_HEIGHT = 14

---@type GuiElements
m.GuiElements = m.GuiElements

---@type WinnersPopupGui
m.WinnersPopupGui = m.WinnersPopupGui

M.center_point = { point = "CENTER", relative_point = "CENTER", x = 0, y = 150 }

---@param popup_builder PopupBuilder
---@param frame_builder FrameBuilderFactory
---@param db table
---@param awarded_loot AwardedLoot
---@param roll_controller RollController
---@param confirm_popup ConfirmPopup
---@param config Config
function M.new( popup_builder, frame_builder, db, awarded_loot, roll_controller, confirm_popup, config )
  ---@type Popup
  local popup
  local refresh
  local headers
  local sort
  local sort_order = "asc"
  local content_frame
  local scroll_frame
  local offset = 0
  local row_count = 0
  local row_frames = {}
  local is_resizing
  local award_filters = config.award_filter()
  local winners_data

  db.point = db.point or M.center_point

  local function create_popup()
    M.debug.add( "create popup" )
    local function on_drag_stop( self )
      if not self then return end
      if m.is_frame_out_of_bounds( self ) then
        self:position( db.point or M.center_point )
        return
      end

      local anchor = self:get_anchor_point()
      db.point = { point = anchor.point, relative_point = anchor.relative_point, x = anchor.x, y = anchor.y }
    end

    local old_width
    local old_height
    local function on_resize( self )
      if not self or not is_resizing then return end
      local min_width, max_width, min_height, max_height = 225, 500, 173, 600

      local width = math.max( min_width, math.min( max_width, self:GetWidth() ) )
      if width ~= self:GetWidth() then
        self:SetWidth( width )
      end

      local height = math.max( min_height, math.min( max_height, self:GetHeight() ) )
      if height ~= self:GetHeight() then
        self:SetHeight( height )
      end

      if not old_width then old_width = self:GetWidth() end
      if not old_height then old_height = self:GetHeight() end
      if (math.abs( width - old_width ) > 7) or (width <= min_width) or (math.abs( height - old_height ) > (ROW_HEIGHT / 2)) then
        old_width = self:GetWidth()
        old_height = self:GetHeight()
        refresh( offset, false )
      end
    end

    local function get_point()
      if popup and m.is_frame_out_of_bounds( popup ) then
        return M.center_point
      elseif db.point then
        return db.point
      else
        return M.center_point
      end
    end

    local frame = popup_builder
        :name( "RollForWinnersFrame" )
        :width( db.width or 290 )
        :height( db.height or 200 )
        :point( get_point() )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :sound()
        :movable()
        :on_drag_stop( on_drag_stop )
        :resizable()
        :on_resize( on_resize )
        :build()

    if not m.classic then
      frame:backdrop_color( 0, 0, 0, .8 )
      frame:border_color( .2, .2, .2, 1 )
    end

    return frame
  end

  local function make_content()
    M.debug.add( "make content" )
    local function set_sort( self )
      if sort == self.sort then
        sort_order = (sort_order == "asc") and "desc" or "asc"
      else
        sort = self.sort
      end
      refresh()
    end

    m.GuiElements.titlebar( popup, "Winners" )

    local btn_reset = m.GuiElements.tiny_button( popup, "R", "Reset Sorting", "#20F99F" )
    btn_reset:SetPoint( "TOPRIGHT", popup, "TOPRIGHT", m.classic and -29 or -25, m.classic and -5 or -7 )
    btn_reset:SetScript( "OnClick", function()
      sort = nil
      refresh()
    end )

    local btn_clear = m.GuiElements.tiny_button( popup, "C", "Clear data", "#209FF9" )
    btn_clear:SetPoint( "TOPRIGHT", btn_reset, "TOPLEFT", m.classic and 0 or -5, 0 )
    btn_clear:SetScript( "OnClick", function()
      if confirm_popup.is_visible() then
        confirm_popup.hide()
        return
      end

      confirm_popup.show( { "This will clear the current winners data.", "Are you sure?" }, function( value )
        if value then
          awarded_loot.clear( true )
          refresh()
        end
      end )
    end )

    local btn_resize = m.GuiElements.resize_grip( popup,
      function()
        is_resizing = true
      end,
      function( frame )
        is_resizing = false
        db.width = frame:GetWidth()
        db.height = frame:GetHeight()
      end
    )
    btn_resize:SetPoint( "BOTTOMRIGHT", popup, "BOTTOMRIGHT", m.classic and -4 or 0, m.classic and 4 or 0 )

    local padding_top = m.classic and -20 or -10
    local padding_side = m.classic and 30 or 20

    headers = m.WinnersPopupGui.headers( popup, set_sort )
    headers:SetPoint( "TOPLEFT", popup, "TOPLEFT", padding_side, padding_top - 20 )
    headers:SetPoint( "RIGHT", popup, "RIGHT", -padding_side, 0 )

    ---@class HeaderFrame
    headers.item_id_header.dropdown = m.GuiElements.dropdown( headers.item_id_header, "RightButton", {
      { text = "Poor",      value = "Poor",      type = "checkbox", checked = award_filters.item_quality.Poor },
      { text = "Common",    value = "Common",    type = "checkbox", checked = award_filters.item_quality.Common },
      { text = "Uncommon",  value = "Uncommon",  type = "checkbox", checked = award_filters.item_quality.Uncommon },
      { text = "Rare",      value = "Rare",      type = "checkbox", checked = award_filters.item_quality.Rare },
      { text = "Epic",      value = "Epic",      type = "checkbox", checked = award_filters.item_quality.Epic },
      { text = "Legendary", value = "Legendary", type = "checkbox", checked = award_filters.item_quality.Legendary }
    }, function( value, checked )
      award_filters.item_quality[ value ] = checked and true or false
      refresh()
    end )
    headers.item_id_header.dropdown:SetPoint( "TOPLEFT", headers.item_id_header, "BOTTOMLEFT", 0, -1 )

    headers.winning_roll_header.dropdown = m.GuiElements.dropdown( headers.winning_roll_header, "RightButton", {
      { text = "Show SR+", value = "show_sr_plus", type = "checkbox", checked = award_filters.winning_roll.show_sr_plus }
    }, function( value, checked )
      award_filters.winning_roll[ value ] = checked and true or false
      refresh()
    end )
    headers.winning_roll_header.dropdown:SetPoint( "TOPRIGHT", headers.winning_roll_header, "BOTTOMRIGHT", 0, -1 )

    headers.roll_type_header.dropdown = m.GuiElements.dropdown( headers.roll_type_header, "RightButton", {
      { text = "MainSpec", value = "MainSpec", type = "checkbox", checked = award_filters.roll_type.MainSpec },
      { text = "OffSpec", value = "OffSpec", type = "checkbox", checked = award_filters.roll_type.OffSpec },
      { text = "Transmog", value = "Transmog", type = "checkbox", checked = award_filters.roll_type.Transmog },
      { text = "Soft reserve", value = "SoftRes", type = "checkbox", checked = award_filters.roll_type.SoftRes },
      { text = "Raid roll", value = "RR", type = "checkbox", checked = award_filters.roll_type.RR },
      { text = "Other", value = "NA", type = "checkbox", checked = award_filters.roll_type.NA }
    }, function( value, checked )
      award_filters.roll_type[ value ] = checked and true or false
      refresh()
    end )
    headers.roll_type_header.dropdown:SetPoint( "TOPRIGHT", headers.roll_type_header, "BOTTOMRIGHT", 0, -1 )

    scroll_frame = m.WinnersPopupGui.create_scroll_frame( popup, "RollForWinnersScrollFrame" )
    scroll_frame.name = scroll_frame:GetName()
    scroll_frame:SetPoint( "TOPLEFT", popup, "TOPLEFT", padding_side, padding_top - 35 )
    scroll_frame:SetPoint( "BOTTOMRIGHT", popup, "BOTTOMRIGHT", -padding_side, m.classic and 20 or 15 )
    scroll_frame:SetScript( "OnVerticalScroll", function()
      m.api.FauxScrollFrame_OnVerticalScroll( ROW_HEIGHT, function()
        refresh( m.api.FauxScrollFrame_GetOffset( scroll_frame ), false )
      end )
    end )

    content_frame = frame_builder.new()
        :parent( popup )
        :name( "RollForWinnersFrameContent" )
        :width( 250 )
        :height( 100 )
        :point( { point = "TOPLEFT", relative_point = "TOPLEFT", relative_frame = "RollForWinnersFrame", x = padding_side, y = padding_top - 35 } )
        :bg_file( "Interface/Buttons/WHITE8x8" )
        :gui_elements( m.WinnersPopupGui )
        :border_size( .5 )
        :border_color( .2, .2, .2, 1 )
        :frame_style( "Modern" )
        :build()

    content_frame:SetPoint( "BOTTOMRIGHT", popup, "BOTTOMRIGHT", -padding_side, m.classic and 20 or 15 )

    return popup
  end

  local function get_data()
    local function filter_winners()
      local quality_filter = {}
      for q, v in pairs( award_filters.item_quality ) do
        if v then
          table.insert( quality_filter, m.Types.ItemQuality[ q ] )
        end
      end

      local rolltype_filter = {}
      for t, v in pairs( award_filters.roll_type ) do
        if v then
          table.insert( rolltype_filter, t )
        end
      end

      winners_data = filter( winners_data, function( item )
        local quality = item.quality or 0
        return m.table_contains_value( quality_filter, quality ) and m.table_contains_value( rolltype_filter, item.roll_type )
      end )
    end

    local function sort_winners( a, b )
      if sort == "winning_roll" then
        local roll_a = tonumber( a[ sort ] ) or 0
        local roll_b = tonumber( b[ sort ] ) or 0

        if sort_order == "asc" then
          return roll_a > roll_b
        else
          return roll_a < roll_b
        end
      end

      local val_a = a[ sort ] or ""
      local val_b = b[ sort ] or ""

      if sort == "player_name" then
        local class_a, class_b = a[ "player_class" ] or "", b[ "player_class" ] or ""
        if class_a ~= class_b then
          return (sort_order == "asc") == (class_a < class_b)
        end
        return a.player_name < b.player_name
      elseif sort == "item_id" then
        local quality_a, quality_b = a[ "quality" ] or 0, b[ "quality" ] or 0
        if quality_a ~= quality_b then
          return (sort_order == "asc") == (quality_a > quality_b)
        end
        return m.ItemUtils.get_item_name( a.item_link ) < m.ItemUtils.get_item_name( b.item_link )
      elseif sort == "roll_type" then
        local roll_order = { SoftRes = 1, MainSpec = 2, OffSpec = 3, Transmog = 4, RR = 5, NA = 6 }
        val_a, val_b = a[ sort ] or "NA", b[ sort ] or "NA"
        if val_a ~= val_b then
          return (sort_order == "asc") == (roll_order[ val_a ] < roll_order[ val_b ])
        end
        return a.item_id < b.item_id
      end
    end

    M.debug.add( "Get data" )
    local db_data = awarded_loot.get_winners()
    winners_data = {}
    for index, v in ipairs( db_data ) do
      if v.item_link then
        table.insert( winners_data, {
          index = index,
          player_name = v.player_name,
          player_class = v.player_class,
          item_id = v.item_id,
          item_link = v.item_link,
          roll_type = (v.rolling_strategy == m.Types.RollingStrategy.RaidRoll or v.rolling_strategy == m.Types.RollingStrategy.InstaRaidRoll) and "RR"
              or v.roll_type or "NA",
          rolling_strategy = v.rolling_strategy,
          winning_roll = v.winning_roll,
          sr_plus = v.sr_plus,
          quality = v.quality
        } )
      end
    end

    filter_winners()
    if (sort) then table.sort( winners_data, sort_winners ) end
  end

  function refresh( new_offset, refresh_data )
    refresh_data = refresh_data == nil and true
    if not popup then
      popup = create_popup()
      make_content()
    end

    if not winners_data or refresh_data then get_data() end

    local winners_count = getn( winners_data )
    local old_row_count = row_count
    row_count = math.floor( ((popup:GetHeight() - (m.classic and 80 or 60)) / ROW_HEIGHT) )
    m.api.FauxScrollFrame_Update( scroll_frame, winners_count, row_count, ROW_HEIGHT )

    if new_offset and new_offset == -1 then
      offset = winners_count - row_count
      if offset < 0 then offset = 0 end
    elseif new_offset then
      offset = new_offset
    end

    local show_sr_plus = award_filters[ "winning_roll" ][ "show_sr_plus" ]
    local got_sr_plus = false
    local content = {}

    for i, item in pairs( winners_data ) do
      if i > offset and i <= row_count + offset then
        table.insert( content, {
          type = "winner",
          index = item.index,
          item_id = item.item_id,
          player_name = item.player_name,
          player_class = item.player_class,
          item_link = item.item_link,
          roll_type = item.roll_type,
          rolling_strategy = item.rolling_strategy,
          winning_roll = item.winning_roll,
          sr_plus = item.sr_plus,
          quality = item.quality
        } )
      end
      if item.sr_plus then got_sr_plus = true end
    end

    local function update_row( frame, v )
      local roll_type_abbrev = v.roll_type == "RR" and "RR" or v.roll_type == "NA" and "NA" or m.roll_type_abbrev( v.roll_type )
      local sr_plus = ""

      if not frame then
        error( "Row frame is empty!" )
        return
      end

      if show_sr_plus and got_sr_plus then
        frame.winning_roll:GetParent():SetWidth( 50 )
        if v.sr_plus and v.rolling_strategy == m.Types.RollingStrategy.SoftResRoll and v.roll_type == m.Types.RollType.SoftRes then
          sr_plus = string.format( "+%s ", v.sr_plus )
        end
      else
        frame.winning_roll:GetParent():SetWidth( 25 )
      end

      frame:SetItem( v.item_link )
      frame.player_name:SetText( c( v.player_name, v.player_class ) )
      frame.winning_roll:SetText( string.format( "%s%s", sr_plus, v.winning_roll or "-" ) )
      frame.roll_type:SetText( r( v.roll_type, roll_type_abbrev ) )
      frame.roll_type.value = v.roll_type
      frame.roll_type.on_update_item = function( rt )
        awarded_loot.update_item( v.index, { roll_type = rt } )
        refresh()
      end
      frame:Show()
    end

    headers.winning_roll_header:SetWidth( (show_sr_plus and got_sr_plus) and 50 or 25 )

    if row_count < old_row_count then
      for i = row_count + 1, old_row_count do
        row_frames[ i ].is_used = false
        row_frames[ i ]:Hide()
      end
    end

    if row_count > old_row_count then
      for i = old_row_count, row_count - 1 do
        if row_frames[ i + 1 ] then
          row_frames[ i + 1 ].is_used = true
        else
          content_frame.add_line( "winner", function( type, frame, lines )
            frame:SetPoint( "TOP", content_frame, "TOP", 0, -i * ROW_HEIGHT )
            frame:Hide()
            table.insert( row_frames, frame )
          end, 0 )
        end
        if offset > 0 then offset = offset - 1 end
      end
    end

    for i = 1, row_count do
      if row_frames[ i ] then
        row_frames[ i ]:Hide()
      end
    end

    for index, v in ipairs( content ) do
      update_row( row_frames[ index ], v )
    end

    m.api.FauxScrollFrame_SetOffset( scroll_frame, offset )
    _G[ scroll_frame.name .. "ScrollBar" ]:SetValue( offset * ROW_HEIGHT )

    if offset == 0 then
      _G[ scroll_frame.name .. "ScrollBarScrollUpButton" ]:Disable()
    else
      _G[ scroll_frame.name .. "ScrollBarScrollUpButton" ]:Enable()
    end

    if offset + math.min( row_count, winners_count ) == winners_count then
      _G[ scroll_frame.name .. "ScrollBarScrollDownButton" ]:Disable()
    else
      _G[ scroll_frame.name .. "ScrollBarScrollDownButton" ]:Enable()
    end
  end

  local function show()
    M.debug.add( "show" )
    if not popup then
      popup = create_popup()
      make_content()
    end
    popup:Show()
    refresh( 0 )
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

  local function loot_awarded()
    M.debug.add( "winners loot_awarded" )
    if popup and popup:IsVisible() then
      if sort then
        refresh( 0 )
      else
        refresh( -1 )
      end
    end
  end

  local function award_data_updated()
    M.debug.add( "award_data_updated" )
    if popup and popup:IsVisible() then
      refresh( 0 )
    end
  end

  roll_controller.subscribe( "loot_awarded", loot_awarded )
  awarded_loot.subscribe( "award_data_updated", award_data_updated )

  ---@type WinnersPopup
  return {
    show = show,
    hide = hide,
    toggle = toggle
  }
end

m.WinnersPopup = M
return M
