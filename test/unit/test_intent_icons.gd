extends GdUnitTestSuite
## The six coarse intent glyphs must ship visible PNGs at both supported sizes (#630).

const INTENTS: Array[String] = ["strike", "hold", "flank", "guard-ally", "call", "flee"]
const SIZES: Array[int] = [24, 64]


func test_intent_exports_have_expected_size_and_visible_alpha() -> void:
	for intent: String in INTENTS:
		for size: int in SIZES:
			var path := "res://assets/icons/png/%d/intents/%s.png" % [size, intent]
			var image := Image.new()
			var error := image.load(path)
			assert_int(error).override_failure_message("Cannot load %s" % path).is_equal(OK)
			if error != OK:
				continue
			assert_vector(image.get_size()).override_failure_message(
				"Wrong dimensions: %s" % path
			).is_equal(Vector2i(size, size))
			assert_bool(image.get_used_rect().has_area()).override_failure_message(
				"No visible pixels: %s" % path
			).is_true()
			assert_int(image.detect_alpha()).override_failure_message(
				"Missing transparent background: %s" % path
			).is_not_equal(Image.ALPHA_NONE)
