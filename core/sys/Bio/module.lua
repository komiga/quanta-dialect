
local U = require "togo.utility"
local O = require "Quanta.Object"
local Measurement = require "Quanta.Measurement"
local Entity = require "Quanta.Entity"
local Unit = require "Quanta.Unit"

local ChemicalElement = require "Dialect.Entity.Chemical".Element

local M = U.module(...)

M.debug = false
M.resolve_func = function()
	U.assert(false, "missing resolver function")
end

local quantity_mass = Measurement.Quantity.mass
local quantity_dimensionless = Measurement.Quantity.dimensionless
local munit_dimensionless = Measurement.get_unit("")
local munit_gram = Measurement.get_unit("g")
local munit_milligram = Measurement.get_unit("mg")
local munit_ratio = Measurement.get_unit("ratio")
M.chemical_id_hash = O.hash_name("chemical")

local BioDebugModifier = U.class(BioDebugModifier)

function BioDebugModifier:__init(unit)
	self.unit = unit
end

function BioDebugModifier:from_object(context, ref, modifier, obj)
end

function BioDebugModifier:to_object(modifier, obj)
	obj = O.push_child(obj)
	if self.unit._factor ~= nil then
		O.set_decimal(obj, self.unit._factor)
	else
		O.set_identifier(obj, "NO_FACTOR")
	end
end

function BioDebugModifier:make_copy()
	return BioDebugModifier(unit)
end

function BioDebugModifier:compare_equal(other)
	return true
end

function M.normalize_measurement(m)
	if m.qindex == quantity_dimensionless.index then
		m.of = m.of + m.value
		m.value = 0
	elseif m.qindex ~= quantity_mass.index then
		if m:is_convertible(quantity_mass) then
			m:convert(quantity_mass.unit_by_magnitude[m.magnitude] or munit_gram)
		end
	end
end

function M.normalize_unit_measurements(unit, outer)
	if #unit.measurements == 0 and unit.thing and not U.is_instance(unit.thing, Entity) then
		unit.measurements = {Measurement(0, munit_dimensionless, 1, 0, true)}
	end
	if #unit.measurements > 0 then
		local specified = unit.measurements[1]
		if specified.qindex == Measurement.QuantityIndex.ratio then
			if outer then
				specified.value = specified.value * outer.value
				specified.qindex = outer.qindex
				specified.magnitude = outer.magnitude
			else
				unit._factor = specified.value
				unit.measurements = {}
				return nil
			end
		else
			M.normalize_measurement(specified)
		end
		for i = 2, #unit.measurements do
			local m = unit.measurements[i]
			M.normalize_measurement(m)
			if m.qindex == specified.qindex then
				specified:add(m)
			end
		end
		unit.measurements = {specified}
		if outer then
			unit._factor = specified.value / outer.value * (10 ^ (specified.magnitude - outer.magnitude))
		end
		return specified
	end
	return outer
end

