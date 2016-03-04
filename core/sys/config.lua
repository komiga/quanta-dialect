
local U = require "togo.utility"
local Vessel = require "Quanta.Vessel"
local Tracker = require "Quanta.Tracker"
local Director = require "Quanta.Director"

local Dialect = require "Dialect"
require "Dialect.Bio.Nutrition"

require "tool/tracker"

Vessel.setup_config(function()
	director = Director()
	Dialect.register_actions(director)
end)
