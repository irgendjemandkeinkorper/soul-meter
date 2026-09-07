extends GdUnitTestSuite

const BAKE_SCRIPT := "res://tools/bake_layout_overrides.gd"

var _test_dir: String = ""


func before_test() -> void:
	var configured_root: String = OS.get_environment("SOUL_METER_TEST_DATA_DIR")
	if configured_root.is_empty():
		configured_root = OS.get_temp_dir()
	_test_dir = configured_root.path_join("soul-meter-layout-bake-%s" % Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(_test_dir)


func after_test() -> void:
	_remove_tree(_test_dir)


func test_bake_persists_an_override_into_a_temporary_scene_copy() -> void:
	var source_path: String = _test_dir.path_join("source.tscn")
	var override_path: String = _test_dir.path_join("override.json")
	var output_path: String = _test_dir.path_join("baked.tscn")
	_write_text(source_path, """[gd_scene format=3]

[node name="BakeFixture" type="Node2D"]

[node name="SoftDetails" type="Node2D" parent="."]
y_sort_enabled = true

[node name="MoveMe" type="Sprite2D" parent="SoftDetails"]
position = Vector2(4, 8)
""")
	_write_text(override_path, JSON.stringify({
		"schema": 1,
		"scene": source_path,
		"edits": [{
			"path": "SoftDetails/MoveMe",
			"position": [120.0, 56.0],
			"scale": [1.25, 0.75],
		}],
		"deletions": [],
		"additions": [],
	}, "  "))

	var process_output: Array = []
	OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path(BAKE_SCRIPT),
			"--",
			"--scene", source_path,
			"--overrides", override_path,
			"--out", output_path,
			"--write",
		],
		process_output,
		true,
	)
	var combined: String = "\n".join(PackedStringArray(process_output))
	var packed: PackedScene = ResourceLoader.load(output_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene

	assert_str(combined).contains("Layout bake summary: edits=1 deletions=0 additions=0 skipped=0")
	assert_object(packed).is_not_null()
	if packed == null:
		return
	var instance: Node2D = auto_free(packed.instantiate()) as Node2D
	var moved: Sprite2D = instance.get_node("SoftDetails/MoveMe") as Sprite2D
	assert_vector(moved.position).is_equal(Vector2(120.0, 56.0))
	assert_vector(moved.scale).is_equal(Vector2(1.25, 0.75))


func test_baked_addition_is_canonical_and_carries_no_scratch_meta() -> void:
	# Gate r1 finding 2: a baked prop is canonical scene content — if the bake
	# serialized the runtime's layout_addition meta, the next layout session
	# would mistake it for a scratch addition.
	var source_path: String = _test_dir.path_join("source_add.tscn")
	var override_path: String = _test_dir.path_join("override_add.json")
	var output_path: String = _test_dir.path_join("baked_add.tscn")
	_write_text(source_path, """[gd_scene format=3]

[node name="BakeFixture" type="Node2D"]

[node name="SolidProps" type="Node2D" parent="."]
y_sort_enabled = true
""")
	_write_text(override_path, JSON.stringify({
		"schema": 1,
		"scene": source_path,
		"edits": [],
		"deletions": [],
		"additions": [{
			"layer": "SolidProps",
			"texture": "res://assets/generated/sprites/world/dom-crate-wood--stacked.png",
			"name": "BakedCrate",
			"position": [96.0, 64.0],
			"scale": [1.0, 1.0],
			"collision": [64.0, 24.0],
		}],
	}, "  "))

	var process_output: Array = []
	OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path(BAKE_SCRIPT),
			"--",
			"--scene", source_path,
			"--overrides", override_path,
			"--out", output_path,
			"--write",
		],
		process_output,
		true,
	)
	var combined: String = "\n".join(PackedStringArray(process_output))
	assert_str(combined).contains("Layout bake summary: edits=0 deletions=0 additions=1 skipped=0")
	var packed: PackedScene = ResourceLoader.load(
		output_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE
	) as PackedScene
	assert_object(packed).is_not_null()
	if packed == null:
		return
	var instance: Node2D = auto_free(packed.instantiate()) as Node2D
	var baked_prop: Node = instance.get_node_or_null("SolidProps/BakedCrate")
	assert_object(baked_prop).is_not_null()
	if baked_prop == null:
		return
	assert_bool(baked_prop.has_meta("layout_addition")) \
		.override_failure_message("Baked additions must not carry scratch layout_addition meta") \
		.is_false()


