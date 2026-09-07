extends Node
## Weftlumin's only resident node, and the only activation path.
##
## It is declared as a `project.godot` autoload rather than being spawned by `plugin.gd`, so
## every build — exports included — carries it. That is what lets the inert suite exercise the
## real activation path instead of a test double: the thing under test in a release build is the
## same object that ships.
##
## Disabled is the default AND the fail-closed state. While disabled this node has no children,
## does not process input, registers no `weftlumin_toggle` action, creates no `user://weftlumin`
## directory, and leaves nothing in production connected to a Weftlumin callable. Enabling and
## then disabling again must return to exactly that state — `test_weftlumin_inert.gd` compares
## the two snapshots field by field.
##
## The activation shape is lifted from `globals/layout_mode.gd:8-11,69-86` deliberately: one
## proven copy, not seven. See `docs/architecture-in-game-editor.md` §4.1, §4.5.1, §4.14.

## Host adapter, loaded only if the host supplies one. It arrives with the shell in E2.3; until
## then this resolves to null and the fallback flag below carries the gate.
const ADAPTER_SCRIPT_PATH := "res://weftlumin/soul_meter_adapter.gd"
const SHELL_SCENE_PATH := "res://addons/weftlumin/shell/shell.tscn"
const TOGGLE_ACTION := &"weftlumin_toggle"
const TOGGLE_KEY := KEY_F12
## Ruling 12 fixes the hotkey; the action exists so it stays remappable from the host's settings.

## Used when there is no adapter, or the adapter names no flag. The gate still needs a name
## before E2.3 lands, and `test_weftlumin_inert.gd` pins this exact one.
const FALLBACK_ENV_FLAG := "SOUL_METER_WEFTLUMIN"

var force_enabled_for_tests: bool = false:
	set(value):
		force_enabled_for_tests = value
		_refresh_activation()

var _enabled: bool = false
var _adapter: WeftluminGameAdapter = null
var _adapter_resolved: bool = false
var _shell: CanvasLayer = null
## The action is erased on disable only if this node is the one that added it, so a host that
## later declares `weftlumin_toggle` in `project.godot` does not lose it to a toggle cycle.
var _registered_toggle_action: bool = false
## Fail-closed warnings are one-shot: an env-enabled build missing its panels should say so
## once, not once per keypress.
var _warned_missing_shell: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(false)
	_refresh_activation()


func _exit_tree() -> void:
	# InputMap is global and outlives this node. A freed autoload must not leave a runtime
	# action behind for whatever runs next — in a test session, that is the next suite.
	_set_enabled(false)


## True only in a debug build that opted in, or under the test seam.
func is_enabled() -> bool:
	return _enabled


## The environment variable this build opts in with.
func env_flag() -> String:
	var adapter: WeftluminGameAdapter = _resolve_adapter()
	var flag: String = adapter.env_flag() if adapter != null else ""
	return flag if not flag.is_empty() else FALLBACK_ENV_FLAG


## Open the shell if it is closed, close it if it is open. Inert while disabled.
func toggle() -> void:
	if not _enabled:
		return
	if _shell == null:
		open()
	else:
		close()


func open() -> void:
	if not _enabled or _shell != null:
		return
	# Lazy by design: a disabled build never touches the shell scene, so the loader never pulls
	# the dock, panels or their dependencies into memory.
	if not ResourceLoader.exists(SHELL_SCENE_PATH):
		_warn_missing_shell()
		return
	var packed: PackedScene = load(SHELL_SCENE_PATH) as PackedScene
	if packed == null:
		_warn_missing_shell()
		return
	var instance: Node = packed.instantiate()
	var shell: CanvasLayer = instance as CanvasLayer
	if shell == null:
		push_warning(
			"Weftlumin: %s is not a CanvasLayer; refusing to open." % SHELL_SCENE_PATH
		)
		instance.free()
		return
	_shell = shell
	_shell.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_shell)
	var adapter: WeftluminGameAdapter = _resolve_adapter()
	if adapter != null:
		adapter.set_editor_open(true)


func close() -> void:
	if _shell == null:
		return
	var shell: CanvasLayer = _shell
	_shell = null
	remove_child(shell)
	shell.free()
	var adapter: WeftluminGameAdapter = _resolve_adapter()
	if adapter != null:
		adapter.set_editor_open(false)


func _unhandled_key_input(event: InputEvent) -> void:
	if not _enabled:
		return
	var key_event := event as InputEventKey
	if key_event == null or not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != TOGGLE_KEY and key_event.keycode != TOGGLE_KEY:
		return
	toggle()
	get_viewport().set_input_as_handled()


func _refresh_activation() -> void:
	if not is_inside_tree():
		return
	var opted_in: bool = OS.get_environment(env_flag()) == "1"
	_set_enabled(OS.is_debug_build() and (opted_in or force_enabled_for_tests))


func _set_enabled(value: bool) -> void:
	if value == _enabled:
		return
	_enabled = value
	set_process_unhandled_key_input(_enabled)
	if _enabled:
		_register_toggle_action()
		return
	# Order matters on the way down: close the shell first so the adapter is told the editor is
	# gone while the action still exists, then take the action away.
	close()
	_unregister_toggle_action()
	_warned_missing_shell = false


func _register_toggle_action() -> void:
	if InputMap.has_action(TOGGLE_ACTION):
		return
	InputMap.add_action(TOGGLE_ACTION)
	var event := InputEventKey.new()
	event.physical_keycode = TOGGLE_KEY
	InputMap.action_add_event(TOGGLE_ACTION, event)
	_registered_toggle_action = true


func _unregister_toggle_action() -> void:
	if not _registered_toggle_action:
		return
	_registered_toggle_action = false
	if InputMap.has_action(TOGGLE_ACTION):
		InputMap.erase_action(TOGGLE_ACTION)


func _resolve_adapter() -> WeftluminGameAdapter:
	if _adapter_resolved:
		return _adapter
	_adapter_resolved = true
	if not ResourceLoader.exists(ADAPTER_SCRIPT_PATH):
		return null
	var script: GDScript = load(ADAPTER_SCRIPT_PATH) as GDScript
	if script == null:
		return null
	var instance: Variant = script.new()
	_adapter = instance as WeftluminGameAdapter
	if _adapter == null:
		push_warning(
			"Weftlumin: %s does not extend WeftluminGameAdapter; ignoring it."
			% ADAPTER_SCRIPT_PATH
		)
	return _adapter


func _warn_missing_shell() -> void:
	if _warned_missing_shell:
		return
	_warned_missing_shell = true
	# The panels and tools directories are export-excluded. An env-enabled debug export that was
	# built without them must fail closed and say why, rather than half-open a shell that cannot
	# work.
	push_warning(
		"Weftlumin is enabled but %s is missing; staying closed. "
		% SHELL_SCENE_PATH
		+ "A debug export excludes addons/weftlumin/panels/* and tools/* — rebuild with them "
		+ "included to use the editor."
	)
