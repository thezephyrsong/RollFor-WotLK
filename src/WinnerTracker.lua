RollFor = RollFor or {}
local m = RollFor

if m.WinnerTracker then return end

local M = {}

local EventType = {
  RollingStarted = "RollingStarted",
  WinnerFound = "WinnerFound"
}

---@class WinnerTracker
---@field start_rolling fun( item_link: string )
---@field track fun( winner_name: string, item_link: string, roll_type: RollType, winning_roll: number?, rolling_strategy: RollingStrategyType )
---@field untrack fun( winner_name: string, item_link: string )
---@field find_winners fun( item_link: string ): table[]
---@field subscribe_for_rolling_started fun( callback: fun() )
---@field subscribe_for_winner_found fun( callback: fun( winner_name: string, item_link: string, winning_roll: number, roll_type: RollType, rolling_strategy: RollingStrategyType ) )
---@field clear fun()

---@param db table
function M.new( db )
  local callbacks = {
    [ EventType.RollingStarted ] = {},
    [ EventType.WinnerFound ] = {}
  }

  db.winners = db.winners or {}

  local function notify_winner_found( winner_name, item_link, roll_type, winning_roll, rolling_strategy )
    for _, callback in ipairs( callbacks[ EventType.WinnerFound ] ) do
      callback( winner_name, item_link, winning_roll, roll_type, rolling_strategy )
    end
  end

  -- Add 'is_sync_packet' as the last parameter
  local function track( winner_name, item_link, roll_type, winning_roll, rolling_strategy, is_sync_packet )
    db.winners[ item_link ] = db.winners[ item_link ] or {}
    db.winners[ item_link ][ winner_name ] = {
      roll_type = roll_type,
      winning_roll = winning_roll,
      rolling_strategy = rolling_strategy
    }

    notify_winner_found( winner_name, item_link, roll_type, winning_roll, rolling_strategy )

    -- === NEW SYNC BROADCAST CODE ===
    -- Only broadcast if this call originated locally on the Master Looter's machine
    if not is_sync_packet then
      -- Check if the player is explicitly the designated Master Looter
      local method, partyMaster, raidMaster = GetLootMethod()
      local is_player_master_looter = false

      if method == "master" then
        -- In 3.3.5a, GetNumRaidMembers() returns > 0 if you are in a raid
        if GetNumRaidMembers() > 0 and raidMaster then
          is_player_master_looter = UnitIsUnit("player", "raid" .. raidMaster)
        -- GetNumPartyMembers() returns > 0 if you are in a 5-man party
        elseif GetNumPartyMembers() > 0 and partyMaster then
          is_player_master_looter = (partyMaster == 0) -- 0 means the player themselves
        end
      end

      -- Fire the broadcast if they are the leader, an assistant, or the designated master looter
      if UnitIsPartyLeader("player") or UnitIsRaidOfficer("player") or is_player_master_looter then
        -- Serialize data into a string separated by '|'
        local payload = string.format("%s|%s|%s|%s|%s", 
          winner_name, 
          item_link, 
          tostring(roll_type), 
          tostring(winning_roll or 0), 
          tostring(rolling_strategy)
        )
        
        -- Using 3.3.5a native group checks to safely send the message
        if GetNumRaidMembers() > 0 then
          SendAddonMessage("RollForSync", payload, "RAID")
        elseif GetNumPartyMembers() > 0 then
          SendAddonMessage("RollForSync", payload, "PARTY")
        end
      end
    end -- Closures fixed: This closes 'if not is_sync_packet then'
  end -- Closures fixed: This closes 'local function track'

  local function untrack( winner_name, item_link )
    db.winners[ item_link ] = db.winners[ item_link ] or {}
    db.winners[ item_link ][ winner_name ] = nil

    if m.count_elements( db.winners[ item_link ] ) == 0 then
      db.winners[ item_link ] = nil
    end
  end

  local function find_winners( item_link )
    local result = {}

    for winner_name, details in pairs( db.winners[ item_link ] or {} ) do
      table.insert( result, {
        winner_name = winner_name,
        roll_type = details.roll_type,
        winning_roll = details.winning_roll,
        rolling_strategy = details.rolling_strategy
      } )
    end

    return result
  end

  local function subscribe_for_rolling_started( callback )
    table.insert( callbacks[ EventType.RollingStarted ], callback )
  end

  local function subscribe_for_winner_found( callback )
    table.insert( callbacks[ EventType.WinnerFound ], callback )
  end

  local function start_rolling( item_link )
    db.winners[ item_link ] = {}

    for _, callback in ipairs( callbacks[ EventType.RollingStarted ] ) do
      callback()
    end
  end

  local function clear()
    m.clear_table( db.winners )
  end

  -- === NEW SYNC LISTENER CODE ===
  -- (Prefix registration is not required or supported in 3.3.5a, so it is removed)
  local sync_frame = CreateFrame("Frame")
  sync_frame:RegisterEvent("CHAT_MSG_ADDON")
  sync_frame:SetScript("OnEvent", function(self, event, prefix, message, channel, sender)
    if prefix ~= "RollForSync" then return end
    if sender == UnitName("player") then return end -- Ignore our own broadcasts

    -- Unpack the '|' separated fields
    local fields = {}
    for field in string.gmatch(message, "[^|]+") do
      table.insert(fields, field)
    end

    -- Ensure we received a complete data packet
    if table.getn(fields) >= 5 then
      local sync_winner = fields[1]
      local sync_item   = fields[2]
      -- Convert numeric values back to numbers if your RollType/Roll values are numeric
      local sync_type   = tonumber(fields[3]) or fields[3]
      local sync_roll   = tonumber(fields[4])
      local sync_strat  = tonumber(fields[5]) or fields[5]

      -- Force write this data into the local raider's database
      -- The 'true' at the end engages the loop guard, preventing re-broadcasts
      track(sync_winner, sync_item, sync_type, sync_roll, sync_strat, true)
    end
  end)
  
  ---@type WinnerTracker
  return {
    start_rolling = start_rolling,
    track = track,
    untrack = untrack,
    find_winners = find_winners,
    subscribe_for_rolling_started = subscribe_for_rolling_started, -- TODO: remove these from here - use RollController
    subscribe_for_winner_found = subscribe_for_winner_found,       -- TODO: remove these from here - use RollController
    clear = clear
  }
end

m.WinnerTracker = M
return M