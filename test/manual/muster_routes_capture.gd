extends GdUnitTestSuite
## Rendered evidence for #652 gap 1: the Bloodbellow on Dorthkor Road, fought where it stands,
## offers its two authored routes on the combat bar, and releasing the bound soldier ends the
## fight as `released`. Run explicitly under Xvfb at 1920x1080:
##   SOUL_METER_HEADLESS=0 scripts/test.sh -a test/manual/muster_routes_capture.gd
## Frames land in user://qa/muster-routes/*.png.

const OUT_DIR := "user://qa/muster-routes"
const MUSTER := &"dorthkor-muster"
const RELEASE := &"release-bound-soldier"
const SPEAK_NAME := &"speak-muster-name"

var _saved_state: Dictionary
var _saved_reputation: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	_saved_reputation = Reputation.to_dict().duplicate(true)
	get_tree().root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	UIManager.close_all()
	GameState.from_dict(_saved_state)
	Reputation.from_dict(_saved_reputation)


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", ProjectSettings.globalize_path(path))


func test_the_bloodbellow_offers_its_routes_on_the_field() -> void:
	GameState.flags.clear()
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	# The vanguard is beaten (the muster's lock) and the muster is not.
	GameState.set_flag("defeated_breach_hound", true)
	GameState.set_flag(EncounterCatalog.defeated_flag(MUSTER), false)
	var runner := scene_runner("res://world/dorthkor_road.tscn")
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	var muster := root.find_child("MusteredDead", true, false) as Hostile
	assert_object(muster).is_not_null()

	# The real edge: the flow watches the field and the party walks up to the muster.
	GameFlow.watch_field_hostiles()
	var player := field.player()
	player.global_position = muster.global_position + Vector2(-150.0, 0.0)
	muster.realert_cooldown = 0.0
	muster._refresh_lock()
	muster._set_sensor_enabled(true)
	muster._check_initial_overlap()
	for _frame: int in 60:
		if Battle.session_active:
			break
		await runner.simulate_frames(1)
	assert_bool(Battle.session_active).override_failure_message(
		"walking up to the unlocked muster must open a session"
	).is_true()
	UIManager.close_all()
	var boot_scene := get_tree().current_scene as CanvasItem
	if boot_scene != null and boot_scene != root:
		boot_scene.hide()

	var field_hud := field.field_hud()
	for layer: Node in root.find_children("*", "CanvasLayer", true, false):
		if layer != field_hud:
			(layer as CanvasLayer).hide()
	field.set_combat_mode(true)
	field_hud.enter_combat(field)
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	camera.reset_smoothing()
	for ally: BattleActor in Battle.allies:
		ally.max_hp = 999
		ally.hp = 999
	# Hand the party the clock after at least one enemy round, so Release is open.
	for _step: int in 40:
		var ally_turn := Battle.controller.state == CombatController.State.ALLY_TURN
		if ally_turn and Battle.enemy_rounds >= 1:
			break
		if ally_turn:
			Battle.controller.submit_action(&"guard")
		else:
			Battle.controller.end_turn()
		await runner.simulate_frames(10, 16)
	await runner.simulate_frames(30, 16)
	var ids: Array[StringName] = []
	for action: CombatAction in Battle.available_actions():
		ids.append(action.id)
	print("ROUTES offered=", ids.has(RELEASE), "/", ids.has(SPEAK_NAME), " enemy_rounds=",
		Battle.enemy_rounds, " balance=", Battle.balance)
	print("RELEASE refusal=", Battle.action_refusal(Battle.controller.action_by_id(RELEASE)))
	print("SPEAK refusal=", Battle.action_refusal(Battle.controller.action_by_id(SPEAK_NAME)))
	assert_array(ids).contains([RELEASE, SPEAK_NAME])
	await _capture("01-muster-routes-on-the-bar")

	assert_bool(Battle.use_action(RELEASE)).is_true()
	await runner.simulate_frames(30, 16)
	await _capture("02-after-release")
	print("RESULT outcome=", Battle.last_result.outcome_id, " message=", Battle.last_result.message)
	print("FLAG dorthkor_muster_outcome=", GameState.get_flag("dorthkor_muster_outcome", ""))
	assert_str(String(Battle.last_result.outcome_id)).is_equal("released")
	assert_int(muster.state).is_equal(Hostile.State.DOWNED)
	# Closed directly rather than through CONTINUE, whose `battle_end` would drive the live
	# flow chart this harness bypasses. The frame shows the field the party walks back into.
	field_hud.exit_combat()
	field.set_combat_mode(false)
	await runner.simulate_frames(30, 16)
	await _capture("03-field-after-the-fight")
	print("MUSTER state=", muster.state, " modulate=", muster.modulate)
