
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
		num_attachments = 0,
		num_entries = 0,
		num_actions = 0,
		attachments = {},
		attachments_ordered = {},
		actions = {},
		actions_ordered = {},
	}
end

local function accumulate_attachment(stats, id, id_hash, num)
	local node = stats.attachments[id_hash]
	if not node then
		node = {
			id = id,
			num = 0,
		}
		stats.attachments[id_hash] = node
		table.insert(stats.attachments_ordered, node)
	end
	node.num = node.num + num
	stats.num_attachments = stats.num_attachments + num
end

local function accumulate_action(stats, id, id_hash, num, duration)
	local node = stats.actions[id_hash]
	if not node then
		node = {
			id = id,
			num = 0,
			duration = 0,
		}
		stats.actions[id_hash] = node
		table.insert(stats.actions_ordered, node)
	end
	node.num = node.num + num
	node.duration = node.duration + duration
	stats.num_actions = stats.num_actions + num
end

local function accumulate(tracker, total, action_selection)
	local stats = make_stats()
	stats.num_days = 1
	total.num_days = total.num_days + 1
	stats.num_entries = #tracker.entries
	total.num_entries = total.num_entries + stats.num_entries

	for _, attachment in ipairs(tracker.attachments) do
		accumulate_attachment(stats, attachment.id, attachment.id_hash, 1)
	end
	for _, entry in ipairs(tracker.entries) do
		local entry_duration = T.value(entry.duration)
		for i, action in ipairs(entry.actions) do
			if not action_selection or action_selection[action.id_hash] then
				local duration
				if i ~= entry.primary_action then
					duration = math.ceil((entry_duration * 0.25) / #entry.actions)
				elseif #entry.actions > 1 then
					duration = math.floor(entry_duration * 0.75)
				else
					duration = entry_duration
				end
				accumulate_action(stats, action.id, action.id_hash, 1, duration)
			end
		end
	end

	for id_hash, node in pairs(stats.attachments) do
		accumulate_attachment(total, node.id, id_hash, node.num)
	end
	for id_hash, node in pairs(stats.actions) do
		accumulate_action(total, node.id, id_hash, node.num, node.duration)
	end
	return stats
end

local function node_order_num(x, y)
	return x.num > y.num
end

local function attachment_order_id(x, y)
	return x.id < y.id
end

local function action_order_duration(x, y)
	return x.duration > y.duration
end

local function action_order_duration_average(x, y)
	return (x.duration / x.num) > (y.duration / y.num)
end

local function print_stats(stats, action_sort_func)
	table.sort(stats.attachments_ordered, attachment_order_id)
	table.sort(stats.actions_ordered, action_sort_func)

	Tool.log(
		"  %4d days\n" ..
		"  %4d attachment classes\n" ..
		"  %4d action classes\n" ..
		"  %4d attachments  %.4f attachments/day\n" ..
		"  %4d entries      %.4f entries/day\n" ..
		"  %4d actions      %.4f actions/entry",
		stats.num_days,
		#stats.attachments_ordered,
		#stats.actions_ordered,

		stats.num_attachments,
		stats.num_attachments / stats.num_days,

		stats.num_entries,
		stats.num_entries / stats.num_days,

		stats.num_actions,
		stats.num_actions / stats.num_entries
	)

	Tool.log(
		"\n" ..
		"------------ attachments -------------\n" ..
		"   num  class                         \n" ..
		"--------------------------------------"
	)
	for _, node in ipairs(stats.attachments_ordered) do
		Tool.log(
			"  %4d  %s",
			node.num,
			node.id
		)
	end

	Tool.log(
		"\n" ..
		"-------------- actions ---------------\n" ..
		"   num    average : total      class  \n" ..
		"--------------------------------------"
	)
	local function hour_part(h)
		if h > 0 then
			return string.format("%4d:", h)
		end
		return "     "
	end
	local ht, mt, st
	local ha, ma, sa
	for _, node in ipairs(stats.actions_ordered) do
		sa = math.ceil(node.duration / node.num)
		ha = math.floor(sa / T.SECS_PER_HOUR)
		ma = math.floor((sa % T.SECS_PER_HOUR) / T.SECS_PER_MINUTE)
		sa = sa % T.SECS_PER_MINUTE

		st = node.duration
		ht = math.floor(st / T.SECS_PER_HOUR)
		mt = math.floor((st % T.SECS_PER_HOUR) / T.SECS_PER_MINUTE)
		st = st % T.SECS_PER_MINUTE
		Tool.log(
			"  %4d %s%02d:%02d : %s%02d:%02d %s",
			node.num,
			hour_part(ha, nil, true), ma, sa,
			hour_part(ht, nil, true), mt, st,
			node.id
		)
	end
end

local command = Tool("stats", {}, {}, [=[
stats [-t] [-a] [-i] [ <date-or-range> [...] ]
  calculate basic tracker statistics

  -t: sort actions by total duration
  -a: sort actions by average duration
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

	local sort_func = node_order_num
	if sort_by_duration then
		sort_func = action_order_duration
	elseif sort_by_duration_average then
		sort_func = action_order_duration_average
	end

	local tracker = Tracker()
	local total = make_stats()
	for _, t in ipairs(dates) do
		local date_str = date_to_string(t.date)
		local success, msg = load_tracker(tracker, t, date_str)
		if not success then
			return Tool.log_error(msg)
		end

		local stats = accumulate(tracker, total, nil)
		if print_individual then
			Tool.log("---------- %s -----------", date_str)
			print_stats(stats, sort_func)
			print()
		end
	end

	if not print_individual or #dates > 1 then
		Tool.log("--------------- total ----------------")
		print_stats(total, sort_func)
	end
end)
command.auto_read_options = false

return command
