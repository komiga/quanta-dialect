
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Entity = require "Quanta.Entity"

local Dialect = require "Dialect"
local M = U.module(...)

local Nutrient = Dialect.make_entity(M, "Nutrient", function(class)

function class.Source:__init(source)
	self.nutrition = {}
end

-- TODO

class.Source.t_body:add({
Match.Pattern{
	name = "nutrition",
	children = true,
},
})

end)

Dialect.director:register_entity("Food", Nutrient)
Dialect.director:register_entity("Drug", Nutrient)

return M