func test_bake_refuses_an_override_file_declared_for_a_different_scene() -> void:
	# Gate r1 finding 1: output defaults to the source scene, so a mismatched
	# override file must never silently overwrite a canonical scene.
	var source_path: String = _test_dir.path_join("source_guard.tscn")
	var override_path: String = _test_dir.path_join("override_other_scene.json")
	var output_path: String = _test_dir.path_join("baked_guard.tscn")
	_write_text(source_path, """[gd_scene format=3]

[node name="BakeFixture" type="Node2D"]
""")
	_write_text(override_path, JSON.stringify({
		"schema": 1,
		"scene": "res://world/interiors/trial_hall.tscn",
		"edits": [],
		"deletions": [],
		"additions": [],
	}, "  "))

	var process_output: Array = []
	OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path(BAKE_SCRIPT),
			"--",
			"--scene", source_path,
			"--overrides", override_path,
			"--out", output_path,
			"--write",
		],
		process_output,
		true,
	)
	var combined: String = "\n".join(PackedStringArray(process_output))
	assert_str(combined).contains("Layout bake refused")
	assert_bool(FileAccess.file_exists(output_path)) \
		.override_failure_message("A refused bake must write nothing") \
		.is_false()


func test_bake_report_only_mode_does_not_modify_file() -> void:
	var source_path: String = _test_dir.path_join("source_report.tscn")
	var override_path: String = _test_dir.path_join("override_report.json")
	var output_path: String = _test_dir.path_join("baked_report.tscn")
	_write_text(source_path, """[gd_scene format=3]

[node name="BakeFixture" type="Node2D"]

[node name="SoftDetails" type="Node2D" parent="."]
y_sort_enabled = true

[node name="MoveMe" type="Sprite2D" parent="SoftDetails"]
position = Vector2(4, 8)
""")
	_write_text(override_path, JSON.stringify({
		"schema": 1,
		"scene": source_path,
		"edits": [{
			"path": "SoftDetails/MoveMe",
			"position": [120.0, 56.0],
			"scale": [1.25, 0.75],
		}],
		"deletions": [],
		"additions": [],
	}, "  "))

	var process_output: Array = []
	OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path(BAKE_SCRIPT),
			"--",
			"--scene", source_path,
			"--overrides", override_path,
			"--out", output_path,
		],
		process_output,
		true,
	)
	var combined: String = "\n".join(PackedStringArray(process_output))
	assert_str(combined).contains("Layout bake summary: edits=1 deletions=0 additions=0 skipped=0 -> %s (report-only)" % output_path)
	assert_bool(FileAccess.file_exists(output_path)) \
		.override_failure_message("Report-only mode must not write file") \
		.is_false()


func test_default_output_and_force_alone_leave_source_bytes_unchanged() -> void:
	var source_path: String = _test_dir.path_join("report_source.tscn")
	var override_path: String = _test_dir.path_join("report_override.json")
	var source: String = """[gd_scene format=3]

[node name="BakeFixture" type="Node2D"]

[node name="MoveMe" type="Node2D" parent="."]
position = Vector2(4, 8)
"""
	_write_text(source_path, source)
	_write_text(override_path, JSON.stringify({
		"schema": 1, "scene": source_path,
		"edits": [{"path": "MoveMe", "position": [20, 30]}],
		"deletions": [], "additions": [],
	}))
	for force_only: bool in [false, true]:
		var args: PackedStringArray = [
			"--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path(BAKE_SCRIPT), "--",
			"--scene", source_path, "--overrides", override_path,
		]
		if force_only:
			args.append("--force")
		var output: Array = []
		OS.execute(OS.get_executable_path(), args, output, true)
		assert_str("\n".join(PackedStringArray(output))).contains("(report-only)")
		assert_str(FileAccess.get_file_as_string(source_path)).is_equal(source)


