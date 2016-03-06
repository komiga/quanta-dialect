
package.path = package.path .. [[;./?/?.lua]]

local U = require "togo.utility"
local Vessel = require "Quanta.Vessel"
local Director = require "Quanta.Director"

local Dialect = require "Dialect"

-- entities
require "Dialect.Entity.Nutrition"

-- tracker
require "Dialect.Attachment.Units"
require "Dialect.Bio.Nutrition"

require "tool/tracker"

Vessel.setup_config(function()
	director = Director()
	Dialect.register_dialect(director)
end)
