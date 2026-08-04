class_name TownNpcSpawner
extends Node
## Populates Dom's outdoor townsfolk from the generated roster and placement data.
## Positions and dialogue routes stay downstream of Pandora; this scene owns only
## the runtime wiring for deterministic 3D-rendered sprite presentation.

const NPC_SCENE: PackedScene = preload("res://actors/npc/npc.tscn")
const SpriteCatalog := preload("res://assets/generated/sprites/isometric_sprite_catalog.gd")

const ROSTER_PATH := "res://data/generated/dom_npc_roster.json"
const PLACEMENTS_PATH := "res://data/generated/dom_npc_placements.json"
const MANIFEST_PATH := "res://assets/generated/sprites/manifest.json"
const TOWN_SCENE_PATH := "res://world/starting_town.tscn"
const CHARACTER_KIT := "mini-characters"
const GENERATED_GROUP := &"generated_townsfolk"
const GENERATED_INTERACTION_RADIUS := 48.0
const IDLE_AMPLITUDE := 1.25
const IDLE_PERIOD := 2.8
const IDLE_ROTATION_DEGREES := 0.4

var _spawned_npcs: Array[NPC] = []
var _idle_sprites: Array[Sprite2D] = []
var _idle_origins: Array[Vector2] = []
var _idle_phases: Array[float] = []
var _idle_elapsed := 0.0


func _ready() -> void:
	# All pre-authored siblings must finish _ready() before their flat placeholder
	# presentation is replaced. The deferred call also keeps scene instantiation
	# deterministic for SceneRunner integration tests.
	set_process(false)
	call_deferred(&"_populate_town")


func _process(delta: float) -> void:
	_idle_elapsed = fposmod(_idle_elapsed + delta, IDLE_PERIOD)
	var base_phase := (_idle_elapsed / IDLE_PERIOD) * TAU
	for index: int in _idle_sprites.size():
		var sprite := _idle_sprites[index]
		var wave := sin(base_phase + _idle_phases[index])
		sprite.position = _idle_origins[index] + Vector2(0.0, wave * IDLE_AMPLITUDE)
		sprite.rotation = deg_to_rad(wave * IDLE_ROTATION_DEGREES)


func spawned_npcs() -> Array[NPC]:
	return _spawned_npcs.duplicate()


static func sprite_models() -> PackedStringArray:
	var manifest := _read_json_dictionary(MANIFEST_PATH)
	var kits_value: Variant = manifest.get("kits", {})
	if not kits_value is Dictionary:
		return PackedStringArray()
	var records_value: Variant = (kits_value as Dictionary).get(CHARACTER_KIT, {})
	if not records_value is Dictionary:
		return PackedStringArray()
	var result := PackedStringArray()
	for model_name: String in records_value:
		result.append(model_name)
	result.sort()
	return result


func _populate_town() -> void:
	if not _spawned_npcs.is_empty():
		return
	var town := get_parent() as Node2D
	if town == null:
		push_error("TownNpcSpawner must be a direct child of a Node2D town scene.")
		return
	var models := sprite_models()
	if models.is_empty():
		push_error("No generated mini-character sprites are registered in the manifest.")
		return

	_upgrade_legacy_townsfolk(town, models)
	_spawn_generated_townsfolk(town, models)
	set_process(not _idle_sprites.is_empty())


func _upgrade_legacy_townsfolk(town: Node2D, models: PackedStringArray) -> void:
	var model_index := 0
	for child: Node in town.get_children():
		if not child is NPC:
			continue
		var npc := child as NPC
		_apply_isometric_visual(npc, models[model_index % models.size()])
		model_index += 1


