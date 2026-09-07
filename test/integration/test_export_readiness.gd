extends GdUnitTestSuite
## Guards the two halves of the export contract that no other suite can see, because both live
## in text config rather than in code: what an export SHIPS and what it EXCLUDES.
##
## Weftlumin (#332) is the reason this exists. Its bootstrap must ship in every build — it is the
## autoload that keeps the editor inert — while its panels and tools must never ship at all. Get
## either half backwards and nothing fails until someone builds a release: a missing autoload
## breaks the game on launch, and shipped editor tooling is a release-blocking leak that no test
## would otherwise catch.

const PROJECT_CONFIG := "res://project.godot"
const EXPORT_PRESETS := "res://export_presets.cfg"

## Directories that must never reach a player's machine.
const MUST_EXCLUDE: Array[String] = [
	"addons/weftlumin/panels/*",
	"addons/weftlumin/tools/*",
	"weftlumin/panels/*",
	"test/*",
	"tools/*",
	"addons/gdUnit4/*",
]

## Weftlumin files that must ship, inert, so the activation gate is the same object in every
## build. Excluding these would make the inert suite prove something about a file players never
## get.
const MUST_SHIP: Array[String] = [
	"res://addons/weftlumin/bootstrap.gd",
	"res://addons/weftlumin/core/adapter.gd",
]


func test_every_autoload_script_exists() -> void:
	# An autoload naming a missing file is a launch-time crash that only shows up in an export,
	# because the editor keeps the last-loaded copy alive in memory.
	var missing: Array[String] = []
	for entry: Dictionary in _autoloads():
		if not ResourceLoader.exists(entry["path"]):
			missing.append("%s -> %s" % [entry["name"], entry["path"]])
	assert_array(missing).override_failure_message(
		"these autoloads name files that do not exist: %s" % ", ".join(missing)
	).is_empty()


func test_weftlumin_bootstrap_is_registered_as_an_autoload() -> void:
	# The bootstrap must be an autoload rather than something plugin.gd spawns, or the inert
	# suite would be testing a path that exports do not take.
	var names: Array[String] = []
	for entry: Dictionary in _autoloads():
		names.append(entry["name"])
	assert_array(names).override_failure_message(
		"WeftluminBootstrap must be a project.godot autoload (architecture note §4.1)"
	).contains(["WeftluminBootstrap"])


func test_editor_only_directories_are_excluded_from_every_preset() -> void:
	var presets: Array[Dictionary] = _presets()
	assert_int(presets.size()).override_failure_message(
		"no export presets found; this suite would pass vacuously"
	).is_greater(0)
	for preset: Dictionary in presets:
		var excluded: PackedStringArray = preset["exclude"]
		for pattern: String in MUST_EXCLUDE:
			assert_bool(excluded.has(pattern)).override_failure_message(
				"preset %d does not exclude %s" % [int(preset["index"]), pattern]
			).is_true()


func test_weftlumin_runtime_files_are_not_excluded() -> void:
	# The mirror of the test above, and the reason it is a separate case: a broad pattern like
	# `addons/weftlumin/*` would satisfy the exclusion test while silently dropping the autoload.
	for preset: Dictionary in _presets():
		for pattern: String in preset["exclude"] as PackedStringArray:
			for shipped: String in MUST_SHIP:
				assert_bool(_matches(pattern, shipped)).override_failure_message(
					"preset %d excludes %s via %s, but it must ship inert"
					% [int(preset["index"]), shipped, pattern]
				).is_false()


func test_files_that_must_ship_exist() -> void:
	for shipped: String in MUST_SHIP:
		assert_bool(ResourceLoader.exists(shipped)).override_failure_message(
			"%s must exist; the export contract above names it" % shipped
		).is_true()


## `exclude_filter` patterns are shell-style globs relative to the project root.
func _matches(pattern: String, res_path: String) -> bool:
	return res_path.trim_prefix("res://").matchn(pattern)


func _autoloads() -> Array[Dictionary]:
	var entries: Array[Dictionary] = []
	var config := ConfigFile.new()
	assert_int(config.load(PROJECT_CONFIG)).is_equal(OK)
	if not config.has_section("autoload"):
		return entries
	for key: String in config.get_section_keys("autoload"):
		# Autoload values carry a leading "*" when the entry is a singleton node.
		var raw: String = str(config.get_value("autoload", key, ""))
		entries.append({"name": key, "path": raw.trim_prefix("*")})
	return entries


func _presets() -> Array[Dictionary]:
	var presets: Array[Dictionary] = []
	var config := ConfigFile.new()
	assert_int(config.load(EXPORT_PRESETS)).is_equal(OK)
	for section: String in config.get_sections():
		if not config.has_section_key(section, "exclude_filter"):
			continue
		var raw: String = str(config.get_value(section, "exclude_filter", ""))
		var patterns := PackedStringArray()
		for piece: String in raw.split(",", false):
			patterns.append(piece.strip_edges())
		presets.append({"index": presets.size(), "exclude": patterns})
	return presets
