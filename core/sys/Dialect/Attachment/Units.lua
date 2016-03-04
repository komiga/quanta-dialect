
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Unit = require "Quanta.Unit"

local Dialect = require "Dialect"
local M = U.module(...)

Dialect.make_attachment(M, "Units", function(class)

function class:__init(items)
	self.items = U.type_assert(items, "table", true) or {}
end

function class:to_object(attachment, obj)
	for _, item in pairs(self.items) do
		item:to_object(O.push_child(obj))
	end
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
	layer = Unit.p_head,
	acceptor = function(context, self, obj)
		return Unit()
	end,
	post_branch_pre = function(context, unit, obj)
		local self = context:value(1)
		if not unit.name then
			return Match.Error("local unit must be named")
		elseif self.items[unit.name] then
			return Match.Error("local unit '%s' already exists", unit.name)
		end
		self.items[unit.name] = unit
	end,
},
})

end)

return M
