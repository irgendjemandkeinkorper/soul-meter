extends GdUnitTestSuite
## U2 (owner 2026-11-02, docs/design/ui-rework-plan-2026-11-01.md): key hints leave once
## learned, the party is a strip of portraits and meters, the objective is one line, and
## world labels speak in the DS display face.

const HUD_SCENE := "res://ui/hud/field_hud.tscn"
const FieldHUDScript := preload("res://ui/hud/field_hud.gd")
const PartyMemberVisualsScript := preload("res://actors/party_followers/party_member_visuals.gd")

var _party_before: Array[PartyMember] = []


func before_test() -> void:
	_party_before = GameState.party.duplicate()
	FieldHUDScript.set_control_hints(true)


func after_test() -> void:
	GameState.party = _party_before
	FieldHUDScript.set_control_hints(true)


func test_a_hint_leaves_once_its_key_is_used_and_stays_gone() -> void:
	var runner := scene_runner(HUD_SCENE)
	await runner.simulate_frames(1)
	assert_int(_visible_hints(runner).size()).is_equal(FieldHUDScript.KEY_HINTS.size())

	var press := InputEventAction.new()
	press.action = &"open_party"
	press.pressed = true
	runner.scene().call("_input", press)

	assert_bool(_hint(runner, "party").visible).is_false()
	assert_bool(_hint(runner, "journal").visible).is_true()
	# Saved: a fresh HUD (a new scene, a new session) still has it learned.
	var again := scene_runner(HUD_SCENE)
	await again.simulate_frames(1)
	assert_bool(_hint(again, "party").visible).is_false()


func test_any_move_key_teaches_the_move_hint() -> void:
	var runner := scene_runner(HUD_SCENE)
	await runner.simulate_frames(1)
	var press := InputEventAction.new()
	press.action = &"move_down"
	press.pressed = true
	runner.scene().call("_input", press)
	assert_bool(_hint(runner, "move").visible).is_false()


func test_the_settings_toggle_brings_the_strip_back_and_can_hide_it() -> void:
	var runner := scene_runner(HUD_SCENE)
	await runner.simulate_frames(1)
	for hint: Dictionary in FieldHUDScript.KEY_HINTS:
		var press := InputEventAction.new()
		press.action = hint["actions"][0]
		press.pressed = true
		runner.scene().call("_input", press)
	assert_int(_visible_hints(runner).size()).is_equal(0)
	assert_bool(FieldHUDScript.control_hints_showing()).is_false()

	FieldHUDScript.set_control_hints(true)
	get_tree().call_group(FieldHUDScript.GROUP, &"refresh_key_hints")
	assert_int(_visible_hints(runner).size()).is_equal(FieldHUDScript.KEY_HINTS.size())
	assert_bool(FieldHUDScript.control_hints_showing()).is_true()

	FieldHUDScript.set_control_hints(false)
	get_tree().call_group(FieldHUDScript.GROUP, &"refresh_key_hints")
	assert_int(_visible_hints(runner).size()).is_equal(0)


func test_a_party_of_six_is_six_cards_with_meters_and_numbers_on_hover() -> void:
	GameState.party = _members(6)
	GameState.party[1].hp = 10
	GameState.party[1].max_hp = 30
	GameState.party[1].breath = 3
	GameState.party[1].breath_max = 15
	var runner := scene_runner(HUD_SCENE)
	await runner.simulate_frames(2)

	var strip := runner.find_child("PartyStrip", true, false) as HBoxContainer
	assert_int(strip.get_child_count()).is_equal(6)
	var hud_width := (runner.find_child("Bar", true, false) as Control).size.x
	assert_float(strip.get_combined_minimum_size().x).is_less(hud_width - 270.0)

	var hurt := strip.get_child(1) as Control
	assert_float((hurt.find_child("HP", true, false) as MeterBar).value).is_equal_approx(1.0 / 3.0, 0.001)
	assert_float((hurt.find_child("Breath", true, false) as MeterBar).value).is_equal_approx(0.2, 0.001)
	var name_label := hurt.find_child("Name", true, false) as Label
	var numbers := hurt.find_child("Numbers", true, false) as Label
	assert_bool(name_label.visible).is_true()
	assert_bool(numbers.visible).is_false()
	hurt.mouse_entered.emit()
	assert_bool(name_label.visible).is_false()
	assert_bool(numbers.visible).is_true()
	assert_str(numbers.text).is_equal("HP 10/30  ·  BR 3/15")
	hurt.mouse_exited.emit()
	assert_bool(name_label.visible).is_true()


