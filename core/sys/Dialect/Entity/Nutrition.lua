
local U = require "togo.utility"
local O = require "Quanta.Object"
local Match = require "Quanta.Match"
local Measurement = require "Quanta.Measurement"
local Unit = require "Quanta.Unit"
local Entity = require "Quanta.Entity"

local Dialect = require "Dialect"
local Bio = require "Bio"

local M = U.module(...)

M.Profile = U.class(M.Profile)

function M.Profile:__init()
	self.name = nil
	self.name_hash = O.NAME_NULL
	self.of = Measurement()
	self.data_source = nil
	self.composition = Unit.Composition()
end

function M.Profile:to_object(obj)
	O.set_name(obj, self.name)

	local of_obj = O.push_child(obj)
	O.set_name(of_obj, "of")
	self.of:to_object(of_obj)

	if self.data_source then
		local data_source_obj = O.push_child(obj)
		O.set_name(data_source_obj, "data_source")
		O.set_string(data_source_obj, self.data_source)
	end

	local composition_obj = O.push_child(obj)
	self.composition:to_object(composition_obj)
	O.set_name(composition_obj, "composition")
end

function M.Profile:normalize()
	if self.composition._normalized then
		return
	end

	Bio.resolve_func(self.composition)
	Bio.normalize_unit(self.composition, self.of)
end

M.Profile.t_body = Match.Tree({
Match.Pattern{
	name = "of",
	vtype = Match.Any,
	children = Match.Any,
	tags = Match.Any,
	acceptor = function(context, self, obj)
		if not self.of:from_object(obj) then
			return Match.Error("invalid measurement")
		end
	end,
},
Match.Pattern{
	name = "data_source",
	vtype = O.Type.string,
	acceptor = function(context, self, obj)
		self.data_source = O.string(obj)
	end,
},
Match.Pattern{
	name = "composition",
	vtype = Match.Any,
	children = Match.Any,
	tags = Match.Any,
	quantity = Match.Any,
	branch = Unit.t_composition_head_gobble,
	acceptor = function(context, self, obj)
		return self.composition
	end,
},
})

M.Profile.t_head = Match.Tree({
Match.Pattern{
	name = true,
	children = M.Profile.t_body,
	acceptor = function(context, self, obj)
		self.name = O.name(obj)
		self.name_hash = O.name_hash(obj)
	end,
},
})

M.Profile.t_body:build()
M.Profile.t_head:build()

M.Nutrient = Dialect.make_entity(
	M, {"Nutrient", "Food", "Drug"},
function(class)

function class.Source:__init(source)
	self.nutrients = {}
end

function class.Source:to_object(source, obj)
	if #self.nutrients > 0 then
		local nutrients_obj = O.push_child(obj)
		O.set_name(nutrients_obj, "nutrients")
		for _, profile in ipairs(self.nutrients) do
			profile:to_object(O.push_child(nutrients_obj))
		end
	end
end

class.Source.t_body:add({
Match.Pattern{
	name = "nutrients",
	children = {Match.Pattern{
		layer = M.Profile.t_head.positional[1],
		acceptor = function(context, self, obj)
			return M.Profile()
		end,
		post_branch_pre = function(context, profile, obj)
			local self = context:value(1)
			if self.data.nutrients[profile.name_hash] then
				return Match.Error("nutrient profile name is not unique")
			end
			table.insert(self.data.nutrients, profile)
			self.data.nutrients[profile.name_hash] = profile
		end,
	}},
},
})

end)

return M