func test_bake_requires_force_to_overwrite_existing_target() -> void:
	var source_path: String = _test_dir.path_join("source_force.tscn")
	var override_path: String = _test_dir.path_join("override_force.json")
	var output_path: String = _test_dir.path_join("baked_force.tscn")
	_write_text(source_path, """[gd_scene format=3]

[node name="BakeFixture" type="Node2D"]
""")
	_write_text(output_path, """[gd_scene format=3]

[node name="Existing" type="Node2D"]
""")
	_write_text(override_path, JSON.stringify({
		"schema": 1,
		"scene": source_path,
		"edits": [],
		"deletions": [],
		"additions": [],
	}, "  "))

	var process_output_refused: Array = []
	OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path(BAKE_SCRIPT),
			"--",
			"--scene", source_path,
			"--overrides", override_path,
			"--out", output_path,
			"--write",
		],
		process_output_refused,
		true,
	)
	var combined_refused: String = "\n".join(PackedStringArray(process_output_refused))
	assert_str(combined_refused).contains("Layout bake refused: target file '%s' exists. Pass --force to overwrite." % output_path)
	assert_str(FileAccess.get_file_as_string(output_path)).contains('[node name="Existing"')

	var process_output_forced: Array = []
	OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path(BAKE_SCRIPT),
			"--",
			"--scene", source_path,
			"--overrides", override_path,
			"--out", output_path,
			"--write",
			"--force",
		],
		process_output_forced,
		true,
	)
	var combined_forced: String = "\n".join(PackedStringArray(process_output_forced))
	assert_str(combined_forced).contains("Layout bake summary: edits=0 deletions=0 additions=0 skipped=0 -> %s" % output_path)


func test_bake_preserves_actor_exports_that_reference_autoloads() -> void:
	var fixture_script_path: String = _test_dir.path_join("fixture_actor.gd")
	var source_path: String = _test_dir.path_join("source_actor.tscn")
	var override_path: String = _test_dir.path_join("override_actor.json")
	var output_path: String = _test_dir.path_join("baked_actor.tscn")

	_write_text(fixture_script_path, """extends Node2D

@export var transition_id: String = "tr_001"
@export var dialogue_path: String = "res://dialogue/dom_townsfolk.dialogue"
@export var target_scene: String = "res://world/starting_town.tscn"

func _ready() -> void:
	if GameState.flag_is_true("dom_intro_seen"):
		pass
""")

	_write_text(source_path, """[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="%s" id="1_actor"]

[node name="BakeFixture" type="Node2D"]

[node name="Actor" type="Node2D" parent="."]
script = ExtResource("1_actor")
transition_id = "tr_custom"
dialogue_path = "res://dialogue/dom_side_quests.dialogue"
target_scene = "res://world/interiors/tavern.tscn"
""" % fixture_script_path)

	_write_text(override_path, JSON.stringify({
		"schema": 1,
		"scene": source_path,
		"edits": [{
			"path": "Actor",
			"position": [20.0, 30.0],
			"scale": [1.0, 1.0],
		}],
		"deletions": [],
		"additions": [],
	}, "  "))

	var process_output: Array = []
	OS.execute(
		OS.get_executable_path(),
		[
			"--headless",
			"--path", ProjectSettings.globalize_path("res://"),
			"--script", ProjectSettings.globalize_path(BAKE_SCRIPT),
			"--",
			"--scene", source_path,
			"--overrides", override_path,
			"--out", output_path,
			"--write",
		],
		process_output,
		true,
	)
	var combined: String = "\n".join(PackedStringArray(process_output))
	assert_str(combined).contains("Layout bake summary: edits=1 deletions=0 additions=0 skipped=0")

	var packed: PackedScene = ResourceLoader.load(output_path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	assert_object(packed).is_not_null()
	if packed == null:
		return
	var instance: Node2D = auto_free(packed.instantiate()) as Node2D
	var actor: Node2D = instance.get_node("Actor") as Node2D
	assert_object(actor).is_not_null()
	if actor == null:
		return
	assert_str(str(actor.get("transition_id"))).is_equal("tr_custom")
	assert_str(str(actor.get("dialogue_path"))).is_equal("res://dialogue/dom_side_quests.dialogue")
	assert_str(str(actor.get("target_scene"))).is_equal("res://world/interiors/tavern.tscn")


func _write_text(path: String, content: String) -> void:
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file == null:
		return
	file.store_string(content)
	file.close()


func _remove_tree(path: String) -> void:
	if path.is_empty() or not DirAccess.dir_exists_absolute(path):
		return
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		DirAccess.remove_absolute(path.path_join(file_name))
	for child_name: String in directory.get_directories():
		_remove_tree(path.path_join(child_name))
	DirAccess.remove_absolute(path)
