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


## #281 G4: the card says who acted on whom, from the event's own snapshot.
func test_headline_names_attacker_and_target() -> void:
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.actor_id = &"vex"
	event.target_id = &"wight"
	event.data = {"damage": 11, "hit": true, "snapshot": {
		"allies": [{"id": "vex", "display_name": "Vex the Unbowed"}],
		"enemies": [{"id": "wight", "display_name": "Bog Wight"}],
	}}
	assert_str(Feedback.headline(event)).is_equal("Vex the Unbowed → Bog Wight")
	var card := auto_free((load("res://ui/hud/combat_result.tscn") as PackedScene).instantiate()) as Control
	var parent := auto_free(Node2D.new()) as Node2D
	add_child(parent)
	parent.add_child(card)
	card.call("setup", event, func() -> Vector2: return Vector2.ZERO, func() -> Rect2: return Rect2(0, 0, 800, 600))
	assert_str((card.get_node("Column/TargetName") as Label).text).is_equal("Vex the Unbowed → Bog Wight")
	assert_str((card.get_node("Column/Outcome") as Label).text).is_equal("11 DAMAGE")
	# Self-targeted, or an actor the snapshot does not list: the target alone.
	event.actor_id = &"wight"
	assert_str(Feedback.headline(event)).is_equal("Bog Wight")
	event.actor_id = &""
	assert_str(Feedback.headline(event)).is_equal("Bog Wight")
