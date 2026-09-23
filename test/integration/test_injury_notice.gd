extends GdUnitTestSuite


func test_notice_queues_committed_records_without_overwriting_open_details() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var notice := interface.injury_notice
	var first := _event("arm", "minor", {"attack_accuracy_pp": -10})
	interface.consume_event(first)
	assert_bool(notice.visible).is_true()
	assert_str(notice.heading.text).is_equal("VEX — SHIELD ARM")
	assert_str(notice.severity.text).is_equal("MINOR INJURY")
	assert_bool(notice.details.visible).is_false()
	notice.details_toggle.grab_focus()
	runner.simulate_action_pressed("ui_accept")
	await runner.simulate_frames(1)
	assert_bool(notice.details.visible).is_true()
	assert_str(notice.details.text).contains("Attack accuracy: -10 percentage points")
	assert_str(notice.details.text).contains("Clears when combat ends.")
	interface.consume_event(first) # Replaying the same record revision adds no second notice.
	assert_int(notice.pending_count()).is_equal(0)
	var next := _event("throat", "serious", {"voice_blocked": true, "vocal_accuracy_pp": -25})
	interface.consume_event(next)
	assert_int(notice.pending_count()).is_equal(1)
	assert_bool(notice.details.visible).is_true()
	assert_str(notice.heading.text).contains("SHIELD ARM")
	assert_str(notice.dismiss_button.text).is_equal("Next (1)")
	notice.dismiss_button.grab_focus()
	runner.simulate_action_pressed("ui_accept")
	await runner.simulate_frames(1)
	assert_str(notice.heading.text).contains("THROAT")
	assert_str(notice.severity.text).is_equal("SERIOUS INJURY")
	assert_bool(notice.details.visible).is_false()
	assert_str(notice.details.text).contains("Vocal accuracy: -25 percentage points")
	assert_str(notice.details.text).contains("Actions requiring a voice are blocked.")
	assert_str(notice.details.text).contains("Persists after combat until treated.")
	runner.simulate_action_pressed("ui_accept")
	await runner.simulate_frames(1)
	assert_bool(notice.visible).is_false()
	interface.consume_event(next)
	assert_bool(notice.visible).is_false()


func test_refresh_shows_actual_retained_penalties_and_battle_reset_clears_queue() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var notice := interface.injury_notice
	var event := _event("leg", "minor", {"move_cost_percent": 50})
	event.data["refreshed"] = true
	event.data["record"]["applications"] = 2
	var before := event.to_dict()
	interface.consume_event(event)
	assert_dict(event.to_dict()).is_equal(before)
	assert_str(notice.severity.text).is_equal("MINOR INJURY · REFRESHED")
	assert_str(notice.details.text).contains("Movement cost: +50%")
	assert_str(notice.details.text).contains("penalties do not stack")
	interface.consume_event(_event("head", "serious", {"sight_accuracy_pp": -30}))
	assert_int(notice.pending_count()).is_equal(1)
	var started := CombatEvent.new()
	started.type = &"battle_started"
	interface.consume_event(started)
	assert_bool(notice.visible).is_false()
	assert_int(notice.pending_count()).is_equal(0)
	interface.consume_event(event)
	assert_bool(notice.visible).is_true()
	interface.bind_controller(null) # The live screen binds after replaying historical events.
	assert_bool(notice.visible).is_false()


func test_forecasts_and_noninjuring_events_do_not_announce_injuries() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	for event_type: StringName in [&"battle_snapshot", &"action_resolved", &"action_refused"]:
		var event := _event("arm", "minor", {"attack_accuracy_pp": -10})
		event.type = event_type
		interface.consume_event(event)
		assert_bool(interface.injury_notice.visible).is_false()
	var not_applied := _event("arm", "minor", {})
	not_applied.data["applied"] = false
	interface.consume_event(not_applied)
	assert_bool(interface.injury_notice.visible).is_false()


