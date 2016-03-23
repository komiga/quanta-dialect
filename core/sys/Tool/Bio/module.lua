
local U = require "togo.utility"
local Tool = require "Quanta.Tool"

local tool = Tool("bio", {}, {}, [=[
bio [command]
  bio tool

  <date-or-range> : [ [-m] [-y] <date> | <date-range> | all | year | month | previous | active | now ]

  precede a single date with -m to expand to the date's month
  precede a single date with -y to expand to the date's year
]=],
function(self, parent, options, params)
	return self:run_command(params)
end)

tool:add_commands({
	require("Tool.Bio.Diet"),
})

Tool.add_tools(tool)
