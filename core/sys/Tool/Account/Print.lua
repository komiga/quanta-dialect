
local U = require "togo.utility"
local O = require "Quanta.Object"
local Tool = require "Quanta.Tool"
local Vessel = require "Quanta.Vessel"
local Entity = require "Quanta.Entity"

require "Tool.common"

local options = {
}

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

local function decrypt_property(property)
	local value = property.value
	if property.encrypted and property.value ~= nil then
		value, _ = string.gsub(property.value, "'", "\\'")
		local command = string.format([[qv-data-cipher decrypt --base64 '%s']], value)
		local proc = io.popen(command, "r")
		value = proc:read("*a")
		local success, termination_reason, code = io.close(proc)
		-- print("'" .. value .. "'", success, termination_reason, code)
		if not value or not success or (termination_reason and code ~= 0) then
			value = "<error>"
		else
			value = trim_trailing_newlines(value)
		end
	end
	return value or "<none>"
end

local function decrypt_property_and_pad(property)
	local value = decrypt_property(property)
	if value then
		value = string.gsub(value, "\n", "\n      ")
	end
	return value
end

local function print_credentials(entity)
	local account = entity.generic.data
	Tool.log("-- %s --", entity:ref())
	Tool.log(
		"desc: %s\n" ..
		"addr: %s\n" ..
		"uid : %s\n" ..
		"pwd : %s",
		entity.generic.description or "<none>",
		decrypt_property_and_pad(account.email),
		decrypt_property_and_pad(account.uid),
		decrypt_property_and_pad(account.pwd)
	)
end

local command = Tool("print", options, {}, [=[
print [<ref> ...]
  print plaintext details for an account
]=],
function(self, parent, options, params)
	if #params == 0 then
		Tool.log("no refs given")
		return
	end

	local universe, msg = Entity.read_universe(Vessel.data_path("entity/account/root.q"))
	if not universe then
		return Tool.log_error(msg)
	end

	local branches = {
		Entity.make_search_branch(universe:search(nil, ".account"), math.huge),
	}

	local entities = {}
	for i, p in ipairs(params) do
		local ref = p.value
		local entity = universe:search(branches, ref)
		if not entity then
			return Tool.log_error("%s not found", ref)
		elseif not U.is_instance(entity.data, Dialect.Entity.Account.Account) then
			return Tool.log_error("%s is not an account", entity:ref())
		end
		table.insert(entities, entity)
	end

	for i, entity in ipairs(entities) do
		print_credentials(entity)

		if i < #entities then
			Tool.log("")
		end
	end
end)

command.default_data = {}

return command
