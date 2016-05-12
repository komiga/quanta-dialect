
package.path = package.path .. [[;./?/module.lua]]

local U = require "togo.utility"
local Vessel = require "Quanta.Vessel"
local Director = require "Quanta.Director"

local Dialect = require "Dialect"

-- entities
require "Dialect.Entity.Chemical"
require "Dialect.Entity.Nutrition"
require "Dialect.Entity.Account"

-- tracker
require "Dialect.Attachment.Units"
require "Dialect.Bio.Nutrition"

-- tools
require "Tool.Entity"
require "Tool.Account"
require "Tool.Tracker"
require "Tool.Bio"

Vessel.setup_config(function()
	director = Dialect.director
end)
