
local U = require "togo.utility"
local Tool = require "Quanta.Tool"

local tool = Tool("utility", {}, {}, [=[
utility [command]
  utility tools
]=],
function(self, parent, options, params)
	return self:run_command(params)
end)

tool:add_commands({
	require("Tool.Utility.TranslateHamster"),
})

Tool.add_tools(tool)
