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
const CHARACTER_SHEET := preload("res://ui/screens/character_sheet.tscn")
const TAVERN := preload("res://ui/screens/tavern.tscn")
const JOURNAL := preload("res://ui/screens/journal.tscn")
const SHOP := preload("res://ui/screens/shop.tscn")
const REGION_MAP := preload("res://ui/screens/region_map.tscn")
const SETTINGS := preload("res://ui/screens/settings.tscn")
const LOAD_GAME := preload("res://ui/screens/load_game.tscn")
const REWARD_REVEAL := preload("res://ui/components/reward_reveal.tscn")
const BUTTON_PRESS_SOUND := preload("res://assets/audio/sfx/metalClick.ogg")
const SCREEN_OPEN_SOUND := preload("res://assets/audio/sfx/bookOpen.ogg")
const SCREEN_CLOSE_SOUND := preload("res://assets/audio/sfx/bookClose.ogg")
const INVENTORY_MOVE_SOUND := preload("res://assets/audio/sfx/handleSmallLeather2.ogg")

var ui_theme: Theme
var _stack: Array[Control] = []
var _paused_by_ui := false
var _reward_reveal
var _reward_queue: Array[Dictionary] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build_theme()
	get_tree().node_added.connect(_on_node_added)
	_create_reward_reveal()
	if not QuestRegistry.quest_rewards_granted.is_connected(_on_quest_rewards_granted):
		QuestRegistry.quest_rewards_granted.connect(_on_quest_rewards_granted)
	if GameState.inventory != null:
		GameState.inventory.item_moved.connect(_on_inventory_moved)


func _build_theme() -> void:
	# The Soul Meter Design System theme (see design/DESIGN_SYSTEM.md, ui/theme/).
	ui_theme = ThemeBuilder.build()
	get_tree().root.theme = ui_theme


func _create_reward_reveal() -> void:
	_reward_reveal = REWARD_REVEAL.instantiate()
	_reward_reveal.name = "RewardReveal"
	_reward_reveal.theme = ui_theme
	_reward_reveal.z_index = 100
	_reward_reveal.dismissed.connect(_on_reward_reveal_dismissed)
	add_child(_reward_reveal)


func _on_quest_rewards_granted(summary: Dictionary) -> void:
	_reward_queue.append(summary.duplicate(true))
	_show_next_reward()


func _show_next_reward() -> void:
	if _reward_reveal.visible or _reward_queue.is_empty():
		return
	move_child(_reward_reveal, get_child_count() - 1)
	var summary: Dictionary = _reward_queue.pop_front()
	var reduced_motion := bool(
		GameState.get_setting("accessibility", "reduced_motion", false)
	)
	_reward_reveal.present(summary, reduced_motion)


func _on_reward_reveal_dismissed() -> void:
	_show_next_reward.call_deferred()


func reset_reward_reveals() -> void:
	_reward_queue.clear()
	if _reward_reveal != null:
		_reward_reveal.reset()


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
	if inst is Screen:
		(inst as Screen).play_enter()
	_play_ui_sound(SCREEN_OPEN_SOUND)
	return inst


func back() -> void:
	if _stack.is_empty():
		return
	if _stack.back().flow_owned:
		if not _stack.back().allow_back:
			return
		GameFlow.send_event("resume")  # chart exit closes it via close_all()
		return
	var top: Control = _stack.pop_back()
	_release_pause_if_empty()
	await _finish_screen_close(top)
	_play_ui_sound(SCREEN_CLOSE_SOUND)


func close_all() -> void:
	var had_open_screen := not _stack.is_empty()
	var screens_to_close: Array[Control] = _stack.duplicate()
	_stack.clear()
	_release_pause_if_empty()
	for index in range(screens_to_close.size() - 1, -1, -1):
		await _finish_screen_close(screens_to_close[index])
	if had_open_screen:
		_play_ui_sound(SCREEN_CLOSE_SOUND)


func _finish_screen_close(screen: Control) -> void:
	if screen is Screen:
		(screen as Screen).play_exit()
		await (screen as Screen).transition_finished
	if is_instance_valid(screen):
		screen.queue_free()


func _release_pause_if_empty() -> void:
	if _stack.is_empty() and _paused_by_ui:
		_paused_by_ui = false
		get_tree().paused = false


func is_open() -> bool:
	return not _stack.is_empty()


func _unhandled_input(event: InputEvent) -> void:
	if _reward_reveal != null and _reward_reveal.visible:
		return
	if event.is_action_pressed("ui_cancel"):
		if is_open():
			back()
		elif get_tree().paused:
			# Dialogue balloons pause gameplay but are not UIManager stack entries.
			# Let the balloon consume Esc instead of opening the pause menu behind it.
			return
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
	elif event.is_action_pressed("open_journal") and _in_gameplay() and not is_open():
		open(JOURNAL, true)
		get_viewport().set_input_as_handled()


func _in_gameplay() -> bool:
	var cur := get_tree().current_scene
	return cur != null and GameFlow.GAMEPLAY_SCENES.has(cur.scene_file_path)


func _on_node_added(node: Node) -> void:
	if node is BaseButton:
		var button := node as BaseButton
		if not button.pressed.is_connected(_on_button_pressed):
			button.pressed.connect(_on_button_pressed)


func _on_button_pressed() -> void:
	_play_ui_sound(BUTTON_PRESS_SOUND)


func _on_inventory_moved() -> void:
	_play_ui_sound(INVENTORY_MOVE_SOUND)


func _play_ui_sound(stream: AudioStream) -> void:
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"SFX"
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
