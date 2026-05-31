---@diagnostic disable: undefined-global
-- WotLK (3.3.5a) backport shims.
-- Most APIs that needed backporting for Vanilla exist natively in WotLK,
-- so this file is intentionally minimal.
function IsInParty() return GetNumRaidMembers() == 0 and GetNumPartyMembers() > 0 end

function IsInRaid() return GetNumRaidMembers() > 0 end

function IsInGroup() return IsInParty() or IsInRaid() end

-- string.gmatch exists natively in WotLK (Lua 5.1) — no shim needed.

-- string.match exists natively in WotLK (Lua 5.1) — no shim needed.

-- LOOT_SLOT_* constants and GetLootSlotType() exist natively in WotLK — no shim needed.

-- UnitIsGroupLeader was renamed to UnitIsGroupLeader in WotLK with the same signature.
-- UnitIsPartyLeader still exists as an alias, but the canonical name works directly.
-- No shim needed.
