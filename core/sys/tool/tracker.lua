
local U = require "togo.utility"
local Tool = require "Quanta.Tool"

local tool = Tool("tracker", {}, {}, [=[
tracker [command]
  tracker tool

  <date-or-range> : [ [-m] [-y] <date> | <date-range> | all | year | month | previous | yesterday | active | now ]

  precede a single date with -m to expand to the date's month
  precede a single date with -y to expand to the date's year
]=],
function(self, parent, options, params)
	return self:run_command(params)
end)

tool:add_commands({
	require("tool/tracker_validate"),
	require("tool/tracker_stats"),
})

Tool.add_tools(tool)
