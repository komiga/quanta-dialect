
local U = require "togo.utility"
local O = require "Quanta.Object"
local Tracker = require "Quanta.Tracker"
local Tool = require "Quanta.Tool"
require "Dialect.Bio.Nutrition"

require "Tool.common"

local action_filter = {
	[Dialect.Bio.Nutrition.Eat] = true,
	[Dialect.Bio.Nutrition.Drugtake] = true,
}

local function collect_actions(t)
	t.actions = {}
	for _, entry in ipairs(t.tracker.entries) do
		for _, action in ipairs(entry.actions) do
			if action_filter[U.type_class(action.data)] then
				table.insert(t.actions, action)
			end
		end
	end
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

		collect_actions(t)
		Tool.log("%s:", date_str)
		for _, action in ipairs(t.actions) do
			local text = O.write_text_string(action:to_object(obj, false), true)
			text = string.gsub(text, "\t", "    ")
			text = string.gsub(text, "\n", "\n  ")
			Tool.log("  %s", text)
		end
	end
end)
command.auto_read_options = false

return command
