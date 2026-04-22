RollFor = RollFor or {}
local m = RollFor

if m.SrConfigGui then return end

local M = {}

---@diagnostic disable-next-line: undefined-global
local UIParent = UIParent

local frame_backdrop = {
  bgFile   = "Interface\\DialogFrame\\UI-DialogBox-Background",
  edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
  tile     = true,
  tileSize = 32,
  edgeSize = 32,
  insets   = { left = 8, right = 8, top = 8, bottom = 8 }
}

local row_backdrop = {
  bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
  edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
  tile     = true,
  tileSize = 16,
  edgeSize = 16,
  insets   = { left = 2, right = 2, top = 2, bottom = 2 }
}

local ROW_HEIGHT   = 20
local PANEL_WIDTH  = 580
local LIST_HEIGHT  = 220
local HEADER_H     = 80   -- space for controls above the list
local FOOTER_H     = 40
local TOTAL_HEIGHT = HEADER_H + LIST_HEIGHT + FOOTER_H

-- ── Helpers ────────────────────────────────────────────────────────────────

local function make_label( parent, text, font, anchor, ox, oy )
  local fs = parent:CreateFontString( nil, "OVERLAY", font or "GameFontNormalSmall" )
  fs:SetTextColor( 1, 1, 1 )
  if text then fs:SetText( text ) end
  if anchor then fs:SetPoint( anchor, ox or 0, oy or 0 ) end
  return fs
end

local function make_button( parent, label_text, width, height )
  local btn = m.api.CreateFrame( "Button", nil, parent, "UIPanelButtonTemplate" )
  btn:SetWidth( width or 80 )
  btn:SetHeight( height or 20 )
  btn:SetText( label_text )
  return btn
end

-- Track all our item editboxes so we can hook shift-click into them
local item_editboxes = {}

local function make_editbox( parent, width, height )
  -- Wrap in a backdrop frame to match the WoW panel aesthetic in 3.3.5a
  local wrapper = m.create_backdrop_frame( m.api, "Frame", nil, parent )
  wrapper:SetWidth( width or 120 )
  wrapper:SetHeight( height or 20 )
  wrapper:SetBackdrop( {
    bgFile   = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile     = true,
    tileSize = 16,
    edgeSize = 12,
    insets   = { left = 2, right = 2, top = 2, bottom = 2 }
  } )
  wrapper:SetBackdropColor( 0.05, 0.05, 0.05, 0.9 )
  wrapper:SetBackdropBorderColor( 0.4, 0.4, 0.4, 1 )

  local eb = m.api.CreateFrame( "EditBox", nil, wrapper )
  eb:SetPoint( "TOPLEFT",     wrapper, "TOPLEFT",     4,  -3 )
  eb:SetPoint( "BOTTOMRIGHT", wrapper, "BOTTOMRIGHT", -4,  3 )
  eb:SetAutoFocus( false )
  eb:SetFontObject( "GameFontNormalSmall" )
  eb:SetTextColor( 1, 1, 1 )
  eb:SetScript( "OnEscapePressed", function() eb:ClearFocus() end )

  -- Forward GetText/SetText/GetText/ClearFocus/SetFocus to inner editbox
  -- so callers can treat the wrapper like a plain editbox
  wrapper.GetText     = function() return eb:GetText() end
  wrapper.SetText     = function( _, t ) eb:SetText( t ) end
  wrapper.ClearFocus  = function() eb:ClearFocus() end
  wrapper.SetFocus    = function() eb:SetFocus() end
  wrapper.HasFocus    = function() return eb:HasFocus() end
  wrapper.Insert      = function( _, t ) eb:Insert( t ) end
  wrapper.SetScript   = function( _, event, fn ) eb:SetScript( event, fn ) end
  wrapper._inner      = eb

  return wrapper
end

