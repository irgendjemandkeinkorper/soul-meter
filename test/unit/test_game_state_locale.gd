extends GdUnitTestSuite

const GameStateScript := preload("res://globals/game_state.gd")


func test_locale_selection_accepts_supported_values_and_falls_back_safely() -> void:
	var original_locale: String = TranslationServer.get_locale()
	var state: GameStateScript = auto_free(GameStateScript.new())

	state.apply_locale("es")
	assert_str(state.get_locale()).is_equal("es")
	assert_str(TranslationServer.get_locale()).is_equal("es")

	state.apply_locale("xx")
	assert_str(state.get_locale()).is_equal(GameStateScript.DEFAULT_LOCALE)
	assert_str(TranslationServer.get_locale()).is_equal(GameStateScript.DEFAULT_LOCALE)

	TranslationServer.set_locale(original_locale)
