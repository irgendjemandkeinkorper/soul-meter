extends Control

const ERROR_COLOR := Color("ff6b6b")

@onready var _log: RichTextLabel = %Log
@onready var _entry: LineEdit = %CommandEntry
@onready var _help_button: Button = %HelpButton
@onready var _flags_button: Button = %FlagsButton
@onready var _phase_button: Button = %PhaseButton
@onready var _clear_button: Button = %ClearButton

var _console: Node = null
var _log_changed_callable := Callable(self, "_refresh_log")


func _ready() -> void:
	_entry.text_submitted.connect(_on_command_submitted)
	_entry.gui_input.connect(_on_entry_gui_input)
	_help_button.pressed.connect(_on_quick_action.bind("help"))
	_flags_button.pressed.connect(_on_quick_action.bind("flags"))
	_phase_button.pressed.connect(_on_quick_action.bind("phase next"))
	_clear_button.pressed.connect(_on_quick_action.bind("clear"))


func configure(console: Node) -> void:
	_console = console
	if _console.has_signal("log_changed") and not _console.is_connected(
		"log_changed", _log_changed_callable
	):
		_console.connect("log_changed", _log_changed_callable)
	_refresh_log()
	_entry.call_deferred("grab_focus")


func _exit_tree() -> void:
	if _console != null and is_instance_valid(_console) and _console.has_signal("log_changed"):
		if _console.is_connected("log_changed", _log_changed_callable):
			_console.disconnect("log_changed", _log_changed_callable)


func _on_command_submitted(command: String) -> void:
	if _console == null:
		return
	_console.call("execute_command", command)
	_entry.clear()


func _on_quick_action(command: String) -> void:
	_entry.text = command
	_entry.caret_column = command.length()
	_on_command_submitted(command)
	_entry.grab_focus()


func _on_entry_gui_input(event: InputEvent) -> void:
	if _console == null or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	var keycode: Key = key_event.physical_keycode
	if keycode == KEY_NONE:
		keycode = key_event.keycode
	var history_text := ""
	match keycode:
		KEY_UP:
			history_text = str(_console.call("history_previous"))
		KEY_DOWN:
			history_text = str(_console.call("history_next"))
		_:
			return
	_entry.text = history_text
	_entry.caret_column = history_text.length()
	_entry.accept_event()


func _refresh_log() -> void:
	if _console == null:
		return
	var entries_value: Variant = _console.call("log_entries")
	if not entries_value is Array:
		return
	var entries := entries_value as Array
	_log.clear()
	for entry_value: Variant in entries:
		if not entry_value is Dictionary:
			continue
		var entry := entry_value as Dictionary
		var is_error := bool(entry.get("error", false))
		if is_error:
			_log.push_color(ERROR_COLOR)
		_log.add_text("%s\n" % str(entry.get("text", "")))
		if is_error:
			_log.pop()
	_log.scroll_to_line(maxi(0, _log.get_line_count() - 1))
