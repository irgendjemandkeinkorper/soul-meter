extends GdUnitTestSuite

const MusicDirectorScript := preload("res://audio/music_director.gd")
var director: Node


func before_test() -> void:
	director = auto_free(MusicDirectorScript.new() as Node)


func test_context_mapping_stable_ids() -> void:
	var track_map: Dictionary = MusicDirectorScript.TRACK_MAP
	assert_str(track_map["title"]).is_equal("res://assets/audio/music/title.ogg")
	assert_str(track_map["field"]).is_equal("res://assets/audio/music/field.ogg")
	assert_str(track_map["battle"]).is_equal("res://assets/audio/music/battle.ogg")
	assert_str(track_map["chapter_complete"]).is_equal(
		"res://assets/audio/music/chapter_complete.ogg"
	)


func test_missing_asset_falls_back_to_silence_without_crashing() -> void:
	director.play_context("field")
	assert_str(director.get_current_context()).is_equal("field")
	assert_bool(is_instance_valid(director.get("_active_player"))).is_false()


func test_context_stack_is_idempotent_and_resumes_previous_context() -> void:
	director.play_context("field")
	director.push_context("battle")
	director.push_context("battle")
	assert_array(director.get_context_stack()).is_equal(["field", "battle"])

	director.pop_context()
	assert_str(director.get_current_context()).is_equal("field")
	assert_array(director.get_context_stack()).is_equal(["field"])

	director.pop_context()
	director.pop_context()
	assert_str(director.get_current_context()).is_equal("")
	assert_array(director.get_context_stack()).is_empty()
