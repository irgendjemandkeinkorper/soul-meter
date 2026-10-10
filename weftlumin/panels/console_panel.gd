class_name WeftluminConsolePanel
extends SoulMeterToolPanel
## Console bottom tab (§4.12): the dev console's interpreter behind the panel contract.
## Provenance is the interpreter's own — `[debug] ` causes, the `dev_console_used` marker and the
## recorder's `dev_console_command` events — so nothing here writes state.

const MODEL_SCRIPT := preload("res://weftlumin/panels/models/dev_console.gd")
const QUICK_ACTIONS: Array[Array] = [
	["Help", "help"], ["Flags", "flags"], ["Next phase", "phase next"], ["Clear", "clear"],
]

var log_box: TextEdit = null
var entry: LineEdit = null


func _init() -> void:
	title = "Console"
	needs_sandbox = false
	hotkey_hint = ""


func _model_script() -> Script:
	return MODEL_SCRIPT


func _build(content: VBoxContainer) -> void:
	log_box = _text_box("Log", false)
	# The log fills what the dock leaves above the entry row and scrolls itself, so the entry
	# never scrolls out of view.
	log_box.scroll_fit_content_height = false
	content.add_child(log_box)
	var row := _row()
	content.add_child(row)
	entry = LineEdit.new()
	entry.name = "CommandEntry"
	entry.placeholder_text = "Command — type help"
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	entry.text_submitted.connect(submit)
	entry.gui_input.connect(_on_entry_gui_input)
	row.add_child(entry)
	row.add_child(_button("Run", "Run", func() -> void: submit(entry.text)))
	for action: Array in QUICK_ACTIONS:
		var command: String = action[1]
		row.add_child(_button(action[0], String(action[0]).replace(" ", ""), func() -> void:
			submit(command)
		))
	model.connect("log_changed", _refresh_log)


func refresh(_payload: Dictionary) -> void:
	_refresh_log()


func commands() -> Array[Callable]:
	return [Callable(model, "execute_command")]


## Run one command through the interpreter.
func submit(command: String) -> bool:
	var ok: bool = bool(model.call("execute_command", command))
	entry.clear()
	return ok


func _refresh_log() -> void:
	if log_box == null:
		return
	var lines: PackedStringArray = []
	var entries: Array = model.call("log_entries")
	for log_entry: Dictionary in entries:
		lines.append(str(log_entry.get("text", "")))
	log_box.text = "\n".join(lines)
	log_box.scroll_vertical = log_box.get_line_count()


func _on_entry_gui_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or not key.pressed or key.echo:
		return
	var recalled := ""
	if key.keycode == KEY_UP:
		recalled = str(model.call("history_previous"))
	elif key.keycode == KEY_DOWN:
		recalled = str(model.call("history_next"))
	else:
		return
	entry.text = recalled
	entry.caret_column = recalled.length()
	entry.accept_event()