local function setup_placeholder(eb, placeholder_text)
  -- We need to find the actual WoW object to change the color
  local raw_eb = eb._inner or eb -- Fallback to eb if _inner doesn't exist

  local function show_placeholder()
    if eb:GetText() == "" then
      eb:SetText(placeholder_text)
      if raw_eb.SetTextColor then
        raw_eb:SetTextColor(0.5, 0.5, 0.5) -- Grey
      end
    end
  end

  eb:SetScript("OnEditFocusGained", function(self)
    if self:GetText() == placeholder_text then
      self:SetText("")
      if raw_eb.SetTextColor then
        raw_eb:SetTextColor(1, 1, 1) -- White
      end
    end
  end)

  eb:SetScript("OnEditFocusLost", function(self)
    show_placeholder()
  end)

  show_placeholder()
end

-- ── Row pool for the SR list ───────────────────────────────────────────────

local function create_sr_row( parent )
  local row = m.create_backdrop_frame( m.api, "Button", nil, parent )
  row:SetHeight( ROW_HEIGHT )
  row:SetBackdrop( row_backdrop )
  row:SetBackdropColor( 0.1, 0.1, 0.1, 0.8 )
  row:SetBackdropBorderColor( 0.3, 0.3, 0.3 )

  row.player_label = row:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
  row.player_label:SetPoint( "LEFT", 6, 0 )
  row.player_label:SetWidth( 110 )
  row.player_label:SetJustifyH( "LEFT" )
  row.player_label:SetTextColor( 1, 0.82, 0 )  -- gold

  row.item_label = row:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
  row.item_label:SetPoint( "LEFT", row.player_label, "RIGHT", 4, 0 )
  row.item_label:SetWidth( 300 )
  row.item_label:SetJustifyH( "LEFT" )
  row.item_label:SetTextColor( 1, 1, 1 )

  row.tag_label = row:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
  row.tag_label:SetPoint( "LEFT", row.item_label, "RIGHT", 4, 0 )
  row.tag_label:SetWidth( 30 )
  row.tag_label:SetJustifyH( "CENTER" )
  row.tag_label:SetTextColor( 0.6, 0.6, 0.6 )

  row.remove_btn = make_button( row, "X", 22, 16 )
  row.remove_btn:SetPoint( "RIGHT", -4, 0 )

  return row
end

local function create_hr_row( parent )
  local row = m.create_backdrop_frame( m.api, "Button", nil, parent )
  row:SetHeight( ROW_HEIGHT )
  row:SetBackdrop( row_backdrop )
  row:SetBackdropColor( 0.15, 0.05, 0.05, 0.9 )
  row:SetBackdropBorderColor( 0.5, 0.2, 0.2 )

  row.tag = row:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
  row.tag:SetPoint( "LEFT", 6, 0 )
  row.tag:SetWidth( 30 )
  row.tag:SetTextColor( 1, 0.3, 0.3 )
  row.tag:SetText( "[HR]" )

  row.item_label = row:CreateFontString( nil, "OVERLAY", "GameFontNormalSmall" )
  row.item_label:SetPoint( "LEFT", row.tag, "RIGHT", 4, 0 )
  row.item_label:SetWidth( 390 )
  row.item_label:SetJustifyH( "LEFT" )
  row.item_label:SetTextColor( 1, 1, 1 )

  row.remove_btn = make_button( row, "X", 22, 16 )
  row.remove_btn:SetPoint( "RIGHT", -4, 0 )

  return row
end

-- ── Main GUI factory ───────────────────────────────────────────────────────

