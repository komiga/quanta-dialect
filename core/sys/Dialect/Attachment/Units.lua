
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Unit = require "Quanta.Unit"

local Dialect = require "Dialect"
local M = U.module(...)

Dialect.make_attachment(M, "Units", function(class)

function class:__init(composition)
	self.composition = U.type_assert(composition, Unit, true) or Unit.Composition()
	U.assert(self.composition.type == Unit.Type.composition)
end

function class:to_object(attachment, obj)
	self.composition:to_object(obj, true)
end

function class.acceptor(context, self, obj)
	local tracker = context.user.tracker
	if tracker.attachments.units then
		return Match.Error("Units attachment must be unique")
	end
	tracker.attachments.units = self
end

class.t_body:add({
Match.Pattern{
	name = Match.Any,
	vtype = Match.Any,
	children = Match.Any,
	tags = Match.Any,
	quantity = Match.Any,
	branch = Unit.t_composition_head_gobble,
	acceptor = function(context, self, obj)
		return self.composition
	end,
	post_branch = function(context, self, obj)
		local unit = U.table_last(self.composition.items)
		if unit.type == Unit.Type.definition then
			if not unit.name then
				return Match.Error("local unit definition must be named")
			end
		end
	end,
},
})

end)

return M
