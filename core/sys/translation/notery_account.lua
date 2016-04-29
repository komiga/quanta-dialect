
package.path = package.path .. [[;./?/module.lua]]

local U = require "togo.utility"
local FS = require "togo.filesystem"
local O = require "Quanta.Object"
local Vessel = require "Quanta.Vessel"
local Prop = require "Quanta.Prop"
local Entity = require "Quanta.Entity"

local Dialect

local BYTE_NEWLINE = string.byte('\n')

local function trim_trailing_newlines(s)
	local b
	for i = #s, 1, -1 do
		b = string.byte(s, i)
		if b ~= BYTE_NEWLINE then
			return string.sub(s, 1, i)
		end
	end
	return s
end

local function encrypt_property(property)
	local value, _ = string.gsub(property.value, "'", "\\'")
	local command = string.format([[qv-data-cipher encrypt --base64 '%s']], value)
	local proc = io.popen(command, "r")
	value = proc:read("*a")
	local success, _, _ = io.close(proc)
	U.assert(value and success)
	property.value = trim_trailing_newlines(value)
	property.encrypted = true
end

-- string "description"
-- string "email"
-- string "uid"
-- string "pwd"
-- string "Tags"
-- string "Notes"
function add_entity(parent, obj)
	U.assert(O.is_identifier(obj))
	local ref = O.identifier(obj)
	local description = O.string(O.child_at(obj, 1))

	U.print("  %-40s   \"%s\"", ref, description or "")

	local email = O.string(O.child_at(obj, 2))
	local uid = O.string(O.child_at(obj, 3))
	local pwd = O.string(O.child_at(obj, 4))
	local tags = O.string(O.child_at(obj, 5))
	local note = O.string(O.child_at(obj, 6))

	local name
	do
		local entity
		local i, j = 1, 1
		j, _ = string.find(ref, '.', i, true)
		while j and j ~= #ref do
			name = string.sub(ref, i, j - 1)
			entity = parent:find(name) or Entity.Category(name)
			parent:add(entity)
			parent = entity
			i = j + 1
			j, _ = string.find(ref, '.', i, true)
		end
		name = string.sub(ref, i)
		print("   O " .. name)
	end

	local entity = Entity(name, "Account", O.hash_name("Account"), Dialect.Entity.Account.Account)
	parent:add(entity)

	local source = entity.generic

	if description and description ~= "" then
		source.description = "FIXUP_DESCRIPTION " .. description
	end

	if email ~= "" then
		source.data.email.value = email
	end
	if uid ~= "" then
		source.data.uid.value = uid
	end
	if pwd ~= "" then
		source.data.pwd.value = pwd
		encrypt_property(source.data.pwd)
	end

	if note ~= "" then
		table.insert(source.note, Prop.Note("FIXUP_NOTE " .. note, nil))
	end
	if tags ~= "" then
		table.insert(source.note, Prop.Note("FIXUP_TAGS " .. tags, nil))
	end
end

function add_category(universe, obj)
	local category = Entity.Category(string.gsub(string.lower(O.text(obj)), "[^%a_-]", "-"))
	universe:add(category)

	print(category.name)
	for _, entity_obj in O.children(obj) do
		add_entity(category, entity_obj)
	end
end

function main(params)
	Vessel.init("lib/core/test/vessel_data")
	U.assert(#params == 2)
	FS.working_dir_scope(U.path_dir(params[1]) .. "/..", function()
		print(FS.working_dir())
		Dialect = require "Dialect"
		require "Dialect.Entity.Account"

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
	end)

	return 0
end

return main(...)
