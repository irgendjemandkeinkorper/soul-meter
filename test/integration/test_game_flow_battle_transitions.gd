extends GdUnitTestSuite

const FIELD_SCENE := preload("res://world/test_room.tscn")
const NO_COMBAT_SCENE := preload("res://world/interiors/players_house.tscn")
const BOOT_STATE := "StateChart/Root/Boot"
const TITLE_STATE := "StateChart/Root/Menus/Title"
const CHARACTER_CREATION_STATE := "StateChart/Root/Menus/CharacterCreation"
const INTRO_STATE := "StateChart/Root/Menus/IntroNarration"
const LOADING_STATE := "StateChart/Root/Playing/Loading"
const ACTIVE_STATE := "StateChart/Root/Playing/Active"
const PAUSED_STATE := "StateChart/Root/Playing/Paused"
const DEPLOYMENT_SLATE_STATE := "StateChart/Root/Playing/DeploymentSlate"
const DEPLOYMENT_ATTUNE_STATE := "StateChart/Root/Playing/DeploymentAttune"
const DEPLOYMENT_LOADOUT_STATE := "StateChart/Root/Playing/DeploymentLoadout"
const DEPLOYMENT_PLACE_STATE := "StateChart/Root/Playing/DeploymentPlace"
const BATTLE_STATE := "StateChart/Root/Playing/Battle"
const CHAPTER_COMPLETE_STATE := "StateChart/Root/Playing/ChapterComplete"

var _field_scene: Node2D
var _field: FieldMap
var _loading_handler_was_connected: bool = false


func before_test() -> void:
	_reset_battle()
	_field_scene = FIELD_SCENE.instantiate() as Node2D
	add_child(_field_scene)
	_field = _field_scene.get_node("FieldMap") as FieldMap
	var loading_state: Node = GameFlow.get_node(LOADING_STATE)
	_loading_handler_was_connected = loading_state.state_entered.is_connected(
		GameFlow._on_loading_entered
	)
	if _loading_handler_was_connected:
		loading_state.state_entered.disconnect(GameFlow._on_loading_entered)
	await _enter_active_state()
	UIManager.close_all()
	get_tree().paused = false


func after_test() -> void:
	if _state_is_active(BATTLE_STATE):
		GameFlow.send_event(&"battle_end")
		await get_tree().process_frame
	await _return_to_title()
	var loading_state: Node = GameFlow.get_node(LOADING_STATE)
	if (
		_loading_handler_was_connected
		and not loading_state.state_entered.is_connected(GameFlow._on_loading_entered)
	):
		loading_state.state_entered.connect(GameFlow._on_loading_entered)
	if _field != null:
		_field.set_combat_mode(false)
	UIManager.close_all()
	get_tree().paused = false
	_reset_battle()
	_field_scene.free()
	_field_scene = null
	_field = null


func test_enter_battle_goes_directly_to_battle_and_pause_returns_there() -> void:
	var music_depth_before: int = MusicDirector.get_context_stack().size()
	Battle.start(EncounterIds.BOG_WIGHT)

	GameFlow.send_event(&"enter_battle")
	await get_tree().process_frame

	assert_bool(_state_is_active(BATTLE_STATE)).is_true()
	assert_bool(_state_is_active(DEPLOYMENT_SLATE_STATE)).is_false()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_field.combat_mode_active()).is_true()
	assert_int(MusicDirector.get_context_stack().size()).is_equal(music_depth_before + 1)

	GameFlow.send_event(&"pause")
	await get_tree().process_frame
	assert_bool(_state_is_active(PAUSED_STATE)).is_true()
	assert_bool(get_tree().paused).is_true()
	# Pausing mid-fight is not ending it: the field stays in combat mode and the battle music
	# context is neither popped nor re-pushed across the round trip.
	assert_bool(_field.combat_mode_active()).is_true()
	assert_int(MusicDirector.get_context_stack().size()).is_equal(music_depth_before + 1)

	GameFlow.send_event(&"resume")
	await get_tree().process_frame
	assert_bool(_state_is_active(BATTLE_STATE)).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_field.combat_mode_active()).is_true()
	assert_int(MusicDirector.get_context_stack().size()).is_equal(music_depth_before + 1)

	GameFlow.send_event(&"battle_end")
	await get_tree().process_frame
	assert_bool(_state_is_active(ACTIVE_STATE)).is_true()
	assert_bool(_field.combat_mode_active()).is_false()
	assert_int(MusicDirector.get_context_stack().size()).is_equal(music_depth_before)


