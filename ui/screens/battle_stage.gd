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


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_cue_layer()
	set_reduced_motion(
		bool(GameState.get_setting(SETTING_SECTION, REDUCED_MOTION_KEY, false))
	)
	if not GameState.setting_changed.is_connected(_on_setting_changed):
		GameState.setting_changed.connect(_on_setting_changed)


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
		queue_redraw()
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
	queue_redraw()


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
	queue_redraw()


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
	queue_redraw()


func _clear_movement_offset(actor_id: StringName) -> void:
	_movement_offsets.erase(actor_id)
	queue_redraw()


func _set_defeat_progress(progress: float, actor_id: StringName) -> void:
	_defeat_progress[actor_id] = progress
	queue_redraw()


func _clear_hit_flash(actor_id: StringName, sequence: int) -> void:
	if int(_hit_flash_sequences.get(actor_id, -1)) == sequence:
		_hit_flash_sequences.erase(actor_id)
		queue_redraw()


func _clear_defining_cue(actor_id: StringName, sequence: int) -> void:
	if int(_defining_sequences.get(actor_id, -1)) == sequence:
		_defining_sequences.erase(actor_id)
		queue_redraw()


func _clear_global_cue(sequence: int) -> void:
	if _global_cue_sequence == sequence:
		_global_cue_sequence = -1
		queue_redraw()


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
		for i in raw_rows.size():
			var raw_row: Variant = raw_rows[i]
			if raw_row is Dictionary and StringName(raw_row.get("id", "")) == actor_id:
				return _base_actor_center(raw_row, i, raw_rows.size())
	return Vector2(size.x * 0.5, size.y * 0.5)


func _base_actor_center(row: Dictionary, index: int, count: int) -> Vector2:
	var w := size.x if size.x > 1.0 else 960.0
	var h := size.y if size.y > 1.0 else 540.0
	var side := str(row.get("side", "ally"))
	var zone := str(row.get("position", "front"))
	var center := Vector2.ZERO
	if side == "ally":
		match zone:
			"back":
				center = Vector2(w * 0.18, h * 0.56)
			"flank":
				center = Vector2(w * 0.29, h * 0.42)
			_:
				center = Vector2(w * 0.34, h * 0.54)
	else:
		match zone:
			"back":
				center = Vector2(w * 0.82, h * 0.52)
			"flank":
				center = Vector2(w * 0.71, h * 0.40)
			_:
				center = Vector2(w * 0.66, h * 0.50)
	var spread := (float(index) - float(count - 1) * 0.5) * minf(72.0, h * 0.08)
	center.y += spread
	center.x += absf(spread) * (-0.08 if side == "ally" else 0.08)
	return center


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return

	for band in range(12):
		var t := float(band) / 11.0
		var color := Color("#17152D").lerp(Color("#07080B"), t)
		draw_rect(Rect2(0, h * 0.72 * t, w, h * 0.72 / 12.0 + 2.0), color)

	var moon := Vector2(w * 0.73, h * 0.24)
	for ring in range(6, 0, -1):
		draw_circle(moon, 42.0 + ring * 18.0, Color(0.45, 0.32, 0.78, 0.015 * ring))
	draw_circle(moon, 42.0, Color("#D9D0FF"))
	draw_circle(moon + Vector2(-10, -8), 34.0, Color("#9E91C9"))

	for mote in range(18):
		var x := fmod(float(mote * 113 + 37), w * 0.78) + w * 0.08
		var y := fmod(float(mote * 67 + 41), h * 0.58) + h * 0.10
		var radius := 1.0 + float(mote % 3) * 0.7
		draw_circle(Vector2(x, y), radius, Color(0.66, 0.55, 0.92, 0.18))

	var horizon := h * 0.48
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)
		]),
		Color("#0D101B"),
	)
	for row_index in range(7):
		var row_y := horizon + pow(float(row_index + 1) / 7.0, 1.8) * h * 0.62
		draw_line(Vector2(0, row_y), Vector2(w, row_y), Color(0.35, 0.31, 0.56, 0.16), 1.0)
	for column in range(-8, 14):
		var top_x := w * 0.5 + column * w * 0.055
		var bottom_x := w * 0.5 + column * w * 0.16
		draw_line(
			Vector2(top_x, horizon), Vector2(bottom_x, h), Color(0.35, 0.31, 0.56, 0.13), 1.0
		)

	_draw_battle_ellipse(
		Vector2(w * 0.73, h * 0.55), Vector2(w * 0.20, h * 0.055), Color(0.48, 0.30, 0.84, 0.16)
	)
	_draw_battle_ellipse(
		Vector2(w * 0.25, h * 0.55), Vector2(w * 0.24, h * 0.07), Color(0.10, 0.55, 0.67, 0.11)
	)

	_draw_side("enemy")
	_draw_side("ally")
	_draw_global_cue(w, h)


func _draw_side(side: String) -> void:
	var rows := _rows_for_side(side)
	for i in rows.size():
		var row := rows[i]
		var actor_id := StringName(row.get("id", ""))
		var center := _base_actor_center(row, i, rows.size()) + Vector2(
			_movement_offsets.get(actor_id, Vector2.ZERO)
		)
		var defeat := float(_defeat_progress.get(actor_id, 0.0))
		center.y += defeat * 18.0
		if side == "enemy":
			_draw_enemy(center, row, actor_id)
		else:
			_draw_ally(center, row, actor_id)
		_draw_actor_cues(center, row, actor_id, defeat)


