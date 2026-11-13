extends GdUnitTestSuite
## Schema 11 compatibility: only the live flat rail migrates; no legacy data loss.

const SaveGameScript := preload("res://globals/save_game.gd")
var _before: Dictionary
var _saves: SaveGameScript
var _paths: Array[String] = []


func before_test() -> void:
	_before = GameState.to_dict()
	_saves = auto_free(SaveGameScript.new())
	var prefix := OS.get_temp_dir().path_join("soul-meter-equipment-%s" % Time.get_ticks_usec())
	_saves.save_path = prefix + ".save"
	_saves.temp_path = prefix + ".save.tmp"
	_saves.backup_path = prefix + ".save.bak"
	_paths = [_saves.save_path, _saves.temp_path, _saves.backup_path]


func after_test() -> void:
	GameState.from_dict(_before)
	for path: String in _paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func test_flat_slots_migrate_to_protagonist_by_id_not_party_order() -> void:
	var source: Dictionary = {
		"schema_version": 10,
		"game_state": {
			"equipped_slots": {"main": ItemIds.WEAPONS_FORGE_HAMMER},
			"party": [{"id": "iris"}, {"id": "vex", "attack": 11, "defense": 4}],
		},
	}
	var result := SaveMigrations.prepare(source)
	assert_bool(result["ok"]).is_true()
	assert_int(result["payload"]["schema_version"]).is_equal(11)
	var state: Dictionary = result["payload"]["game_state"]
	assert_bool(state.has("equipped_slots")).is_false()
	assert_bool(state["party"][0].has("equipped_slots")).is_false()
	assert_dict(state["party"][1]["equipped_slots"]).is_equal({"main": ItemIds.WEAPONS_FORGE_HAMMER})
	assert_int(state["party"][1]["attack"]).is_equal(11)
	assert_dict(SaveMigrations.prepare(result["payload"])["payload"]).is_equal(result["payload"])
	assert_bool(source["game_state"].has("equipped_slots")).is_true()


func test_missing_equipment_and_unrelated_nested_legacy_records_are_unchanged() -> void:
	for state: Dictionary in [
		{"party": [{"id": "vex"}]},
		{"party": [{"id": "vex"}], "equipped_slots": {"vex": {"weapon": "taubstummer-axe"}}},
		{"party": [{"id": "iris"}], "equipped_slots": {"main": ItemIds.WEAPONS_FORGE_HAMMER}},
	]:
		assert_dict(SaveMigrations.migrate_equipment_state(state)).is_equal(state)


func test_existing_member_slots_take_precedence_when_migrating() -> void:
	var state: Dictionary = {
		"party": [{"id": "vex", "equipped_slots": {"main": ItemIds.WEAPONS_ROADWARDEN_SPEAR}}],
		"equipped_slots": {"main": ItemIds.WEAPONS_FORGE_HAMMER},
	}
	var migrated := SaveMigrations.migrate_equipment_state(state)
	assert_dict(migrated["party"][0]["equipped_slots"]).is_equal({"main": ItemIds.WEAPONS_ROADWARDEN_SPEAR})
	assert_bool(migrated.has("equipped_slots")).is_false()


func test_flat_save_loads_off_disk_and_resaves_with_per_member_slots() -> void:
	GameState.inventory.clear()
	var lead := PartyMember.new()
	lead.id = GameState.PROTAGONIST_ID
	lead.attack = 11
	lead.defense = 4
	var other := PartyMember.new()
	other.id = "iris"
	other.equipped_slots = {"main": ItemIds.WEAPONS_ROADWARDEN_SPEAR}
	GameState.set_party([other, lead])
	GameState.inventory.create_and_add_item(ItemIds.WEAPONS_FORGE_HAMMER)
	GameState.inventory.create_and_add_item(ItemIds.WEAPONS_ROADWARDEN_SPEAR)
	var payload: Dictionary = _saves._build_payload()
	payload["schema_version"] = 10
	payload["game_state"]["party"][1].erase("equipped_slots")
	payload["game_state"]["equipped_slots"] = {"main": ItemIds.WEAPONS_FORGE_HAMMER}
	var file := FileAccess.open(_saves.save_path, FileAccess.WRITE)
	file.store_var(payload)
	file.close()
	assert_bool(_saves.load_save()).is_true()
	assert_dict(GameState.protagonist().equipped_slots).is_equal({"main": ItemIds.WEAPONS_FORGE_HAMMER})
	assert_int(BattleActor.from_party_member(GameState.protagonist(), 1).attack).is_equal(13)
	assert_int(GameState.protagonist().attack).is_equal(11)
	assert_bool(_saves.save()).is_true()
	assert_bool(_saves.load_save()).is_true()
	assert_dict(GameState.party[0].equipped_slots).is_equal({"main": ItemIds.WEAPONS_ROADWARDEN_SPEAR})
	assert_int(BattleActor.from_party_member(GameState.protagonist(), 1).attack).is_equal(13)
	assert_int(GameState.inventory.get_item_count()).is_equal(2)
	file = FileAccess.open(_saves.save_path, FileAccess.READ)
	var resaved: Dictionary = file.get_var(false)
	file.close()
	assert_int(resaved["schema_version"]).is_equal(11)
	assert_bool(resaved["game_state"].has("equipped_slots")).is_false()
