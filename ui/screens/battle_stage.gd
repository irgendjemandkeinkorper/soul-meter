extends Control
## Event-driven battle tableau. CombatEvent snapshots are the only combat input;
## transient feedback never queries Battle or CombatController state.

signal feedback_presented(
	kind: StringName, event_sequence: int, motion_used: bool
)

const SETTING_SECTION := "accessibility"
const REDUCED_MOTION_KEY := "reduced_motion"

const HIT_FLASH_SECONDS := 0.18
const DEFINING_CUE_SECONDS := 0.85
const GLOBAL_CUE_SECONDS := 1.0
const INFORMATION_SECONDS := 1.0
const MOVE_SECONDS := 0.34
const DEFEAT_SECONDS := 0.48

const HIT_COLOR := Color("#F3E8FF")
const DEFINING_COLOR := Color("#D9AB45")
const ORDER_COLOR := Color("#22D3EE")
const CHAOS_COLOR := Color("#B39AF5")

const ENVIRONMENT_NATURE := &"nature"
const ENVIRONMENT_TOWN := &"fantasy-town"
const ENVIRONMENT_CASTLE := &"castle"
const SPRITE_ROOT := "res://assets/generated/sprites"
const SPRITE_PIVOT_OFFSET := Vector2(0.0, -50.596443)
const GROUND_ATLAS := preload("res://assets/generated/sprites/ground/ground_tiles.png")
const UnitArtScript := preload("res://globals/unit_art.gd")

const ENVIRONMENT_TITLES := {
	ENVIRONMENT_NATURE: "WILDS  •  BROKEN GROUND",
	ENVIRONMENT_TOWN: "DOM OUTSKIRTS  •  CONTESTED STREET",
	ENVIRONMENT_CASTLE: "FORTIFIED APPROACH  •  STONE LINE",
}
const ENVIRONMENT_COLORS := {
	ENVIRONMENT_NATURE: Color("#101B1B"),
	ENVIRONMENT_TOWN: Color("#1A171B"),
	ENVIRONMENT_CASTLE: Color("#111621"),
}
const ENVIRONMENT_TILE_REGIONS := {
	ENVIRONMENT_NATURE: Rect2(0, 0, 64, 32),
	ENVIRONMENT_TOWN: Rect2(192, 0, 64, 32),
	ENVIRONMENT_CASTLE: Rect2(128, 0, 64, 32),
}
const ENVIRONMENT_PROPS := {
	ENVIRONMENT_NATURE: [
		{"texture": "nature-kit/tree_pineTallA_detailed.png", "position": Vector2(0.06, 0.36), "scale": 1.55},
		{"texture": "nature-kit/tree_oak_dark.png", "position": Vector2(0.94, 0.35), "scale": 1.35, "flip_h": true},
		{"texture": "nature-kit/tent_detailedOpen.png", "position": Vector2(0.10, 0.57), "scale": 1.15},
		{"texture": "nature-kit/rock_largeE.png", "position": Vector2(0.90, 0.57), "scale": 1.25},
		{"texture": "nature-kit/plant_bushLarge.png", "position": Vector2(0.80, 0.50), "scale": 1.0},
	],
	ENVIRONMENT_TOWN: [
		{"texture": "fantasy-town-kit/wall-wood-door.png", "position": Vector2(0.06, 0.39), "scale": 1.35},
		{"texture": "fantasy-town-kit/wall-broken.png", "position": Vector2(0.94, 0.39), "scale": 1.30, "flip_h": true},
		{"texture": "fantasy-town-kit/stall-green.png", "position": Vector2(0.10, 0.57), "scale": 1.15},
		{"texture": "fantasy-town-kit/fountain-round-detail.png", "position": Vector2(0.89, 0.57), "scale": 1.10},
		{"texture": "fantasy-town-kit/tree-high-round.png", "position": Vector2(0.84, 0.34), "scale": 1.10},
	],
	ENVIRONMENT_CASTLE: [
		{"texture": "castle-kit/tower-square.png", "position": Vector2(0.06, 0.38), "scale": 1.45},
		{"texture": "castle-kit/wall-half.png", "position": Vector2(0.18, 0.48), "scale": 1.30},
		{"texture": "castle-kit/gate.png", "position": Vector2(0.94, 0.40), "scale": 1.45, "flip_h": true},
		{"texture": "castle-kit/flag-banner-long.png", "position": Vector2(0.84, 0.28), "scale": 1.15},
		{"texture": "castle-kit/rocks-large.png", "position": Vector2(0.89, 0.57), "scale": 1.20},
	],
}

const ALLY_UNIT_IDS_BY_NAME := {
	"Vex": "vex",
	"Vex the Unbowed": "vex",
	"Serai-Lun": "serai-lun",
	"Old Grumbrand": "old-grumbrand",
	"Wyneth Hallow-Tide": "wyneth-hallow-tide",
	"Ressa Quickfingers": "ressa-quickfingers",
	"Korrath Ninefold": "korrath-ninefold",
	"Maura Greyfen": "maura-greyfen",
}

var _snapshot: Dictionary = {}
var _target_id: StringName = &""
var _active_actor_id: StringName = &""
var _enemy_turn := false
var _reduced_motion := false

var _movement_offsets: Dictionary = {}
var _hit_flash_sequences: Dictionary = {}
var _defining_sequences: Dictionary = {}
var _defeat_progress: Dictionary = {}
var _defeated_actor_ids: Dictionary = {}

var _feedback_counts: Dictionary = {}
var _feedback_sequences: Dictionary = {}
var _visible_feedback_text: Dictionary = {}

var _motion_tweens: Array[Tween] = []
var _motion_effects: Array[JuiceeEffect] = []

