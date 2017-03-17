
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Unit = require "Quanta.Unit"

local Dialect = require "Dialect"
local M = U.module(...)

function M.group(action)
	if U.is_type(action.data, M.Eat) then
		return action.data.group
	elseif U.is_type(action.data, M.Drugtake) then
		return "Drug"
	else
		U.assert(false)
	end
end

Dialect.make_action(
	M, "Eat",
function(class)

function class:__init(group, binge, composition)
	self.prep = false
	self.group = U.type_assert(group, "string", true) or nil
	self.binge = U.type_assert(binge, "boolean", true) or false
	self.composition = U.type_assert(composition, Unit, true) or Unit.Composition()
end

function class:to_object(action, obj)
	local group_obj = O.push_child(obj)
	O.set_name(group_obj, "group")
	if self.group then
		O.set_identifier(group_obj, self.group)
	else
		O.set_value_certain(group_obj, false)
	end

	local items_obj = O.push_child(obj)
	O.set_name(items_obj, "items")
	self.composition:to_object(items_obj)
end

class.t_body:add({
Match.Pattern{
	name = "group",
	vtype = O.Type.identifier,
	acceptor = function(context, self, obj)
		self.group = O.identifier(obj)
	end,
},
Match.Pattern{
	name = {"items", "food"},
	children = Unit.t_composition_body,
	acceptor = function(context, self, obj)
		return self.composition
	end,
},
Match.Pattern{
	tags = {
	Match.Pattern{
		name = "binge",
		acceptor = function(context, self, obj)
			self.binge = true
		end,
	},
	},
},
})

end)

M.Drugtake = Dialect.make_action(
	M, "B_Drugtake",
function(class)

function class:__init(composition)
	self.prep = false
	self.composition = U.type_assert(composition, Unit, true) or Unit.Composition()
end

function class:to_object(action, obj)
	self.composition:to_object(obj)
end

-- TODO: proper variant system
class.t_head_tags:add({
Match.Pattern{
	name = "init",
	acceptor = function(context, self, obj)
	self.prep = true
	end,
},
Match.Pattern{
	name = "post",
	acceptor = function(context, self, obj)
	self.prep = true
	end,
},
})

class.t_body:add({
Match.Pattern{
	any = true,
	branch = Unit.t_composition_body,
	acceptor = function(context, self, obj)
		return self.composition
	end,
},
})

end)

return M
