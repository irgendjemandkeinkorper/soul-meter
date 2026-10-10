extends GdUnitTestSuite
## Isolated authored scene, real shell GUI, and a test-only pause adapter. No root-list policy.

const SHELL := preload("res://addons/weftlumin/shell/shell.tscn")
const PANEL := preload("res://weftlumin/panels/scene_panel.tscn")
const Recovery := preload("res://globals/layout_recovery.gd")

class FixtureAdapter extends WeftluminGameAdapter:
	var world: Node
	var previous_paused := false

	func gameplay_scene_root() -> Node:
		return world

	func theme() -> Theme:
		return UIManager.ui_theme

	func panels() -> Array[PackedScene]:
		return [PANEL]

	func set_editor_open(open: bool) -> void:
		if open:
			previous_paused = world.get_tree().paused
			world.get_tree().paused = true
		else:
			world.get_tree().paused = previous_paused

var world: Node2D
var shell: WeftluminShell
var panel: WeftluminScenePanel
var model: WeftluminSceneModel
var solid: StaticBody2D
var _previous_scene: Node
var _previous_paused := false
var _hidden: Array[CanvasItem] = []
var _scene_path := ""


func before_test() -> void:
	_previous_scene = get_tree().current_scene
	_previous_paused = get_tree().paused
	await UIManager.close_all()
	get_tree().paused = false
	for child: Node in get_tree().root.get_children():
		if child is CanvasItem and child.visible:
			_hidden.append(child)
			child.hide()
	world = Node2D.new()
	world.name = "ScenePickFixture"
	_scene_path = "res://world/scene_pick_fixture_%d.tscn" % Time.get_ticks_usec()
	world.scene_file_path = _scene_path
	get_tree().root.add_child(world)
	get_tree().current_scene = world
	for layer_name: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		var layer := Node2D.new()
		layer.name = layer_name
		world.add_child(layer)
		layer.owner = world
	solid = StaticBody2D.new()
	solid.name = "TestProp"
	world.get_node("SolidProps").add_child(solid)
	solid.owner = world
	var sprite := Sprite2D.new()
	sprite.texture = load("res://icon.svg")
	solid.add_child(sprite)
	sprite.owner = world
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(64, 24)
	collision.shape = shape
	solid.add_child(collision)
	collision.owner = world
	await open_shell()
	solid.global_position = world_at(shell.viewport_surface.size / 2.0)
	model.select_only(solid)


func after_test() -> void:
	if is_instance_valid(shell):
		shell.close()
		await get_tree().process_frame
	if is_instance_valid(world):
		world.free()
	assert_int(Recovery.clear(_scene_path)).is_equal(OK)
	var save_path: String = LayoutOverrides.override_path_for_scene(_scene_path)
	if FileAccess.file_exists(save_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	get_tree().current_scene = _previous_scene if is_instance_valid(_previous_scene) else null
	for item: CanvasItem in _hidden:
		if is_instance_valid(item):
			item.show()
	_hidden.clear()
	get_tree().paused = _previous_paused
	model = null


func open_shell() -> void:
	shell = SHELL.instantiate() as WeftluminShell
	var adapter := FixtureAdapter.new()
	adapter.world = world
	shell.adapter = adapter
	add_child(shell)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	panel = shell.root.find_child("Scene tree", true, false) as WeftluminScenePanel
	model = panel.model
	shell.camera.zoom = Vector2.ONE
	shell.camera.position = Vector2.ZERO
	shell.camera.force_update_scroll()


func add_sprite(node_name: String, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load("res://icon.svg")
	sprite.scale = Vector2(0.25, 0.25)
	world.get_node("GroundDetails").add_child(sprite)
	sprite.owner = world
	sprite.global_position = at
	panel._rebuild()
	return sprite


func world_at(local: Vector2) -> Vector2:
	return shell.viewport_to_world(local)


func screen_at(at: Vector2) -> Vector2:
	return get_viewport().canvas_transform * at


func motion(at: Vector2, held: bool = false, free_move: bool = false) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if held else 0
	event.alt_pressed = free_move
	get_viewport().push_input(event, true)


func edge(at: Vector2, pressed: bool, shift: bool = false, control: bool = false, alt: bool = false, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	# Each invocation allocates a fresh event. Every test pairs each press with its release.
	var event := InputEventMouseButton.new()
	event.position = at
	event.global_position = at
	event.button_index = button
	event.button_mask = (1 << (button - 1)) if pressed else 0
	event.pressed = pressed
	event.shift_pressed = shift
	event.ctrl_pressed = control
	event.alt_pressed = alt
	get_viewport().push_input(event, true)


func click(at: Vector2, shift: bool = false, control: bool = false, alt: bool = false) -> void:
	motion(at)
	for pressed: bool in [true, false]:
		edge(at, pressed, shift, control, alt)


func key(code: Key, control: bool = false, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.pressed = pressed
		event.physical_keycode = code
		event.keycode = code
		event.ctrl_pressed = control
		event.shift_pressed = shift
		get_viewport().push_input(event, true)
