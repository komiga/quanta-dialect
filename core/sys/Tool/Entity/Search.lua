
local U = require "togo.utility"
local Tool = require "Quanta.Tool"
local Vessel = require "Quanta.Vessel"
local Entity = require "Quanta.Entity"

local options = {
Tool.Option({"-u", "--universe"}, "string", [=[
-u=UNIVERSE_NAME --universe=UNIVERSE_NAME
  select a universe (from data/entity/)
]=],
function(tool, value)
	tool.data.universe = value
end),
}

local command = Tool("search", options, {}, [=[
search [options] <ref> [...]
  search for entities
]=],
function(self, parent, options, params)
	if #params == 0 then
		Tool.log("no refs given")
		return
	end

	local universe, msg = Entity.read_universe(Vessel.data_path("entity/" .. self.data.universe .. ".q"))
	if not universe then
		return Tool.log_error(msg)
	end

	local branches = {
		Entity.make_search_branch(universe, math.huge),
	}

	local matches = nil
	local function handler(entity)
		table.insert(matches, entity)
		return false
	end

	for i, p in ipairs(params) do
		matches = {}

		local ref = p.value
		universe:search(branches, ref, handler)

		Tool.log("%s =>", ref)
		if #matches == 0 then
			Tool.log("  found nothing")
		else
			for _, entity in pairs(matches) do
				Tool.log(
					"  %s  %-12s  %s",
					entity_type_shorthand(entity),
					entity_class_name(entity),
					entity:ref()
				)
			end
		end

		if i < #params then
			Tool.log("")
		end
	end
end)

command.default_data = {
	universe = "universe",
}

return command
