extends GdUnitTestSuite
## Rendered evidence for the Soul Meter UI audit (owner 2026-11-01: "a heavy rework of all
## the UI buttons and info — it's so busy and doesn't really convey information we need,
## especially in conversations"). The screenshot sweep photographs each conversation's
## opening line only; this harness reaches the choice menus the player actually decides in.
## Run explicitly under Xvfb:
##   scripts/test.sh -a test/manual/ui_audit_capture.gd
## Frames land in user://qa/ui-audit/*.png; a CHOICES line per menu lists what is offered.

const OUT_DIR := "user://qa/ui-audit"
const CAPTURE_SIZE := Vector2i(1920, 1080)

var _saved_state: Dictionary


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	get_tree().root.size = CAPTURE_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))


func after_test() -> void:
	UIManager.close_all()
	GameState.from_dict(_saved_state)


func test_iris_choice_menu_and_a_consequence() -> void:
	var field := await _open_field("res://world/test_room.tscn")
	var balloon := await _start_balloon(field, "res://dialogue/iris_illepah.dialogue", "start")
	await _advance(balloon)
	_print_choices("iris-hub", balloon)
	await _capture("01-iris-choice-menu")

	# Pick the first offered faction line and photograph the reply and its notices.
	var choice := _first_enabled_choice(balloon, "Bloom")
	assert_object(choice).is_not_null()
	choice.pressed.emit()
	await _frames(12)
	await _capture("02-iris-after-a-choice")
	balloon.free()


func test_council_skill_check_menu() -> void:
	var field := await _open_field("res://world/starting_town.tscn")
	var balloon := await _start_balloon(field, "res://dialogue/council_elder.dialogue", "start")
	await _advance(balloon)
	_print_choices("council-charge", balloon)
	await _capture("03-council-skill-check-menu")
	balloon.free()


## U1: the same menu with the check open, so its chance shows beside the tag.
func test_council_open_check_shows_its_chance() -> void:
	var hero := PartyMember.new()
	hero.id = GameState.PROTAGONIST_ID
	hero.display_name = "Tester"
	hero.skill_percentages = {"undertone": 52.0}
	GameState.set_party([hero] as Array[PartyMember])
	var field := await _open_field("res://world/starting_town.tscn")
	var balloon := await _start_balloon(field, "res://dialogue/council_elder.dialogue", "start")
	await _advance(balloon)
	_print_choices("council-open-check", balloon)
	await _capture("04-council-open-check")
	balloon.free()


func _open_field(path: String) -> Node:
	var runner := scene_runner(path)
	var field := runner.scene()
	await runner.simulate_frames(40)
	var boot_scene := field.get_tree().current_scene
	if boot_scene != null and boot_scene != field:
		boot_scene.hide()
	return field


func _start_balloon(field: Node, dialogue_path: String, cue: String) -> Node:
	var balloon: Node = load("res://ui/dialogue/dialogue_balloon.tscn").instantiate()
	field.add_child(balloon)
	balloon.call("start", load(dialogue_path), cue)
	await _frames(10)
	return balloon


## Click through spoken lines until the balloon offers choices.
func _advance(balloon: Node) -> void:
	for _step: int in 6:
		var line: DialogueLine = balloon.get("dialogue_line")
		if line == null or not line.responses.is_empty():
			break
		balloon.call("_next", line.next_id)
		await _frames(8)


func _print_choices(label: String, balloon: Node) -> void:
	var box := balloon.get("_choices_box") as VBoxContainer
	var rows := PackedStringArray()
	for child: Node in box.get_children():
		if child is Button:
			var button := child as Button
			rows.append("%s%s" % ["(locked) " if button.disabled else "", str(button.get("choice_text"))])
	print("CHOICES %s %d: %s" % [label, rows.size(), " | ".join(rows)])


func _first_enabled_choice(balloon: Node, containing: String) -> Button:
	var box := balloon.get("_choices_box") as VBoxContainer
	for child: Node in box.get_children():
		if child is Button and not (child as Button).disabled and str(child.get("choice_text")).contains(containing):
			return child as Button
	return null


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", ProjectSettings.globalize_path(path))
