extends GdUnitTestSuite

const Overrides := preload("res://globals/layout_overrides.gd")
const Recovery := preload("res://globals/layout_recovery.gd")


func test_checkpoint_recovers_unsaved_work_without_changing_saved_file() -> void:
	var scene: String = _unique_scene("recover")
	var saved: Dictionary = Overrides.create_document(scene)
	var working: Dictionary = _edited_document(scene, 24.0)
	assert_int(Recovery.checkpoint(scene, working, saved)).is_equal(OK)
	assert_bool(FileAccess.file_exists(Overrides.override_path_for_scene(scene))).is_false()
	var result: Dictionary = Recovery.load_scene(scene)
	assert_bool(result["recovered"]).is_true()
	assert_dict(result["saved"]).is_equal(saved)
	assert_dict(result["working"]).is_equal(working)
	assert_bool(result["working"].has("_recovery_base")).is_false()
	assert_bool(working.has("_recovery_base")).is_false()
	_cleanup(scene)


func test_changed_manual_save_makes_old_recovery_stale() -> void:
	var scene: String = _unique_scene("stale")
	var saved: Dictionary = _edited_document(scene, 10.0)
	assert_int(Overrides.save_file(Overrides.override_path_for_scene(scene), saved)).is_equal(OK)
	assert_int(Recovery.checkpoint(scene, _edited_document(scene, 20.0), saved)).is_equal(OK)
	var updated_save: Dictionary = _edited_document(scene, 30.0)
	assert_int(Overrides.save_file(Overrides.override_path_for_scene(scene), updated_save)).is_equal(OK)
	var result: Dictionary = Recovery.load_scene(scene)
	assert_bool(result["recovered"]).is_false()
	assert_dict(result["saved"]).is_equal(updated_save)
	assert_dict(result["working"]).is_equal(updated_save)
	_cleanup(scene)


func test_recovery_uses_full_scene_path_and_normalized_baseline() -> void:
	var basename: String = "layout_recovery_shared_%d.tscn" % Time.get_ticks_usec()
	var first_scene: String = "res://world/first/" + basename
	var second_scene: String = "res://world/second/" + basename
	assert_str(Recovery.recovery_path_for_scene(first_scene)).is_not_equal(
		Recovery.recovery_path_for_scene(second_scene)
	)
	var saved: Dictionary = _edited_document(first_scene, 10.0)
	assert_int(Overrides.save_file(Overrides.override_path_for_scene(first_scene), saved)).is_equal(OK)
	var reordered := {
		"deletions": [], "edits": [{"position": [10, 4], "path": "Dressing/SoftDetails/Prop"}],
		"additions": [], "scene": first_scene, "schema": 1.0,
	}
	var working: Dictionary = _edited_document(first_scene, 20.0)
	assert_int(Recovery.checkpoint(first_scene, working, reordered)).is_equal(OK)
	var second_working: Dictionary = _edited_document(second_scene, 50.0)
	assert_int(Recovery.checkpoint(second_scene, second_working, Overrides.create_document(second_scene))).is_equal(OK)
	assert_bool(Recovery.load_scene(first_scene)["recovered"]).is_true()
	assert_dict(Recovery.load_scene(first_scene)["working"]).is_equal(working)
	assert_dict(Recovery.load_scene(second_scene)["working"]).is_equal(second_working)
	_cleanup(first_scene)
	_cleanup(second_scene)


func test_corrupt_or_wrong_scene_recovery_is_ignored() -> void:
	var scene: String = _unique_scene("invalid")
	var saved: Dictionary = Overrides.create_document(scene)
	assert_int(Recovery.checkpoint(scene, _edited_document(scene, 10.0), saved)).is_equal(OK)
	var path: String = Recovery.recovery_path_for_scene(scene)
	var recovery: Dictionary = Overrides.load_file(path)
	recovery["scene"] = "res://world/wrong_scene.tscn"
	assert_int(Overrides.save_file(path, recovery)).is_equal(OK)
	assert_bool(Recovery.load_scene(scene)["recovered"]).is_false()
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_string("{broken JSON")
	file.close()
	var result: Dictionary = Recovery.load_scene(scene)
	assert_bool(result["recovered"]).is_false()
	assert_dict(result["working"]).is_equal(saved)
	_cleanup(scene)


func test_unchanged_checkpoint_creates_no_file_and_clears_obsolete_work() -> void:
	var scene: String = _unique_scene("unchanged")
	var saved: Dictionary = Overrides.create_document(scene)
	assert_int(Recovery.checkpoint(scene, saved.duplicate(true), saved)).is_equal(OK)
	assert_bool(FileAccess.file_exists(Recovery.recovery_path_for_scene(scene))).is_false()
	assert_int(Recovery.checkpoint(scene, _edited_document(scene, 10.0), saved)).is_equal(OK)
	assert_bool(FileAccess.file_exists(Recovery.recovery_path_for_scene(scene))).is_true()
	assert_int(Recovery.checkpoint(scene, saved.duplicate(true), saved)).is_equal(OK)
	assert_bool(FileAccess.file_exists(Recovery.recovery_path_for_scene(scene))).is_false()
	assert_int(Recovery.clear(scene)).is_equal(OK)
	assert_int(Recovery.checkpoint(scene, _edited_document("res://wrong.tscn", 10.0), saved)).is_equal(
		ERR_INVALID_DATA
	)
	_cleanup(scene)


func _edited_document(scene: String, x: float) -> Dictionary:
	var document: Dictionary = Overrides.create_document(scene)
	document["edits"] = [{"path": "Dressing/SoftDetails/Prop", "position": [x, 4.0]}]
	return document


func _unique_scene(label: String) -> String:
	return "res://world/layout_recovery_%s_%d.tscn" % [label, Time.get_ticks_usec()]


func _cleanup(scene: String) -> void:
	assert_int(Recovery.clear(scene)).is_equal(OK)
	var saved_path: String = Overrides.override_path_for_scene(scene)
	if FileAccess.file_exists(saved_path):
		assert_int(DirAccess.remove_absolute(ProjectSettings.globalize_path(saved_path))).is_equal(OK)
