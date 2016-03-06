
local U = require "togo.utility"
local Tool = require "Quanta.Tool"

local tool = Tool("entity", {}, {}, [=[
entity [command]
  entity tool
]=],
function(self, parent, options, params)
	return self:run_command(params)
end)

tool:add_commands({
	require("Tool.Entity.List"),
	require("Tool.Entity.Search"),
})

Tool.add_tools(tool)
