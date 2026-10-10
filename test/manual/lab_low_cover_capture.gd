extends GdUnitTestSuite
## Rendered check of the combat lab's low-cover called-shot fixture: torso hidden, throat open.
## The F3 overlay that printed the aim quote was retired in E2.5b (#337); the quote is read from
## the model feed the Weftlumin combat panel renders (its rendered capture lives in
## test/integration/test_weftlumin_panels.gd).

const CombatLabScript := preload("res://weftlumin/panels/models/combat_lab.gd")

var _game_state_before: Dictionary
var _skill_check_before: Dictionary


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)
	_skill_check_before = SkillCheck.to_dict().duplicate(true)


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	GameState.from_dict(_game_state_before)
	SkillCheck.from_dict(_skill_check_before)
	get_tree().paused = false


func test_low_cover_fixture_renders_its_refusal_and_open_throat() -> void:
	var scene: Node = (load("res://world/test_room.tscn") as PackedScene).instantiate()
	add_child(scene)
	auto_free(scene)
	await get_tree().process_frame
	var lab := auto_free(CombatLabScript.new()) as Node
	add_child(lab)
	assert_bool(bool(lab.call("host_in_panel", CombatLabScript.SANDBOX_OWNER))).is_true()
	var party_ids: Array[StringName] = []
	for member: PartyMember in GameState.party:
		party_ids.append(member.id)
	lab.call("start_test_session", {
		"encounter_id": EncounterIds.BOG_WIGHT, "party_ids": party_ids,
		"called_shot_fixture": true, "anatomy_fixture": "low_cover", "seed": 42,
	})
	var grid := Battle.controller.battlefield as GridBattlefieldModel
	var ally_cell: Vector2i = grid.cell_of(Battle.controller.active_actor())
	assert_bool(grid.displace(Battle.controller.enemies[0], ally_cell + Vector2i(2, 0))["allowed"]).is_true()
	lab.call("_seat_low_cover", Battle.controller)
	var payloads: Array[Dictionary] = []
	lab.connect("inspector_changed", func(payload: Dictionary) -> void: payloads.append(payload))
	var texts: PackedStringArray = []
	for location: StringName in [&"torso", &"throat"]:
		lab.call("select_lab_aim", location)
		var quote: Dictionary = lab.call("aim_forecast")
		lab.call("_update_panel")
		await get_tree().process_frame
		var fed: Dictionary = {}
		if not payloads.is_empty():
			var last_payload: Dictionary = payloads[payloads.size() - 1]
			fed = last_payload.get("aim_forecast", {})
		texts.append(str(fed.get("message", "")))
		if location == &"torso":
			assert_bool(quote["allowed"]).is_false()
			assert_str(str(fed.get("message", ""))).is_equal("Low cover hides that location from here.")
		else:
			assert_bool(quote["allowed"]).override_failure_message(str(quote)).is_true()
			assert_bool(bool(fed.get("allowed", false))).is_true()
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
		assert_int(get_viewport().get_texture().get_image().save_png("user://qa/lab-low-cover-%s.png" % location)).is_equal(OK)
	lab.call("stop_test_session")