func test_enter_set_piece_traverses_the_existing_deployment_chain() -> void:
	Battle.start(EncounterIds.BOG_WIGHT)

	GameFlow.send_event(&"enter_set_piece")
	await get_tree().process_frame
	assert_bool(_state_is_active(DEPLOYMENT_SLATE_STATE)).is_true()

	var expected_states: Array[String] = [
		DEPLOYMENT_ATTUNE_STATE,
		DEPLOYMENT_LOADOUT_STATE,
		DEPLOYMENT_PLACE_STATE,
	]
	for state_path: String in expected_states:
		GameFlow.send_event(&"deployment_next")
		await get_tree().process_frame
		assert_bool(_state_is_active(state_path)).is_true()

	GameFlow.send_event(&"accept_slate")
	await get_tree().process_frame
	assert_bool(_state_is_active(BATTLE_STATE)).is_true()
	assert_bool(get_tree().paused).is_false()
	assert_bool(_field.combat_mode_active()).is_true()


func test_enter_battle_guard_refuses_a_no_combat_field_with_fr606_shape() -> void:
	_field_scene.free()
	_field_scene = NO_COMBAT_SCENE.instantiate() as Node2D
	add_child(_field_scene)
	_field = _field_scene.find_child("FieldMap", true, false) as FieldMap

	var refusal: Dictionary = Battle.can_fight_here()
	assert_bool(bool(refusal.get("allowed", true))).is_false()
	assert_str(String(refusal.get("blocked_by", &""))).is_equal("no_combat_zone")
	assert_bool(refusal.has("nearest_unblock")).is_true()
	assert_bool(refusal.has("message")).is_true()
	var guard: ExpressionGuard = GameFlow.get_node(
		"StateChart/Root/Playing/Active/ToBattle"
	).guard
	assert_str(guard.expression).is_equal("can_fight_here")

	GameFlow.send_event(&"enter_battle")
	await get_tree().process_frame

	assert_bool(_state_is_active(ACTIVE_STATE)).is_true()
	assert_bool(_state_is_active(BATTLE_STATE)).is_false()
	assert_bool(_field.combat_mode_active()).is_false()


func _enter_active_state() -> void:
	if _state_is_active(ACTIVE_STATE):
		return
	if _state_is_active(BOOT_STATE):
		GameFlow.send_event(&"boot_done")
		await get_tree().process_frame
	if _state_is_active(CHARACTER_CREATION_STATE):
		GameFlow.send_event(&"new_game")
		await get_tree().process_frame
	if _state_is_active(INTRO_STATE):
		GameFlow.send_event(&"intro_done")
		await get_tree().process_frame
	if _in_deployment():
		Battle.start(EncounterIds.BOG_WIGHT)
		await _finish_deployment()
	if _state_is_active(PAUSED_STATE):
		GameFlow.chart.set_expression_property(&"resume_to_battle", false)
		GameFlow.send_event(&"resume")
		await get_tree().process_frame
	if _state_is_active(BATTLE_STATE):
		GameFlow.send_event(&"battle_end")
		await get_tree().process_frame
	if _state_is_active(CHAPTER_COMPLETE_STATE):
		GameFlow.send_event(&"continue_exploring")
		await get_tree().process_frame
	if _state_is_active(TITLE_STATE):
		GameFlow.send_event(&"new_game")
		await get_tree().process_frame
	if _state_is_active(LOADING_STATE):
		GameFlow.send_event(&"level_ready")
		await get_tree().process_frame


func _return_to_title() -> void:
	await _enter_active_state()
	if _state_is_active(ACTIVE_STATE):
		GameFlow.send_event(&"pause")
		await get_tree().process_frame
	if _state_is_active(PAUSED_STATE):
		GameFlow.send_event(&"to_main_menu")
		await get_tree().process_frame


func _in_deployment() -> bool:
	return (
		_state_is_active(DEPLOYMENT_SLATE_STATE)
		or _state_is_active(DEPLOYMENT_ATTUNE_STATE)
		or _state_is_active(DEPLOYMENT_LOADOUT_STATE)
		or _state_is_active(DEPLOYMENT_PLACE_STATE)
	)


func _finish_deployment() -> void:
	if _state_is_active(DEPLOYMENT_SLATE_STATE):
		GameFlow.send_event(&"deployment_next")
		await get_tree().process_frame
	if _state_is_active(DEPLOYMENT_ATTUNE_STATE):
		GameFlow.send_event(&"deployment_next")
		await get_tree().process_frame
	if _state_is_active(DEPLOYMENT_LOADOUT_STATE):
		GameFlow.send_event(&"deployment_next")
		await get_tree().process_frame
	if _state_is_active(DEPLOYMENT_PLACE_STATE):
		GameFlow.send_event(&"accept_slate")
		await get_tree().process_frame


func _state_is_active(path: String) -> bool:
	var state: Node = GameFlow.get_node_or_null(path)
	return state != null and bool(state.get("active"))


func _reset_battle() -> void:
	Battle.controller = null
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._definition.clear()
	Battle._combat_history.clear()
	Battle.encounter_id = &""
	Battle.last_result = null
	Battle.ended = true
