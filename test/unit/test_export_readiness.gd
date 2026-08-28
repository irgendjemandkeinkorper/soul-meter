extends GdUnitTestSuite

const EXPORT_PRESETS := "res://export_presets.cfg"
const PLAYTEST_BUILD_SCRIPT := "res://scripts/build_playtest.sh"


func test_release_presets_exclude_unused_limboai_extension() -> void:
	var presets := ConfigFile.new()
	assert_int(presets.load(EXPORT_PRESETS)).is_equal(OK)
	for section: String in ["preset.0", "preset.1"]:
		var excluded := str(presets.get_value(section, "exclude_filter", ""))
		assert_str(excluded).contains("addons/limboai/*")


func test_gloot_runtime_helper_does_not_reference_editor_only_types() -> void:
	var source := FileAccess.get_file_as_string("res://addons/gloot/editor/undoables.gd")
	assert_str(source).not_contains("-> EditorUndoRedoManager")


func test_playtest_builder_runs_acceptance_export_smoke_and_hash_steps() -> void:
	var source := FileAccess.get_file_as_string(PLAYTEST_BUILD_SCRIPT)
	assert_str(source).is_not_empty()
	assert_str(source).contains("SOUL_METER_LOCALE_STRICT=1")
	assert_str(source).contains("--export-release")
	assert_str(source).contains("--headless")
	assert_str(source).contains("sha256sum")
	assert_str(source).contains("BUILD-MANIFEST.txt")


func test_playtest_builder_refuses_unmarked_dirty_builds_and_parses_as_shell() -> void:
	var source := FileAccess.get_file_as_string(PLAYTEST_BUILD_SCRIPT)
	assert_str(source).contains("--allow-dirty")
	assert_str(source).contains("git status --porcelain")
	var output: Array = []
	var script_path := ProjectSettings.globalize_path(PLAYTEST_BUILD_SCRIPT)
	assert_int(OS.execute("bash", ["-n", script_path], output, true)).is_equal(0)
