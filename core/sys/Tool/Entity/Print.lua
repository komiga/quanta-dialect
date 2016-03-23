
local U = require "togo.utility"
local O = require "Quanta.Object"
local Tool = require "Quanta.Tool"
local Vessel = require "Quanta.Vessel"
local Entity = require "Quanta.Entity"

require "Tool.common"

local options = {
}

local function print_entity(entity)
	local obj = O.create()
	entity:to_object(obj)
	O.set_name(obj, entity:ref())

	local text = O.write_text_string(obj, true)
	text = string.gsub(text, "\t", "    ")
	Tool.log("%s", text)
end

local command = Tool("print", options, {}, [=[
print [<ref> ...]
  print entities
]=],
function(self, parent, options, params)
	if #params == 0 then
		Tool.log("no refs given")
		return
	end

	local universe, msg = Entity.read_universe(Vessel.data_path("entity/universe.q"))
	if not universe then
		return Tool.log_error(msg)
	end

	local branches = {
		Entity.make_search_branch(universe, math.huge),
	}

	local entities = {}
	for i, p in ipairs(params) do
		local ref = p.value
		local entity = universe:search(branches, ref)
		if not entity then
			return Tool.log_error("%s not found", ref)
		end
		table.insert(entities, entity)
	end

	for i, entity in ipairs(entities) do
		print_entity(entity)

		if i < #entities then
			Tool.log("")
		end
	end
end)

command.default_data = {}

return command
