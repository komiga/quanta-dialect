
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Prop = require "Quanta.Prop"
local Entity = require "Quanta.Entity"
local Tracker = require "Quanta.Tracker"
local Director = require "Quanta.Director"
local M = U.module(...)

M.director = Director()

M.director:register_action("ETODO", Tracker.PlaceholderAction)

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
			O.set_string(O.push_child(obj), self.description)
		end
	end

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
		quantity = Match.Any,
	},
	})

	function class.setup_sub(fallback)
		class.sub_action_spec = Prop.Specializer()
		class.sub_action_spec_fallback = fallback
		function class:read_action(context, action, obj)
			return class.sub_action_spec:read(context, self, action, obj, class.sub_action_spec_fallback)
		end
	end

	setup(class)
	class.setup_sub = nil

	class.t_body:build()
	class.t_head_tags:build()
	class.t_head:build()

	M.director:register_action(class.name, class)

	return class
end

function M.make_attachment(mod, name, setup)
	U.type_assert(mod, "table")
	U.type_assert(name, "string")
	U.type_assert(setup, "function")

	local class = U.class(mod[name])
	mod[name] = class
	class.name = name

	function class:__init()
	end

	function class:from_object(context, tracker, attachment, obj)
		return context:consume(class.t_head, obj, self)
	end

	function class:to_object(attachment, obj)
	end

	class.t_body = Match.Tree()
	class.t_head_tags = Match.Tree()
	class.t_head = Match.Tree({
	Match.Pattern{
		name = Match.Any,
		vtype = Match.Any,
		tags = class.t_head_tags,
		children = class.t_body,
		quantity = Match.Any,
		acceptor = function(context, self, obj)
			return class.acceptor(context, self, obj)
		end,
	},
	})

	setup(class)
	U.type_assert(class.acceptor, "function")

	class.t_body:build()
	class.t_head_tags:build()
	class.t_head:build()

	M.director:register_attachment(class.name, class)

	return class
end

function M.make_entity(mod, name, setup)
	U.type_assert(mod, "table")
	U.type_assert(name, "string")
	U.type_assert(setup, "function")

	local class = U.class(mod[name])
	mod[name] = class
	class.name = name

	class.Source = U.class(class.Source)

	function class.Source:__init(source)
	end

	function class.Source:to_object(source, obj)
	end

	function class:__init()
	end

	function class:from_object(context, parent, entity, obj)
		return context:consume(class.t_head, obj, entity)
	end

	function class:to_object(entity, obj)
	end

	class.Source.Source = class.Source
	class.Source.t_body = Match.Tree()
	class.Source.t_body:add({
	Entity.Source.t_body,
	Entity.specialize_sub_sources(class.Source.t_body),
	})

	class.t_body = Match.Tree({
	Entity.t_entity_body,
	Entity.specialize_sources(class.Source.t_body),
	})

	class.t_head_tags = Match.Tree()
	class.t_head = Match.Tree({
	Match.Pattern{
		name = Match.Any,
		vtype = Match.Any,
		tags = class.t_head_tags,
		children = class.t_body,
	},
	})

	setup(class)

	class.t_body:add({
	Entity.specialize_generic_fallthrough(class.Source.t_body),
	})

	class.Source.t_body:build()
	class.t_body:build()
	class.t_head_tags:build()
	class.t_head:build()

	M.director:register_entity(class.name, class)

	return class
end

return M
