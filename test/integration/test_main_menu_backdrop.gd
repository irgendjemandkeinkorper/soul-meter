extends GdUnitTestSuite
## Wave AG: the main menu's ObsidianMirror shader renders the painterly
## key-art plate as its base while keeping every authored effect on top.
## The shader's key_art_mix defaults to 0.0, so the procedural backdrop is
## the intact fallback whenever the plate is missing.

const MainMenuScript := preload("res://ui/screens/main_menu.gd")


func test_key_art_plate_exists_and_is_full_hd() -> void:
	var exists_for_export := (
		ResourceLoader.exists(MainMenuScript.KEY_ART_PATH)
		or FileAccess.file_exists(MainMenuScript.KEY_ART_PATH)
	)
	assert_bool(exists_for_export) \
		.override_failure_message("Key-art plate is missing: %s" % MainMenuScript.KEY_ART_PATH) \
		.is_true()
	if not exists_for_export:
		return
	var texture := load(MainMenuScript.KEY_ART_PATH) as Texture2D
	assert_object(texture).is_not_null()
	if texture != null:
		assert_int(texture.get_width()).is_equal(1920)
		assert_int(texture.get_height()).is_equal(1080)


func test_backdrop_material_mixes_the_key_art_under_the_authored_effects() -> void:
	var runner = scene_runner("res://ui/screens/main_menu.tscn")
	await runner.simulate_frames(2)
	var backdrop: ColorRect = runner.find_child("ObsidianMirror", true, false) as ColorRect
	assert_object(backdrop).is_not_null()
	if backdrop == null:
		return
	var material := backdrop.material as ShaderMaterial
	assert_object(material).is_not_null()
	if material == null:
		return
	var key_art: Variant = material.get_shader_parameter("key_art")
	assert_bool(key_art is Texture2D) \
		.override_failure_message("ObsidianMirror must carry the key-art texture.") \
		.is_true()
	if key_art is Texture2D:
		assert_str((key_art as Texture2D).resource_path) \
			.is_equal(MainMenuScript.KEY_ART_PATH)
	assert_float(float(material.get_shader_parameter("key_art_mix"))) \
		.is_equal_approx(MainMenuScript.KEY_ART_MIX, 0.001)
	# Gate Wave AG finding: parameters alone don't prove base-layer placement.
	# The key-art mix must happen BEFORE the first authored effect (ripple) in
	# fragment(), so every effect composites on top of the plate.
	var shader_code := (material.shader as Shader).code
	var mix_position := shader_code.find("texture(key_art")
	var first_effect_position := shader_code.find("float ripple")
	assert_bool(mix_position >= 0 and first_effect_position >= 0) \
		.override_failure_message("Shader lost the key-art mix or the ripple effect.") \
		.is_true()
	assert_bool(mix_position < first_effect_position) \
		.override_failure_message(
			"key_art must mix into the BASE before the authored effects."
		) \
		.is_true()


func test_shader_defaults_keep_the_procedural_backdrop_as_fallback() -> void:
	# Asserted at source level: RenderingServer parameter reflection is not
	# available under the CI dummy renderer.
	var shader := load("res://ui/screens/main_menu_backdrop.gdshader") as Shader
	assert_object(shader).is_not_null()
	if shader == null:
		return
	# Anchored to an uncommented line start with an identifier boundary (gate
	# finding: an unanchored pattern also matches comments or *_legacy names).
	var declaration := RegEx.create_from_string(
		"(?m)^\\s*uniform\\s+float\\s+key_art_mix\\b[^;\\n]*=\\s*0\\.0\\s*;"
	)
	assert_object(declaration.search(shader.code)) \
		.override_failure_message("key_art_mix must default to 0.0 (procedural fallback).") \
		.is_not_null()