func _draw_enemy(center: Vector2, foe: Dictionary, actor_id: StringName) -> void:
	var alive := int(foe.get("hp", 0)) > 0
	var display_name := str(foe.get("display_name", ""))
	var body_color := Color("#5F426D") if "wight" in display_name.to_lower() else Color("#604D45")
	if not alive:
		body_color = Color("#2B2A3A")
	elif _hit_flash_sequences.has(actor_id):
		body_color = HIT_COLOR
	var actor_scale := clampf(0.82 + float(foe.get("max_hp", 1)) / 100.0, 0.82, 1.28)
	var c := center + Vector2(0, -34.0 * actor_scale)

	if actor_id == _target_id and alive:
		draw_arc(center + Vector2(0, 14), 78.0 * actor_scale, PI * 0.12, PI * 0.88, 28, DEFINING_COLOR, 3.0, true)
		draw_arc(
			center + Vector2(0, 14), 88.0 * actor_scale, PI * 0.18, PI * 0.82,
			24, Color(0.85, 0.67, 0.27, 0.24), 2.0, true
		)

	var head_color := Color("#B8A5C9") if alive else body_color
	if _hit_flash_sequences.has(actor_id):
		head_color = HIT_COLOR
	draw_circle(c + Vector2(0, -42) * actor_scale, 25.0 * actor_scale, head_color)
	draw_line(c + Vector2(-12, -62) * actor_scale, c + Vector2(-35, -92) * actor_scale, body_color, 5.0 * actor_scale)
	draw_line(c + Vector2(12, -62) * actor_scale, c + Vector2(35, -92) * actor_scale, body_color, 5.0 * actor_scale)
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-40, -18) * actor_scale, c + Vector2(40, -18) * actor_scale,
			c + Vector2(60, 72) * actor_scale, c + Vector2(-62, 72) * actor_scale
		]),
		body_color,
	)
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-10, -18) * actor_scale, c + Vector2(10, -18) * actor_scale,
			c + Vector2(6, 72) * actor_scale, c + Vector2(-6, 72) * actor_scale
		]),
		Color(0.10, 0.08, 0.16, 0.8),
	)
	draw_circle(c + Vector2(-9, -45) * actor_scale, 4.0 * actor_scale, Color("#EF4444") if alive else Color("#343144"))
	draw_circle(c + Vector2(9, -45) * actor_scale, 4.0 * actor_scale, Color("#EF4444") if alive else Color("#343144"))


func _draw_ally(center: Vector2, ally: Dictionary, actor_id: StringName) -> void:
	var alive := int(ally.get("hp", 0)) > 0
	var selected := actor_id == _active_actor_id
	var accent := ORDER_COLOR if selected else Color("#607A96")
	if not alive:
		accent = Color("#303542")
	elif _hit_flash_sequences.has(actor_id):
		accent = HIT_COLOR
	if selected and alive:
		draw_arc(center + Vector2(0, 14), 52.0, PI * 0.18, PI * 0.82, 24, ORDER_COLOR, 3.0, true)
	var head_color := Color("#C2CCD8") if alive else Color("#3A3D49")
	if _hit_flash_sequences.has(actor_id):
		head_color = HIT_COLOR
	draw_circle(center + Vector2(0, -47), 17.0, head_color)
	draw_colored_polygon(
		PackedVector2Array([
			center + Vector2(-24, -29), center + Vector2(20, -29),
			center + Vector2(37, 58), center + Vector2(-38, 58)
		]),
		Color("#283B51") if alive else Color("#20232D"),
	)
	draw_line(center + Vector2(18, -18), center + Vector2(48, 34), accent, 5.0 if selected else 3.0)
	draw_line(center + Vector2(48, 34), center + Vector2(64, 27), accent, 3.0)


func _draw_actor_cues(
	center: Vector2, row: Dictionary, actor_id: StringName, defeat: float
) -> void:
	if actor_id == _active_actor_id and int(row.get("hp", 0)) > 0:
		var marker := center + Vector2(0, -128)
		draw_colored_polygon(PackedVector2Array([
			marker + Vector2(0, -9), marker + Vector2(9, 0),
			marker + Vector2(0, 9), marker + Vector2(-9, 0),
		]), ORDER_COLOR)
		draw_line(marker + Vector2(0, 11), center + Vector2(0, -82), ORDER_COLOR, 2.0)
	if _defining_sequences.has(actor_id):
		draw_arc(center + Vector2(0, -20), 84.0, 0.0, TAU, 40, DEFINING_COLOR, 4.0, true)
		draw_arc(center + Vector2(0, -20), 98.0, 0.0, TAU, 40, Color(0.85, 0.67, 0.27, 0.45), 2.0, true)
	if defeat > 0.0:
		var width := 34.0 * defeat
		draw_line(center + Vector2(-width, -50), center + Vector2(width, 18), Color("#A9A1B8"), 3.0)
		draw_line(center + Vector2(width, -50), center + Vector2(-width, 18), Color("#A9A1B8"), 3.0)


func _draw_global_cue(w: float, h: float) -> void:
	if _global_cue_sequence < 0:
		return
	var color := ORDER_COLOR if _global_cue_balance > 0 else CHAOS_COLOR
	draw_rect(Rect2(Vector2.ZERO, Vector2(w, h)), Color(color.r, color.g, color.b, 0.08))
	draw_rect(Rect2(8, 8, w - 16, h - 16), Color(color.r, color.g, color.b, 0.72), false, 5.0)
	draw_arc(Vector2(w * 0.5, h * 0.48), minf(w, h) * 0.34, 0.0, PI, 56, color, 3.0, true)
	draw_arc(Vector2(w * 0.5, h * 0.48), minf(w, h) * 0.34, PI, TAU, 56, color, 3.0, true)


func _draw_battle_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
