
function quote(str)
	return "\"" .. (str or "") .. "\""
end

function add_from_table(a, b)
	for _, v in pairs(b) do
		table.insert(a, v)
	end
end

function json_value(name, value)
	assert(type(name) == "string")
	assert(type(value) == "string")
	return quote(name) .. ": " .. quote(value)
end

function make_action(trigger, entry)
	return {t = trigger, e = entry}
end

function transform_template(tpl)
	assert(tpl ~= nil and tpl ~= "")
	local has_newline = string.find(tpl, "\n", 1, true) ~= nil
	tpl = string.gsub(tpl, "\\", "\\\\")
	tpl = string.gsub(tpl, "\t", "\\t")
	tpl = string.gsub(tpl, "\n", "\\n") -- \\t
	tpl = string.gsub(tpl, "%$", "\\\\$")
	tpl = string.gsub(tpl, "@@@<<([^>]*)>>", function(content) -- `@@@{([^}]*)}` also works..
		content = string.gsub(content, "{", "\\\\{")
		content = string.gsub(content, "}", "\\\\}")
		return "${__QUANTA_ST_SNIPPET_ELEMENT__:" .. content .. "}"
	end)
	tpl = string.gsub(tpl, "@@", function()
		return "$__QUANTA_ST_SNIPPET_ELEMENT__"
	end)

	local tab_index = 0
	tpl = string.gsub(tpl, "__QUANTA_ST_SNIPPET_ELEMENT__", function()
		tab_index = tab_index + 1
		return tab_index
	end)
	tpl = string.gsub(tpl, '"', '\\"')
	return tpl--[[ .. "\\n"--]]--[[ .. (has_newline and "\\t" or "")--]] .. "$0"
end

function read_actions(path)
	local actions = dofile(path) or {}
	for _, action in pairs(actions) do
		assert(action.t ~= nil and action.t ~= "")
		--[[if action.d == "" then
			action.d = nil
		end

		local is_general = string.sub(action.t, -1) == "_"
		if not action.d then
			action.d = action.t .. (is_general and "*" or "")
		end--]]
		if string.sub(action.e, 1, 1) == "{" then
			action.e = action.t .. (is_general and "@@" or "") .. action.e
		end
		action.e = transform_template(action.e)
	end
	return actions
end

function write_completions(actions, path)
	local stream = io.open(path, "w+")
	stream:write(
	[[{
	"scope": "source.quanta",
	"completions": [
]])
	for i, action in ipairs(actions) do
		stream:write(
			"\t\t{" ..
			json_value("trigger", action.t .. "\\tQ"--[[ .. action.d--]]) .. ", " ..
			json_value("contents", action.e) ..
			"}" .. (i < #actions and "," or "") .. "\n"
		)
	end
	stream:write("\t]\n}\n")
	stream:close()
end

function main(arguments)
	if #arguments < 2 then
		print("usage: make-st-completions <output> <input> [input [...]]")
		return 0
	end
	local actions = {}
	local output_path = arguments[1]
	for i = 2, #arguments do
		add_from_table(actions, read_actions(arguments[i]))
	end
	write_completions(actions, output_path)
	return 0
end

os.exit(main(arg))