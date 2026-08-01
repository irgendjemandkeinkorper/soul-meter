extends GdUnitTestSuite

const Generator := preload("res://tools/generate_gloot.gd")


func test_committed_generated_data_matches_pandora() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var result: Dictionary = Generator.generate(true)
	assert_bool(result.drift).is_false()
