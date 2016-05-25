
local U = require "togo.utility"
local O = require "Quanta.Object"
local Measurement = require "Quanta.Measurement"
local Entity = require "Quanta.Entity"
local Unit = require "Quanta.Unit"

local ChemicalElement = require "Dialect.Entity.Chemical".Element

local M = U.module(...)

M.resolve_func = function()
	U.assert(false, "missing resolver function")
end

local quantity_mass = Measurement.Quantity.mass
local munit_gram = Measurement.get_unit("g")
local chemical_id_hash = O.hash_name("chemical")

function M.normalize_measurement(m)
	if m.qindex ~= Measurement.QuantityIndex.mass then
		if m:quantity().tangible then
			m:rebase(quantity_mass.UnitByMagnitude[m.magnitude])
		else
			m:rebase(munit_gram)
		end
	end
end

function M.normalize_unit_measurements(unit, outer)
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
			unit._factor = specified.value / outer.value
		end
		return specified
	end
	return outer
end

local function normalize_unit_impl(unit, outer)
	if unit._normalized then
		return
	end
	unit._factor = 1.0

	-- TODO: use average mass of thing if unit only measures number of instances
	-- TODO: use typical/average measurement of thing if unspecified
	-- TODO: depreciate to single entity if outer.of > 1

	outer = M.normalize_unit_measurements(unit, outer)

	if unit.id == chemical_id_hash and unit.thing then
		local total_atomic_mass = 0
		for _, item in ipairs(unit.items) do
			U.assert(item.thing and U.is_instance(item.thing.data, ChemicalElement))
			local element = item.thing.generic.data
			local n = 1
			if #item.measurements > 0 then
				n = item.measurements[1].of
				U.assert(n >= 1)
			end
			item._factor = n * element.mass
			total_atomic_mass = total_atomic_mass + item._factor
		end

		local unit = outer and outer:unit() or nil
		for _, item in ipairs(unit.items) do
			item._factor = item._factor / total_atomic_mass
			if outer then
				item.measurements = {Measurement(item._factor * outer.value, unit, 0, 0, false)}
			end
		end
	else
		local common_unit = outer and outer:unit() or munit_gram
		local inner_sum = Measurement(0, common_unit)

		local quantified = {}
		local unquantified = {}
		for _, item in ipairs(unit.items) do
			if #item.measurements > 0 then
				normalize_unit_impl(item, outer)
				local m = item.measurements[1]
				if m.qindex == Measurement.QuantityIndex.mass then
					inner_sum:add(m)
				end
				table.insert(quantified, item)
			else
				table.insert(unquantified, item)
			end
		end

		if not outer then
			if #unquantified == 0 then
				unit.measurements = {inner_sum:make_copy()}
			end
			for _, item in ipairs(quantified) do
				item._factor = item.measurements[1].value / inner_sum.value
			end
		elseif #unquantified > 0 then
			-- TODO: maybe a better way to handle this?
			local dist_amount = U.max(0, (outer.value - inner_sum.value) / #unquantified)
			if dist_amount > 0 then
				for _, item in ipairs(unquantified) do
					item.measurements = {Measurement(dist_amount, common_unit, 0, 0, false)}
					normalize_unit_impl(item, outer)
				end
			end
		end
	end
	unit._normalized = true
end

function M.normalize_unit(unit, outer)
	if outer then
		outer = outer:make_copy()
		outer:rebase(munit_gram)
	end
	normalize_unit_impl(unit, outer)
end

return M
