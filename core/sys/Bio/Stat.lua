
local U = require "togo.utility"
local O = require "Quanta.Object"
local Measurement = require "Quanta.Measurement"
local Entity = require "Quanta.Entity"
local Unit = require "Quanta.Unit"

local Nutrient = require "Dialect.Entity.Nutrition".Nutrient
local Bio = require "Bio"

local M = U.module(...)

local munit_gram = Measurement.get_unit("g")

U.class(M)

function M:__init(item, amount)
	self.children = {}
	self.item_tangible = nil

	if not item then
		self.item = nil
	elseif U.is_instance(item, Unit) or U.is_instance(item, Unit.Element) then
		self.item = self:_expand(item, amount)
	elseif U.is_type(item, "string") then
		self.item = item
	else
		U.assert(false, "unsupported item type: '%s'", type(item))
	end

	if not self.amount then
		amount = Measurement(0, munit_gram)
	end
end

function M:add(item, amount)
	U.assert(item ~= nil)
	if U.is_instance(item, M) then
		table.insert(self.children, item)
	elseif not U.is_instance(item, Unit) or not item:is_empty() then
		table.insert(self.children, M(item, amount))
	end
end

function M:to_object(obj)
	if obj then
		O.clear(obj)
	else
		obj =  O.create()
	end

	if not self.item then
		O.set_string(obj, "__EMPTY__")
	elseif U.is_type(self.item, "string") then
		O.set_string(obj, self.item)
	elseif U.is_instance(self.item, Unit.Element) then
		O.set_identifier(obj, self.item:name())
		-- Measurement.struct_list_to_quantity(self.item._steps_joined.measurements, obj)
	else
		local unit = self.item
		local tmp_items = unit.items
		local tmp_parts = unit.parts
		local tmp_measurements = unit.measurements
		unit.items = {}
		unit.parts = {}
		unit.measurements = {}

		obj = unit:to_object(obj)
		if unit.type == Unit.Type.composition then
			O.set_identifier(obj, "<composition>")
		end

		unit.measurements = tmp_measurements
		unit.items = tmp_items
		unit.parts = tmp_parts
	end
	Measurement.struct_list_to_quantity({self.amount}, obj)
	if self.item_tangible then
		local tag = O.push_tag(obj)
		O.set_name(tag, "tangible_item")
		tag = O.push_child(tag)
		O.set_identifier(tag, self.item_tangible:ref())
	end
	return obj
end

function M._normalize_amount(unit, outer)
	if U.is_instance(unit, Unit.Element) then
		unit = unit._steps_joined
	end
	local amount = unit.measurements[1]
	if amount then
		amount = amount:make_copy()
		if outer then
			if outer.value > 0 then
				amount.value = unit._factor * (outer.value * 10 ^ (outer.magnitude - amount.magnitude))
			else
				amount.value = amount.value * outer.of
			end
		end
	else
		amount = outer:make_copy()
	end
	Bio.normalize_measurement(amount)
	--[[if amount.value ~= 0 and amount.of == 1 then
		amount.of = 0
	end--]]
	return amount
end

function M:_expand(unit, outer)
	if not unit._normalized then
		unit = unit:make_copy()
		Bio.normalize(unit)
	end
	self.item = unit
	-- if not self.amount then
		self.amount = M._normalize_amount(unit, outer)
	-- end
	self:_expand_parts(unit, self.amount)
	return unit
end

function M:_expand_parts(unit, amount)
	if U.is_instance(unit, Unit.Element) then
		unit = unit._steps_joined
	end
	if unit.type == Unit.Type.reference and unit.thing and #unit.items == 0 then
		if U.is_instance(unit.thing, Entity) then
			self:_expand_entity(unit.thing, unit.thing_variant, amount)
		elseif U.is_instance(unit.thing, Unit.Element) then
			self.item = self:_expand(unit.thing, amount)
		else
			self:add(unit.thing.parts[1], amount)
		end
	elseif unit.type == Unit.Type.definition then
		self:add(unit.parts[1], amount)
	else -- composition or compound
		for _, item in ipairs(unit.items) do
			self:add(item, amount)
		end
	end
end

function M:_expand_entity(entity, variant, amount)
	if not amount or not U.is_instance(entity.data, Nutrient) then
		return
	end
	if not variant or (#variant.composition.items == 0 and #variant.data.nutrients == 0) then
		variant = entity.generic
	end

	local ref_entity = entity
	local composition
	while entity and not entity:is_universe() do
		if U.is_instance(entity.data, Nutrient) and #variant.data.nutrients > 0 then
			local profile = variant.data.nutrients[1]
			profile:normalize()
			composition = profile.composition
		elseif not variant.composition:is_empty() then
			composition = variant.composition
			Bio.resolve_func(composition)
			Bio.normalize_unit(composition, #composition.measurements == 0 and amount)
		end
		if composition then
			break
		end
		entity = entity.parent
		variant = entity.generic
	end
	if composition then
		if entity ~= ref_entity then
			self.item_tangible = entity
		end
		-- U.print("_expand_entity: %s", O.write_text_string(composition:to_object(), true))
		--[[if composition.type == Unit.Type.composition then
			for _, item in ipairs(composition.items) do
				self:add(item, amount)
			end
		else--]]
			self:_expand(composition, amount)
		-- end
	end
end

return M
