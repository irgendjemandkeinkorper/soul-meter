extends GdUnitTestSuite


func test_generated_item_keys_are_stable_and_path_based() -> void:
	assert_str(ItemLocalization.key_for("materials/loamroot_sprig", "name")).is_equal(
		"ITEM_MATERIALS_LOAMROOT_SPRIG_NAME"
	)
	assert_str(ItemLocalization.key_for("weapons/taubstummer-axe", "description")).is_equal(
		"ITEM_WEAPONS_TAUBSTUMMER_AXE_DESC"
	)


func test_untranslated_item_text_falls_back_to_pandora_source() -> void:
	assert_str(
		ItemLocalization.text(
			"materials/loamroot_sprig", "name", "Loamroot Sprig"
		)
	).is_equal("Loamroot Sprig")
	assert_str(ItemLocalization.text("materials/loamroot_sprig", "description", "Source text")).is_equal(
		"Source text"
	)


func test_supported_locale_translates_a_registered_item_key() -> void:
	var original_locale := TranslationServer.get_locale()
	TranslationServer.set_locale("es")
	assert_str(
		ItemLocalization.text(
			"consumables/loam_bread", "name", "Loam Bread"
		)
	).is_equal("Pan de Loam")
	TranslationServer.set_locale(original_locale)
