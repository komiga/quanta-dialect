
local U = require "togo.utility"
local T = require "Quanta.Time"
local O = require "Quanta.Object"
local Unit = require "Quanta.Unit"
local Entity = require "Quanta.Entity"
local Tracker = require "Quanta.Tracker"
local Vessel = require "Quanta.Vessel"
local Tool = require "Quanta.Tool"

local Stat = require "Bio.Stat"
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
					g = {
						name = name,
						actions = {},
					}
					t.groups[name] = g
					table.insert(t.groups, g)
				end
				table.insert(g.actions, action)
			end
		end
	end
end

local function print_stat(stat, left)
	local str = "__NIL__"
	if U.is_type(stat.item, "string") then
		str = stat.item
	elseif U.is_instance(stat.item, Unit) then
		local unit = stat.item
		local tmp_items = unit.items
		local tmp_parts = unit.parts
		unit.items = {}
		unit.parts = {}

		local obj = unit:to_object()
		str = O.write_text_string(obj, true)
		if unit.type == Unit.Type.composition then
			str = "<composition>" .. string.sub(str, 5)
		end

		unit.items = tmp_items
		unit.parts = tmp_parts
	end
	Tool.log("%s%s", string.rep(' ', left), str)
	for _, s in ipairs(stat.children) do
		print_stat(s, left + 2)
	end
end

local NotFoundModifier = U.class(NotFoundModifier)

function NotFoundModifier:__init()
end

function NotFoundModifier:from_object(context, ref, modifier, obj)
end

function NotFoundModifier:to_object(modifier, obj)
end

function NotFoundModifier:make_copy()
	return NotFoundModifier()
end

function NotFoundModifier:compare_equal(other)
	return true
end

local debug_thing_type_name = {
	[Entity] = "Entity",
	[Unit] = "Unit",
	[Unit.Element] = "Unit.Element",
}

local function debug_searcher_wrapper(name, searcher)
	return function(resolver, parent, unit)
		local thing, variant, terminate = searcher(resolver, parent, unit)
		U.print(
			"%12s %s %s $%d$%d => %s %s",
			name,
			unit.scope and date_to_string(unit.scope) or "____-__-__",
			unit.id,
			unit.source,
			unit.sub_source,
			thing ~= nil and "found" or "...",
			thing ~= nil and (debug_thing_type_name[U.type_class(thing)] or "<unknown type>") or ""
		)
		return thing, variant, terminate
	end
end

local function searcher_wrapper(name, searcher)
	return searcher
end

local function select_searcher(part)
	if part.type ~= Unit.Type.reference then
		return searcher_wrapper("child", Unit.Resolver.searcher_unit_child(part))
	else
		return searcher_wrapper("selector", Unit.Resolver.searcher_unit_selector(part))
	end
end

local command = Tool("diet", {}, {}, [=[
diet [ <date-or-range> [...] ]
  calculate nutrient intake stats

  -d: debug mode
]=],
function(self, parent, options, params)
	local function read_modifier(p)
		if p.name == "-d" then
			self.data.debug = true
			searcher_wrapper = debug_searcher_wrapper
		else
			return false
		end
		return true
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

	local tracker_cache = {}
	local function cache_tracker(t)
		U.assert(not t.tracker)
		t.date_str = date_to_string(t.date)
		t.tracker = Tracker()
		tracker_cache[T.value(t.date)] = t

		if not t.requested and self.data.debug then
			Tool.log("caching %s", t.date_str)
		end
		local success, msg, source_line = load_tracker(t.tracker, t.path, t.date_str)
		if not success then
			Tool.log_error("%s", msg)
			open_tracker_file_in_editor(t.path, source_line)
			return nil
		end

		t.local_units = t.tracker.attachments.units
		return t
	end

	local function scoped_unit_searcher(resolver, _, unit)
		local t = tracker_cache[T.value(unit.scope)]
		if not t then
			t = cache_tracker({
				date = T(unit.scope),
				path = Vessel.tracker_path(unit.scope)
			})
			U.assert(t ~= nil)
		end
		if t.local_units then
			return Unit.Resolver.searcher_unit_child_func(resolver, t.local_units.composition, unit)
		end
		return nil, nil, false
	end

	local not_found_modifier = Unit.Modifier("____NOT_FOUND____", nil, NotFoundModifier())
	local function resolve_and_mark(resolver, unit)
		local result = resolver:do_tree(unit)
		for _, p in ipairs(result.not_found) do
			table.insert(p.unit.modifiers, not_found_modifier)
		end
		return result
	end

	local search_branches = {
		Entity.make_search_branch(universe:search(nil, "food"), 0),
		Entity.make_search_branch(universe:search(nil, "drug"), 0),
		Entity.make_search_branch(universe, 0),
	}
	local resolver = Unit.Resolver(
		select_searcher,
		searcher_wrapper("scoped_unit", scoped_unit_searcher),
		nil
	)
	U.assert(resolver.scope_searcher ~= nil)
	resolver:push_searcher(searcher_wrapper("universe", Unit.Resolver.searcher_universe(universe, search_branches, nil)))

	Bio.resolve_func = function(unit)
		return resolve_and_mark(resolver, unit)
	end

	local obj = O.create()
	for _, t in ipairs(dates) do
		t.requested = true
		if not cache_tracker(t) then
			return false
		end

		Tool.log("------------ %s ------------", t.date_str)
		if t.local_units then
			resolver:push_searcher(searcher_wrapper("local", Unit.Resolver.searcher_unit_child(t.local_units.composition)))

			Tool.log("local:")
			for _, unit in ipairs(t.local_units.composition.items) do
				resolve_and_mark(resolver, unit)
				local text = O.write_text_string(unit:to_object(obj), true)
				text = string.gsub(text, "\t", "  ")
				text = string.gsub(text, "\n", "\n")
				Tool.log("%s\n", text)
			end
		end
		collect_actions(t)

		for _, g in ipairs(t.groups) do
			Tool.log("group %s:", g.name)
			for _, action in ipairs(g.actions) do
				resolve_and_mark(resolver, action.data.composition)

				local text = O.write_text_string(action.data.composition:to_object(obj), false)
				text = string.gsub(text, "\t", "  ")
				text = string.gsub(text, "\n", "\n  ")
				Tool.log("  %s", text)
			end
			Tool.log("")
		end
		if t.local_units then
			resolver:pop()
		end

		Tool.log("\nstats:")
		t.stat = Stat()
		for _, g in ipairs(t.groups) do
			g.stat = Stat(g.name)
			for _, action in ipairs(g.actions) do
				g.stat:add(action.data.composition)
			end
			t.stat:add(g.stat)
			print_stat(g.stat, 0)
		end
	end
end)

command.auto_read_options = false
command.default_data = {
	debug = false,
}

return command
