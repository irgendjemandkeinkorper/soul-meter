extends GdUnitTestSuite

const Generator := preload("res://tools/generate_gloot.gd")


func test_committed_generated_data_matches_pandora() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var result: Dictionary = Generator.generate(true)
	assert_bool(result.drift).is_false()


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
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