local function create_frame( sr_db, on_apply, on_whisper_player )
  local api = m.api

  local frame = m.create_backdrop_frame( api, "Frame", "RollForSrConfigFrame", UIParent )
  frame:Hide()
  frame:SetWidth( PANEL_WIDTH )
  frame:SetHeight( TOTAL_HEIGHT )
  frame:SetPoint( "CENTER", UIParent, "CENTER", 0, 50 )
  frame:EnableMouse( true )
  frame:SetMovable( true )
  frame:SetToplevel( true )
  frame:SetFrameStrata( "DIALOG" )
  frame:SetBackdrop( frame_backdrop )
  frame:SetBackdropColor( 0, 0, 0, 1 )

  frame:SetScript( "OnMouseDown", function() frame:StartMoving() end )
  frame:SetScript( "OnMouseUp",   function() frame:StopMovingOrSizing() end )

  ---@diagnostic disable-next-line: undefined-global
  table.insert( UISpecialFrames, "RollForSrConfigFrame" )

  -- ── Title ──
  local title = make_label( frame, "SR / HR Manager", "GameFontNormal", "TOP", 0, -12 )
  title:SetTextColor( 1, 0.82, 0 )

  -- ── Lock / Unlock button ──
  local lock_btn = make_button( frame, "Lock SR", 90, 22 )
  lock_btn:SetPoint( "TOPLEFT", frame, "TOPLEFT", 16, -30 )

  local lock_status = make_label( frame, "", "GameFontNormalSmall", nil )
  lock_status:SetPoint( "LEFT", lock_btn, "RIGHT", 8, 0 )

  local function refresh_lock_display()
    if sr_db.is_open() then
      lock_btn:SetText( "Lock SR" )
      lock_status:SetText( "|cff00ff00Open|r" )
    else
      lock_btn:SetText( "Unlock SR" )
      lock_status:SetText( "|cffff4444Locked|r" )
    end
  end

  lock_btn:SetScript( "OnClick", function()
    sr_db.set_open( not sr_db.is_open() )
    refresh_lock_display()
  end )

  -- ── Close button ──
  local close_btn = make_button( frame, "Close", 70, 22 )
  close_btn:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -16, 10 )
  close_btn:SetScript( "OnClick", function() frame:Hide() end )

  -- ── Max SRs spinner ──
  local max_sr_label = make_label( frame, "Max SRs per player:", "GameFontNormalSmall", nil )
  max_sr_label:SetPoint( "TOP", frame, "TOP", -40, -35 )

  local max_label = make_label( frame, "", "GameFontNormal", nil )
  max_label:SetPoint( "LEFT", max_sr_label, "RIGHT", 8, 0 )
  max_label:SetTextColor( 1, 1, 0 )

  local function refresh_max_display()
    max_label:SetText( tostring( sr_db.get_max_srs() ) )
  end

  local function announce_sr_info()
    local channel = "SAY"
    if api.GetNumRaidMembers() > 0 then
      channel = "RAID"
    elseif api.GetNumPartyMembers() > 0 then
      channel = "PARTY"
    end

    local msg = "SoftRes is active! Whisper me your reservations like this: !SR [Item Link]"
    
    if api.IsRaidLeader() or api.IsRaidOfficer() or api.GetNumRaidMembers() == 0 then
      api.SendChatMessage(msg, channel)
    else
      m.pretty_print("You must be the Raid Leader or Assistant to announce.", m.colors.red)
    end
  end

  local announce_btn = make_button( frame, "Announce Info", 110, 22 )
  announce_btn:SetPoint( "TOPRIGHT", frame, "TOPRIGHT", -16, -30 ) 
  announce_btn:SetScript( "OnClick", announce_sr_info )
  announce_btn:SetScript("OnEnter", function(self)
   api.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
   api.GameTooltip:SetText("Announce Instructions", 1, 1, 1)
   api.GameTooltip:AddLine("Broadcasts SR instructions to Raid/Party.", 0.5, 0.5, 0.5)
   api.GameTooltip:Show()
  end)
  announce_btn:SetScript("OnLeave", function() api.GameTooltip:Hide() end)

  local dec_btn = make_button( frame, "-", 22, 20 )
  dec_btn:SetPoint( "LEFT", max_label, "RIGHT", 6, 0 )
  dec_btn:SetScript( "OnClick", function()
    local n = sr_db.get_max_srs()
    if n > 1 then
      sr_db.set_max_srs( n - 1 )
      refresh_max_display()
      on_apply()
    end
  end )

  local inc_btn = make_button( frame, "+", 22, 20 )
  inc_btn:SetPoint( "LEFT", dec_btn, "RIGHT", 4, 0 )
  inc_btn:SetScript( "OnClick", function()
    local n = sr_db.get_max_srs()
    if n < 10 then
      sr_db.set_max_srs( n + 1 )
      refresh_max_display()
      on_apply()
    end
  end )

  local clear_confirm = false

  local clear_all_btn = make_button( frame, "Clear All", 80, 22 )
  clear_all_btn:SetPoint( "RIGHT", close_btn, "LEFT", -6, 0 )
  
  clear_all_btn:SetScript( "OnClick", function(self)
    if not clear_confirm then
      clear_confirm = true
      self:SetText("|cffff0000Confirm?|r")
      
      -- Use the standard WoW Timer API
      C_Timer.After(3, function() 
        clear_confirm = false
        self:SetText("Clear All")
      end)
    else
      -- The actual clearing logic
      sr_db.clear_all_srs()
      clear_confirm = false
      self:SetText("Clear All")
      m.pretty_print("All Soft Reserves have been cleared.", m.colors.green)
      on_apply()
      if refresh then 
        refresh() 
      elseif frame.refresh then
        frame.refresh()
    end
   end
  end )

  -- Add a helpful tooltip
  clear_all_btn:SetScript("OnEnter", function(self)
    api.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    api.GameTooltip:SetText("Clear All SRs", 1, 0, 0)
    api.GameTooltip:AddLine("Permanently deletes all player reservations.", 1, 1, 1)
    api.GameTooltip:AddLine("Requires two clicks to confirm.", 0.5, 0.5, 0.5)
    api.GameTooltip:Show()
  end)
  clear_all_btn:SetScript("OnLeave", function() api.GameTooltip:Hide() end)

  -- ── Column headers ──
  local headers_y = -HEADER_H + 12
  local ph = make_label( frame, "Player", "GameFontNormalSmall", "TOPLEFT", 16, headers_y )
  ph:SetTextColor( 0.7, 0.7, 0.7 )
  local ih = make_label( frame, "Item", "GameFontNormalSmall", "TOPLEFT", 132, headers_y )
  ih:SetTextColor( 0.7, 0.7, 0.7 )

  -- ── Scroll area ──
  local scroll_frame = api.CreateFrame( "ScrollFrame", "RollForSrConfigScroll", frame, "UIPanelScrollFrameTemplate" )
  scroll_frame:SetPoint( "TOPLEFT",     frame, "TOPLEFT",     16,  -(HEADER_H) )
  scroll_frame:SetPoint( "BOTTOMRIGHT", frame, "BOTTOMRIGHT", -36, FOOTER_H )

  local scroll_child = api.CreateFrame( "Frame", nil, scroll_frame )
  scroll_child:SetWidth( PANEL_WIDTH - 52 )
  scroll_child:SetHeight( 2 )
  scroll_frame:SetScrollChild( scroll_child )

  -- ── Add-SR row at bottom of frame ──
  local add_sep = make_label( frame, "Add SR:", "GameFontNormalSmall", "BOTTOMLEFT", 16, FOOTER_H - 4 )
  add_sep:SetTextColor( 0.7, 0.7, 0.7 )

  local add_player_eb = make_editbox( frame, 110, 20 )
  add_player_eb:SetPoint( "LEFT", add_sep, "RIGHT", 6, 0 )
  add_player_eb:SetScript( "OnTabPressed", function() add_player_eb:ClearFocus() end )
  setup_placeholder(add_player_eb, "Character Name")

  local add_item_eb = make_editbox( frame, 200, 20 )
  add_item_eb:SetPoint( "LEFT", add_player_eb, "RIGHT", 6, 0 )
  add_item_eb:SetScript( "OnTabPressed", function() add_item_eb:ClearFocus() end )
  table.insert( item_editboxes, add_item_eb )
  setup_placeholder(add_item_eb, "Shift-Click Item Here")

  -- Intercept item link drops into the add-item editbox
  add_item_eb:SetScript( "OnReceiveDrag", function()
    local info_type, _, _, link = GetCursorInfo and GetCursorInfo() or nil
    if info_type == "item" and link then
      add_item_eb:SetText( link )
      ClearCursor()
    end
  end )

  local add_sr_btn = make_button( frame, "Add SR", 60, 20 )
  add_sr_btn:SetPoint( "LEFT", add_item_eb, "RIGHT", 6, 0 )

  -- ── Add-HR row ──
  local add_hr_sep = make_label( frame, "Add HR:", "GameFontNormalSmall", "BOTTOMLEFT", 16, FOOTER_H - 26 )
  add_hr_sep:SetTextColor( 1, 0.3, 0.3 )

  local add_hr_eb = make_editbox( frame, 200, 20 )
  add_hr_eb:SetPoint( "LEFT", add_hr_sep, "RIGHT", 6, 0 )
  table.insert( item_editboxes, add_hr_eb )

  add_hr_eb:SetScript( "OnReceiveDrag", function()
    local info_type, _, _, link = GetCursorInfo and GetCursorInfo() or nil
    if info_type == "item" and link then
      add_hr_eb:SetText( link )
      ClearCursor()
    end
  end )

  local add_hr_btn = make_button( frame, "Add HR", 60, 20 )
  add_hr_btn:SetPoint( "LEFT", add_hr_eb, "RIGHT", 6, 0 )

  -- ── Row rendering ─────────────────────────────────────────────────────────

  local sr_rows = {}
  local hr_rows = {}

  local function get_or_create_sr_row( index )
    if not sr_rows[ index ] then
      sr_rows[ index ] = create_sr_row( scroll_child )
    end
    return sr_rows[ index ]
  end

  local function get_or_create_hr_row( index )
    if not hr_rows[ index ] then
      hr_rows[ index ] = create_hr_row( scroll_child )
    end
    return hr_rows[ index ]
  end

  local function hide_all_rows()
    for _, r in ipairs( sr_rows ) do r:Hide() end
    for _, r in ipairs( hr_rows ) do r:Hide() end
  end

  local function refresh()
    hide_all_rows()

    local row_w = scroll_child:GetWidth()
    local y     = 0
    local sr_i  = 0
    local hr_i  = 0

    -- ── HR rows first ──
    for item_id, item_link in pairs( sr_db.get_all_hrs() ) do
      hr_i = hr_i + 1
      local row = get_or_create_hr_row( hr_i )
      row:SetWidth( row_w )
      row:SetPoint( "TOPLEFT", scroll_child, "TOPLEFT", 0, -y )

      local display = (type(item_link) == "string" and item_link) or ("item:" .. item_id)
      row.item_label:SetText( display )

      local captured_id   = item_id
      row.remove_btn:SetScript( "OnClick", function()
        sr_db.remove_hr( captured_id )
        on_apply()
        refresh()
      end )

      row:Show()
      y = y + ROW_HEIGHT + 2
    end

    -- ── SR rows ──
    for player_name, entries in pairs( sr_db.get_all_srs() ) do
      for _, entry in ipairs( entries ) do
        sr_i = sr_i + 1
        local row = get_or_create_sr_row( sr_i )
        row:SetWidth( row_w )
        row:SetPoint( "TOPLEFT", scroll_child, "TOPLEFT", 0, -y )

        row.player_label:SetText( player_name )
        local display = entry.item_link or entry.item_name or ("item:" .. entry.item_id)
        row.item_label:SetText( display )

        local used = #sr_db.get_player_srs( player_name )
        local max  = sr_db.get_max_srs()
        row.tag_label:SetText( string.format( "%d/%d", used, max ) )

        local cap_player = player_name
        local cap_id     = entry.item_id
        local cap_name   = entry.item_name or ("item:" .. entry.item_id)
        row.remove_btn:SetScript( "OnClick", function()
          sr_db.remove_sr( cap_player, cap_id )
          on_apply()
          -- Notify the player
          on_whisper_player( cap_player,
            string.format( "Your SR for [%s] has been removed by the raid leader.", cap_name ) )
          refresh()
        end )

        row:Show()
        y = y + ROW_HEIGHT + 2
      end
    end

    scroll_child:SetHeight( math.max( y, scroll_frame:GetHeight() ) )
    scroll_frame:UpdateScrollChildRect()
  end

