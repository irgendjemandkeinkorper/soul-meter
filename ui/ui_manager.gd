extends CanvasLayer
## UIManager — MECHANISM ONLY: a screen stack that draws menus above the game.
## It decides nothing about game flow. Flow policy lives in GameFlow's state chart
## (ui/flow/game_flow.gd); this node just opens/closes Control scenes when told to,
## and translates raw input into chart events.
##
## Overlay screens (Inventory, Party, Settings) are *views*, not flow states — they
## stack here directly. Flow-owned screens (the pause menu) are opened by the chart
## and closed by the chart; Esc on them sends "resume" instead of popping.

const INVENTORY := preload("res://ui/screens/inventory.tscn")
const PARTY := preload("res://ui/screens/party.tscn")
const STANDING := preload("res://ui/screens/standing.tscn")
const TAVERN := preload("res://ui/screens/tavern.tscn")

var ui_theme: Theme
var _stack: Array[Control] = []
var _paused_by_ui := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_theme()


func _build_theme() -> void:
	# The Soul Meter Design System theme (see design/DESIGN_SYSTEM.md, ui/theme/).
	ui_theme = ThemeBuilder.build()
	get_tree().root.theme = ui_theme


## Open a screen. `pause` halts the tree for overlay views (inventory while playing);
## `flow_owned` marks screens whose lifecycle belongs to the state chart.
func open(scene: PackedScene, pause: bool = false, flow_owned: bool = false) -> Control:
	if pause and not _paused_by_ui:
		_paused_by_ui = true
		get_tree().paused = true
	var inst: Control = scene.instantiate()
	inst.flow_owned = flow_owned
	inst.theme = ui_theme  # CanvasLayer children don't inherit the root Window theme
	add_child(inst)
	_stack.append(inst)
	return inst


func back() -> void:
	if _stack.is_empty():
		return
	if _stack.back().flow_owned:
		GameFlow.send_event("resume")  # chart exit closes it via close_all()
		return
	var top: Control = _stack.pop_back()
	top.queue_free()
	if _stack.is_empty() and _paused_by_ui:
		_paused_by_ui = false
		get_tree().paused = false


func close_all() -> void:
	while not _stack.is_empty():
		_stack.pop_back().queue_free()
	if _paused_by_ui:
		_paused_by_ui = false
		get_tree().paused = false


func is_open() -> bool:
	return not _stack.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if is_open():
			back()
		elif _in_gameplay():
			GameFlow.send_event("pause")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_inventory") and _in_gameplay() and not is_open():
		open(INVENTORY, true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_party") and _in_gameplay() and not is_open():
		open(PARTY, true)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_standing") and _in_gameplay() and not is_open():
		open(STANDING, true)
		get_viewport().set_input_as_handled()


func _in_gameplay() -> bool:
	var cur := get_tree().current_scene
	return cur != null and GameFlow.GAMEPLAY_SCENES.has(cur.scene_file_path)
