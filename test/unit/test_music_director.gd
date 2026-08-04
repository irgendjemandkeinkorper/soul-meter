extends GdUnitTestSuite

const MusicDirectorScript := preload("res://audio/music_director.gd")
var director: Node


func before_test() -> void:
	director = auto_free(MusicDirectorScript.new() as Node)
	add_child(director)


func test_every_known_context_resolves_to_an_imported_track() -> void:
	var expected_contexts: Array[String] = ["battle", "chapter_complete", "field", "title"]
	var actual_contexts: Array = MusicDirectorScript.TRACK_MAP.keys()
	actual_contexts.sort()
	assert_array(actual_contexts).is_equal(expected_contexts)
	for context_id: String in expected_contexts:
		var path := MusicDirectorScript.track_path_for_context(context_id)
		assert_str(path).is_not_empty()
		assert_bool(ResourceLoader.exists(path)).is_true()


func test_known_context_creates_a_music_bus_player() -> void:
	director.play_context("field")
	assert_str(director.get_current_context()).is_equal("field")
	var player := director.get("_active_player") as AudioStreamPlayer
	assert_bool(is_instance_valid(player)).is_true()
	assert_str(String(player.bus)).is_equal("Music")
	assert_object(player.stream).is_not_null()


func test_unknown_context_has_no_track_path() -> void:
	assert_str(MusicDirectorScript.track_path_for_context("unknown")).is_empty()


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
