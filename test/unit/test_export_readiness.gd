extends GdUnitTestSuite

const EXPORT_PRESETS := "res://export_presets.cfg"
const PLAYTEST_BUILD_SCRIPT := "res://scripts/build_playtest.sh"
const CI_WORKFLOW := "res://.github/workflows/test.yml"
const PACK_PROBE := "res://tools/playtest_pack_probe.gd"
## Both places that export a release build a tester may receive.
const RELEASE_EXPORTERS: Array[String] = [PLAYTEST_BUILD_SCRIPT, CI_WORKFLOW]


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


## `--recovery-mode` disables editor plugins, so the Dialogue Manager importer never runs and the
## pack ships without one `.dialogue`: the CI Windows artifact did until 2026-11-20.
func test_release_exports_never_use_recovery_mode() -> void:
	for path: String in RELEASE_EXPORTERS:
		var source := FileAccess.get_file_as_string(path)
		assert_str(source).contains("--export-release")
		for line: String in source.split("\n"):
			if line.contains("--export-release"):
				assert_str(line).override_failure_message(
					"%s exports in recovery mode: %s" % [path, line.strip_edges()]
				).not_contains("--recovery-mode")


## A boot smoke cannot see missing dialogue (the menu never loads one), so both exporters must
## run the pack probe against the exported pack, from outside the project.
func test_release_exporters_probe_the_exported_pack() -> void:
	assert_bool(FileAccess.file_exists(PACK_PROBE)).is_true()
	for path: String in RELEASE_EXPORTERS:
		var source := FileAccess.get_file_as_string(path)
		assert_str(source).contains("tools/playtest_pack_probe.gd")
		assert_str(source).contains("--main-pack")
		assert_str(source).contains("SOUL_METER_PACK_PROBE_LIST")


func test_playtest_builder_offers_the_windows_kit() -> void:
	var source := FileAccess.get_file_as_string(PLAYTEST_BUILD_SCRIPT)
	assert_str(source).contains("--target")
	assert_str(source).contains("\"Windows Desktop\"")
	assert_str(source).contains("SoulMeter-windows-x86_64.zip")
	assert_str(source).contains("--skip-acceptance")
