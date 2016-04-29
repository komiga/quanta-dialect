
local U = require "togo.utility"
local Tool = require "Quanta.Tool"
local Vessel = require "Quanta.Vessel"
local Entity = require "Quanta.Entity"

require "Tool.common"

local options = {
Tool.Option("-h", "boolean", [=[
-h
  print as a hierarchy
]=],
function(tool, value)
	tool.data.hierarchy = value
end),

Tool.Option({"-u", "--universe"}, "string", [=[
-u=UNIVERSE_NAME --universe=UNIVERSE_NAME
  print as a hierarchy
]=],
function(tool, value)
	tool.data.universe = value
end),
}

local function make_stats()
	return {
		num_by_type = {0, 0, 0},
		num_specialized = 0,
		num_sources = 0,
		num_sub_sources = 0,
		num_total = 0,
	}
end

local function do_stats(stats, e)
	stats.num_by_type[e.type] = stats.num_by_type[e.type] + 1
	if e:is_specialized() then
		stats.num_specialized = stats.num_specialized + 1
	end
	for _, source in ipairs(e.generic.sources) do
		stats.num_sub_sources = stats.num_sub_sources + #source.sources
	end
	stats.num_sources = stats.num_sources + #e.generic.sources
	stats.num_total = stats.num_total + 1
end

local function print_stats(stats)
	Tool.log("\n--------------- stats ----------------")
	Tool.log(" %4d universes", stats.num_by_type[Entity.Type.universe])
	Tool.log(" %4d categories", stats.num_by_type[Entity.Type.category])
	Tool.log(" %4d things", stats.num_by_type[Entity.Type.thing])
	Tool.log("    %4d sources", stats.num_sources)
	Tool.log("    %4d sub-sources", stats.num_sub_sources)
	Tool.log(" %4d total", stats.num_total)
	Tool.log("    %4d specialized", stats.num_specialized)
	Tool.log("    %4d generic", stats.num_total - stats.num_specialized)
end

local function non_empty_string_or_nil(str)
	return str ~= "" and str or nil
end

local function describe_author(a)
	return a and (
		non_empty_string_or_nil(a.name) or
		non_empty_string_or_nil(a.address)
	)
end

local function describe_source(s)
	return s and (
		non_empty_string_or_nil(s.description) or
		non_empty_string_or_nil(s.label) or
		describe_author(s.author[1]) or
		describe_author(s.vendor[1])
	)
end

local function left_column(left, i, p)
	return U.pad_left(U.pad_right(left, #left + i), p)
end

local function print_hierarchy(stats, root)
	local function do_branch(e, i)
		do_stats(stats, e)

		Tool.log(
			" %s %s \"%s\"",
			entity_type_shorthand(e),
			left_column(e.name, i, 56),
			describe_source(e.generic) or ""
		)
		if e:any_sources() then
			for n, s in ipairs(e.generic.sources) do
				Tool.log(
					"  S %s \"%s\"",
					left_column(tostring(n), i, 55),
					describe_source(s) or ""
				)
				for sub_n, sub_s in ipairs(s.sources) do
					Tool.log(
						"   S %s \"%s\"",
						left_column(tostring(sub_n), i, 54),
						describe_source(sub_s) or ""
					)
				end
			end
		end

		i = i + 1
		for _, s in pairs(e.children) do
			do_branch(s, i)
		end
	end

	Tool.log(
		"%s %-12s  %s",
		entity_type_shorthand(root),
		root.id or "",
		root.parent and root:ref() or root.name
	)
	do_stats(stats, root)
	for _, c in pairs(root.children) do
		do_branch(c, 0)
	end
end

local function print_list(stats, root)
	local parts = {}
	if root.parent then
		table.insert(parts, root:ref())
	end

	local function do_branch(e)
		do_stats(stats, e)

		table.insert(parts, e.name)
		Tool.log(
			" %2s %s %-12s  %s",
			#e.generic.sources > 0 and tostring(#e.generic.sources) or "",
			entity_type_shorthand(e),
			e.id or "",
			table.concat(parts, '.')
		)

		for _, c in pairs(e.children) do
			do_branch(c)
		end
		table.remove(parts)
	end

	Tool.log(
		"%s %-12s  %s",
		entity_type_shorthand(root),
		root.id or "",
		root.parent and root:ref() or root.name
	)
	do_stats(stats, root)
	for _, c in pairs(root.children) do
		do_branch(c)
	end
end

local command = Tool("list", options, {}, [=[
list [-h] [<ref> ...]
  list entities
]=],
function(self, parent, options, params)
	local universe, msg = Entity.read_universe(Vessel.data_path("entity/" .. self.data.universe .. ".q"))
	if not universe then
		return Tool.log_error(msg)
	end

	local branches = {
		Entity.make_search_branch(universe, math.huge),
	}

	local roots = {}
	if #params == 0 then
		table.insert(roots, universe)
	else
		for i, p in ipairs(params) do
			local ref = p.value
			local root = universe:search(branches, ref)
			if not root then
				return Tool.log_error("%s not found", ref)
			end
			table.insert(roots, root)
		end
	end

	local stats = make_stats()
	for i, root in ipairs(roots) do
		if self.data.hierarchy then
			print_hierarchy(stats, root)
		else
			print_list(stats, root)
		end

		if i < #roots then
			Tool.log("")
		end
	end
	print_stats(stats)
end)

command.default_data = {
	hierarchy = false,
	universe = "universe",
}

return command
