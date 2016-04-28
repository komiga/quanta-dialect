
local U = require "togo.utility"
local Tool = require "Quanta.Tool"

local tool = Tool("account", {}, {}, [=[
account [command]
  account tool
]=],
function(self, parent, options, params)
	return self:run_command(params)
end)

tool:add_commands({
	require("Tool.Account.Print"),
})

Tool.add_tools(tool)