-- ── Add SR button handler ──
  add_sr_btn:SetScript( "OnClick", function()
    local player_name = add_player_eb:GetText()
    local link_text   = add_item_eb:GetText()

    -- Check for empty OR placeholder text
    if not player_name or player_name == "" or player_name == "Character Name" then
      m.pretty_print( "Enter a player name.", m.colors.red )
      return
    end

    -- Check for empty OR placeholder text for item
    if not link_text or link_text == "" or link_text == "Shift-Click Item Here" then
      m.pretty_print( "Please link a valid item.", m.colors.red )
      return
    end

    local item_id = string.match( link_text, "|Hitem:(%d+):" )
    item_id = item_id and tonumber( item_id )

    if not item_id then
      m.pretty_print( "Please link a valid item.", m.colors.red )
      return
    end

    local item_name = string.match( link_text, "|h%[(.-)%]|h" )

    sr_db.add_sr_for_player( player_name, item_id, link_text )
    on_apply()
    on_whisper_player( player_name,
      string.format( "[%s] has been added to your SRs by the raid leader.", item_name or ("item:" .. item_id) ) )

    -- Clear text and remove focus so placeholders show back up
    add_player_eb:SetText( "" )
    add_item_eb:SetText( "" )
    add_player_eb:ClearFocus()
    add_item_eb:ClearFocus()
    
    refresh()
  end )

  -- ── Add HR button handler ──
  add_hr_btn:SetScript( "OnClick", function()
    local link_text = add_hr_eb:GetText()
    
    -- Check for placeholder (assuming you add a placeholder to the HR box too)
    if not link_text or link_text == "" or link_text == "Shift-Click Item Here" then
      m.pretty_print( "Please link a valid item for HR.", m.colors.red )
      return
    end

    local item_id = string.match( link_text, "|Hitem:(%d+):" )
    item_id = item_id and tonumber( item_id )

    if not item_id then
      m.pretty_print( "Please link a valid item for HR.", m.colors.red )
      return
    end

    local item_name = string.match( link_text, "|h%[(.-)%]|h" ) or ("item:" .. item_id)

    -- add_hr returns list of displaced players
    local displaced = sr_db.add_hr( item_id, link_text )
    on_apply()

    for _, player_name in ipairs( displaced ) do
      on_whisper_player( player_name,
        string.format( "Your SR for [%s] has been removed — it is now hard reserved.", item_name ) )
    end

    add_hr_eb:SetText( "" )
    add_hr_eb:ClearFocus() -- Resets placeholder
    refresh()
  end )

  frame:SetScript( "OnShow", function()
    refresh_lock_display()
    refresh_max_display()
    refresh()
  end )

  frame.refresh = refresh

  -- Hook shift-click item linking: when ChatEdit_InsertLink fires and one of our
  -- item editboxes has focus, insert the link into it instead.
  -- hooksecurefunc is safe in 3.3.5a and won't taint the original function.
  if not _G._RollForSrLinkHooked then
    _G._RollForSrLinkHooked = true
    hooksecurefunc( "ChatEdit_InsertLink", function( link )
      for _, eb_wrapper in ipairs( item_editboxes ) do
        if eb_wrapper.HasFocus and eb_wrapper:HasFocus() then
          eb_wrapper:SetText( link )
          return
        end
      end
    end )
  end

  return frame
end

-- ── Public ────────────────────────────────────────────────────────────────

function M.new( sr_db, on_apply, on_whisper_player )
  local frame

  local function show()
    if not frame then
      frame = create_frame( sr_db, on_apply, on_whisper_player )
    end
    if frame:IsVisible() then
      frame:Hide()
    else
      frame:Show()
    end
  end

  local function refresh()
    if frame and frame:IsVisible() then
      frame.refresh()
    end
  end

  -- ADD THIS LINE:
  -- This attaches the show function to the module so m.SrConfigGui.show() works.
  M.show = show

  return {
    show    = show,
    refresh = refresh,
  }
end

m.SrConfigGui = M
return M
