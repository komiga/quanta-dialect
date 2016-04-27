
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Measurement = require "Quanta.Measurement"
local Unit = require "Quanta.Unit"
local Entity = require "Quanta.Entity"

local Dialect = require "Dialect"
local M = U.module(...)

M.Property = U.class(M.Property)

function M.Property:__init(value, encrypted)
	self.value = U.type_assert(value, "string", true)
	self.encrypted = U.type_assert(encrypted, "boolean", true) or false
end

function M.Property:to_object(obj, serialized_name)
	if self.value ~= nil and self.value ~= "" then
		local value_obj = O.push_child(obj)
		O.set_name(value_obj, serialized_name)
		O.set_string(value_obj, self)
		if self.encrypted then
			O.set_string_type(value_obj, "enc")
		end
	end
end

function M.Property.adapt_pattern(property_name)
	return Match.Pattern{
		name = property_name,
		vtype = O.Type.string,
		acceptor = function(context, thing, obj)
			local self = thing.data[property_name]
			self.value = O.string(obj)

			local string_type = O.string_type(obj)
			if string_type == "enc" then
				self.encrypted = true
			elseif string_type == "" then
				self.encrypted = false
			else
				return Match.Error("string type '%s' not recognized; must be none or 'enc'", string_type)
			end
		end,
	}
end

M.Account = Dialect.make_entity(
	M, "Account",
function(class)

function class.Source:__init(source)
	self.uid = M.Property()
	self.pwd = M.Property()
end

function class.Source:to_object(source, obj)
	self.uid:to_object(obj, "uid")
	self.pwd:to_object(obj, "pwd")
end

class.Source.t_body:add({
M.Property.adapt_pattern("uid"),
M.Property.adapt_pattern("pwd"),
})

end)

return M
