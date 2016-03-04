
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Prop = require "Quanta.Prop"
local Tracker = require "Quanta.Tracker"
local M = U.module(...)

M.actions = {}

function M.make_action(mod, name, setup)
	U.type_assert(mod, "table")
	U.type_assert(name, "string")
	U.type_assert(setup, "function")

	local class = U.class(mod[name])
	mod[name] = class
	class.name = name

	function class:__init()
	end

	function class:from_object(context, parent, action, obj)
		return context:consume(class.t_head, obj, self)
	end

	function class:to_object(action, obj)
		if self.description and #self.description > 0 then
			local d = O.push_child(obj)
			O.set_string(d, self.description)
		end
	end

	--[[function class:compare_equal(other)
		return false
	end--]]

	class.t_body = Match.Tree()
	class.t_head_tags = Match.Tree({
	Tracker.Action.t_ignore_internal_tags,
	})

	class.t_head = Match.Tree({
	Match.Pattern{
		name = Match.Any,
		vtype = Match.Any,
		tags = class.t_head_tags,
		children = class.t_body,
	},
	})

	function class.setup_sub(fallback)
		class.sub_action_spec = Prop.Specializer()
		class.sub_action_spec_fallback = fallback
		function class:read_action(context, parent, action, obj)
			return class.sub_action_spec:read(context, parent, action, obj, class.sub_action_spec_fallback)
		end
	end
	U.assert(not class.read_action)

	setup(class)
	class.setup_sub = nil
	class.t_body:build()
	class.t_head_tags:build()
	class.t_head:build()

	Dialect.add_action(class.name, class)

	return class
end

function M.add_action(name, class)
	U.assert(not M.actions[name])
	M.actions[name] = class
end

function M.register_actions(director)
	for name, action in pairs(M.actions) do
		director:register_action(name, action)
	end
end

M.add_action("ETODO", Tracker.PlaceholderAction)

return M
