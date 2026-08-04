class_name NPC
extends StaticBody2D
## A field NPC the player can talk to. Walk into range, press the interact key (E) —
## the configured dialogue starts via Dialogue Manager (which loads our balloon).

@export var npc_name: String = "NPC"
@export var npc_id: String = ""
@export_file("*.dialogue") var dialogue_path: String
@export var dialogue_start: String = "start"
@export var vendor_id: String = ""
@export_range(32.0, 240.0, 1.0) var interaction_radius: float = 120.0
@export_group("Placeholder presentation")
## Scene-owned presentation keeps NPC content from branching on lore names.
@export var visual_region := Rect2(0, 68, 16, 16)
@export var visual_modulate := Color(0.55, 0.78, 0.64, 1.0)
@export var visual_scale := Vector2(3.5, 3.5)

var _player_in_range := false
var _prompt: Label


func _ready() -> void:
	_apply_visual_identity()
	var range_area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = interaction_radius
	shape.shape = circle
	range_area.add_child(shape)
	add_child(range_area)
	range_area.body_entered.connect(_on_body.bind(true))
	range_area.body_exited.connect(_on_body.bind(false))

	_prompt = Label.new()
	_prompt.text = "E — TRADE" if not vendor_id.is_empty() else "E — TALK"
	_prompt.theme_type_variation = "EyebrowLabel"
	_prompt.position = Vector2(-100, -108)
	_prompt.size = Vector2(200, 32)
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.visible = false
	add_child(_prompt)


func _on_body(body: Node2D, entered: bool) -> void:
	if body is Player:
		_player_in_range = entered
		_prompt.visible = entered


func _unhandled_input(event: InputEvent) -> void:
	if _player_in_range and event.is_action_pressed("interact") and not get_tree().paused:
		get_viewport().set_input_as_handled()
		if not vendor_id.is_empty():
			var shop_screen := UIManager.open(UIManager.SHOP, true)
			shop_screen.call("configure_vendor", vendor_id)
			return
		var route := QuestRegistry.dialogue_route_for_actor(
			_stable_actor_id(), dialogue_path, dialogue_start
		)
		var resolved_path := str(route.get("path", ""))
		var resolved_title := str(route.get("title", "start"))
		if resolved_path.is_empty():
			push_error("NPC '%s' has no dialogue resource." % npc_name)
			return
		var dialogue := load(resolved_path) as DialogueResource
		if dialogue == null:
			push_error("NPC '%s' could not load dialogue '%s'." % [npc_name, resolved_path])
			return
		DialogueManager.show_dialogue_balloon(dialogue, resolved_title)


func _stable_actor_id() -> String:
	if not npc_id.is_empty():
		return npc_id
	return str(get_meta(&"npc_id", ""))


func _apply_visual_identity() -> void:
	var sprite := $Sprite2D as Sprite2D
	if sprite == null:
		return
	sprite.region_rect = visual_region
	sprite.modulate = visual_modulate
	sprite.scale = visual_scale
