
local U = require "togo.utility"
local T = require "Quanta.Time"
require "Quanta.Time.Gregorian"
local O = require "Quanta.Object"

local M = U.module(...)

M.Category = U.class(M.Category)
M._hamster_object_name = "Category"

function M.Category:__init(id, name)
	self.id = U.type_assert(id, "number")
	self.name = U.type_assert(name, "string")

	self.activities = {}
end

M.Activity = U.class(M.Activity)
M._hamster_object_name = "Activity"

function M.Activity:__init(id, name, category_id)
	self.id = U.type_assert(id, "number")
	self.name = U.type_assert(name, "string")
	self.category_id = U.type_assert(category_id, "number", true)
	if self.category_id == -1 then
		self.category_id = nil
	end
end

M.Tag = U.class(M.Tag)
M._hamster_object_name = "Tag"

function M.Tag:__init(id, name)
	self.id = U.type_assert(id, "number")
	self.name = U.type_assert(name, "string")
end

M.Fact = U.class(M.Fact)
M._hamster_object_name = "Fact"

function M.Fact:__init(id, activity_id, r_start, r_end, description, tag_ids)
	self.id = U.type_assert(id, "number", true)
	self.activity_id = U.type_assert(activity_id, "number", true)
	self.r_start = T.from_posix(r_start)
	self.r_end = T.from_posix(r_end)
	self.description = U.type_assert(description, "string", true)
	self.tag_ids = U.type_assert(tag_ids, "table", true) or {}
end

U.class(M)

function M:__init()
	self.categories = {}
	self.activities = {}
	self.facts_key = {}
	self.facts_list = {}
	self.tags = {}
	self.tz_ranges = {}

	self.categories[-1] = M.Category(-1, "-- NO CATEGORY --")
end

function M.init_db_context(db)
	db:create_function("Q_unix_to_integer", 1, function(ctx, sec)
		sec = tonumber(sec) or 0
		ctx:result_int(sec)
	end)
end

local QUERY_CATEGORIES = [[
SELECT
	id,
	name
FROM categories
]]

local QUERY_ACTIVITIES = [[
SELECT
	id,
	name,
	category_id
FROM activities
]]

local QUERY_TAGS = [[
SELECT
	id,
	name
FROM tags
]]

local QUERY_FACTS = [[
SELECT
	id,
	activity_id,
	Q_unix_to_integer(strftime('%s', start_time)),
	Q_unix_to_integer(strftime('%s', end_time)),
	description
FROM facts
]]

local QUERY_FACT_TAGS = [[
SELECT
	fact_id,
	tag_id
FROM fact_tags
]]

local function build_from_result(handler, id, ...)
	if not id then
		return false
	end
	return handler(id, ...)
end

local function build_from_results(db, handler, query)
	local iter, iter_ud = db:urows(query)
	local ec = db:error_code()
	if ec ~= 0 then
		U.log("SQL error: %d - %s", ec, db:error_message())
		return false
	end
	while build_from_result(handler, iter(iter_ud)) ~= false do end
	return true
end

local function add_key(c, k)
	return function(...)
		local obj = c(...)
		if k[obj.id] ~= nil then
			U.log("warning: non-unique %s id: %d", getmetatable(obj)._hamster_object_name, obj.id)
		end
		k[obj.id] = obj
	end
end

local function add_key_order(c, k, l)
	return function(...)
		local obj = c(...)
		if k[obj.id] ~= nil then
			U.log("warning: non-unique %s id: %d", getmetatable(obj)._hamster_object_name, obj.id)
		end
		k[obj.id] = obj
		table.insert(l, obj)
	end
end

local function add_fact_tag(self)
	return function(fact_id, tag_id)
		local fact = self.facts_key[fact_id]
		if not fact then
			U.log("warning: adding tag %6d to %6d: fact does not exist", tag_id, fact_id)
			return
		end
		if not self.tags[tag_id] then
			U.log("warning: adding tag %6d to %6d: tag does not exist", tag_id, fact_id)
			return
		end
		for _, fact_tag_id in ipairs(fact.tag_ids) do
			if tag_id == fact_tag_id then
				return
			end
		end
		table.insert(fact.tag_ids, tag_id)
	end
end

function M:load(db)
	if not build_from_results(db, add_key(M.Category, self.categories), QUERY_CATEGORIES) then
		return false
	end
	if not build_from_results(db, add_key(M.Activity, self.activities), QUERY_ACTIVITIES) then
		return false
	end
	if not build_from_results(db, add_key(M.Tag, self.tags), QUERY_TAGS) then
		return false
	end
	if not build_from_results(db, add_key_order(M.Fact, self.facts_key, self.facts_list), QUERY_FACTS) then
		return false
	end
	if not build_from_results(db, add_fact_tag(self), QUERY_FACT_TAGS) then
		return false
	end
	return true
end

local THREE_MINUTES = (3 * T.SECS_PER_MINUTE)

function M:normalize()
	for _, a in pairs(self.activities) do
		local c = self.categories[a.category_id or -1]
		if c then
			c.activities[a.id] = a
		elseif a.category_id then
			U.log(
				"warning: category %d, referenced by activity %d ('%s'), does not exist",
				a.category_id,
				a.id,
				a.name
			)
		end
	end

	for _, tag in ipairs(self.tags) do
	end

	-- NB: updating a fact in Hamster replaces the record with a brand new
	-- one -- at the end of the table
	table.sort(self.facts_list, function(a, b)
		return T.compare_less(a.r_start, b.r_start)
	end)

	for i, fa in ipairs(self.facts_list) do
		-- NB: seconds are kept for natural facts, but they are truncated
		-- when a fact's range is modified manually
		local fb = self.facts_list[i + 1]
		if not fb then
			goto l_continue
		end

		local diff = T.difference(fa.r_end, fb.r_start)
		local diff_abs = math.abs(diff)
		if 0 < diff_abs and diff_abs <= THREE_MINUTES then
			--[[U.log(
				"patching segment:\n %6d %s - %s\n %6d %s - %s",
				fa.id,
				time_to_string(fa.r_start, O.TimeType.clock),
				time_to_string(fa.r_end, O.TimeType.clock),

				fb.id,
				time_to_string(fb.r_start, O.TimeType.clock),
				time_to_string(fb.r_end, O.TimeType.clock)
			)--]]

			local a_sec = T.second_utc(fa.r_end)
			local b_sec = T.second_utc(fb.r_start)
			if a_sec > 0 then
				T.set(fb.r_start, fa.r_end)
			elseif b_sec > 0 then
				T.set(fa.r_end, fb.r_start)
			elseif diff > 0 then
				T.set(fb.r_start, fa.r_end)
			else
				T.set(fa.r_end, fb.r_start)
			end
		end
	::l_continue::
	end

	return true
end

return M
