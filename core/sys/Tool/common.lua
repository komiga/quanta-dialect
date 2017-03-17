
local U = require "togo.utility"
local FS = require "togo.filesystem"
local T = require "Quanta.Time"
require "Quanta.Time.Gregorian"
local O = require "Quanta.Object"
local Vessel = require "Quanta.Vessel"
local Tool = require "Quanta.Tool"

local entity_type_shorthands = {"T", "C", "U"}

function entity_type_shorthand(entity)
	return entity_type_shorthands[entity.type]
end

function entity_class_name(entity)
	return entity.id or "Generic"
end

-- call iterator once
function get_single_result(f, ...)
	return f(...)
end

function time_to_string(t, time_type, zoned)
	local obj = O.create()
	O.set_time_value(obj, t)
	O.set_time_type(obj, time_type or O.TimeType.date)
	O.set_zoned(obj, zoned or false)
	return O.write_text_string(obj, true)
end

function load_tracker(tracker, path, date_str)
	local obj = O.create()
	if O.read_text_file(obj, path, true) then
		local success, msg, source_line = tracker:from_object(obj)
		if success then
			return true
		else
			return false, string.format("%s\n!! %s is malformed !!", msg, date_str), source_line
		end
	else
		return false, string.format("failed to read tracker: %s", path)
	end
end

function open_tracker_file_in_editor(path, source_line)
	os.execute(string.format([[sbt2 "%s:%d"]], path, source_line or 0))
end

function parse_dates(dates, options, params, read_modifier)
	if #params == 0 then
		table.insert(params, {value = "active"})
	end
	for _, p in ipairs(options) do
		table.insert(params, 1, p)
	end

	local i = 1
	while i <= #params do
		local p = params[i]
		if p.value == "-" then
			if i == 1 then
				return Tool.log_error("incomplete date range: no start date")
			elseif i == #params then
				return Tool.log_error("incomplete date range: no end date")
			end
			local r_end = params[i + 1].value
			local r_start = params[i - 1].value
			table.remove(params, i + 1)
			table.remove(params, i - 1)
			p.value = r_start .. " - " .. r_end
			i = i - 1
		end
		i = i + 1
	end

	--[[U.print("[%s] %d params:", self.name, #params)
	for _, p in pairs(params) do
		U.print("  %s%s", p.name and (p.name .. " = ") or "", p.value)
	end--]]

	local t_now = T()
	T.set_date_now(t_now)
	local t_previous = T(Vessel.tracker_active_date())
	T.sub(t_previous, T.SECS_PER_DAY)

	local function fixup_date(obj)
		if O.is_identifier(obj) then
			local str = O.identifier(obj)
			if str == "previous" then
				return T(t_previous)
			elseif str == "active" then
				return Vessel.tracker_active_date()
			elseif str == "now" then
				return T(t_now)
			end
		elseif O.is_time(obj) then
			local date = O.time_resolved(obj, t_now)
			T.clear_clock(date)
			T.adjust_zone_utc(date)
			return date
		end
		return nil
	end

	local EXPAND_NONE = 0
	local EXPAND_YEAR = 1
	local EXPAND_MONTH = 2

	local expand_opt = EXPAND_NONE
	local dates_keyed = {}
	local function add_range(r_start, r_end, nonexist_passive)
		if not r_end then
			r_end = T(r_start)
		end
		local value
		repeat
			value = T.value(r_start)
			if not dates_keyed[value] then
				local path = Vessel.tracker_path(r_start)
				if FS.is_file(path) then
					table.insert(dates, {
						date = T(r_start),
						path = path
					})
				elseif not nonexist_passive then
					Tool.log_error("%s does not exist", time_to_string(r_start))
				end
				dates_keyed[value] = true
			end
			T.add(r_start, T.SECS_PER_DAY)
		until T.difference(r_start, r_end) > 0
	end
	local function add_year(context, nonexist_passive)
		local y, m, d = T.G.date(context)
		local r_start = T(context)
		local r_end = T(context)
		T.G.set(r_start, y, 1, 1)
		T.G.set(r_end, y + 1, 1, 0)
		add_range(r_start, r_end, nonexist_passive)
	end
	local function add_month(context, nonexist_passive)
		local y, m, d = T.G.date(context)
		local r_start = T(context)
		local r_end = T(context)
		T.G.set(r_start, y, m, 1)
		T.G.set(r_end, y, m + 1, 0)
		add_range(r_start, r_end, nonexist_passive)
	end

	local obj = O.create()
	for _, p in ipairs(params) do
		if p.name then
			if p.name == "-m" then
				expand_opt = EXPAND_MONTH
			elseif p.name == "-y" then
				expand_opt = EXPAND_YEAR
			elseif not read_modifier(p) then
				return Tool.log_error("unrecognized modifier: %s = %s", p.name, p.value)
			end
			goto l_continue
		end

		if not O.read_text_string(obj, p.value, true) then
			return Tool.log_error("failed to parse parameter: %s", p.value)
		end
		local single = fixup_date(obj)
		if single then
			if expand_opt == EXPAND_YEAR then
				add_year(single, true)
			elseif expand_opt == EXPAND_MONTH then
				add_month(single, true)
			else
				add_range(single, nil, false)
			end
		elseif O.is_identifier(obj) then
			local str = O.identifier(obj)
			if str == "year" then
				add_year(t_now, true)
			elseif str == "month" then
				add_month(t_now, true)
			else
				return Tool.log_error("parameter not recognized: %s", p.value)
			end
		elseif O.is_expression(obj) then
			if O.num_children(obj) ~= 2 then
				return Tool.log_error("invalid date range: %s", p.value)
			end
			local r_start_obj = O.child_at(obj, 1)
			local r_end_obj = O.child_at(obj, 2)
			if O.op(r_end_obj) ~= O.Operator.sub then
				return Tool.log_error("expression is not a range: %s", p.value)
			end
			local r_start = fixup_date(r_start_obj)
			local r_end = fixup_date(r_end_obj)
			if not r_start or not r_end then
				return Tool.log_error("range does not consist of a start and end date: %s", p.value)
			end
			if T.difference(r_end, r_start) < 0 then
				return Tool.log_error("date range is negative: %s", p.value)
			end
			add_range(r_start, r_end, true)
		else
			return Tool.log_error("parameter not recognized: %s", p.value)
		end

		expand_opt = EXPAND_NONE
		::l_continue::
	end

	--[[U.print("%d dates:", #dates)
	for _, p in ipairs(dates) do
		U.print("  %s", time_to_string(p.date))
	end--]]

	return true
end