var _cue_layer: Control
var _turn_label: Label
var _special_label: Label
var _global_label: Label
var _channel_generations: Dictionary = {}
var _global_cue_sequence := -1
var _global_cue_balance := 0

var _art_root: Control
var _backdrop: ColorRect
var _environment_layer: Control
var _zone_layer: Control
var _combatant_layer: Control
var _balance_overlay: ColorRect
var _environment_label: Label
var _environment_id: StringName = &""
var _environment_prop_nodes: Array[Sprite2D] = []
var _zone_nodes: Dictionary = {}
var _zone_tiles: Dictionary = {}
var _zone_labels: Dictionary = {}
var _occupied_zones: Dictionary = {}
var _actor_nodes: Dictionary = {}
var _actor_texture_paths: Dictionary = {}


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	_build_art_layers()
	_build_cue_layer()
	set_reduced_motion(
		bool(GameState.get_setting(SETTING_SECTION, REDUCED_MOTION_KEY, false))
	)
	if not GameState.setting_changed.is_connected(_on_setting_changed):
		GameState.setting_changed.connect(_on_setting_changed)
	if not resized.is_connected(_layout_stage_art):
		resized.connect(_layout_stage_art)
	_sync_stage_art()


func consume_event(event: CombatEvent, present_feedback: bool = true) -> void:
	if event == null:
		return
	var previous_snapshot := _snapshot.duplicate(true)
	if event.type == &"battle_started":
		_reset_presentation()
		previous_snapshot.clear()

	var snapshot_value: Variant = event.data.get("snapshot", {})
	if snapshot_value is Dictionary:
		_snapshot = snapshot_value.duplicate(true)
	_update_turn_state(event)
	_update_target(event)

	if not present_feedback:
		_sync_defeated_state()
		_sync_stage_art()
		return

	match event.type:
		&"turn_started":
			_present_turn(event, false)
		&"enemy_turn_started":
			_present_turn(event, true)
		&"action_resolved":
			_present_action(event, previous_snapshot)
		&"balance_band_changed":
			_present_balance_band(event)
		&"battle_finished":
			_present_battle_finished(event)

	_present_new_defeats(event, previous_snapshot)
	_sync_stage_art()


func set_reduced_motion(enabled: bool) -> void:
	if _reduced_motion == enabled:
		Juicee.accessibility.reduced_motion = enabled
		return
	_reduced_motion = enabled
	Juicee.accessibility.reduced_motion = enabled
	if enabled:
		_stop_motion()
		_movement_offsets.clear()
		for actor_id: Variant in _defeat_progress:
			_defeat_progress[actor_id] = 1.0
		var last_text := _latest_feedback_text()
		if not last_text.is_empty():
			_show_static_information(last_text, _active_actor_id, INFORMATION_SECONDS)
	_sync_stage_art()


func is_reduced_motion_enabled() -> bool:
	return _reduced_motion


func feedback_count(kind: StringName) -> int:
	return int(_feedback_counts.get(kind, 0))


func feedback_text(kind: StringName) -> String:
	return str(_visible_feedback_text.get(kind, ""))


func active_motion_count() -> int:
	var count := 0
	for tween: Tween in _motion_tweens:
		if tween != null and tween.is_valid():
			count += 1
	for effect: JuiceeEffect in _motion_effects:
		if effect != null and effect.is_busy():
			count += 1
	return count


func actor_draw_position(actor_id: StringName) -> Vector2:
	return _center_for_snapshot(_snapshot, actor_id) + Vector2(
		_movement_offsets.get(actor_id, Vector2.ZERO)
	)


func environment_id() -> StringName:
	return _environment_id


func combatant_texture_path(actor_id: StringName) -> String:
	return str(_actor_texture_paths.get(actor_id, ""))


func environment_sprite_count() -> int:
	return _environment_prop_nodes.size()


func zone_marker_count() -> int:
	return _zone_nodes.size()


func zone_is_occupied(side: StringName, zone: StringName) -> bool:
	return bool(_occupied_zones.get(_zone_key(side, zone), false))


func zone_marker_position(side: StringName, zone: StringName) -> Vector2:
	return _zone_center(side, zone)


func _build_art_layers() -> void:
	_art_root = Control.new()
	_art_root.name = "BattleArt"
	_art_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	# Actor y-sorting stays relative inside this deep band, so every art sprite
	# remains behind the independently-built battle HUD and command rail.
	_art_root.z_index = -1000
	add_child(_art_root)

	_backdrop = ColorRect.new()
	_backdrop.name = "EnvironmentBackdrop"
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_art_root.add_child(_backdrop)

	_environment_layer = _new_art_layer("EnvironmentSprites", 0)
	_zone_layer = _new_art_layer("BattleZones", 1)
	_combatant_layer = _new_art_layer("CombatantSprites", 2)

	_balance_overlay = ColorRect.new()
	_balance_overlay.name = "BalanceFieldOverlay"
	_balance_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_balance_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_balance_overlay.z_index = 3
	_balance_overlay.visible = false
	_art_root.add_child(_balance_overlay)

	_environment_label = Label.new()
	_environment_label.name = "EnvironmentName"
	_environment_label.theme_type_variation = &"EyebrowLabel"
	_environment_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_environment_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_environment_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_environment_label.z_index = 3
	_art_root.add_child(_environment_label)
	_build_zone_nodes()


func _new_art_layer(layer_name: String, layer_z_index: int) -> Control:
	var layer := Control.new()
	layer.name = layer_name
	layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.z_index = layer_z_index
	_art_root.add_child(layer)
	return layer


