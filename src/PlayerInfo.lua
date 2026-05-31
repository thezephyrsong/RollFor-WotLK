RollFor = RollFor or {}
local m = RollFor

if m.PlayerInfo then return end

---@class PlayerInfo
---@field get_name fun(): string
---@field get_class fun(): string
---@field is_master_looter fun(): boolean
---@field is_leader fun(): boolean
---@field is_assistant fun(): boolean

local M = {}

---@param api table
function M.new( api )
  local function get_name()
    return api.UnitName( "player" )
  end

  local function get_class()
  local _, class = api.UnitClass( "player" )
  return class
end

  local function is_master_looter()
    if not api.IsInGroup() then return false end

    if m.vanilla then
      -- Vanilla: GetLootMethod returns (method, id)
      -- Party: id = 0-4 (0 = you)
      -- Raid: id = 1-40 (raid member index)
      local loot_method, id = api.GetLootMethod()
      if loot_method ~= "master" or not id then return false end
      if id == 0 then return true end

      if api.IsInRaid() then
        local name = api.GetRaidRosterInfo( id )
        return name == get_name()
      end

      return api.UnitName( "party" .. id ) == get_name()
    else
      -- WotLK 3.3.5a, BCC, Retail: GetLootMethod returns (method, partyMaster, raidMaster)
      -- Party: partyMaster = 0-4, raidMaster = nil
      -- Raid: partyMaster = nil, raidMaster = 1-40
      local loot_method, party_id, raid_id = api.GetLootMethod()
      if loot_method ~= "master" then return false end

      if party_id == 0 then return true end

      if raid_id then
        local name = api.GetRaidRosterInfo( raid_id )
        return name == get_name()
      end

      if party_id then
        return api.UnitName( "party" .. party_id ) == get_name()
      end

      return false
    end
  end

  local function is_leader()
    -- UnitIsGroupLeader was added in Cataclysm. In WotLK 3.3.5a, UnitIsPartyLeader
    -- only works in party context. For raids, check raid roster rank.
    if api.UnitIsGroupLeader then
      return api.UnitIsGroupLeader( "player" )
    end

    if api.IsInRaid() then
      local my_name = get_name()
      for i = 1, 40 do
        local name, rank = api.GetRaidRosterInfo( i )
        if name and name == my_name then
          return rank == 2
        end
      end
      return false
    end

    return api.UnitIsPartyLeader and api.UnitIsPartyLeader( "player" ) or false
  end

  local function is_assistant()
    if not api.IsInRaid() then return false end
    local my_name = get_name()

    for i = 1, 40 do
      local name, rank = api.GetRaidRosterInfo( i )

      if name and name == my_name then
        return rank and rank > 0 or false
      end
    end
  end

  ---@type PlayerInfo
  return {
    get_name = get_name,
    get_class = get_class,
    is_master_looter = is_master_looter,
    is_leader = is_leader,
    is_assistant = is_assistant
  }
end

m.PlayerInfo = M
return M
