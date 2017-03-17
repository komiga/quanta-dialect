
local U = require "togo.utility"
local FS = require "togo.filesystem"
local IO = require "togo.io"
local O = require "Quanta.Object"
local T = require "Quanta.Time"
require "Quanta.Time.Gregorian"
local Tool = require "Quanta.Tool"
local Vessel = require "Quanta.Vessel"
local Tracker = require "Quanta.Tracker"

require "Tool.common"
local HamsterTracker = require "Tool.Utility.HamsterTracker"
local HamsterTranslator = require "Tool.Utility.HamsterTranslator"

local SQL

local options = {
Tool.Option({"-s", "--script"}, "string", [=[
-s=SCRIPT_PATH --script=SCRIPT_PATH
  pass translator to script to specialize translation

  e.g.,

	local translator, output_path, database_path = ...

    function translator.init(self)
    end

    function translator.do_entry(self, entry, fact, htr_action)
    end

    function translator.finish(self)
    end
]=],
function(tool, value)
	if value and not FS.is_file(value) then
		return Tool.log_error("script path does not exist or is not a file: %s", value)
	end
	tool.data.script_path = value
end),
}

local command = Tool("translate-hamster", options, {}, [=[
translate-hamster [options] <output_path> [database_path]
  translate Hamster database to Quanta
]=],
function(self, parent, options, params)
	do
		local success, m = pcall(require, "lsqlite3")
		if not success then
			return Tool.log_error("missing or failed to load LuaSQLite3 (lsqlite3):\n%s", m)
		end
		SQL = m
	end

	if #params == 0 then
		Tool.log("no output path given")
		return
	end

	local output_path = U.trim_trailing_slashes(params[1].value) .. "/"
	local database_path
	if #params > 1 then
		database_path = params[2].value
	else
		database_path = U.join_paths(os.getenv("HOME"), ".local/share/hamster-applet/")
	end
	if string.sub(database_path, #database_path) == "/" then
		database_path = database_path .. "hamster.db"
	end
	if not FS.is_file(database_path) then
		return Tool.log_error("database path does not exist or is not a file: %s", database_path)
	end

	local translator = HamsterTranslator()
	if self.data.script_path then
		Tool.log("loading translator script")
		local data = IO.read_file(self.data.script_path)
		if data == nil then
			return Tool.log_error("failed to read script: %s", self.data.script_path)
		end
		local chunk, err = load(data, "@" .. self.data.script_path, "t")
		if err then
			return Tool.log_error("failed to read script as Lua: %s\n%s", self.data.script_path, err)
		end
		chunk(translator, output_path, database_path)
	end

	--[[do
		Tool.log("translate database?")
		Tool.log("  from: %s", database_path)
		Tool.log("  to  : %s", output_path)
		Tool.log("y/n")
		local r = io.read("*l")
		if string.lower(string.sub(r, 1, 1)) ~= "y" then
			Tool.log("exiting")
			return
		end
	end--]]

	do
		local stubs = {
			"",
			"chrono",
		}
		for _, path in ipairs(stubs) do
			path = U.join_paths(output_path, path)
			-- Tool.log("stub: %s", path)
			if not FS.create_directory_whole(path, true) then
				return Tool.log_error("failed to create stub directory: %s", path)
			end
		end
	end

	Tool.log("loading database")
	local db = SQL.open(database_path)
	HamsterTracker.init_db_context(db)

	local htr = HamsterTracker()
	if not htr:load(db) then
		return Tool.log_error("failed to load Hamster tracker data")
	end
	if not htr:normalize() then
		return Tool.log_error("failed to normalize Hamster tracker data")
	end

	Tool.log("translating")
	if not translator:translate(htr) then
		return Tool.log_error("failed to translate Hamster tracker data")
	end
	Tool.log("writing trackers")
	if not translator:write_trackers(output_path) then
		return Tool.log_error("failed to write Quanta trackers")
	end

	--[[local tables = {}
	for tbl_name in db:urows("SELECT tbl_name FROM sqlite_master WHERE type='table'") do
		if not string.find(tbl_name, "fact_index_seg") then
			table.insert(tables, tbl_name)
		end
	end
	
	for _, tbl_name in ipairs(tables) do
		local num_rows = get_single_result(db:urows(string.format("SELECT Count(*) FROM '%s'", tbl_name)))
		U.print("table %s (%d):", tbl_name, num_rows)
		local columns = {}
		for r in db:nrows(string.format("PRAGMA table_info('%s')", tbl_name)) do
			table.insert(columns, r)
		end
		for _, r in ipairs(columns) do
			io.write(U.pad_right(string.format(" %s ", (#r.type > 0) and r.type or "<any>"), 24))
		end
		print()

		local q = ""
		for i, r in ipairs(columns) do
			io.write(U.pad_right(string.format(" %s ", r.name), 24))
			if r.type == "timestamp" then
				q = q .. string.format("strftime('%%s', %s)", r.name)
			else
				q = q .. r.name
			end
			if i < #columns then
				q = q .. ", "
			end
		end
		print()

		q = string.format("SELECT %s FROM %s LIMIT 10", q, tbl_name)
		for r in db:rows(q) do
			for _, c in pairs(r) do
				c = string.gsub(c, "\n", "\n   ")
				io.write(U.pad_right(string.format(" %s ", c), 24))
			end
			print()
		end
		print()
	end--]]

	--[[Tool.log("activities:")
	for _, c in pairs(htr.categories) do
		Tool.log("category  %3d = %s", c.id, c.name)
		for _, a in pairs(c.activities) do
			Tool.log("  activity  %3d = %s", a.id, a.name)
		end
		print()
	end

	Tool.log("tags:")
	for _, t in pairs(htr.tags) do
		Tool.log("  %3d = %s", t.id, t.name)
	end--]]

	--[[print("facts:")
	local obj = O.create()
	for _, f in ipairs(htr.facts_list) do
		O.set_time(obj, f.r_start)
		-- O.set_zoned(obj, false)
		local r_start = O.write_text_string(obj, true)

		O.set_time(obj, f.r_end)
		-- O.set_zoned(obj, false)
		local r_end = O.write_text_string(obj, true)

		local a = htr.activities[f.activity_id]
		Tool.log(
			"  fact  %6d %s %s  %s `%s`",
			f.id, r_start, r_end,
			U.pad_right(a and a.name or "-- INVALID ACTIVITY --", 32),
			f.description
		)
	end--]]

	db:close()
end)

command.default_data = {
	script_path = nil,
}

return command
