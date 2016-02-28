
local U = require "togo.utility"
local Vessel = require "Quanta.Vessel"
local Tracker = require "Quanta.Tracker"
local Director = require "Quanta.Director"

Vessel.setup_config(function()
	director = Director()
	director:register_action("ETODO", Tracker.PlaceholderAction)
end)

require "tool/tracker"
