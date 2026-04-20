RollFor = RollFor or {}
local m = RollFor

if m.NewGroupEvent then return end

local M = {}

---@class NewGroupEvent
---@field on_group_changed fun()
---@field subscribe fun( callback: fun() )

---@param group_roster GroupRoster
function M.new( group_roster )
  local m_subscribers = {}
  local group = group_roster.am_i_in_group()

  local function notify_subscribers()
    for _, subscriber in ipairs( m_subscribers ) do
      subscriber()
    end
  end

  local function on_group_changed()
    local in_group_now = group_roster.am_i_in_group()

    if not group and in_group_now then
      group = true
      notify_subscribers()
      return
    end

    if group and not in_group_now then
      group = false
    end
  end

  local function subscribe( callback )
    table.insert( m_subscribers, callback )
  end

  return {
    on_group_changed = on_group_changed,
    subscribe = subscribe
  }
end

m.NewGroupEvent = M
return M