func test_active_badge_click_opens_live_details_and_treatment_removes_them() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var event := _active_badge_event()
	var before := event.to_dict()
	interface.consume_event(event)
	await runner.simulate_frames(2)
	var plate := interface.active_unit_plate
	var badge := plate.injury_button("arm")
	assert_str(badge.text).is_equal("SHIELD ARM · SERIOUS")
	assert_int(plate.injury_badges.get_child_count()).is_equal(1)
	assert_bool(interface.injury_notice.visible).is_false()
	assert_bool(interface.injury_inspector.visible).is_false()
	runner.simulate_mouse_move(badge.get_global_rect().get_center())
	runner.simulate_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	await runner.simulate_frames(1)
	var inspector := interface.injury_inspector
	assert_bool(inspector.visible).is_true()
	assert_bool(inspector.details.visible).is_true()
	assert_str(inspector.heading.text).is_equal("VEX — SHIELD ARM")
	assert_str(inspector.details.text).contains("Attack accuracy: -20 percentage points")
	assert_str(inspector.dismiss_button.text).is_equal("Close")
	assert_dict(event.to_dict()).is_equal(before)
	# Ordinary updates preserve both the open detail and the existing button/focus.
	badge.grab_focus()
	event.data["snapshot"]["allies"][0]["hp"] = 80
	interface.consume_event(event)
	assert_object(plate.injury_button("arm")).is_same(badge)
	assert_bool(badge.has_focus()).is_true()
	assert_bool(inspector.visible).is_true()
	event.data["snapshot"]["allies"][0]["injuries"] = {}
	interface.consume_event(event)
	assert_bool(inspector.visible).is_false()
	assert_bool(plate.injury_badges.visible).is_false()
	assert_object(plate.injury_button("arm")).is_null()


func test_badge_keyboard_inspection_closes_on_turn_change_and_does_not_reopen_after_close() -> void:
	var runner := scene_runner("res://ui/hud/battle_interface.tscn")
	var interface := runner.scene() as BattleInterface
	var event := _active_badge_event()
	interface.consume_event(event)
	await runner.simulate_frames(1)
	interface.active_unit_plate.injury_button("arm").grab_focus()
	runner.simulate_action_pressed("ui_accept")
	await runner.simulate_frames(1)
	assert_bool(interface.injury_inspector.visible).is_true()
	interface.injury_inspector.dismiss_button.grab_focus()
	runner.simulate_action_pressed("ui_accept")
	await runner.simulate_frames(1)
	interface.consume_event(event)
	assert_bool(interface.injury_inspector.visible).is_false()
	interface.active_unit_plate.injury_button("arm").pressed.emit()
	event.data["snapshot"]["active_actor_id"] = "enemy"
	interface.consume_event(event)
	assert_bool(interface.injury_inspector.visible).is_false()
	assert_object(interface.active_unit_plate.injury_button("arm")).is_null()
	assert_str(interface.active_unit_plate.injury_button("leg").text).is_equal("LEG · MINOR")
	interface.active_unit_plate.injury_button("leg").pressed.emit()
	assert_str(interface.injury_inspector.heading.text).contains("BOG WIGHT — LEG")
	assert_str(interface.injury_inspector.details.text).contains("Movement cost: +50%")
	event.data["snapshot"]["active_actor_id"] = ""
	interface.consume_event(event)
	assert_bool(interface.injury_inspector.visible).is_false()
	assert_bool(interface.active_unit_plate.injury_badges.visible).is_false()


func _active_badge_event() -> CombatEvent:
	var event := CombatEvent.new()
	event.type = &"battle_snapshot"
	event.data = {"snapshot": {
		"active_actor_id": "vex",
		"allies": [{"id": "vex", "display_name": "Vex", "hp": 100, "max_hp": 100,
			"anatomy": {"arm": {"display_name": "Shield arm"}},
			"injuries": {"arm": {"severity": "serious", "effects": {"attack_accuracy_pp": -20}}}}],
		"enemies": [{"id": "enemy", "display_name": "Bog Wight", "hp": 100,
			"injuries": {"leg": {"severity": "minor", "effects": {"move_cost_percent": 50}}}}],
	}}
	return event


func _event(location: String, severity: String, effects: Dictionary) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = &"injury_applied"
	event.target_id = &"vex"
	event.data = {
		"applied": true, "refreshed": false,
		"record": {
			"instance_id": location + "-instance", "applications": 1,
			"location_id": location, "severity": severity, "effects": effects,
		},
		"snapshot": {"allies": [{"id": "vex", "display_name": "Vex", "hp": 100,
			"anatomy": {"arm": {"display_name": "Shield arm"}}}]},
	}
	return event