local function normalize_unit_impl(unit, outer)
	if unit._normalized then
		return
	end
	if unit._factor == nil then
		unit._factor = 1.0
	end
	if M.debug then
		table.insert(unit.modifiers, Unit.Modifier("__bio_dbg__", nil, BioDebugModifier(unit)))
	end
	unit._normalized = true

	-- TODO: use average mass of thing if unit only measures number of instances
	-- TODO: use typical/average measurement of thing if unspecified

	outer = M.normalize_unit_measurements(unit, outer)
	local common_unit = outer and outer:unit()
	-- U.log("%s :: %s", unit.id, common_unit and common_unit.name or "none")

	if unit.id_hash == M.chemical_id_hash and unit.thing then
		if not common_unit then
			common_unit = munit_milligram
		end
		local atomic_multiplier = 1
		local m = unit.measurements[1]
		if m and m.of > 0 then
			atomic_multiplier = m.of
			m.of = 0
			if m.value == 0 then
				unit.measurements = {}
			end
		end

		local inner_sum = Measurement(0, common_unit)
		local specified_atomic_mass = 0
		local total_atomic_mass = 0
		for index, item in ipairs(unit.items) do
			U.assert(item.thing and U.is_instance(item.thing.data, ChemicalElement))
			local element = item.thing.generic.data
			if #item.measurements > 0 then
				local m = M.normalize_unit_measurements(item)
				if m.of == 0 then
					m.of = 1
				end
				m.of = m.of * atomic_multiplier
				item._num_atoms = m.of
				item._factor = m.of * element.mass
				if m.qindex == Measurement.QuantityIndex.mass then
					if specified_atomic_mass == 0 then
						common_unit = m:unit()
						inner_sum:convert(common_unit)
					end
					inner_sum:add(m)
					specified_atomic_mass = specified_atomic_mass + item._factor
				end
			else
				item._num_atoms = atomic_multiplier
				item._factor = atomic_multiplier * element.mass
			end
			total_atomic_mass = total_atomic_mass + item._factor
		end
		if specified_atomic_mass ~= 0 then
			inner_sum.of = 0
			inner_sum.value = inner_sum.value / (specified_atomic_mass / total_atomic_mass)
			unit.measurements = {inner_sum}
			outer = M.normalize_unit_measurements(unit, outer)
		end
		for index, item in ipairs(unit.items) do
			if M.debug and not item._normalized then
				table.insert(item.modifiers, Unit.Modifier("__bio_dbg__", nil, BioDebugModifier(item)))
			end
			item._normalized = true
			item._factor = item._factor / total_atomic_mass
			if outer then
				item.measurements = {Measurement(item._factor * outer.value, common_unit, item._num_atoms, 0, outer.certain)}
			else
				item.measurements = {Measurement(item._factor, munit_ratio, item._num_atoms, 0, true)}
			end
		end
	elseif #unit.items > 0 then
		if not common_unit then
			common_unit = munit_gram
			for _, item in ipairs(unit.items) do
				if #item.measurements > 0 then
					local m = item.measurements[1]
					if m:quantity().tangible then
						common_unit = quantity_mass.unit_by_magnitude[m.magnitude]
						U.assert(common_unit)
						break
					end
				end
			end
		end

		local inner_sum = Measurement(0, common_unit)
		local specified = {}
		local unspecified = {}
		for _, item in ipairs(unit.items) do
			local factor_known = false
			if item.id_hash == M.chemical_id_hash then
				local m = item.measurements[1]
				if m and m.value ~= 0 and m.qindex ~= quantity_dimensionless.index then
					factor_known = true
				else
					for _, item_element in ipairs(item.items) do
						m = item_element.measurements[1]
						if m and m.value ~= 0 and m.qindex ~= quantity_dimensionless.index then
							factor_known = true
							break
						end
					end
				end
			elseif #item.measurements > 0 then
				factor_known = true
			end
			if factor_known then
				normalize_unit_impl(item, outer)
				local m = item.measurements[1]
				if m.qindex == inner_sum.qindex then
					inner_sum:add(m)
				end
				table.insert(specified, item)
			elseif not item:is_empty() then
				table.insert(unspecified, item)
			end
		end

		inner_sum.of = 0
		if not outer then
			if #unspecified == 0 then
				unit.measurements = {inner_sum:make_copy()}
			end
			for _, item in ipairs(specified) do
				local m = item.measurements[1]
				item._factor = m.value / (inner_sum.value * (10 ^ (inner_sum.magnitude - m.magnitude)))
			end
			for _, item in ipairs(unspecified) do
				normalize_unit_impl(item, nil)
			end
		elseif #unspecified > 0 then
			-- TODO: maybe a better way to handle this?
			local dist_amount = U.max(0, (outer.value - inner_sum.value) / #unspecified)
			if dist_amount > 0 then
				local dist = Measurement(dist_amount, common_unit, 0, 0, #unspecified == 1)
				for _, item in ipairs(unspecified) do
					local m = item.measurements[1]
					item.measurements = {dist:make_copy()}
					if m and item.id_hash == M.chemical_id_hash then
						item.measurements[1].of = m.of
					end
					normalize_unit_impl(item, outer)
				end
			end
		elseif outer.value ~= 0 and outer.value ~= inner_sum.value then
			local imbalance = outer.value - inner_sum.value
			-- U.log("imbalance @ %s: %f - %f = %f", unit.id, outer.value, inner_sum.value, imbalance)
			local imbalance_unit = Unit.Reference()
			if imbalance > 0 then
				imbalance_unit:set_id("unknown.underflow")
			else
				imbalance_unit:set_id("unknown.overflow")
			end
			table.insert(imbalance_unit.measurements, Measurement(imbalance, common_unit, 0, 0, inner_sum.certain))
			M.resolve_func(imbalance_unit)
			normalize_unit_impl(imbalance_unit, outer)
			table.insert(unit.items, imbalance_unit)
		end
	end
end

function M.normalize(unit, outer)
	if not U.is_instance(unit, Unit) then
		U.assert(false, "unrecognized type")
	end
	if outer then
		outer = outer:make_copy()
		M.normalize_measurement(outer)
	end
	normalize_unit_impl(unit, outer)
end

return M