func test_hp_changes_reach_the_strip_without_a_party_signal() -> void:
	GameState.party = _members(2)
	var runner := scene_runner(HUD_SCENE)
	await runner.simulate_frames(2)
	GameState.party[0].hp = GameState.party[0].max_hp / 2
	await runner.simulate_frames(2)
	var card := (runner.find_child("PartyStrip", true, false) as Node).get_child(0)
	assert_float((card.find_child("HP", true, false) as MeterBar).value).is_equal_approx(
		float(GameState.party[0].hp) / float(GameState.party[0].max_hp), 0.001
	)


func test_the_objective_is_one_line_with_title_and_step() -> void:
	var runner := scene_runner(HUD_SCENE)
	await runner.simulate_frames(1)
	var objective := runner.find_child("Objective", true, false) as Label
	assert_bool(objective.text.contains("\n")).is_false()
	assert_str(objective.text).contains(ChapterOneProgress.title())
	assert_str(objective.text).contains(ChapterOneProgress.objective())


func test_go_to_only_names_a_place_in_another_area() -> void:
	assert_bool(FieldHUDScript.destination_is_here("Trial Council Hall in Dom", "Dom")).is_true()
	assert_bool(FieldHUDScript.destination_is_here("The Four Arms in Dom", "Dom")).is_true()
	assert_bool(FieldHUDScript.destination_is_here("North Road → Dorthkor", "Dom")).is_false()
	assert_bool(FieldHUDScript.destination_is_here("North Road → Dorthkor", "Dorthkor Road")).is_true()
	assert_bool(FieldHUDScript.destination_is_here("East Road → Loamroot Grove", "Dom")).is_false()
	# Unknown area: say where to go rather than hide it.
	assert_bool(FieldHUDScript.destination_is_here("Trial Council Hall in Dom", "")).is_false()


func test_area_names_follow_interiors_back_to_their_hub() -> void:
	assert_str(LocationRegistry.area_name("res://world/starting_town.tscn")).is_equal("Dom")
	assert_str(LocationRegistry.area_name("res://world/interiors/trial_hall.tscn")).is_equal("Dom")
	assert_str(LocationRegistry.area_name("res://world/interiors/lower_trial_hall.tscn")).is_equal("Dom")
	assert_str(LocationRegistry.area_name("res://world/dorthkor_road.tscn")).is_equal("Dorthkor Road")
	assert_str(LocationRegistry.area_name("res://nowhere.tscn")).is_empty()


func test_in_dom_the_objective_does_not_send_you_to_dom() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(3)
	var objective := runner.find_child("Objective", true, false) as Label
	var destination := ChapterOneProgress.destination()
	if FieldHUDScript.destination_is_here(destination, "Dom"):
		assert_bool(objective.text.contains("GO TO")).is_false()
	else:
		assert_str(objective.text).contains("GO TO  " + destination)


func test_world_labels_use_the_display_face() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(3)
	var town := runner.scene()
	var town_hall := town.get_node("TownHall/LocationLabel") as Label
	assert_object(town_hall.theme).is_not_null()
	assert_str(String(town_hall.theme_type_variation)).is_equal("WorldLabel")
	# Screen-space HUD labels keep their own faces.
	var objective := runner.find_child("Objective", true, false) as Label
	assert_str(String(objective.theme_type_variation)).is_equal("HUDObjectiveLabel")


func test_a_sprite_only_member_gets_a_square_bust() -> void:
	var member := PartyMember.new()
	member.id = "aela-quietforge"
	var bust := PartyMemberVisualsScript.bust_texture(member)
	assert_object(bust).is_instanceof(AtlasTexture)
	var region := (bust as AtlasTexture).region
	assert_float(region.size.x).is_equal(region.size.y)
	assert_bool(Rect2(Vector2.ZERO, Vector2(256, 256)).encloses(region)).is_true()
	# The member is only read: no portrait written back.
	assert_object(member.portrait).is_null()


func test_an_authored_portrait_is_used_as_is() -> void:
	var member := PartyMember.new()
	member.id = "iris"
	member.portrait = load("res://assets/generated/portraits/iris_illepah_portrait_neutral.png")
	assert_object(PartyMemberVisualsScript.bust_texture(member)).is_same(member.portrait)


# --- helpers ------------------------------------------------------------------------------------

func _hint(runner: GdUnitSceneRunner, id: String) -> Label:
	return runner.find_child("Hint_%s" % id, true, false) as Label


func _visible_hints(runner: GdUnitSceneRunner) -> Array:
	var shown: Array = []
	for hint: Dictionary in FieldHUDScript.KEY_HINTS:
		var label := _hint(runner, str(hint["id"]))
		if label != null and label.visible:
			shown.append(hint["id"])
	return shown


func _members(count: int) -> Array[PartyMember]:
	var members: Array[PartyMember] = []
	for index: int in count:
		var member := PartyMember.new()
		member.id = "u2_member_%d" % index
		member.display_name = "Member %d" % index
		member.max_hp = 20
		member.hp = 20
		member.breath_max = 15
		member.breath = 15
		members.append(member)
	return members
