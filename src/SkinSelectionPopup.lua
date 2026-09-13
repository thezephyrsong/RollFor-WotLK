RollFor = RollFor or {}
local m = RollFor

if m.SkinSelectionPopup then return end

local M = {}

local button_defaults = {
  width = 90,
  height = 24,
  scale = 0.9
}

---@class SkinSelectionPopup
---@field should_show fun(): boolean
---@field show fun()

---@param frame_builder FrameBuilderFactory
---@param config Config
function M.new( frame_builder, config )
  local popup

  local function dragonui_available()
    return _G.NineSliceUtils and _G.NineSliceUtils.ApplyLayout and true or false
  end

  local function create_popup()
    -- Always rendered with the plain Modern builder: no skin has been picked
    -- yet, so the picker itself shouldn't depend on Classic or DragonUI.
    local frame = m.PopupBuilder.modern( frame_builder, 30, 8, 45 )
        :name( "RollForSkinSelectionPopup" )
        :point( { point = "CENTER", relative_point = "CENTER", x = 0, y = 100 } )
        :sound()
        :gui_elements( m.GuiElements )
        :backdrop_color( 0, 0, 0, 0.85 )
        :border_color( 0.125, 0.624, 0.976, 0.3 )
        :strata( "FULLSCREEN_DIALOG" )
        :movable()
        :build()

    return frame
  end

  local function make_content( on_pick )
    local content = {
      { type = "text", value = "Welcome to RollFor!" },
      { type = "text", value = "Pick a look for RollFor's windows." },
      { type = "text", value = "You can change this later with /rf config skin." },
    }

    table.insert( content, { type = "button", label = "Classic", width = 90, on_click = function() on_pick( "classic" ) end } )
    table.insert( content, { type = "button", label = "Modern", width = 90, on_click = function() on_pick( "modern" ) end } )

    if dragonui_available() then
      table.insert( content, { type = "button", label = "DragonUI", width = 90, on_click = function() on_pick( "dragonui" ) end } )
    end

    return content
  end

  local function show()
    if not popup then popup = create_popup() end
    popup:clear()

    local function on_pick( skin )
      config.set_skin( skin )
      popup:Hide()
    end

    for _, v in ipairs( make_content( on_pick ) ) do
      popup.add_line( v.type, function( line_type, frame, lines )
        if line_type == "text" then
          frame:SetText( v.value )
        elseif line_type == "button" then
          frame:SetWidth( v.width or button_defaults.width )
          frame:SetHeight( v.height or button_defaults.height )
          frame:SetText( v.label or "" )
          frame:SetScale( v.scale or button_defaults.scale )
          frame:SetScript( "OnClick", v.on_click or function() end )
          frame:SetFrameLevel( popup:GetFrameLevel() + 1 )
        end

        if line_type ~= "button" then
          local count = m.getn( lines )

          if count == 0 then
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", popup, "TOP", 0, -18 )
          else
            local line_anchor = lines[ count ].frame
            frame:ClearAllPoints()
            frame:SetPoint( "TOP", line_anchor, "BOTTOM", 0, -2 )
          end
        end
      end )
    end

    popup:Show()
  end

  ---@type SkinSelectionPopup
  return {
    should_show = function() return not config.skin_chosen_by_user() end,
    show = show,
  }
end

m.SkinSelectionPopup = M
return M
