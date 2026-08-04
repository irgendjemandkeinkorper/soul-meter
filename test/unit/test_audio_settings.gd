extends GdUnitTestSuite

const GameStateScript := preload("res://globals/game_state.gd")
const TEST_SETTINGS_PATH := "user://gdunit_audio_settings.cfg"

var _original_bus_state: Dictionary = {}
var _original_locale := ""
var _original_window_mode := DisplayServer.WINDOW_MODE_WINDOWED


func before_test() -> void:
	_original_bus_state.clear()
	for bus: StringName in GameStateScript.AUDIO_BUSES:
		var index := AudioServer.get_bus_index(bus)
		_original_bus_state[bus] = {
			"volume_db": AudioServer.get_bus_volume_db(index),
			"muted": AudioServer.is_bus_mute(index),
		}
	_original_locale = TranslationServer.get_locale()
	_original_window_mode = DisplayServer.window_get_mode()
	_remove_test_settings()


func after_test() -> void:
	for bus: StringName in GameStateScript.AUDIO_BUSES:
		var index := AudioServer.get_bus_index(bus)
		var state: Dictionary = _original_bus_state[bus]
		AudioServer.set_bus_volume_db(index, float(state["volume_db"]))
		AudioServer.set_bus_mute(index, bool(state["muted"]))
	TranslationServer.set_locale(_original_locale)
	DisplayServer.window_set_mode(_original_window_mode)
	_remove_test_settings()


func test_music_and_sfx_buses_feed_master() -> void:
	var state: GameStateScript = auto_free(GameStateScript.new())
	state._ensure_audio_buses()

	for bus: StringName in [&"Music", &"SFX"]:
		var index := AudioServer.get_bus_index(bus)
		assert_int(index).is_greater_equal(0)
		assert_str(String(AudioServer.get_bus_send(index))).is_equal("Master")


func test_volume_settings_round_trip_through_config_file() -> void:
	var writer: GameStateScript = auto_free(GameStateScript.new())
	writer.settings_path = TEST_SETTINGS_PATH
	writer._ensure_audio_buses()
	writer.set_setting(
		"display",
		"fullscreen",
		DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN,
	)
	writer.set_setting("display", "locale", _original_locale)
	var expected := {&"Master": 0.72, &"Music": 0.41, &"SFX": 0.0}
	for bus: StringName in GameStateScript.AUDIO_BUSES:
		writer.set_bus_volume(bus, float(expected[bus]), true)

	var reader: GameStateScript = auto_free(GameStateScript.new())
	reader.settings_path = TEST_SETTINGS_PATH
	reader._ensure_audio_buses()
	reader._load_settings()

	for bus: StringName in GameStateScript.AUDIO_BUSES:
		assert_float(float(reader.get_setting("audio", String(bus), -1.0))).is_equal_approx(
			float(expected[bus]), 0.001
		)
		assert_float(reader.get_bus_volume(bus)).is_equal_approx(float(expected[bus]), 0.001)


func _remove_test_settings() -> void:
	if FileAccess.file_exists(TEST_SETTINGS_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
