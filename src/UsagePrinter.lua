RollFor = RollFor or {}
local m = RollFor

if m.UsagePrinter then return end

local M = {}

local hl = m.colors.hl
local RollSlashCommand = m.Types.RollSlashCommand

function M.new( chat )
  local function print_usage( roll_type )
    if roll_type == RollSlashCommand.NormalRoll or roll_type == RollSlashCommand.NoSoftResRoll then
      chat.info( string.format( "Usage: %s <%s> [%s]", roll_type, hl( "item" ), hl( "seconds" ) ) )
    elseif roll_type == RollSlashCommand.RaidRoll then
      chat.info( string.format( "Usage: %s <%s>", roll_type, hl( "item" ) ), nil, "RaidRoll" )
    elseif roll_type == RollSlashCommand.InstaRaidRoll then
      chat.info( string.format( "Usage: %s <%s>", roll_type, hl( "item" ) ), nil, "InstaRaidRoll" )
    end
  end

  return {
    print_usage = print_usage
  }
end

m.UsagePrinter = M
return M
