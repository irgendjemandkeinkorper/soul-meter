extends GdUnitTestSuite

const SaveGameScript := preload("res://globals/save_game.gd")
var saves
var runtime_before: Dictionary


func before_test() -> void:
	runtime_before = SaveGame.capture_runtime_state()
	saves = auto_free(SaveGameScript.new())
	add_child(saves)
	var prefix := OS.get_temp_dir().path_join("soul-meter-structures-%s" % Time.get_ticks_usec())
	saves.save_path = prefix + ".save"
	saves.temp_path = prefix + ".tmp"
	saves.backup_path = prefix + ".bak"
	WorldClock.reset()


func after_test() -> void:
	for path: String in [saves.save_path, saves.temp_path, saves.backup_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	SaveGame.restore_runtime_state(runtime_before)


func test_only_declared_clock_advances_rebuild_structures() -> void:
	saves.world_structures.register_structure("gate", 10, 2)
	saves.world_structures.damage("gate", 10, 0)
	WorldClock.set_phase(&"evening", "presentation-only")
	WorldClock.from_dict({"phase": "morning", "phase_count": 0})
	for _index in range(3):
		await get_tree().process_frame
	assert_str(saves.world_structures.structure("gate")["state"]).is_equal("ruined")
	WorldClock.advance("travel:test")
	assert_str(saves.world_structures.structure("gate")["state"]).is_equal("rebuilding")
	WorldClock.advance("quest:test")
	assert_str(saves.world_structures.structure("gate")["state"]).is_equal("intact")


func test_disk_save_restores_damage_and_deadlines_without_aging_unloaded_sites() -> void:
	saves.world_structures.register_structure("town/gate", 10, 4)
	saves.world_structures.register_structure("wilds/temple", 10)
	saves.world_structures.register_service("test-grocer", "town/gate", "item-shop", "dom")
	saves.world_structures.damage("town/gate", 10, 0)
	saves.world_structures.damage("wilds/temple", 10, 0)
	WorldClock.advance("travel:test")
	assert_bool(saves.save()).is_true()
	for _index in range(3):
		WorldClock.advance("travel:test")
	assert_str(saves.world_structures.structure("town/gate")["state"]).is_equal("intact")
	assert_bool(saves.load_save()).is_true()
	assert_int(WorldClock.phase_count).is_equal(1)
	assert_str(saves.world_structures.structure("town/gate")["state"]).is_equal("rebuilding")
	assert_int(saves.world_structures.structure("town/gate")["rebuild_at"]).is_equal(4)
	assert_str(saves.world_structures.service_status("test-grocer")["location_id"]).is_equal("dom")
	for _index in range(3):
		WorldClock.advance("travel:test")
	assert_str(saves.world_structures.structure("town/gate")["state"]).is_equal("intact")
	assert_str(saves.world_structures.structure("wilds/temple")["state"]).is_equal("ruined")
	assert_str(saves.world_structures.service_status("test-grocer")["location_id"]).is_equal("item-shop")


func test_legacy_save_defaults_empty_and_corrupt_structure_section_is_rejected() -> void:
	var payload: Dictionary = saves._build_payload()
	payload.erase("world_structures")
	assert_bool(saves.validate_payload(payload)).is_true()
	payload["world_structures"] = {"structures": {"gate": {"integrity": -1}}}
	assert_bool(saves.validate_payload(payload)).is_false()
	payload["world_structures"] = []
	assert_bool(saves.validate_payload(payload)).is_false()


func test_snapshot_rollback_and_new_game_include_structures() -> void:
	saves.world_structures.register_structure("gate", 10, 4)
	saves.world_structures.damage("gate", 10, 0)
	var snapshot: Dictionary = saves.capture_runtime_state()
	saves.new_game()
	assert_dict(saves.world_structures.structure("gate")).is_empty()
	assert_bool(saves.restore_runtime_state(snapshot)).is_true()
	assert_str(saves.world_structures.structure("gate")["state"]).is_equal("ruined")
	assert_int(WorldClock.phase_count).is_zero()
