
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
	self.amount = amount or Measurement(0)

	if not item then
		self.item = nil
	elseif U.is_instance(item, Unit) then
		self:_expand(item, amount)
	elseif U.is_type(item, "string") then
		self.item = item
	else
		U.assert(false, "unsupported item type: '%s'", type(item))
	end
end

function M:add(item, amount)
	U.assert(item ~= nil)
	if U.is_instance(item, M) then
		table.insert(self.children, item)
	else
		table.insert(self.children, M(item, amount))
	end
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

	if not unit._normalized then
		unit = unit:make_copy()
		Bio.normalize_unit(unit)
	end
	amount = amount or unit.measurements[1] or Measurement(0, munit_gram)
	amount = amount:make_copy()
	Bio.normalize_measurement(amount)
	amount.value = amount.value * unit._factor

	self.item = unit
	self.amount = amount

	if unit.type == Unit.Type.reference then
		if not unit.thing then
			-- nothing to do
		elseif U.is_instance(unit.thing, Entity) then
			if #unit.items == 0 then -- simple
				self:_expand_entity(unit.thing, unit.thing_variant, amount)
			else -- compound
				for _, item in ipairs(unit.items) do
					self:add(item, amount)
				end
			end
		elseif U.is_instance(unit.thing, Unit) then
			-- TODO: parts
			Bio.normalize_unit(unit.thing)
			self:add(unit.thing, amount)
		else
			U.assert(false, "unknown thing type (referenced by '%s')", item.id)
		end
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
		Bio.normalize_unit(composition)
	end

	if composition then
		for _, item in ipairs(composition.items) do
			self:add(item, amount)
		end
	end
end

return M
