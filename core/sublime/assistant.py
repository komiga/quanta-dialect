
import sublime_plugin
import time

# , tags = {%(e_tags)s}, rel_id = %(e_rel_id)s
ENTRY_TEMPLATE = '''
Entry%(e_entry_tags)s{range = ${2:%(e_range_begin)s} - ${3:%(e_range_end)s}, continue_id = ${4:%(e_continue_id)s}%(e_content)s};
'''

# , tags = {%(e_tags)s}, rel_id = %(e_rel_id)s
ENTRY_TEMPLATE_SC = '''
Entry%(e_entry_tags)s{range = %(e_range_begin)s - %(e_range_end)s, continue_id = %(e_continue_id)s%(e_content)s};
'''

ENTRY_ACTIONS = ''', actions = {
	%(e_content)s
}'''

class QuantaNewTrackerEntryCommand(sublime_plugin.TextCommand):
	def run(
		self, edit,
		auto_complete = False,
		short_circuit = False,
		content_selected = False,
		at_end = False,
		e_entry_tags = "",
		e_range_begin = "auto",
		e_range_end = "ENEXT",
		e_tags = "",
		e_rel_id = "null",
		e_continue_id = "null",
		e_content = ""
	):
		view = self.view
		if e_range_begin == "auto":
			e_range_begin = time.strftime("%H:%M:%S", time.gmtime())
		has_actions = True
		if e_content == None:
			has_actions = False
			e_content = ""
		elif content_selected:
			e_content = "${1:" + e_content + "}"
		else:
			e_content += "$1"
		if short_circuit:
			contents = ENTRY_TEMPLATE_SC
		else:
			contents = ENTRY_TEMPLATE
			e_content += "$0"
		if has_actions:
			e_content = ENTRY_ACTIONS % locals()
		contents = contents % locals()

		if at_end:
			view.run_command("goto_line", {"line" : -1})
		view.run_command(
			"insert_snippet",
			{"contents" : contents}
		)
		if auto_complete:
			view.run_command("auto_complete")

class QuantaInsertTimeCommand(sublime_plugin.TextCommand):
	def run(self, edit):
		view = self.view
		for region in view.sel():
			view.replace(edit, region, time.strftime("%H:%M:%S", time.gmtime()))

# class QuantaAssistant(sublime_plugin.EventListener):
# 	def on_query_completions(self, view, prefix, locations):
# 		matches = []
# 		if prefix == "":
# 			matches.append((
# 				"time entry - Quanta",
# 				("" + QUANTA_TRACKER_ENTRY).replace("TIME", time.strftime("%H:%M:%S"))
# 			))
# 		return matches
