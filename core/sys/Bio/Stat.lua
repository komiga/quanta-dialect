
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

	if not item then
		self.item = nil
	elseif U.is_instance(item, Unit) or U.is_instance(item, Unit.Element) then
		self:_expand(item, amount)
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
	return obj
end

function M:_expand(unit, amount)
	-- inputs:
	-- ref to entity
	-- ref to entity (compound)
	-- ref to unit
	--   x[..] -> x{P1[..]}
	--   x{P2[..]}
	--   x{P1, P2}[..]
	-- composition
	--   {x[..], y[..]}
	--   {x[..], y}[..]
	--   {x, y}[..]
	-- definition
	--   FH{..}[..]
	--   FH{P1 = {}[..], P2 = {}[..]}
	-- element

	if not unit._normalized then
		unit = unit:make_copy()
		Bio.normalize(unit)
	end
	self.item = unit

	local is_element = U.is_instance(unit, Unit.Element)
	if is_element then
		unit = unit._steps_joined
	end
	local base_amount = unit.measurements[1]
	local common_unit = base_amount and base_amount:unit() or munit_gram
	if not amount then
		amount = base_amount or Measurement(0, common_unit)
	end
	amount = amount:make_copy()
	amount:rebase(common_unit)
	if base_amount then
		if amount:is_exact() then
			amount.approximation = base_amount.approximation
			amount.certain = base_amount.certain
		end
		if amount.of == 0 then
			amount.of = base_amount.of
		end
		if amount.value == 0 then
			amount.value = amount.of * base_amount.value
		end
	end
	Bio.normalize_measurement(amount)
	amount.value = amount.value * unit._factor
	if amount.value ~= 0 and amount.of == 1 then
		amount.of = 0
	end
	self.amount = amount

	unit = self.item
	if is_element then
		for _, item in ipairs(unit._steps_joined.items) do
			self:add(item, amount)
		end
	elseif unit.type == Unit.Type.reference then
		if unit.thing then
			if #unit.items == 0 then -- direct
				if U.is_instance(unit.thing, Entity) then
					self:_expand_entity(unit.thing, unit.thing_variant, amount)
				elseif U.is_instance(unit.thing, Unit.Element) then
					self:_expand(unit.thing, amount)
					return
				else
					self:add(unit.thing.parts[1], amount)
				end
			else -- compound or selection
				for _, item in ipairs(unit.items) do
					self:add(item, amount)
				end
			end
		end
	elseif unit.type == Unit.Type.definition then
		self:add(unit.parts[1], amount)
	else
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

	local composition
	if #variant.data.nutrients > 0 then
		local profile = variant.data.nutrients[1]
		profile:normalize()
		composition = profile.composition
	elseif #variant.composition.items > 0 then
		composition = variant.composition
		Bio.resolve_func(composition)
		Bio.normalize_unit(composition, #composition.measurements == 0 and amount)
	end

	if composition then
		for _, item in ipairs(composition.items) do
			self:add(item, amount)
		end
	end
end

return M
