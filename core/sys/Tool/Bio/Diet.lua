
local U = require "togo.utility"
local O = require "Quanta.Object"
local Unit = require "Quanta.Unit"
local Entity = require "Quanta.Entity"
local Tracker = require "Quanta.Tracker"
local Vessel = require "Quanta.Vessel"
local Tool = require "Quanta.Tool"
require "Dialect.Bio.Nutrition"

require "Tool.common"

local action_filter = {
	[Dialect.Bio.Nutrition.Eat] = true,
	[Dialect.Bio.Nutrition.Drugtake] = true,
}

local function collect_actions(t)
	t.groups = {}
	for _, entry in ipairs(t.tracker.entries) do
		for _, action in ipairs(entry.actions) do
			if action_filter[U.type_class(action.data)] then
				local name = Dialect.Bio.Nutrition.group(action)
				local g = t.groups[name]
				if not g then
					g = {name = name, actions = {}}
					t.groups[name] = g
					table.insert(t.groups, g)
				end
				table.insert(g.actions, action)
			end
		end
	end
end

local NotFoundModifier = U.class(NotFoundModifier)

function NotFoundModifier:__init()
end

function NotFoundModifier:from_object(context, ref, modifier, obj)
end

function NotFoundModifier:to_object(modifier, obj)
end

function NotFoundModifier:compare_equal(other)
	return true
end

local command = Tool("diet", {}, {}, [=[
diet [ <date-or-range> [...] ]
  calculate nutrient intake stats
]=],
function(self, parent, options, params)
	local function read_modifier(p)
		return false
	end

	local dates = {}
	if not parse_dates(dates, options, params, read_modifier) then
		return false
	end
	if #dates == 0 then
		Tool.log("note: no dates")
		return true
	end

	local universe, msg = Entity.read_universe(Vessel.data_path("entity/u_nutrition.q"))
	if not universe then
		return Tool.log_error(msg)
	end

	local search_branches = {
		Entity.make_search_branch(universe, math.huge),
	}
	local resolver = Unit.Resolver(Unit.Resolver.select_searcher_default)
	resolver:push_searcher(Unit.Resolver.searcher_universe(universe, search_branches, nil))

	local not_found_modifier = Unit.Modifier("NF", nil, NotFoundModifier())
	local obj = O.create()
	for _, t in ipairs(dates) do
		t.tracker = Tracker()

		local date_str = date_to_string(t.date)
		local success, msg, source_line = load_tracker(t.tracker, t, date_str)
		if not success then
			Tool.log_error("%s", msg)
			open_tracker_file_in_editor(t.path, source_line)
			return false
		end

		if t.tracker.attachments.units then
			resolver:push_searcher(Unit.Resolver.searcher_unit_child(t.tracker.attachments.units.composition))
		end
		collect_actions(t)

		Tool.log("%s:", date_str)
		for _, g in ipairs(t.groups) do
			Tool.log(" group %s:", g.name)
			for _, action in ipairs(g.actions) do
				local result = resolver:do_tree(action.data.composition)
				for _, p in ipairs(result.not_found) do
					table.insert(p.unit.modifiers, not_found_modifier)
				end

				local text = O.write_text_string(action.data.composition:to_object(obj), false)
				text = string.gsub(text, "\t", "    ")
				text = string.gsub(text, "\n", "\n   ")
				Tool.log("   %s", text)
			end
		end
		if t.tracker.attachments.units then
			resolver:pop()
		end
	end

end)
command.auto_read_options = false

return command
