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
