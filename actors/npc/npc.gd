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
## Only relevant when npc_id is empty and no generated unit art applies —
## the default Sprite2D texture is already a painterly crowd figure at 1:1.
@export var visual_region := Rect2(0, 68, 16, 16)
@export var visual_modulate := Color.WHITE
@export var visual_scale := Vector2.ONE

const UnitArtScript := preload("res://globals/unit_art.gd")

var _player_in_range := false
var _prompt: Label
var _collision_layer_default := 0


func _ready() -> void:
	GridPlacement.snap_to_walkable_cell(self, global_position)
	# A standing NPC is a solid body. Overworld click-paths must route around it rather than
	# grind into it (GH #190) — see world/nav/nav_occupancy.gd.
	NavOccupancy.register(self)
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

	# FR-504a routines: a named NPC with a NpcRoutines row is placed (or made
	# absent) per clock phase, on scene load and again on each phase change.
	# An NPC without a row keeps FR-504 flag/rep reactivity — that path does
	# nothing here by design.
	_collision_layer_default = collision_layer
	_apply_routine()
	WorldClock.phase_changed.connect(_on_world_phase_changed)


func _on_world_phase_changed(
	_previous: StringName, _current: StringName, _cause: String
) -> void:
	_apply_routine()


func _apply_routine() -> void:
	if npc_id.is_empty():
		return
	var row := NpcRoutines.placement(npc_id, WorldClock.phase())
	if row.is_empty():
		return
	# Routine positions are HUB_SCENE coordinates; never apply them elsewhere.
	# (A null current_scene — headless test harness — passes through.)
	var scene := get_tree().current_scene if is_inside_tree() else null
	if scene != null and scene.scene_file_path != NpcRoutines.HUB_SCENE:
		return
	var present := bool(row.get("present", false))
	visible = present
	if present:
		var routine_position: Vector2 = row["position"]
		GridPlacement.snap_to_walkable_cell(self, routine_position)
		collision_layer = _collision_layer_default
		process_mode = Node.PROCESS_MODE_INHERIT
		NavOccupancy.register(self)
	else:
		# §2.1 "absent": not findable, not interactable, and — because a solid
		# invisible body would still block clicks and paths — not solid either.
		collision_layer = 0
		process_mode = Node.PROCESS_MODE_DISABLED
		remove_from_group(NavOccupancy.GROUP)
		_player_in_range = false
		_prompt.visible = false


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
	# A scene-authored npc_id (e.g. the hand-placed story NPCs in
	# starting_town.tscn) self-wires to its own generated unit art here;
	# TownNpcSpawner-driven NPCs get theirs later via apply_isometric_visual.
	if not npc_id.is_empty() and apply_isometric_visual(npc_id):
		return
	var sprite := $Sprite2D as Sprite2D
	if sprite == null:
		return
	sprite.region_rect = visual_region
	sprite.modulate = visual_modulate
	sprite.scale = visual_scale


func apply_isometric_visual(model_name: String, facing: String = "east") -> bool:
	var resolved_id := UnitArtScript.resolve(model_name)
	var texture := load(UnitArtScript.texture_path(resolved_id)) as Texture2D
	if texture == null:
		push_error("Could not load generated NPC sprite for '%s'." % model_name)
		return false
	var sprite := get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("NPC '%s' is missing its Sprite2D presentation node." % npc_name)
		return false
	visual_modulate = Color.WHITE
	visual_scale = Vector2.ONE
	sprite.texture = texture
	sprite.region_enabled = false
	sprite.position = Vector2.ZERO
	sprite.offset = UnitArtScript.PIVOT_OFFSET
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	sprite.flip_h = facing == "west"
	return true
