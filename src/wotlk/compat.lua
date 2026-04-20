RollFor = RollFor or {}
local M = RollFor

M.wotlk = true

-- WotLK Polyfill for modern GetLootSlotType
if not _G.GetLootSlotType then
    _G.LOOT_SLOT_ITEM = 1
    _G.LOOT_SLOT_MONEY = 2
    _G.LOOT_SLOT_CURRENCY = 3

    _G.GetLootSlotType = function(slot)
        if LootSlotIsCoin and LootSlotIsCoin(slot) then
            return _G.LOOT_SLOT_MONEY
        elseif LootSlotIsItem and LootSlotIsItem(slot) then
            return _G.LOOT_SLOT_ITEM
        end
        return 0 -- Unknown / Empty
    end
end

-- WotLK uses Lua 5.1, so # operator works and math.mod is gone.
---@param t table
---@return number
M.getn = function( t ) return #t end

---@param a number
---@param b number
---@return number
M.mod = function( a, b ) return a % b end

-- WotLK uses ChatFrame1EditBox (same as BCC, different from Vanilla's ChatFrameEditBox).
---@param item_link string
function M.link_item_in_chat( item_link )
  if M.api.ChatEdit_InsertLink then
    M.api.ChatEdit_InsertLink( item_link )
  elseif M.api.ChatFrame1EditBox:IsVisible() then
    M.api.ChatFrame1EditBox:Insert( item_link )
  end
end

---@param slash_command RollSlashCommand
---@param item_link ItemLink
function M.slash_command_in_chat( slash_command, item_link )
  M.api.ChatFrame1EditBox:Show()
  M.api.ChatFrame1EditBox:SetText( string.format( "%s %s ", slash_command, item_link ) )
  M.api.ChatFrame1EditBox:SetFocus()
end

-- WotLK GetItemInfo returns 10 values (same layout as BCC): texture is index 10.
---@param api table
---@param item_id ItemId
---@return ItemTexture
function M.get_item_texture( api, item_id )
  local _, _, _, _, _, _, _, _, _, texture = api.GetItemInfo( item_id )
  return texture
end

---@param api table
---@param item_id ItemId
---@return ItemQuality
---@return ItemTexture
function M.get_item_quality_and_texture( api, item_id )
  local _, _, quality, _, _, _, _, _, _, texture = api.GetItemInfo( item_id )
  return quality, texture
end

-- WotLK does NOT need "BackdropTemplate" as a 4th arg to CreateFrame.
-- Backdrop is configured directly on frame objects via frame:SetBackdrop{}.
---@param api CreateFrameApi
---@param parent Frame
function M.create_loot_button( api, parent )
  return api.CreateFrame( "Button", nil, parent )
end

---@param api CreateFrameApi
---@param type string
---@param name string
---@param parent Frame
function M.create_backdrop_frame( api, type, name, parent )
  return api.CreateFrame( type, name, parent )
end

-- WotLK has UnitGUID natively (introduced in 2.4), same as BCC.
---@param api table
---@param unit_type string
---@return string
function M.UnitGUID( api, unit_type )
  return api.UnitGUID( unit_type )
end

-- WotLK uses the plain global SendAddonMessage (no C_ChatInfo namespace).
-- NOTE: RegisterAddonMessagePrefix( "RollFor" ) must be called at login
-- (see main.lua on_player_login) or CHAT_MSG_ADDON will not fire.
---@param api table
---@param prefix string
---@param message string
---@param channel string
function M.SendAddonMessage( api, prefix, message, channel )
  api.SendAddonMessage( prefix, message, channel )
end

-- WotLK has IsInGroup/IsInRaid/IsInParty natively — no backport needed.
---@param api table
---@param chat Chat
---@param f function
function M.in_group_check( api, chat, f )
  return function( ... )
    if not api.IsInGroup() then
      chat.info( "Not in a group." )
      return
    end

    f( ... )
  end
end
