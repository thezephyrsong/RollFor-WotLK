RollFor = RollFor or {}
local m = RollFor

if m.Sandbox then return end

local M = {}

---@class Sandbox
---@field run fun()

---@param loot_frame LootFrame
function M.new( loot_frame )
  local function run()
    m.info( "Happy testing!" )

    if not loot_frame then return end

    local frame = loot_frame.get_frame and loot_frame.get_frame()
    if frame and frame.IsShown and frame:IsShown() then
      loot_frame.hide()
      return
    end

    ---@type LootFrameItem[]
    local test_items = {
      {
        index = 1,
        texture = "Interface\\Icons\\INV_Misc_Gem_Emerald_02",
        name = "Test Uncommon Item",
        quality = 2,
        quantity = 1,
        link = nil,
        click_fn = function() end,
        is_selected = false,
        is_enabled = true,
        bind = "BoP",
      },
      {
        index = 2,
        texture = "Interface\\Icons\\INV_Potion_54",
        name = "Test Common Item",
        quality = 1,
        quantity = 1,
        link = nil,
        click_fn = function() end,
        is_selected = false,
        is_enabled = true,
      },
      {
        index = 3,
        texture = "Interface\\Icons\\INV_Fabric_Linen_01",
        name = "Test Rare Item",
        quality = 3,
        quantity = 4,
        link = nil,
        click_fn = function() end,
        is_selected = false,
        is_enabled = true,
      },
      {
        index = 4,
        texture = "Interface\\Icons\\INV_Misc_Coin_01",
        name = "24 Silver, 8 Copper",
        quality = 0,
        quantity = 1,
        link = nil,
        click_fn = function() end,
        is_selected = false,
        is_enabled = true,
      },
    }

    loot_frame.update( test_items )
    loot_frame.show()
  end

  ---@type Sandbox
  return {
    run = run
  }
end

m.Sandbox = M
return M
