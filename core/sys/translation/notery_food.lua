
local U = require "togo.utility"
local O = require "Quanta.Object"
local Vessel = require "Quanta.Vessel"
local Prop = require "Quanta.Prop"
local Entity = require "Quanta.Entity"
local Instance = require "Quanta.Instance"

local function split_question_mark(s)
	if string.sub(s, 1, 1) == "?" then
		return string.sub(s, 2), false
	end
	return s, true
end

function add_entity(category, obj)
	local desc_glob = O.string(O.child_at(obj, 1))
	if desc_glob == "" then
		print()
		return
	end

	local description = nil
	local pos_slash, _ = string.find(desc_glob, "/")
	if pos_slash then
		description = string.sub(desc_glob, pos_slash + 1)
		desc_glob = string.sub(desc_glob, 1, pos_slash - 1)
	end

	local instance_obj = O.create(desc_glob)
	U.assert(instance_obj)

	local instance = Instance()
	local success, msg = instance:from_object(instance_obj)
	U.assert(success, msg)

	local name = instance.id
	U.assert(name)

	do
		local i = string.find(name, category.name .. "_")
		if i == 1 then
			name = string.sub(name, #category.name + 2)
		end
	end

	U.print("  %-40s $ %2s %2s   \"%s\"", name, instance.source or "0", instance.sub_source or "0", description or "")

	local author, author_certain = split_question_mark(O.string(O.child_at(obj, 2)))
	local tags = O.string(O.child_at(obj, 3))
	local note = O.string(O.child_at(obj, 4))

	local entity = category:find(name)
	if not entity then
		entity = Entity(name)
		category:add(entity)
	end

	local source = nil
	if instance.source == 0 then
		source = entity.generic
	else
		source = entity.generic.sources[instance.source]
		if not source then
			source = Entity.Source(entity)
			entity.generic.sources[instance.source] = source
		end
		if instance.sub_source > 0 then
			U.assert(
				not source.sources[instance.sub_source],
				"source %2d sub-source %2d already defined",
				instance.source, instance.sub_source
			)
			local sub_source = Entity.Source(entity)
			source.sources[instance.sub_source] = sub_source
			source = sub_source
		end
	end
	U.assert(not source.touched)
	source.touched = true

	if description and description ~= "" then
		source.description = "FIXUP_DESCRIPTION " .. description
	end

	if author ~= "" then
		table.insert(source.author, Prop.Author("FIXUP_AUTHOR " .. author, author_certain, nil, nil))
	end
	if not instance.source_certain then
		table.insert(source.note, Prop.Note("FIXUP_SOURCE_UNCERTAIN", nil))
	end
	if note ~= "" then
		table.insert(source.note, Prop.Note("FIXUP_NOTE " .. note, nil))
	end
	if tags ~= "" then
		table.insert(source.note, Prop.Note("FIXUP_TAGS " .. tags, nil))
	end
end

function add_category(universe, obj)
	local category = Entity.Category(string.gsub(string.lower(O.string(obj)), "[^%a_-]", "-"))
	universe:add(category)

	print(category.name)
	for _, entity_obj in O.children(obj) do
		add_entity(category, entity_obj)
	end
end

function main(params)
	Vessel.init("lib/core/test/vessel_data")
	U.assert(#params == 2)

	local path = params[2]
	local obj = O.create()
	U.assert(O.read_text_file(obj, path, false))

	local universe = Entity.Universe("universe")
	for _, category_obj in O.children(obj) do
		add_category(universe, category_obj)
	end

	O.clear(obj)
	universe:to_object(obj)
	print(O.write_text_string(obj, false))

	return 0
end

return main(...)