func _spawn_generated_townsfolk(town: Node2D, models: PackedStringArray) -> void:
	var roster_data := _read_json_dictionary(ROSTER_PATH)
	var placements_data := _read_json_dictionary(PLACEMENTS_PATH)
	var roster_value: Variant = roster_data.get("npcs", {})
	var placements_value: Variant = placements_data.get("placements", {})
	if not roster_value is Dictionary or not placements_value is Dictionary:
		push_error("Generated Dom NPC data does not contain dictionary records.")
		return
	var roster := roster_value as Dictionary
	var placements := placements_value as Dictionary
	var outdoor_ids := PackedStringArray()
	for npc_id: String in placements:
		var placement_value: Variant = placements[npc_id]
		if placement_value is Dictionary and placement_value.get("scene", "") == TOWN_SCENE_PATH:
			outdoor_ids.append(npc_id)
	outdoor_ids.sort()

	for index in outdoor_ids.size():
		var npc_id := outdoor_ids[index]
		var row_value: Variant = roster.get(npc_id, {})
		var placement_value: Variant = placements.get(npc_id, {})
		if not row_value is Dictionary or not placement_value is Dictionary:
			push_error("Missing generated roster or placement row for '%s'." % npc_id)
			continue
		var row := row_value as Dictionary
		var placement := placement_value as Dictionary
		var anchor := town.find_child(str(placement.get("anchor", "")), true, false) as Node2D
		if anchor == null:
			push_error("Missing outdoor NPC anchor '%s'." % placement.get("anchor", ""))
			continue
		var offset_value: Variant = placement.get("offset", [])
		if not offset_value is Array or offset_value.size() != 2:
			push_error("Invalid outdoor NPC offset for '%s'." % npc_id)
			continue

		var npc := NPC_SCENE.instantiate() as NPC
		if npc == null:
			push_error("Could not instantiate the NPC scene for '%s'." % npc_id)
			continue
		var dialogue_value: Variant = row.get("dialogue", {})
		var portrait_value: Variant = row.get("portrait", {})
		if not dialogue_value is Dictionary or not portrait_value is Dictionary:
			npc.free()
			push_error("Missing dialogue or portrait data for '%s'." % npc_id)
			continue
		var dialogue := dialogue_value as Dictionary
		var portrait := portrait_value as Dictionary
		var model_index := int(placement.get("model_index", index))
		var model_name := models[posmod(model_index, models.size())]
		var facing := str(placement.get("facing", "east"))
		var idle_phase := float(placement.get("idle_phase", 0.0))
		npc.name = _node_name(npc_id)
		npc.npc_name = str(row.get("display_name", npc_id))
		npc.dialogue_path = str(dialogue.get("path", ""))
		npc.dialogue_start = str(dialogue.get("title", ""))
		npc.position = town.to_local(anchor.global_position) + Vector2(
			float(offset_value[0]), float(offset_value[1])
		)
		npc.set_meta(&"npc_id", npc_id)
		npc.set_meta(&"portrait_id", str(portrait.get("id", "")))
		npc.set_meta(&"facing", facing)
		npc.set_meta(&"idle_phase", idle_phase)
		npc.set_meta(&"model_index", model_index)
		_apply_isometric_visual(npc, model_name, facing)
		town.add_child(npc)
		_set_generated_interaction_radius(npc)
		_register_idle(npc, idle_phase)
		npc.add_to_group(GENERATED_GROUP)
		_spawned_npcs.append(npc)


func _apply_isometric_visual(npc: NPC, model_name: String, facing: String = "east") -> void:
	var texture_path := SpriteCatalog.texture_path(CHARACTER_KIT, model_name)
	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_error("Could not load generated townsfolk sprite: " + texture_path)
		return
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		push_error("NPC '%s' is missing its Sprite2D presentation node." % npc.name)
		return
	npc.visual_modulate = Color.WHITE
	npc.visual_scale = Vector2.ONE
	sprite.texture = texture
	sprite.region_enabled = false
	sprite.position = Vector2.ZERO
	sprite.offset = SpriteCatalog.SPRITE_PIVOT_OFFSET
	sprite.scale = Vector2.ONE
	sprite.modulate = Color.WHITE
	sprite.flip_h = facing == "west"
	npc.set_meta(&"sprite_model", model_name)
	npc.set_meta(&"sprite_path", texture_path)


func _register_idle(npc: NPC, idle_phase: float) -> void:
	var sprite := npc.get_node_or_null("Sprite2D") as Sprite2D
	if sprite == null:
		return
	_idle_sprites.append(sprite)
	_idle_origins.append(sprite.position)
	_idle_phases.append(fposmod(idle_phase, TAU))


static func _set_generated_interaction_radius(npc: NPC) -> void:
	var areas := npc.find_children("*", "Area2D", true, false)
	if areas.size() != 1:
		push_error("Generated NPC '%s' does not have exactly one interaction area." % npc.name)
		return
	var area := areas[0] as Area2D
	var shape_nodes := area.find_children("*", "CollisionShape2D", true, false)
	if shape_nodes.size() != 1:
		push_error("Generated NPC '%s' interaction area has no collision shape." % npc.name)
		return
	var shape_node := shape_nodes[0] as CollisionShape2D
	var circle := shape_node.shape as CircleShape2D
	if circle == null:
		push_error("Generated NPC '%s' interaction area is not circular." % npc.name)
		return
	circle.radius = GENERATED_INTERACTION_RADIUS


static func _read_json_dictionary(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("Missing generated NPC artifact: " + path)
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		push_error("Generated NPC artifact is not a JSON dictionary: " + path)
		return {}
	return parsed as Dictionary


static func _node_name(npc_id: String) -> String:
	var result := ""
	for part: String in npc_id.split("-", false):
		result += part.capitalize()
	return result
