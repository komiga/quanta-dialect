
local U = require "togo.utility"
local FS = require "togo.filesystem"
local T = require "Quanta.Time"
require "Quanta.Time.Gregorian"
local O = require "Quanta.Object"
local Vessel = require "Quanta.Vessel"
local Tracker = require "Quanta.Tracker"

local HamsterTracker = require "Tool.Utility.HamsterTracker"

local M = U.module(...)

U.class(M)

function f_default_init(self)
end

function f_default_do_entry(self, entry, fact, htr_action)
	table.insert(entry.actions, htr_action)
end

function f_default_finish(self)
end

function M:__init(init, do_entry, finish)
	self.trackers = {}
	self.entries = {}
	self.init = U.type_assert(init, "function", true) or f_default_init
	self.do_entry = U.type_assert(do_entry, "function", true) or f_default_do_entry
	self.finish = U.type_assert(finish, "function", true) or f_default_finish
end

local function empty_string_to_nil(s)
	return s and (#s > 0 and s or nil) or nil
end

function M:translate(htr)
	-- TODO: Quanta: control whether seconds are specified (for building
	-- Quanta tracker entries)
	U.type_assert(htr, HamsterTracker)
	self.htr = htr
	if self:init() == false then
		return false
	end

	for i, fact in ipairs(htr.facts_list) do
		local entry = Tracker.Entry()
		entry.r_start.type = Tracker.EntryTime.Type.specified
		entry.r_end.type = Tracker.EntryTime.Type.specified
		T.set(entry.r_start.time, fact.r_start)
		T.set(entry.r_end.time, fact.r_end)

		local next_fact = htr.facts_list[i + 1]
		if next_fact and T.compare_equal(fact.r_end, next_fact.r_start) then
			entry.r_end.type = Tracker.EntryTime.Type.ref
			entry.r_end.index = 1
		end

		local activity = htr.activities[fact.activity_id]
		local category = htr.categories[activity.category_id]
		local tags = {}
		for _, tag_id in ipairs(fact.tag_ids) do
			local tag = htr.tags[tag_id]
			if tag then
				table.insert(tags, tag.name)
			end
		end

		local htr_action = Vessel.config.director:create_action(
			"HamsterEntry",
			empty_string_to_nil(activity.name),
			empty_string_to_nil(fact.description),
			tags
		)
		if self:do_entry(entry, fact, htr_action) == false then
			return false
		end
		entry:fixup()
		table.insert(self.entries, entry)
	end

	if self:finish() == false then
		return false
	end
	return true
end

function M:write_trackers(output_path)
	U.type_assert(output_path, "string")
	output_path = U.join_paths(output_path, "chrono")

	if #self.trackers == 0 and #self.entries > 0 then
		-- naïvely slice trackers out of available entries
		local scope = self.entries[1]
		local st = 0
		local tracker
		for _, entry in ipairs(self.entries) do
			local t = T.value(entry.r_start.time)
			t = t - (t % T.SECS_PER_DAY)
			if not scope or t ~= st then
				scope = entry
				st = t
				tracker = Tracker()
				T.set(tracker.date, scope.r_start.time)
				table.insert(self.trackers, tracker)
			end
			table.insert(tracker.entries, entry)
		end
	end

	local obj = O.create()
	for _, tracker in ipairs(self.trackers) do
		tracker:to_object(obj)
		local path = U.join_paths(output_path, string.format("%04d/%02d/%02d.q", T.G.date_utc(tracker.date)))
		if not FS.create_directory_whole(U.path_dir(path)) then
			U.log(
				"failed to write tracker %s - %s file: %s",
				time_to_string(tracker.entries[1].r_start.time),
				time_to_string(tracker.entries[#tracker.entries].r_end.time),
				path
			)
		end
		if not O.write_text_file(obj, path, true) then
			U.log(
				"failed to write tracker %s - %s file: %s",
				time_to_string(tracker.entries[1].r_start.time),
				time_to_string(tracker.entries[#tracker.entries].r_end.time),
				path
			)
			return false
		end
	end
	return true
end

return M
