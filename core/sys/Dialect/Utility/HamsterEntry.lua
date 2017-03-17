
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Unit = require "Quanta.Unit"

local Dialect = require "Dialect"
local M = U.module(...)

local function needs_quotation(s)
	local i, _ = string.find(s, '["\\ \n\t]')
	return i ~= nil
end

M = Dialect.make_action(M, "HamsterEntry", function(class)

function class:__init(activity, description, tags)
	self.activity = U.type_assert(activity, "string", true) or nil
	self.description = U.type_assert(description, "string", true) or nil
	self.tags = U.type_assert(tags, "table", true) or {}
end

function class:to_object(action, obj)
	if self.activity then
		local activity_obj = O.push_child(obj)
		O.set_name(activity_obj, "activity")
		if needs_quotation(self.activity) then
			O.set_string(activity_obj, self.activity)
		else
			O.set_identifier(activity_obj, self.activity)
		end
	end
	if #self.tags > 0 then
		local tags_obj = O.push_child(obj)
		O.set_name(tags_obj, "tags")
		for _, tag in ipairs(self.tags) do
			local tag_obj = O.push_child(tags_obj)
			if needs_quotation(tag) then
				O.set_string(tag_obj, tag)
			else
				O.set_identifier(tag_obj, tag)
			end
		end
	end

	if self.description then
		local description_obj = O.push_child(obj)
		O.set_name(description_obj, "d")
		O.set_string(description_obj, self.description)
	end
end

class.t_body:add({
Match.Pattern{
	name = "activity",
	vtype = {O.Type.identifier, O.Type.string},
	acceptor = function(context, self, obj)
		self.activity = O.text(obj)
	end,
},
Match.Pattern{
	name = "d",
	vtype = {O.Type.string},
	acceptor = function(context, self, obj)
		self.description = O.string(obj)
	end,
},
Match.Pattern{
	name = {"tags"},
children = {
	Match.Pattern{
		vtype = {O.Type.identifier, O.Type.string},
		acceptor = function(context, self, obj)
			table.insert(self.tags, O.text(obj))
		end,
	},
}},

})

end)

return M