func _build_zone_nodes() -> void:
	var tile_offsets := [
		Vector2(-64, 0),
		Vector2.ZERO,
		Vector2(64, 0),
		Vector2(-32, 20),
		Vector2(32, 20),
	]
	for side: StringName in [&"ally", &"enemy"]:
		for zone: StringName in [&"back", &"front", &"flank"]:
			var key := _zone_key(side, zone)
			var zone_node := Node2D.new()
			zone_node.name = "Zone%s%s" % [
				String(side).capitalize(), String(zone).capitalize()
			]
			_zone_layer.add_child(zone_node)
			_zone_nodes[key] = zone_node

			var tiles: Array[Sprite2D] = []
			for tile_offset: Vector2 in tile_offsets:
				var tile := Sprite2D.new()
				tile.name = "GroundTile"
				tile.position = tile_offset
				tile.scale = Vector2(1.35, 1.35)
				tile.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				zone_node.add_child(tile)
				tiles.append(tile)
			_zone_tiles[key] = tiles

			var label := Label.new()
			label.name = "ZoneLabel"
			label.position = Vector2(-90, 43)
			label.size = Vector2(180, 28)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.theme_type_variation = &"EyebrowLabel"
			label.mouse_filter = Control.MOUSE_FILTER_IGNORE
			label.z_index = 2
			zone_node.add_child(label)
			_zone_labels[key] = label


func _sync_stage_art() -> void:
	if not is_instance_valid(_art_root):
		return
	var next_environment := _environment_for_snapshot(_snapshot)
	if next_environment != _environment_id:
		_environment_id = next_environment
		_rebuild_environment()
	_sync_zone_occupancy()
	_sync_combatant_nodes()
	_sync_balance_overlay()
	_layout_stage_art()


func _environment_for_snapshot(source: Dictionary) -> StringName:
	var archetypes: Array[StringName] = []
	var raw_enemies: Variant = source.get("enemies", [])
	if raw_enemies is Array:
		for raw_enemy: Variant in raw_enemies:
			if not raw_enemy is Dictionary:
				continue
			var archetype_id := StringName(raw_enemy.get("archetype_id", ""))
			if not archetype_id.is_empty():
				archetypes.append(archetype_id)
	if &"cleaned-jawbrace-guard" in archetypes:
		return ENVIRONMENT_CASTLE
	if &"mustered-bloodbellow" in archetypes:
		return ENVIRONMENT_TOWN
	return ENVIRONMENT_NATURE


func _rebuild_environment() -> void:
	for child: Node in _environment_layer.get_children():
		child.free()
	_environment_prop_nodes.clear()
	_backdrop.color = Color(ENVIRONMENT_COLORS.get(_environment_id, Color("#101B1B")))
	_environment_label.text = str(
		ENVIRONMENT_TITLES.get(_environment_id, ENVIRONMENT_TITLES[ENVIRONMENT_NATURE])
	)
	_set_zone_textures()

	var definitions: Variant = ENVIRONMENT_PROPS.get(
		_environment_id, ENVIRONMENT_PROPS[ENVIRONMENT_NATURE]
	)
	if not definitions is Array:
		return
	for raw_definition: Variant in definitions:
		if not raw_definition is Dictionary:
			continue
		var relative_path := str(raw_definition.get("texture", ""))
		var texture := load("%s/%s" % [SPRITE_ROOT, relative_path]) as Texture2D
		if texture == null:
			push_warning("Battle environment sprite is missing: %s" % relative_path)
			continue
		var prop := Sprite2D.new()
		prop.name = relative_path.get_file().get_basename().to_pascal_case()
		prop.texture = texture
		prop.offset = SPRITE_PIVOT_OFFSET
		prop.flip_h = bool(raw_definition.get("flip_h", false))
		prop.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		prop.set_meta("normalized_position", raw_definition.get("position", Vector2.ZERO))
		prop.set_meta("base_scale", float(raw_definition.get("scale", 1.0)))
		_environment_layer.add_child(prop)
		_environment_prop_nodes.append(prop)


func _set_zone_textures() -> void:
	var atlas_texture := AtlasTexture.new()
	atlas_texture.atlas = GROUND_ATLAS
	atlas_texture.region = Rect2(
		ENVIRONMENT_TILE_REGIONS.get(
			_environment_id, ENVIRONMENT_TILE_REGIONS[ENVIRONMENT_NATURE]
		)
	)
	for key: Variant in _zone_tiles:
		var raw_tiles: Variant = _zone_tiles[key]
		if not raw_tiles is Array:
			continue
		for raw_tile: Variant in raw_tiles:
			var tile := raw_tile as Sprite2D
			if tile != null:
				tile.texture = atlas_texture


func _sync_zone_occupancy() -> void:
	_occupied_zones.clear()
	for row: Dictionary in _combatant_rows():
		var side := StringName(row.get("side", ""))
		var zone := StringName(row.get("position", "front"))
		if side.is_empty():
			continue
		_occupied_zones[_zone_key(side, zone)] = true

	for key: Variant in _zone_nodes:
		var occupied := bool(_occupied_zones.get(key, false))
		var parts := str(key).split(":")
		var side := StringName(parts[0]) if parts.size() > 0 else &"ally"
		var zone := StringName(parts[1]) if parts.size() > 1 else &"front"
		var color := _zone_color(side, zone, occupied)
		var raw_tiles: Variant = _zone_tiles.get(key, [])
		if raw_tiles is Array:
			for raw_tile: Variant in raw_tiles:
				var tile := raw_tile as Sprite2D
				if tile != null:
					tile.modulate = color
		var label := _zone_labels.get(key) as Label
		if label != null:
			label.text = "%s%s  /  %s" % [
				"◆  " if occupied else "",
				String(side).to_upper(),
				String(zone).to_upper(),
			]
			label.modulate = Color.WHITE if occupied else Color(0.78, 0.78, 0.82, 0.72)


