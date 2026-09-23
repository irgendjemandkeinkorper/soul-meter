extends GdUnitTestSuite

const Feedback := preload("res://ui/hud/hit_pulse.gd")


func test_damage_zero_miss_and_fizzle_are_distinct_and_only_resolved_attacks_qualify() -> void:
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.target_id = &"target"
	for row: Dictionary in [
		{"damage": 13, "resolution": {"hit": true}, "expected": "13 DAMAGE"},
		{"damage": 0, "hit": true, "expected": "NO DAMAGE"},
		{"damage": 0, "resolution": {"hit": false}, "expected": "MISS"},
		{"damage": 0, "resolution": {"hit": true, "fizzled": true}, "expected": "FIZZLE"},
	]:
		event.data = row.duplicate(true)
		assert_bool(Feedback.has_result(event)).is_true()
		assert_str(Feedback.result_text(event)).is_equal(row["expected"])
	event.data = {"damage": 0, "action_id": "guard"}
	assert_bool(Feedback.has_result(event)).is_false()
	event.data = {"damage": 0, "resolution": {"hit": true, "direct_damage_enabled": false}}
	assert_bool(Feedback.has_result(event)).is_false()
	event.data = {"damage": 13, "hit": true}
	event.type = &"forecast"
	assert_bool(Feedback.has_result(event)).is_false()
	event.type = &"action_resolved"
	event.data["path_cells"] = [Vector2i.ZERO, Vector2i.ONE]
	assert_bool(Feedback.has_result(event)).is_false()


func test_injury_uses_committed_record_severity_and_provenance_without_mutation() -> void:
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.actor_id = &"attacker"
	event.target_id = &"target"
	event.data = {"damage": 13, "resolution": {
		"hit": true, "battle_id": "battle", "tick": 4, "ability_id": "strike",
		"injury": {"applies": true, "location_id": "arm", "severity": "serious"},
	}, "snapshot": {"enemies": [{
		"id": "target", "anatomy": {"arm": {"display_name": "Shield arm"}},
		"injuries": {"arm": {"severity": "minor", "applications": 2, "source_key": "battle|4|attacker|strike"}},
	}]}}
	var before := event.to_dict()
	assert_str(Feedback.injury_text(event)).is_equal("SHIELD ARM · MINOR INJURY\nREFRESHED")
	assert_dict(event.to_dict()).is_equal(before)
	event.data["snapshot"]["enemies"][0]["injuries"]["arm"]["source_key"] = "earlier-action"
	assert_str(Feedback.injury_text(event)).is_empty()
	event.data["snapshot"]["enemies"][0]["injuries"]["arm"]["source_key"] = "battle|4|attacker|strike"
	event.data["resolution"]["injury"]["applies"] = false
	assert_str(Feedback.injury_text(event)).is_empty()
	event.data["resolution"]["injury"]["applies"] = true
	event.data["resolution"]["hit"] = false
	assert_str(Feedback.injury_text(event)).is_empty()
