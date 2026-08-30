extends GdUnitTestSuite

const Generator := preload("res://tools/generate_gloot.gd")


func test_committed_generated_data_matches_pandora() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var result: Dictionary = Generator.generate(true)
	assert_bool(result.drift).is_false()
	assert_int(result.vendor_count).is_equal(12)
	assert_int(result.count).is_equal(22)


func test_drift_probe_reports_both_matching_and_changed_content() -> void:
	var path := "user://generated-data-drift-probe.txt"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("committed\n")
	file.close()
	assert_bool(Generator._differs(path, "committed\n")).is_false()
	assert_bool(Generator._differs(path, "regenerated\n")).is_true()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func test_item_po_merge_preserves_translations_and_marks_changed_sources_fuzzy() -> void:
	var path := "user://item-localization-merge-test.po"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(
		(
			"msgid \"\"\nmsgstr \"\"\n\n"
			+ "#. materials/example — display name\n"
			+ "#. English source: Old Name\n"
			+ "msgid \"ITEM_MATERIALS_EXAMPLE_NAME\"\n"
			+ "msgstr \"Nombre antiguo\"\n\n"
			+ "#: dialogue/example.dialogue\n"
			+ "msgid \"Existing dialogue source\"\n"
			+ "msgstr \"Diálogo existente\"\n\n"
		)
	)
	file.close()
	var entries: Array[Dictionary] = [
		{
			"key": "ITEM_MATERIALS_EXAMPLE_NAME",
			"path": "materials/example",
			"field": "display name",
			"source": "New Name",
		}
	]
	var merged := Generator._merge_locale_po(path, entries)
	assert_str(merged).contains('msgstr "Nombre antiguo"')
	assert_str(merged).contains("#, fuzzy")
	assert_str(merged).contains('msgid "Existing dialogue source"')
	assert_str(merged).contains('msgstr "Diálogo existente"')
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Wave AE: every item prototype must reference a real, loadable painterly
## icon (GLoot's InventoryItem.get_texture() reads the "image" property).
## The path is a naming convention emitted by the generator; this contract
## keeps a missing or opaque-background icon from shipping silently.
func test_every_item_prototype_references_a_loadable_transparent_icon() -> void:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(Generator.PROTOTREE_PATH)
	)
	assert_bool(parsed is Dictionary).is_true()
	var protos := parsed as Dictionary
	assert_int(protos.size()).is_equal(22)
	for item_path: String in protos:
		var props: Dictionary = protos[item_path]
		var image_path := str(props.get("image", ""))
		assert_str(image_path) \
			.override_failure_message("Item %s has no image property." % item_path) \
			.is_not_empty()
		# Gate Wave AE finding: pin the exact slug mapping — prefix/suffix
		# checks alone would pass if every item pointed at one shared icon.
		assert_str(image_path).is_equal(
			"%s/%s--icon.png" % [Generator.ITEM_ICON_DIR, item_path.get_file()]
		)
		var exists_for_export := (
			ResourceLoader.exists(image_path) or FileAccess.file_exists(image_path)
		)
		assert_bool(exists_for_export) \
			.override_failure_message("Item icon is missing: %s" % image_path) \
			.is_true()
		if not exists_for_export:
			continue
		var texture := load(image_path) as Texture2D
		assert_object(texture) \
			.override_failure_message("Item icon does not load: %s" % image_path) \
			.is_not_null()
		if texture == null:
			continue
		assert_int(texture.get_width()) \
			.override_failure_message("Item icon must be 256x256: %s" % image_path) \
			.is_equal(256)
		assert_int(texture.get_height()) \
			.override_failure_message("Item icon must be 256x256: %s" % image_path) \
			.is_equal(256)
		var image := texture.get_image()
		assert_bool(image.detect_alpha() != Image.ALPHA_NONE) \
			.override_failure_message("Item icon has no alpha channel: %s" % image_path) \
			.is_true()