func _zone_color(side: StringName, zone: StringName, occupied: bool) -> Color:
	var color := Color("#496A72") if side == &"ally" else Color("#725064")
	match zone:
		&"back":
			color = Color("#40566E") if side == &"ally" else Color("#67465F")
		&"flank":
			color = Color("#7A633C") if side == &"ally" else Color("#76513D")
	var alpha := 0.90 if occupied else 0.48
	return Color(color.r, color.g, color.b, alpha)


func _layout_stage_art() -> void:
	if not is_instance_valid(_art_root):
		return
	_environment_label.position = Vector2(28, clampf(size.y * 0.11, 18.0, 80.0))
	_environment_label.size = Vector2(minf(420.0, size.x * 0.42), 34)
	var scale_factor := _art_scale()
	for prop: Sprite2D in _environment_prop_nodes:
		var normalized := Vector2(prop.get_meta("normalized_position", Vector2.ZERO))
		prop.position = Vector2(size.x * normalized.x, size.y * normalized.y)
		prop.scale = Vector2.ONE * float(prop.get_meta("base_scale", 1.0)) * scale_factor
	for key: Variant in _zone_nodes:
		var node := _zone_nodes.get(key) as Node2D
		if node == null:
			continue
		var parts := str(key).split(":")
		var side := StringName(parts[0]) if parts.size() > 0 else &"ally"
		var zone := StringName(parts[1]) if parts.size() > 1 else &"front"
		node.position = _zone_center(side, zone)
		node.scale = Vector2.ONE * scale_factor
	_sync_combatant_nodes()


func _art_scale() -> float:
	var width_scale := size.x / 1280.0 if size.x > 1.0 else 1.0
	var height_scale := size.y / 720.0 if size.y > 1.0 else 1.0
	return clampf(minf(width_scale, height_scale), 0.72, 1.25)


func _zone_key(side: StringName, zone: StringName) -> StringName:
	return StringName("%s:%s" % [String(side), String(zone)])


func _zone_center(side: StringName, zone: StringName) -> Vector2:
	var w := size.x if size.x > 1.0 else 960.0
	var h := size.y if size.y > 1.0 else 540.0
	if side == &"ally":
		match zone:
			&"back":
				return Vector2(w * 0.17, h * 0.54)
			&"flank":
				return Vector2(w * 0.29, h * 0.37)
			_:
				return Vector2(w * 0.36, h * 0.55)
	match zone:
		&"back":
			return Vector2(w * 0.83, h * 0.52)
		&"flank":
			return Vector2(w * 0.71, h * 0.35)
		_:
			return Vector2(w * 0.64, h * 0.53)


func _build_cue_layer() -> void:
	_cue_layer = Control.new()
	_cue_layer.name = "CombatFeedback"
	_cue_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cue_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_cue_layer.z_index = 4
	add_child(_cue_layer)

	_turn_label = _cue_label("TurnCue", "EyebrowLabel", 0.38, 38.0)
	_special_label = _cue_label("DefiningStrikeCue", "HeadingLabel", 0.43, 56.0)
	_global_label = _cue_label("BalanceExtremeCue", "HeadingLabel", 0.49, 76.0)


func _cue_label(
	label_name: String, variation: StringName, anchor_y: float, height: float
) -> Label:
	var label := Label.new()
	label.name = label_name
	label.anchor_right = 1.0
	label.anchor_top = anchor_y
	label.anchor_bottom = anchor_y
	label.offset_bottom = height
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.theme_type_variation = variation
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.visible = false
	_cue_layer.add_child(label)
	return label


func _on_setting_changed(section: String, key: String, value: Variant) -> void:
	if section == SETTING_SECTION and key == REDUCED_MOTION_KEY:
		set_reduced_motion(bool(value))


func _update_turn_state(event: CombatEvent) -> void:
	match event.type:
		&"turn_started":
			_active_actor_id = event.actor_id
			_enemy_turn = false
		&"enemy_turn_started":
			_active_actor_id = &""
			_enemy_turn = true
		&"action_resolved":
			if _enemy_turn or _row_side(event.actor_id) == "enemy":
				_active_actor_id = event.actor_id
		&"battle_finished":
			_active_actor_id = &""


func _update_target(event: CombatEvent) -> void:
	if not event.target_id.is_empty():
		_target_id = event.target_id
	var selected := _row_for(_target_id)
	if selected.is_empty() or int(selected.get("hp", 0)) <= 0:
		_target_id = _first_living_enemy_id()


func _present_turn(event: CombatEvent, enemy: bool) -> void:
	var text := "ENEMY TURN" if enemy else "ACTIVE  •  %s" % _display_name_for(event.actor_id).to_upper()
	_show_channel_label(&"turn", _turn_label, text, INFORMATION_SECONDS, not _reduced_motion)
	_record_feedback(&"turn_started", event, not _reduced_motion, text)


func _present_action(event: CombatEvent, previous_snapshot: Dictionary) -> void:
	if int(event.data.get("ap_cost", 0)) > 0:
		_present_ap_spent(event)
	if event.data.has("from") and event.data.has("to"):
		_present_zone_movement(event, previous_snapshot)
	var damage := int(event.data.get("damage", 0))
	if damage > 0:
		_present_hit(event, damage)
	if bool(event.data.get("defining_strike", false)):
		_present_defining_strike(event)


func _present_ap_spent(event: CombatEvent) -> void:
	var ap_cost := int(event.data.get("ap_cost", 0))
	var text := "AP  −%d" % ap_cost
	_present_actor_information(text, event.actor_id, &"ap_spent")
	_record_feedback(&"ap_spent", event, not _reduced_motion, text)


