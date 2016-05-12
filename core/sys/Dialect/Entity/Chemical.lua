
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"

local Dialect = require "Dialect"
local M = U.module(...)

M.Element = Dialect.make_entity(
	M, {"ChemicalElement"},
function(class)

function class.Source:__init(source)
	self.period = 0
	self.period_certain = false

	self.number = 0
	self.number_certain = false

	self.group = 0
	self.group_certain = false

	-- g/mol
	self.mass = 0
	self.mass_certain = false
end

local function set_property(self, obj, func_set, name)
	local value = self[name]
	local value_certain = self[name .. "_certain"]

	local property_obj = O.push_child(obj)
	O.set_name(property_obj, name)
	O.set_value_certain(property_obj, value_certain and value ~= 0)
	if value ~= 0 then
		func_set(property_obj, value)
	end
end

function class.Source:to_object(source, obj)
	set_property(self, obj, O.set_integer, "period")
	set_property(self, obj, O.set_integer, "number")
	set_property(self, obj, O.set_integer, "group")
	set_property(self, obj, O.set_decimal, "mass")
end

class.Source.t_body:add({
Match.Pattern{
	name = "period",
	vtype = {O.Type.null, O.Type.integer},
	acceptor = function(context, self, obj)
		if O.is_integer(obj) then
			self.data.period = O.integer(obj)
			self.data.period_certain = O.value_certain(obj)
		else
			self.data.period_certain = false
		end
	end,
},
Match.Pattern{
	name = "number",
	vtype = {O.Type.null, O.Type.integer},
	acceptor = function(context, self, obj)
		if O.is_integer(obj) then
			self.data.number = O.integer(obj)
			self.data.number_certain = O.value_certain(obj)
		else
			self.data.number_certain = false
		end
	end,
},
Match.Pattern{
	name = "group",
	vtype = {O.Type.null, O.Type.integer},
	acceptor = function(context, self, obj)
		if O.is_integer(obj) then
			self.data.group = O.integer(obj)
			self.data.group_certain = O.value_certain(obj)
		else
			self.data.group_certain = false
		end
	end,
},
Match.Pattern{
	name = "mass",
	vtype = {O.Type.null, O.Type.integer, O.Type.decimal},
	acceptor = function(context, self, obj)
		if O.is_numeric(obj) then
			self.data.mass = O.numeric(obj)
			self.data.mass_certain = O.value_certain(obj)
		else
			self.data.mass_certain = false
		end
	end,
},
})

end)

return M
