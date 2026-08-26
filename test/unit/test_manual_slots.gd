extends GdUnitTestSuite
## FR-905 manual save slots: disk-level coverage for the ≥3-slot policy —
## slot isolation, round-trip, per-slot corrupted-save fallback, and the
## slot-picker summary metadata.

const SaveGameScript := preload("res://globals/save_game.gd")
const PROBE_FLAG := "manual_slot_test_probe"

var saves
var save_diagnostics: Array[Dictionary] = []
var game_state_before_test: Dictionary = {}
var reputation_before_test: Dictionary = {}
var renown_before_test: Dictionary = {}
var quests_before_test: Dictionary = {}
var skill_check_before_test: Dictionary = {}
var target_scene_before_test := ""
var target_spawn_id_before_test: StringName = &"default"


func before_test() -> void:
	game_state_before_test = GameState.to_dict()
	reputation_before_test = Reputation.to_dict()
	renown_before_test = Renown.to_dict()
	quests_before_test = QuestRegistry.to_dict()
	skill_check_before_test = SkillCheck.to_dict()
	target_scene_before_test = GameFlow._target_scene
	target_spawn_id_before_test = GameFlow._target_spawn_id
	saves = auto_free(SaveGameScript.new())
	var test_save_prefix := OS.get_temp_dir().path_join(
		"soul-meter-gdunit-slots-%s" % Time.get_ticks_usec()
	)
	saves.save_path = test_save_prefix + ".save"
	saves.temp_path = test_save_prefix + ".save.tmp"
	saves.backup_path = test_save_prefix + ".save.bak"
	save_diagnostics.clear()
	saves.save_diagnostic.connect(_record_save_diagnostic)
	_remove_test_saves()


func after_test() -> void:
	_remove_test_saves()
	GameState.from_dict(game_state_before_test)
	Reputation.from_dict(reputation_before_test)
	Renown.from_dict(renown_before_test)
	QuestRegistry.from_dict(quests_before_test)
	SkillCheck.from_dict(skill_check_before_test)
	GameFlow._target_scene = target_scene_before_test
	GameFlow._target_spawn_id = target_spawn_id_before_test


func test_manual_slot_count_meets_the_fr905_floor() -> void:
	assert_int(SaveGameScript.MANUAL_SLOT_COUNT).is_greater_equal(3)


func test_slots_are_isolated_from_each_other_and_from_the_autosave() -> void:
	var autosave_ok: bool = saves.save()
	var slot_one_ok: bool = saves.save_to_slot(1)
	var slot_two_ok: bool = saves.save_to_slot(2)
	assert_bool(autosave_ok and slot_one_ok and slot_two_ok).is_true()
	var slot_one_path: String = saves.manual_slot_path(1)
	var slot_two_path: String = saves.manual_slot_path(2)
	assert_str(slot_one_path).is_not_equal(slot_two_path)
	assert_str(slot_one_path).is_not_equal(saves.save_path)
	assert_bool(FileAccess.file_exists(saves.save_path)).is_true()
	assert_bool(FileAccess.file_exists(slot_one_path)).is_true()
	assert_bool(FileAccess.file_exists(slot_two_path)).is_true()
	assert_bool(saves.has_manual_save(1)).is_true()
	assert_bool(saves.has_manual_save(3)).is_false()


func test_save_and_load_slot_round_trips_game_state() -> void:
	GameState.set_flag(PROBE_FLAG, true)
	assert_bool(saves.save_to_slot(2)).is_true()
	GameState.set_flag(PROBE_FLAG, false)
	assert_bool(saves.load_slot(2)).is_true()
	assert_bool(GameState.flag_is_true(PROBE_FLAG)).is_true()


func test_corrupt_slot_primary_falls_back_to_the_slot_backup() -> void:
	GameState.set_flag(PROBE_FLAG, true)
	assert_bool(saves.save_to_slot(1)).is_true()
	# A second save rotates the first payload into the slot's .bak.
	assert_bool(saves.save_to_slot(1)).is_true()
	var slot_path: String = saves.manual_slot_path(1)
	var vandal := FileAccess.open(slot_path, FileAccess.WRITE)
	vandal.store_string("not a save payload")
	vandal.close()
	GameState.set_flag(PROBE_FLAG, false)
	assert_bool(saves.load_slot(1)).is_true()
	assert_bool(GameState.flag_is_true(PROBE_FLAG)).is_true()
	var warned := false
	for diagnostic in save_diagnostics:
		warned = warned or str(diagnostic.get("message", "")).contains("backup")
	assert_bool(warned).is_true()


func test_out_of_range_slots_are_rejected() -> void:
	assert_bool(saves.save_to_slot(0)).is_false()
	assert_bool(saves.save_to_slot(SaveGameScript.MANUAL_SLOT_COUNT + 1)).is_false()
	assert_bool(saves.load_slot(0)).is_false()
	assert_bool(saves.has_manual_save(0)).is_false()
	var summary: Dictionary = saves.manual_slot_summary(0)
	assert_bool(bool(summary.get("exists", true))).is_false()


func test_manual_slot_summary_reports_picker_metadata() -> void:
	var empty: Dictionary = saves.manual_slot_summary(3)
	assert_bool(bool(empty.get("exists", true))).is_false()
	assert_bool(saves.save_to_slot(3)).is_true()
	var summary: Dictionary = saves.manual_slot_summary(3)
	assert_bool(bool(summary.get("exists", false))).is_true()
	assert_int(int(summary.get("saved_at", 0))).is_greater(0)
	# Off-tree saves fall back to the DOM location default in _build_payload().
	assert_str(str(summary.get("location_id", ""))).is_equal("dom")


func _record_save_diagnostic(severity: String, message: String) -> void:
	save_diagnostics.append({"severity": severity, "message": message})


func _remove_test_saves() -> void:
	var paths: Array[String] = [saves.save_path, saves.temp_path, saves.backup_path]
	for slot in range(1, SaveGameScript.MANUAL_SLOT_COUNT + 1):
		var slot_path: String = saves.manual_slot_path(slot)
		paths.append(slot_path)
		paths.append(slot_path + ".tmp")
		paths.append(slot_path + ".bak")
	for path in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
