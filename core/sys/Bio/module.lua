
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
local munit_dimensionless = Measurement.get_unit("")
local munit_gram = Measurement.get_unit("g")
local munit_milligram = Measurement.get_unit("mg")
local munit_ratio = Measurement.get_unit("ratio")
local chemical_id_hash = O.hash_name("chemical")

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
	if m.qindex == Measurement.QuantityIndex.dimensionless then
		m.of = m.of + m.value
		m.value = 0
	elseif m.qindex ~= quantity_mass.index then
		if m:quantity().tangible then
			m:rebase(quantity_mass.UnitByMagnitude[m.magnitude])
		else
			m:rebase(munit_gram)
		end
	end
end

function M.normalize_unit_measurements(unit, outer)
	if #unit.measurements == 0 and unit.thing and not U.is_instance(unit.thing, Entity) then
		unit.measurements = {Measurement(0, munit_gram, 1, 0, true)}
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
			specified:add(m.value)
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

	if unit.id_hash == chemical_id_hash and unit.thing then
		if not common_unit then
			common_unit = munit_milligram
		end
		local inner_sum = Measurement(0, common_unit)
		local specified_mass = 0
		local total_atomic_mass = 0
		for index, item in ipairs(unit.items) do
			U.assert(item.thing and U.is_instance(item.thing.data, ChemicalElement))
			local element = item.thing.generic.data
			if #item.measurements > 0 then
				local m = M.normalize_unit_measurements(item)
				if m.of == 0 then
					m.of = 1
				end
				item._num_atoms = m.of
				item._factor = m.of * element.mass
				if m.qindex == Measurement.QuantityIndex.mass then
					if specified_mass == 0 then
						common_unit = m:unit()
						inner_sum:rebase(common_unit)
					end
					inner_sum:add(m)
					specified_mass = specified_mass + item._factor
				end
			else
				item._num_atoms = 1
				item._factor = element.mass
			end
			total_atomic_mass = total_atomic_mass + item._factor
		end
		if specified_mass ~= 0 then
			inner_sum.of = 0
			inner_sum.value = inner_sum.value / (specified_mass / total_atomic_mass)
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
	elseif unit.type == Unit.Type.definition then
		for _, item in ipairs(unit.items) do
			for _, step in ipairs(item.steps) do
				M.normalize_unit(step.composition)
			end
		end
		for _, part in ipairs(unit.parts) do
			for _, step in ipairs(part.steps) do
				M.normalize_unit(step.composition)
			end
		end
		if #unit.measurements > 0 then
			local p1 = unit.parts[1]
			if p1 then
				local composition = U.table_last(p1.steps).composition
				composition.measurements = unit.measurements
				-- FIXME: what to do, what to do
				unit.measurements = {}
			end
		end
	elseif #unit.items > 0 then
		if not common_unit then
			common_unit = munit_gram
			for _, item in ipairs(unit.items) do
				if #item.measurements > 0 then
					local m = item.measurements[1]
					if m:quantity().tangible then
						common_unit = quantity_mass.UnitByMagnitude[m.magnitude]
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
			if #item.measurements == 0 then
				if item.id_hash == chemical_id_hash and item.thing then
					normalize_unit_impl(item, outer)
				elseif not U.is_instance(item.thing, Entity) then
					unit.measurements = {Measurement(0, munit_dimensionless, 1, 0, true)}
				end
			end
			if #item.measurements > 0 then
				normalize_unit_impl(item, outer)
				local m = item.measurements[1]
				if m.qindex == quantity_mass.index then
					inner_sum:add(m)
				end
				table.insert(specified, item)
			elseif not item:is_empty() then
				table.insert(unspecified, item)
			end
		end
		if not outer then
			if #unspecified == 0 then
				unit.measurements = {inner_sum:make_copy()}
			end
			for _, item in ipairs(specified) do
				local m = item.measurements[1]
				item._factor = m.value / (inner_sum.value * (10 ^ (inner_sum.magnitude - m.magnitude)))
			end
		elseif #unspecified > 0 then
			-- TODO: maybe a better way to handle this?
			local dist_amount = U.max(0, (outer.value - inner_sum.value) / #unspecified)
			if dist_amount > 0 then
				for _, item in ipairs(unspecified) do
					item.measurements = {Measurement(dist_amount, common_unit, 0, 0, #unspecified == 1)}
					normalize_unit_impl(item, outer)
				end
			end
		end
	end
end

function M.normalize_unit(unit, outer)
	if outer then
		if outer.qindex ~= quantity_mass.index then
			outer = outer:make_copy()
			outer:rebase(munit_gram)
		end
	end
	normalize_unit_impl(unit, outer)
end

return M
