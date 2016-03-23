
local U = require "togo.utility"
local FS = require "togo.filesystem"
local T = require "Quanta.Time"
require "Quanta.Time.Gregorian"
local O = require "Quanta.Object"
local Vessel = require "Quanta.Vessel"
local Tracker = require "Quanta.Tracker"
local Tool = require "Quanta.Tool"

require "Tool.common"

local command = Tool("validate", {}, {}, [=[
validate [-h] [-e] [-p] [-o] [ <date-or-range> [...] ]
  validate for basic tracker data errors

  -h: halt at the first validation error
  -p: print tracker
  -e: print tracker only on error
  -o: open tracker on error

  default: active
]=],
function(self, parent, options, params)
	local halt = false
	local print_always = false
	local print_error = false
	local open_on_error = false
	local function read_modifier(p)
		if p.name == "-h" then
			halt = true
		elseif p.name == "-p" then
			print_always = true
		elseif p.name == "-e" then
			print_error = true
		elseif p.name == "-o" then
			open_on_error = true
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

	local obj = O.create()
	local tracker = Tracker()
	for _, t in ipairs(dates) do
		local date_str = date_to_string(t.date)
		local success, msg, source_line = load_tracker(tracker, t, date_str)
		if print_always or (not success and print_error) then
			tracker:to_object(obj)
			Tool.log("\n%s", O.write_text_string(obj, true))
		end
		if success then
			Tool.log("%s is valid", date_str)
		else
			Tool.log_error("%s", msg)
			if open_on_error then
				open_tracker_file_in_editor(t.path, source_line)
			end
			if halt then
				return false
			end
		end
	end
end)
command.auto_read_options = false

return command
