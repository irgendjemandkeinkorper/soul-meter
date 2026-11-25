extends GdUnitTestSuite
## Rendered evidence for the calling-and-measures sprint
## (docs/design/calling-and-measures-2026-11-25.md). Opens character creation through GameFlow
## and captures the class card's patron measure and the MEASURES tab's live numbers for two
## builds that invest differently. Run explicitly under Xvfb:
##   CAPTURE_OUT=<dir> scripts/test.sh -a test/manual/calling_measures_capture.gd
## Frames land in $CAPTURE_OUT (default user://qa/calling-measures).

const CHARGEN_STATE_PATH := "StateChart/Root/Menus/CharacterCreation"

var _saved_state: Dictionary
var _out_dir := ""


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	_out_dir = OS.get_environment("CAPTURE_OUT")
	if _out_dir.is_empty():
		_out_dir = ProjectSettings.globalize_path("user://qa/calling-measures")
	DirAccess.make_dir_recursive_absolute(_out_dir)


func after_test() -> void:
	UIManager.close_all()
	GameState.from_dict(_saved_state)
	get_tree().root.size = Vector2i(1920, 1080)


func test_the_register_shows_what_measures_and_class_buy() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	GameFlow.send_event("start_chargen")
	await _frames(12)
	var screen := _find_chargen_screen()
	assert_object(screen).is_not_null()
	screen._random_rng.seed = 7
	screen.randomize_character()

	# A Lensbearer who put everything into Reason, then one who put it into Grit.
	screen.select_class("lensbearer")
	_spread(screen, {"reason": 5, "intuition": 4, "alacrity": 3})
	await _frames(6)
	await _capture("01-calling-lensbearer-reason-5")
	screen.go_to_tab(&"measures")
	await _frames(6)
	await _capture("02-measures-lensbearer-reason-5")
	print("MEASURE reason: ", screen.find_child("Effects_reason", true, false).get_node("Now").text)

	screen.select_class("ironbrand")
	_spread(screen, {"grit": 5, "muster": 4, "alacrity": 3})
	await _frames(6)
	await _capture("03-measures-ironbrand-grit-5")
	screen.go_to_tab(&"calling")
	await _frames(6)
	await _capture("04-calling-ironbrand-grit-5")

	get_tree().root.size = Vector2i(1366, 768)
	screen.go_to_tab(&"measures")
	await _frames(8)
	await _capture("05-measures-1366x768")

	# S4 and S5: a Stormbearer on Chordblade, measures placed by SUGGEST.
	get_tree().root.size = Vector2i(1920, 1080)
	screen.select_discipline("chordblade")
	screen.select_class("stormbearer")
	screen.go_to_tab(&"measures")
	(screen.find_child("SuggestMeasuresButton", true, false) as Button).pressed.emit()
	await _frames(8)
	await _capture("06-measures-stormbearer-suggested")
	screen.go_to_tab(&"calling")
	await _frames(6)
	await _capture("07-calling-stormbearer-chordblade")


## Every measure to the floor, then the named ones up; the rest of the budget lands on Decorum
## and Doctrine so every point is placed.
func _spread(screen: CharacterCreationScreen, wanted: Dictionary) -> void:
	for attribute_id: String in DramgidSchema.ATTRIBUTE_IDS:
		screen.set_attribute(attribute_id, DramgidSchema.ATTRIBUTE_FLOOR)
	for attribute_id: String in wanted:
		screen.set_attribute(attribute_id, int(wanted[attribute_id]))
	for filler: String in ["decorum", "doctrine", "muster", "grit"]:
		while screen.build.remaining_attribute_points() > 0 and int(screen.build.attributes[filler]) < DramgidSchema.ATTRIBUTE_CAP:
			screen.set_attribute(filler, int(screen.build.attributes[filler]) + 1)


func _frames(count: int) -> void:
	for _frame: int in count:
		await get_tree().process_frame


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", path)


func _find_chargen_screen() -> CharacterCreationScreen:
	for child: Node in UIManager.get_children():
		if child is CharacterCreationScreen:
			return child as CharacterCreationScreen
	return null
