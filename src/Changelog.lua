RollFor = RollFor or {}
local m = RollFor

if m.Changelog then return end

---@class Changelog
---@field entries fun(): table

local M = {}

M.entries = {
  { ver = "1.2.3", text = "Track winners of Blizzard's built-in group-loot Need/Greed/Disenchant rolls into the same award history as SR/MS/OS." },
  { ver = "1.2.2", text = "Bug fix and seperate changelog" },
  { ver = "1.2.1", text = "Aggregate per-player +1s & multiline rows" },
  { ver = "1.2.0", text = "Add +1s GUI and improve award handling" },
  { ver = "1.1.8", text = "Strip realm suffix from player names" },
  { ver = "1.1.7", text = "Add guards for nil checks and unknown roll types" },
  { ver = "1.1.6", text = "Loot tracking overhaul. Integrated 'awarded_loot' data into the broadcasts and RollController packets to capture and track comprehensive roll context, including item links, winning rolls, roll types, and rolling strategies." },
  { ver = "1.1.5", text = "Compatibility and maintenance release. Fixed numerous WotLK 3.3.5a API and Lua 5.1 compatibility issues (including 'this'/'arg1' replacements, unpack variations, and GetLootMethod arity). Cleaned up dead event registrations, scoped global math mutations, and corrected UI casing typos." },
  { ver = "1.1.4", text = "Hardening release. Added defensive boundary checks to prevent UI crashes if target data returns nil." },
  { ver = "1.1.3", text = "Fixed a script error occurring when item links contain unrecognized localization tokens from non-English clients." },
  { ver = "1.1.2", text = "Enhanced soft-reserve matching logic to automatically strip trailing spaces and handle minor case discrepancies." },
  { ver = "1.1.1", text = "Added option to adjust default rolling session countdown timers via '/rf config default-rolling-time'." },
  { ver = "1.1.0", text = "Introduced a basic real-time loot overlay frame for the Master Looter to view active roll candidates." },

  -- 1.0.x Series: First Major Stable Release
  { ver = "1.0.4", text = "Fixed countdown timer sync errors when multiple item rolls are triggered simultaneously." },
  { ver = "1.0.3", text = "Patched a memory leak caused by un-cleared roll table histories between sequential boss encounters." },
  { ver = "1.0.2", text = "Adjusted chat message hooks to correctly parse roll text from players with foreign or accented characters." },
  { ver = "1.0.1", text = "Fixed a nil-pointer exception occurring when players are offline or zoning into an instance during a roll." },
  { ver = "1.0.0", text = "Official stable release. Polished primary loot management loops, `/rf`, `/rr`, and basic `/sr` commands." },

  -- 0.x.x Series: Alpha/Beta Core Feature Building
  { ver = "0.9.0", text = "Optimized data processing for large 40-man raid groups to prevent micro-stutters during intensive roll phases." },
  { ver = "0.8.0", text = "Initial implementation of the Soft-Reservation (SR) system string import utility via clipboard." },
  { ver = "0.7.0", text = "Added a preliminary interactive minimap icon with color-coded status indications for raid configuration." },
  { ver = "0.6.0", text = "Introduced primitive Main Spec (MS) and Off Spec (OS) rolling thresholds based on numeric roll targets." },
  { ver = "0.5.0", text = "Added fundamental slash configuration tracking framework via the new `/rf config` base parser." },
  { ver = "0.4.0", text = "Implemented the raid-rolling command `/rr` to automate picking a random member directly from group listings." },
  { ver = "0.3.0", text = "Added text-based roll winner summaries that automatically announce directly to Raid or Party chat." },
  { ver = "0.2.0", text = "Built automated tie-breaker handling to isolate matching top rolls and query players for a re-roll." },
  { ver = "0.1.0", text = "Added multi-item support allowing the Master Looter to open rolls for duplicate items simultaneously." },
  { ver = "0.0.4", text = "Implemented anti-cheat check to track duplicate entries and suppress extra rolls from a single player." },
  { ver = "0.0.3", text = "Created local session data tables to store rolling candidates and sort values in descending order." },
  { ver = "0.0.2", text = "Introduced the `/rf` slash command structure and ignored random rolls falling outside the standard 1-100 range." },
  { ver = "0.0.1", text = "Initial proof-of-concept. Hooked into `CHAT_MSG_SYSTEM` events to capture raw player roll system strings." },
}

m.Changelog = M