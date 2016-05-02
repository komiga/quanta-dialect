
local U = require "togo.utility"
local O = require "Quanta.Object"
local Tool = require "Quanta.Tool"
local Vessel = require "Quanta.Vessel"
local Entity = require "Quanta.Entity"

require "Tool.common"

local function exclude_previous_and_disable(tool)
	if tool.data.show_exclusive then
		for k, _ in pairs(tool.data.show) do
			tool.data.show[k] = false
		end
		tool.data.show_exclusive = false
	end
end

local options = {
Tool.Option("-i", "boolean", [=[
-i
  inclusive (treat options additively, not exclusively)
]=],
function(tool, value)
	tool.data.show_exclusive = false
end),

Tool.Option("-a", "boolean", [=[
-a
  show all
]=],
function(tool, value)
	for k, _ in pairs(tool.data.show) do
		tool.data.show[k] = true
	end
	tool.data.show_exclusive = false
end),

Tool.Option("-m", "boolean", [=[
-m
  show misc
]=],
function(tool, value)
	exclude_previous_and_disable(tool)
	tool.data.show.misc = value
end),

Tool.Option("-e", "boolean", [=[
-e
  show email (default)
]=],
function(tool, value)
	exclude_previous_and_disable(tool)
	tool.data.show.email = value
end),

Tool.Option("-u", "boolean", [=[
-u
  show uid (default)
]=],
function(tool, value)
	exclude_previous_and_disable(tool)
	tool.data.show.uid = value
end),

Tool.Option("-p", "boolean", [=[
-p
  show pwd (default)
]=],
function(tool, value)
	exclude_previous_and_disable(tool)
	tool.data.show.pwd = value
end),
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
		if not value or value == "" or not success or (termination_reason and code ~= 0) then
			value = "<error>"
		else
			value = trim_trailing_newlines(value)
		end
	end
	return value
end

local function pretty_property(property, show)
	if not show then
		return "<skip>"
	end
	local value = decrypt_property(property)
	if not value or value == "" then
		value = "<none>"
	elseif value then
		value = string.gsub(value, "\n", "\n      ")
	end
	return value
end

local function print_credentials(entity, show)
	local account = entity.generic.data
	Tool.log("-- %s --", entity:ref())
	Tool.log(
		"desc: %s\n" ..
		"addr: %s\n" ..
		"misc: %s\n" ..
		"uid : %s\n" ..
		"pwd : %s",
		entity.generic.description or "<none>",
		pretty_property(account.email, show.email),
		pretty_property(account.misc, show.misc),
		pretty_property(account.uid, show.uid),
		pretty_property(account.pwd, show.pwd)
	)
end

local command = Tool("print", options, {}, [=[
print [property selectors] <ref> [...]
  print plaintext details for an account

  default options: -e -u -p
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
		print_credentials(entity, self.data.show)

		if i < #entities then
			Tool.log("")
		end
	end
end)

command.default_data = {
	show_exclusive = true,
	show = {
		email = true,
		misc = false,
		uid = true,
		pwd = true,
	},
}

return command
