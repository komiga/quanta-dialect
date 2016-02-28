
local U = require "togo.utility"
local FS = require "togo.filesystem"
local T = require "Quanta.Time"
require "Quanta.Time.Gregorian"
local O = require "Quanta.Object"
local Vessel = require "Quanta.Vessel"
local Tracker = require "Quanta.Tracker"
local Tool = require "Quanta.Tool"

require "tool/common"

local function make_stats()
	return {
		num_days = 0,
		num_entries = 0,
		num_actions = 0,
		action_sums = {},
		action_sums_ordered = {},
	}
end

local function accumulate_action(stats, id, id_hash, num, duration)
	local id_sum = stats.action_sums[id_hash]
	if not id_sum then
		id_sum = {
			id = id,
			num = 0,
			duration = 0,
		}
		stats.action_sums[id_hash] = id_sum
		table.insert(stats.action_sums_ordered, id_sum)
	end
	id_sum.num = id_sum.num + num
	id_sum.duration = id_sum.duration + duration
end

local function accumulate(tracker, total, selection)
	local stats = make_stats()
	for _, entry in ipairs(tracker.entries) do
		local entry_duration = T.value(entry.duration)
		for i, action in ipairs(entry.actions) do
			if not selection or selection[action.id_hash] then
				local duration
				if i ~= entry.primary_action then
					duration = math.ceil((entry_duration * 0.25) / #entry.actions)
				elseif #entry.actions > 1 then
					duration = math.floor(entry_duration * 0.75)
				else
					duration = entry_duration
				end
				accumulate_action(stats, action.id, action.id_hash, 1, duration)
				stats.num_actions = stats.num_actions + 1
			end
		end
		stats.num_entries = stats.num_entries + 1
	end
	for id_hash, id_sum in pairs(stats.action_sums) do
		accumulate_action(total, id_sum.id, id_hash, id_sum.num, id_sum.duration)
	end
	stats.num_days = 1

	total.num_actions = total.num_actions + stats.num_actions
	total.num_entries = total.num_entries + stats.num_entries
	total.num_days = total.num_days + 1
	return stats
end

local function action_sum_order_duration(x, y)
	return x.duration > y.duration
end

local function action_sum_order_duration_average(x, y)
	return (x.duration / x.num) > (y.duration / y.num)
end

local function action_sum_order_num(x, y)
	return x.num > y.num
end

local function print_stats(stats, sort_func)
	table.sort(stats.action_sums_ordered, sort_func)
	Tool.log(
		"  %4d days\n" ..
		"  %4d action classes\n" ..
		"  %4d entries  %3.4f entries/day\n" ..
		"  %4d actions    %0.4f actions/entry\n" ..
		"-------------------------------------\n" ..
		"   num  average : total      class\n" ..
		"-------------------------------------",
		stats.num_days,
		#stats.action_sums_ordered,

		stats.num_entries,
		stats.num_entries / stats.num_days,

		stats.num_actions,
		stats.num_actions / stats.num_entries
	)

	local function hour_part(h)
		if h > 0 then
			return string.format("%4d:", h)
		end
		return "     "
	end
	local ht, mt, st
	local ha, ma, sa
	for _, id_sum in ipairs(stats.action_sums_ordered) do
		sa = math.ceil(id_sum.duration / id_sum.num)
		ha = math.floor(sa / T.SECS_PER_HOUR)
		ma = math.floor((sa % T.SECS_PER_HOUR) / T.SECS_PER_MINUTE)
		sa = sa % T.SECS_PER_MINUTE

		st = id_sum.duration
		ht = math.floor(st / T.SECS_PER_HOUR)
		mt = math.floor((st % T.SECS_PER_HOUR) / T.SECS_PER_MINUTE)
		st = st % T.SECS_PER_MINUTE
		Tool.log(
			"  %4d %s%02d:%02d : %s%02d:%02d %s",
			id_sum.num,
			hour_part(ha, nil, true), ma, sa,
			hour_part(ht, nil, true), mt, st,
			id_sum.id
		)
	end
end

local command = Tool("stats", {}, {}, [=[
stats [-t] [-a] [-i] [ <date-or-range> [...] ]
  calculate basic tracker statistics

  -t: sort by total duration
  -a: sort by average duration
  -i: show individual tracker statistics

  default: active
]=],
function(self, parent, options, params)
	local sort_by_duration = false
	local sort_by_duration_average = false
	local print_individual = false
	local function read_modifier(p)
		if p.name == "-t" then
			sort_by_duration = true
		elseif p.name == "-a" then
			sort_by_duration_average = true
		elseif p.name == "-i" then
			print_individual = true
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

	local sort_func = action_sum_order_num
	if sort_by_duration then
		sort_func = action_sum_order_duration
	elseif sort_by_duration_average then
		sort_func = action_sum_order_duration_average
	end

	local tracker = Tracker()
	local total = make_stats()
	for _, t in ipairs(dates) do
		local date_str = date_to_string(t.date)
		local success, msg = load_tracker(tracker, t, date_str)
		if not success then
			return Tool.log_error(msg)
		end

		local stats = accumulate(tracker, total)
		if print_individual then
			Tool.log("== %s ==", date_str)
			print_stats(stats, sort_func)
			print()
		end
	end

	if not print_individual or #dates > 1 then
		Tool.log("== total ==")
		print_stats(total, sort_func)
	end
end)
command.auto_read_options = false

return command