func _present_zone_movement(event: CombatEvent, previous_snapshot: Dictionary) -> void:
	var from_zone := StringName(event.data.get("from", ""))
	var to_zone := StringName(event.data.get("to", ""))
	if from_zone.is_empty() or to_zone.is_empty() or from_zone == to_zone:
		return
	var text := "%s  →  %s" % [
		String(from_zone).to_upper(), String(to_zone).to_upper()
	]
	if not _reduced_motion:
		var from_center := _center_for_snapshot(previous_snapshot, event.actor_id)
		var to_center := _center_for_snapshot(_snapshot, event.actor_id)
		_movement_offsets[event.actor_id] = from_center - to_center
		var tween := create_tween()
		tween.tween_method(
			_set_movement_offset.bind(event.actor_id),
			Vector2(_movement_offsets[event.actor_id]),
			Vector2.ZERO,
			MOVE_SECONDS,
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
		tween.finished.connect(_clear_movement_offset.bind(event.actor_id), CONNECT_ONE_SHOT)
		_track_motion_tween(tween)
	_present_actor_information(text, event.actor_id, &"zone_moved")
	_record_feedback(&"zone_moved", event, not _reduced_motion, text)


func _present_hit(event: CombatEvent, damage: int) -> void:
	var actor_id := event.target_id
	_hit_flash_sequences[actor_id] = event.sequence
	get_tree().create_timer(HIT_FLASH_SECONDS).timeout.connect(
		_clear_hit_flash.bind(actor_id, event.sequence), CONNECT_ONE_SHOT
	)
	var text := "DAMAGE  %d" % damage
	if _reduced_motion:
		_show_static_information(text, actor_id, INFORMATION_SECONDS)
	else:
		var defining := bool(event.data.get("defining_strike", false))
		Juicee.flash(
			self,
			DEFINING_COLOR if defining else HIT_COLOR,
			0.12 if not defining else 0.16,
			1,
		)
		_start_hit_shake(damage, defining)
		_start_damage_number(actor_id, damage, defining)
	_record_feedback(&"hit", event, not _reduced_motion, text)


func _present_defining_strike(event: CombatEvent) -> void:
	var actor_id := event.target_id
	_defining_sequences[actor_id] = event.sequence
	get_tree().create_timer(DEFINING_CUE_SECONDS).timeout.connect(
		_clear_defining_cue.bind(actor_id, event.sequence), CONNECT_ONE_SHOT
	)
	var weakness := str(event.data.get("weakness_name", "NAMED WEAKNESS")).to_upper()
	var text := "DEFINING STRIKE\n%s" % weakness
	_show_channel_label(
		&"defining", _special_label, text, DEFINING_CUE_SECONDS, not _reduced_motion
	)
	if not _reduced_motion:
		Juicee.flash(self, DEFINING_COLOR, 0.16, 1)
	_record_feedback(&"defining_strike", event, not _reduced_motion, text)


func _present_balance_band(event: CombatEvent) -> void:
	var effects: Variant = event.data.get("effects", {})
	if not effects is Dictionary or int(effects.get("damage_bonus", 0)) <= 0:
		return
	_global_cue_sequence = event.sequence
	_global_cue_balance = int(_snapshot.get("balance", 0))
	var pole := "ORDER" if _global_cue_balance > 0 else "CHAOS"
	var text := "%s EXTREME\nTHE WHOLE FIELD SHIFTS" % pole
	_show_channel_label(
		&"balance", _global_label, text, GLOBAL_CUE_SECONDS, not _reduced_motion
	)
	get_tree().create_timer(GLOBAL_CUE_SECONDS).timeout.connect(
		_clear_global_cue.bind(event.sequence), CONNECT_ONE_SHOT
	)
	if not _reduced_motion:
		Juicee.flash(
			self, ORDER_COLOR if _global_cue_balance > 0 else CHAOS_COLOR, 0.18, 1
		)
	_record_feedback(&"balance_extreme", event, not _reduced_motion, text)


func _present_battle_finished(event: CombatEvent) -> void:
	var defeated := StringName(event.data.get("outcome_id", "")) == &"defeat"
	var text := "THE PARTY FALLS" if defeated else "ENCOUNTER RESOLVED"
	_show_channel_label(
		&"result", _turn_label, text, GLOBAL_CUE_SECONDS, not _reduced_motion
	)
	_record_feedback(&"battle_finished", event, not _reduced_motion, text)


func _present_new_defeats(event: CombatEvent, previous_snapshot: Dictionary) -> void:
	for row: Dictionary in _combatant_rows():
		var actor_id := StringName(row.get("id", ""))
		if actor_id.is_empty() or int(row.get("hp", 0)) > 0 or _defeated_actor_ids.has(actor_id):
			continue
		var previous := _row_for_snapshot(previous_snapshot, actor_id)
		if previous.is_empty() or int(previous.get("hp", 0)) <= 0:
			continue
		_defeated_actor_ids[actor_id] = true
		var text := "%s  •  DEFEATED" % str(row.get("display_name", actor_id)).to_upper()
		if _reduced_motion:
			_defeat_progress[actor_id] = 1.0
			_show_static_information(text, actor_id, INFORMATION_SECONDS)
		else:
			_defeat_progress[actor_id] = 0.0
			var tween := create_tween()
			tween.tween_method(
				_set_defeat_progress.bind(actor_id), 0.0, 1.0, DEFEAT_SECONDS
			).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			_track_motion_tween(tween)
			_start_floating_text(actor_id, "DEFEATED")
		_record_feedback(&"defeated", event, not _reduced_motion, text)


func _present_actor_information(
	text: String, actor_id: StringName, _kind: StringName
) -> void:
	if _reduced_motion:
		_show_static_information(text, actor_id, INFORMATION_SECONDS)
	else:
		_start_floating_text(actor_id, text)


func _start_hit_shake(damage: int, defining: bool) -> void:
	var effect := JuiceeShakeControlEffect.new()
	effect.intensity = clampf(3.0 + float(damage) * 0.45, 4.0, 11.0)
	if defining:
		effect.intensity = minf(effect.intensity * 1.3, 13.0)
	effect.duration = 0.16 if not defining else 0.24
	effect.frequency = 18.0
	_track_motion_effect(effect, self)


func _start_damage_number(actor_id: StringName, damage: int, defining: bool) -> void:
	var anchor := _effect_anchor(actor_id, "DamageAnchor")
	var effect := JuiceeDamageNumberEffect.new()
	effect.duration = 0.68 if not defining else 0.82
	effect.rise_distance = 54.0 if not defining else 68.0
	effect.spread = 12.0
	effect.prefix = "−"
	_track_motion_effect(effect, anchor, {"damage": damage, "is_crit": defining}, anchor)


func _start_floating_text(actor_id: StringName, text: String) -> void:
	var anchor := _effect_anchor(actor_id, "InformationAnchor")
	var effect := JuiceeFloatingTextEffect.new()
	effect.duration = 0.72
	effect.travel_distance = 42.0
	effect.spread = 8.0
	effect.pop_in_amount = 0.16
	_track_motion_effect(effect, anchor, {"text": text}, anchor)


func _effect_anchor(actor_id: StringName, prefix: String) -> Node2D:
	var anchor := Node2D.new()
	anchor.name = "%s_%s" % [prefix, String(actor_id)]
	anchor.position = actor_draw_position(actor_id) + Vector2(0, -92)
	add_child(anchor)
	return anchor


func _show_static_information(
	text: String, actor_id: StringName, duration: float
) -> void:
	if not is_instance_valid(_cue_layer):
		return
	var label := Label.new()
	label.name = "StaticCombatInformation"
	label.text = text
	label.theme_type_variation = &"StatLabel"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.size = Vector2(220, 42)
	label.position = actor_draw_position(actor_id) - Vector2(110, 132)
	_cue_layer.add_child(label)
	get_tree().create_timer(duration).timeout.connect(label.queue_free, CONNECT_ONE_SHOT)


func _show_channel_label(
	channel: StringName,
	label: Label,
	text: String,
	duration: float,
	animate: bool,
) -> void:
	var generation := int(_channel_generations.get(channel, 0)) + 1
	_channel_generations[channel] = generation
	label.text = text
	label.visible = true
	label.modulate = Color.WHITE
	label.scale = Vector2.ONE
	if animate:
		var tween := create_tween()
		tween.tween_property(label, "scale", Vector2(1.06, 1.06), 0.12).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
		tween.tween_property(label, "scale", Vector2.ONE, 0.16).set_trans(
			Tween.TRANS_SINE
		).set_ease(Tween.EASE_IN_OUT)
		_track_motion_tween(tween)
	get_tree().create_timer(duration).timeout.connect(
		_hide_channel_label.bind(channel, generation, label), CONNECT_ONE_SHOT
	)


func _record_feedback(
	kind: StringName, event: CombatEvent, motion_used: bool, text: String
) -> void:
	_feedback_counts[kind] = int(_feedback_counts.get(kind, 0)) + 1
	_feedback_sequences[kind] = event.sequence
	_visible_feedback_text[kind] = text
	get_tree().create_timer(INFORMATION_SECONDS).timeout.connect(
		_expire_feedback_text.bind(kind, event.sequence), CONNECT_ONE_SHOT
	)
	feedback_presented.emit(kind, event.sequence, motion_used)


func _latest_feedback_text() -> String:
	var latest_sequence := -1
	var latest_text := ""
	for kind: Variant in _feedback_sequences:
		var sequence := int(_feedback_sequences[kind])
		if sequence >= latest_sequence:
			latest_sequence = sequence
			latest_text = str(_visible_feedback_text.get(kind, ""))
	return latest_text


func _track_motion_tween(tween: Tween) -> void:
	_motion_tweens.append(tween)
	tween.finished.connect(_forget_motion_tween.bind(tween), CONNECT_ONE_SHOT)


func _track_motion_effect(
	effect: JuiceeEffect,
	target: Node,
	params: Dictionary = {},
	cleanup_node: Node = null,
) -> void:
	_motion_effects.append(effect)
	effect.finished.connect(
		_forget_motion_effect.bind(effect, cleanup_node), CONNECT_ONE_SHOT
	)
	effect.stopped.connect(
		_forget_motion_effect.bind(effect, cleanup_node), CONNECT_ONE_SHOT
	)
	effect.apply(target, params)


func _forget_motion_tween(tween: Tween) -> void:
	_motion_tweens.erase(tween)


func _forget_motion_effect(effect: JuiceeEffect, cleanup_node: Node) -> void:
	_motion_effects.erase(effect)
	if is_instance_valid(cleanup_node):
		cleanup_node.queue_free()


func _stop_motion() -> void:
	var tweens := _motion_tweens.duplicate()
	_motion_tweens.clear()
	for tween: Tween in tweens:
		if tween != null and tween.is_valid():
			tween.kill()
	var effects := _motion_effects.duplicate()
	_motion_effects.clear()
	for effect: JuiceeEffect in effects:
		if effect != null and effect.is_busy():
			effect.stop()


func _set_movement_offset(offset: Vector2, actor_id: StringName) -> void:
	_movement_offsets[actor_id] = offset
	_sync_combatant_nodes()


func _clear_movement_offset(actor_id: StringName) -> void:
	_movement_offsets.erase(actor_id)
	_sync_combatant_nodes()


func _set_defeat_progress(progress: float, actor_id: StringName) -> void:
	_defeat_progress[actor_id] = progress
	_sync_combatant_nodes()


func _clear_hit_flash(actor_id: StringName, sequence: int) -> void:
	if int(_hit_flash_sequences.get(actor_id, -1)) == sequence:
		_hit_flash_sequences.erase(actor_id)
		_sync_combatant_nodes()


func _clear_defining_cue(actor_id: StringName, sequence: int) -> void:
	if int(_defining_sequences.get(actor_id, -1)) == sequence:
		_defining_sequences.erase(actor_id)
		_sync_combatant_nodes()


func _clear_global_cue(sequence: int) -> void:
	if _global_cue_sequence == sequence:
		_global_cue_sequence = -1
		_sync_balance_overlay()


func _hide_channel_label(
	channel: StringName, generation: int, label: Label
) -> void:
	if int(_channel_generations.get(channel, -1)) == generation and is_instance_valid(label):
		label.visible = false


func _expire_feedback_text(kind: StringName, sequence: int) -> void:
	if int(_feedback_sequences.get(kind, -1)) == sequence:
		_visible_feedback_text.erase(kind)


func _reset_presentation() -> void:
	_stop_motion()
	_snapshot.clear()
	_target_id = &""
	_active_actor_id = &""
	_enemy_turn = false
	_movement_offsets.clear()
	_hit_flash_sequences.clear()
	_defining_sequences.clear()
	_defeat_progress.clear()
	_defeated_actor_ids.clear()
	_feedback_counts.clear()
	_feedback_sequences.clear()
	_visible_feedback_text.clear()
	_global_cue_sequence = -1
	if is_instance_valid(_turn_label):
		_turn_label.visible = false
	if is_instance_valid(_special_label):
		_special_label.visible = false
	if is_instance_valid(_global_label):
		_global_label.visible = false


func _sync_defeated_state() -> void:
	for row: Dictionary in _combatant_rows():
		if int(row.get("hp", 0)) <= 0:
			var actor_id := StringName(row.get("id", ""))
			_defeated_actor_ids[actor_id] = true
			_defeat_progress[actor_id] = 1.0


func _combatant_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for key in ["allies", "enemies"]:
		var raw_rows: Variant = _snapshot.get(key, [])
		if raw_rows is Array:
			for raw_row: Variant in raw_rows:
				if raw_row is Dictionary:
					result.append(raw_row)
	return result


func _rows_for_side(side: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var key := "allies" if side == "ally" else "enemies"
	var raw_rows: Variant = _snapshot.get(key, [])
	if raw_rows is Array:
		for raw_row: Variant in raw_rows:
			if raw_row is Dictionary:
				result.append(raw_row)
	return result


func _row_for(actor_id: StringName) -> Dictionary:
	return _row_for_snapshot(_snapshot, actor_id)


func _row_for_snapshot(source: Dictionary, actor_id: StringName) -> Dictionary:
	if actor_id.is_empty():
		return {}
	for key in ["allies", "enemies"]:
		var raw_rows: Variant = source.get(key, [])
		if not raw_rows is Array:
			continue
		for raw_row: Variant in raw_rows:
			if raw_row is Dictionary and StringName(raw_row.get("id", "")) == actor_id:
				return raw_row
	return {}


func _row_side(actor_id: StringName) -> String:
	return str(_row_for(actor_id).get("side", ""))


func _display_name_for(actor_id: StringName) -> String:
	var row := _row_for(actor_id)
	return str(row.get("display_name", actor_id)) if not row.is_empty() else String(actor_id)


func _first_living_enemy_id() -> StringName:
	for row: Dictionary in _rows_for_side("enemy"):
		if int(row.get("hp", 0)) > 0:
			return StringName(row.get("id", ""))
	return &""


func _center_for_snapshot(source: Dictionary, actor_id: StringName) -> Vector2:
	for key in ["allies", "enemies"]:
		var raw_rows: Variant = source.get(key, [])
		if not raw_rows is Array:
			continue
		for raw_row: Variant in raw_rows:
			if not raw_row is Dictionary or StringName(raw_row.get("id", "")) != actor_id:
				continue
			var zone := StringName(raw_row.get("position", "front"))
			var zone_index := 0
			var zone_count := 0
			for candidate: Variant in raw_rows:
				if not candidate is Dictionary:
					continue
				if StringName(candidate.get("position", "front")) != zone:
					continue
				if StringName(candidate.get("id", "")) == actor_id:
					zone_index = zone_count
				zone_count += 1
			return _base_actor_center(raw_row, zone_index, zone_count)
	return Vector2(size.x * 0.5, size.y * 0.5)


func _base_actor_center(row: Dictionary, index: int, count: int) -> Vector2:
	var side := StringName(row.get("side", "ally"))
	var zone := StringName(row.get("position", "front"))
	var center := _zone_center(side, zone)
	var h := size.y if size.y > 1.0 else 540.0
	var zone_spread := clampf(h * 0.20, 60.0, 76.0)
	var spread := (float(index) - float(maxi(count, 1) - 1) * 0.5) * zone_spread
	center.y += spread
	center.x += absf(spread) * (-0.08 if side == &"ally" else 0.08)
	return center


func _sync_combatant_nodes() -> void:
	if not is_instance_valid(_combatant_layer):
		return
	var visible_actor_ids: Dictionary = {}
	for row: Dictionary in _combatant_rows():
		var actor_id := StringName(row.get("id", ""))
		if actor_id.is_empty():
			continue
		visible_actor_ids[actor_id] = true
		var node := _actor_nodes.get(actor_id) as Node2D
		if node == null:
			node = _create_combatant_node(actor_id)
			_actor_nodes[actor_id] = node
		_update_combatant_node(node, row, actor_id)

	for raw_actor_id: Variant in _actor_nodes.keys():
		if visible_actor_ids.has(raw_actor_id):
			continue
		var stale_node := _actor_nodes.get(raw_actor_id) as Node2D
		if stale_node != null:
			stale_node.free()
		_actor_nodes.erase(raw_actor_id)
		_actor_texture_paths.erase(raw_actor_id)


func _create_combatant_node(actor_id: StringName) -> Node2D:
	var node := Node2D.new()
	node.name = "Combatant_%s" % String(actor_id).replace("-", "_").to_pascal_case()
	_combatant_layer.add_child(node)

	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.offset = UnitArtScript.PIVOT_OFFSET
	node.add_child(sprite)

	var identity := Label.new()
	identity.name = "Identity"
	identity.position = Vector2(-105, -146)
	identity.size = Vector2(210, 42)
	identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	identity.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	identity.theme_type_variation = &"EyebrowLabel"
	identity.mouse_filter = Control.MOUSE_FILTER_IGNORE
	identity.z_index = 2
	node.add_child(identity)

	var marker := Label.new()
	marker.name = "StateMarker"
	marker.position = Vector2(-105, -178)
	marker.size = Vector2(210, 32)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	marker.theme_type_variation = &"StatLabel"
	marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marker.z_index = 3
	node.add_child(marker)
	return node


func _update_combatant_node(
	node: Node2D, row: Dictionary, actor_id: StringName
) -> void:
	var side := StringName(row.get("side", "ally"))
	var alive := int(row.get("hp", 0)) > 0
	var texture_path := _sprite_path_for(row)
	var sprite := node.get_node_or_null("Sprite") as Sprite2D
	var visual_scale := _art_scale()
	if sprite != null and str(_actor_texture_paths.get(actor_id, "")) != texture_path:
		sprite.texture = load(texture_path) as Texture2D
		_actor_texture_paths[actor_id] = texture_path
	if sprite != null:
		sprite.flip_h = side == &"enemy"
		var defeat := float(_defeat_progress.get(actor_id, 0.0))
		var base_scale := _combatant_scale(row) * visual_scale
		sprite.scale = Vector2(base_scale, base_scale * (1.0 - defeat * 0.34))
		sprite.rotation = (0.42 if side == &"enemy" else -0.42) * defeat
		var tint := _combatant_tint(row)
		if _hit_flash_sequences.has(actor_id) and alive:
			tint = HIT_COLOR
		elif not alive:
			tint = Color("#777884")
			tint.a = 0.52
		sprite.modulate = tint

	var center := _center_for_snapshot(_snapshot, actor_id)
	center += Vector2(_movement_offsets.get(actor_id, Vector2.ZERO))
	center.y += float(_defeat_progress.get(actor_id, 0.0)) * 18.0
	node.position = center
	node.z_index = clampi(int(center.y), 0, 1000)

	var identity := node.get_node_or_null("Identity") as Label
	if identity != null:
		identity.position.y = -146.0 * visual_scale
		identity.text = "%s\n%s" % [
			str(row.get("display_name", actor_id)).to_upper(),
			str(row.get("position", "front")).to_upper(),
		]
		identity.modulate = Color.WHITE if alive else Color(0.65, 0.65, 0.70, 0.62)

	var markers: Array[String] = []
	if actor_id == _active_actor_id and alive:
		markers.append("◆ ACTIVE")
	if actor_id == _target_id and alive:
		markers.append("◎ TARGET")
	if _defining_sequences.has(actor_id):
		markers.append("✦ DEFINED")
	var marker := node.get_node_or_null("StateMarker") as Label
	if marker != null:
		marker.position.y = -178.0 * visual_scale
		if center.y + marker.position.y < 2.0:
			marker.position.y = 2.0 - center.y
			if identity != null:
				identity.position.y = 30.0 - center.y
		marker.text = "   ".join(markers)
		marker.modulate = (
			DEFINING_COLOR
			if _defining_sequences.has(actor_id)
			else (ORDER_COLOR if side == &"ally" else Color("#E8B5CD"))
		)


func _sprite_path_for(row: Dictionary) -> String:
	var side := StringName(row.get("side", "ally"))
	var unit_id := ""
	if side == &"enemy":
		unit_id = String(StringName(row.get("archetype_id", "")))
	else:
		var display_name := str(row.get("display_name", ""))
		unit_id = str(ALLY_UNIT_IDS_BY_NAME.get(display_name, display_name))
	return UnitArtScript.texture_path(UnitArtScript.resolve(unit_id))


func _combatant_scale(row: Dictionary) -> float:
	if StringName(row.get("side", "ally")) == &"ally":
		return 2.70
	return clampf(2.68 + float(row.get("max_hp", 1)) / 180.0, 2.72, 3.15)


func _combatant_tint(_row: Dictionary) -> Color:
	# Painterly unit art is already fully colored/shaded — tinting it (as the
	# old flat mini-characters kit needed for per-archetype variety) would
	# just wash out the detail.
	return Color.WHITE


func _sync_balance_overlay() -> void:
	if not is_instance_valid(_balance_overlay):
		return
	_balance_overlay.visible = _global_cue_sequence >= 0
	if not _balance_overlay.visible:
		return
	var color := ORDER_COLOR if _global_cue_balance > 0 else CHAOS_COLOR
	_balance_overlay.color = Color(color.r, color.g, color.b, 0.10)
