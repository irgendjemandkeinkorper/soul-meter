extends GdUnitTestSuite

const CombatAudioScript := preload("res://audio/combat_audio.gd")


func test_hit_event_maps_to_varied_impact_sounds() -> void:
	var event := _event(&"action_resolved", {"damage": 4})

	assert_str(String(CombatAudioScript.cue_for_event(event))).is_equal("hit")
	assert_array(CombatAudioScript.sound_paths_for_cue(&"hit")).has_size(5)


func test_defining_strike_landing_maps_to_a_distinct_sound() -> void:
	var event := _event(
		&"action_resolved",
		{"damage": 8, "defining_strike": true, "check": {"success": true}},
	)

	assert_str(String(CombatAudioScript.cue_for_event(event))).is_equal("defining_strike")
	assert_array(CombatAudioScript.sound_paths_for_cue(&"defining_strike")).contains_exactly(
		["res://assets/audio/sfx/impactGlass_heavy_003.ogg"]
	)


func test_defining_strike_miss_does_not_play_a_landing_sound() -> void:
	var event := _event(
		&"action_resolved",
		{"damage": 0, "defining_strike": true, "check": {"success": false}},
	)

	assert_str(String(CombatAudioScript.cue_for_event(event))).is_empty()


func test_balance_extreme_event_maps_from_event_payload_only() -> void:
	var extreme := _event(
		&"balance_band_changed",
		{"band_id": &"order_extreme", "effects": {"damage_bonus": 2}},
	)
	var center := _event(
		&"balance_band_changed",
		{"band_id": &"center", "effects": {"damage_bonus": 0}},
	)

	assert_str(String(CombatAudioScript.cue_for_event(extreme))).is_equal("balance_extreme")
	assert_str(String(CombatAudioScript.cue_for_event(center))).is_empty()


func test_every_combat_cue_resolves_to_an_imported_sound() -> void:
	var cues: Array[StringName] = [
		CombatAudioScript.CUE_HIT,
		CombatAudioScript.CUE_DEFINING_STRIKE,
		CombatAudioScript.CUE_BALANCE_EXTREME,
	]
	for cue: StringName in cues:
		var paths := CombatAudioScript.sound_paths_for_cue(cue)
		assert_array(paths).is_not_empty()
		for path: String in paths:
			assert_bool(ResourceLoader.exists(path)).is_true()


func _event(type: StringName, data: Dictionary) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = type
	event.data = data
	return event
