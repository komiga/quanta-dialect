
local U = require "togo.utility"
local Vessel = require "Quanta.Vessel"
local Director = require "Quanta.Director"

Vessel.export("?/module.lua")

local Dialect = require "Dialect"

-- entities
require "Dialect.Entity.Chemical"
require "Dialect.Entity.Nutrition"
require "Dialect.Entity.Account"

-- tracker
require "Dialect.Attachment.Units"
require "Dialect.Bio.Nutrition"
require "Dialect.Utility.HamsterEntry"

-- tools
require "Tool.Entity"
require "Tool.Account"
require "Tool.Tracker"
require "Tool.Bio"
require "Tool.Utility"

Vessel.setup_config(function(_ENV)
	director = Dialect.director
end)
