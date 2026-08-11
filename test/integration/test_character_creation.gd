extends GdUnitTestSuite
## Integration coverage for ui/screens/character_creation.tscn (#98/#129) — both the
## boot-time player-identity path (driven through the real main menu + GameFlow chart,
## the way a player actually reaches it) and the re-triggerable recruit-mode path.
##
## Scope note: this suite drives the chart through CharacterCreation -> the "new_game"
## event that starts Playing/Loading, and asserts GameState reflects the finished
## build. It does not wait out Maaack's SceneLoader/loading-screen machinery to land
## on world/starting_town.tscn — no existing suite in this project drives that addon
## end-to-end under gdUnit4, and doing so here risked an unbounded/flaky wait for a
## step this feature does not own. `test/integration/test_starting_town.gd` already
## covers the town scene itself.

var _original_party: Array[PartyMember]
var _original_flags: Dictionary
var _original_custom_recruits: Array[PartyMember]


func before_test() -> void:
	_original_party = GameState.party.duplicate()
	_original_flags = GameState.flags.duplicate(true)
	_original_custom_recruits = GameState.custom_recruits.duplicate()


func after_test() -> void:
	GameState.party = _original_party
	GameState.flags = _original_flags
	GameState.custom_recruits = _original_custom_recruits
	UIManager.close_all()


func test_player_chargen_boots_from_the_main_menu_and_writes_the_lead_identity() -> void:
	var runner := scene_runner("res://ui/screens/main_menu.tscn")
	await runner.simulate_frames(3)

	var new_game_btn := _find_button_with_text(runner.scene(), "New Game")
	assert_object(new_game_btn).is_not_null()
	# Pressed twice: covers both "no existing save" (proceeds immediately) and
	# "existing save" (first press arms the overwrite-confirm, per main_menu.gd) —
	# the test must not depend on whatever save file is on disk from a prior run.
	new_game_btn.pressed.emit()
	await runner.simulate_frames(1)
	new_game_btn.pressed.emit()
	await runner.simulate_frames(3)

	var screen := _find_chargen_screen()
	assert_object(screen).is_not_null()
	assert_bool(screen._accept_btn.disabled).is_true()

	_fill_out_valid_build(screen, "Sera", "the unbowed")
	await runner.simulate_frames(2)
	assert_bool(screen._accept_btn.disabled).is_false()

	screen._on_accept()
	await runner.simulate_frames(3)

	assert_bool(GameState.has_created_character()).is_true()
	assert_str(GameState.party[0].display_name).is_equal("Sera")
	assert_str(GameState.party[0].id).is_equal(GameState.PROTAGONIST_ID)
	assert_str(GameState.party[0].race).is_equal("Vael")


func test_recruit_mode_writes_the_custom_roster_instead_of_the_player_slot() -> void:
	var lead_before := GameState.protagonist()
	var screen: CharacterCreationScreen = load("res://ui/screens/character_creation.tscn").instantiate()
	screen.mode = CharacterCreationScreen.Mode.RECRUIT
	add_child(screen)
	await get_tree().process_frame

	_fill_out_valid_build(screen, "Vann", "the quiet")
	assert_bool(screen._accept_btn.disabled).is_false()

	var emitted: Array[PartyMember] = []
	screen.recruit_created.connect(func(m: PartyMember) -> void: emitted.append(m))
	screen._on_accept()
	await get_tree().process_frame

	assert_int(emitted.size()).is_equal(1)
	assert_str(emitted[0].display_name).is_equal("Vann")
	assert_bool(GameState.custom_recruits.any(func(m: PartyMember) -> bool: return m.display_name == "Vann")).is_true()
	# The player slot itself must be untouched by recruit mode.
	assert_object(GameState.protagonist()).is_equal(lead_before)

	screen.queue_free()


func _fill_out_valid_build(screen: CharacterCreationScreen, name: String, epithet: String) -> void:
	screen._name_edit.text = name
	screen._name_edit.text_changed.emit(name)
	screen._epithet_edit.text = epithet
	screen._epithet_edit.text_changed.emit(epithet)
	screen._on_ancestry_pressed("vael")
	# Spend the full 20-point budget: 5+5+5+2+2+... adjusted to sum exactly to budget.
	screen._attributes = {"forge": 5, "edge": 5, "anchor": 4, "spark": 2, "pitch": 2, "voice": 2}
	screen._refresh_all()


func _find_chargen_screen() -> CharacterCreationScreen:
	for child in UIManager.get_children():
		if child is CharacterCreationScreen:
			return child
	return null


func _find_button_with_text(node: Node, text: String) -> Button:
	if node is Button and (node as Button).text == text:
		return node
	for child in node.get_children():
		var found := _find_button_with_text(child, text)
		if found != null:
			return found
	return null
