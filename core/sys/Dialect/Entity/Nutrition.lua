
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Composition = require "Quanta.Composition"
local Entity = require "Quanta.Entity"

local Dialect = require "Dialect"
local M = U.module(...)

local Nutrient = Dialect.make_entity(M, "Nutrient", function(class)

function class.Source:__init(source)
	self.nutrition = {}
end

class.Source.t_body:add({
Match.Pattern{
	name = "nutrition",
	children = true,
},
})

end)

Dialect.add_entity("Food", Nutrient)
Dialect.add_entity("Drug", Nutrient)

return M
