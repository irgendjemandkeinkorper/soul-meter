extends GdUnitTestSuite
## Save schema 6 — the tactical section added by issue #141.
##
## Schema 5 -> 6 adds a top-level `tactical` block (units / unit_jobs /
## unit_attunement / unit_loadout) derived from the party already in the save.

const SaveGameScript := preload("res://globals/save_game.gd")
const SCHEMA_FIVE_FIXTURE_PATH := "res://test/fixtures/save_game_schema_5.json"
const SCHEMA_SIX_FIXTURE_PATH := "res://test/fixtures/save_game_schema_6.json"

var saves
var test_save_paths: Array[String] = []
var game_state_before_test: Dictionary = {}


func before_test() -> void:
	game_state_before_test = GameState.to_dict()
	saves = auto_free(SaveGameScript.new())
	# Save-rotation work must never touch the developer's real slot.
	var prefix := OS.get_temp_dir().path_join("soul-meter-schema6-%s" % Time.get_ticks_usec())
	saves.save_path = prefix + ".save"
	saves.temp_path = prefix + ".save.tmp"
	saves.backup_path = prefix + ".save.bak"
	test_save_paths = [saves.save_path, saves.temp_path, saves.backup_path]
	_remove_test_saves()


func after_test() -> void:
	_remove_test_saves()
	GameState.from_dict(game_state_before_test)


func _remove_test_saves() -> void:
	for path in test_save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fixture(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	assert_object(file).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_bool(parsed is Dictionary).is_true()
	var fixture: Dictionary = parsed
	# JSON represents every number as a float; the binary envelope stores ints.
	fixture["version"] = int(fixture["version"])
	fixture["schema_version"] = int(fixture["schema_version"])
	fixture["elapsed_seconds"] = int(fixture["elapsed_seconds"])
	fixture["ng_plus"]["style_points"] = int(fixture["ng_plus"]["style_points"])
	return fixture


func test_current_schema_is_eight() -> void:
	# Schema 7 = schema 6 + the FR-504a world_clock envelope.
	# Schema 8 = the 2026-09-06 elemental rename (every Wheel id but `khor`).
	assert_int(SaveGameScript.SCHEMA_VERSION).is_equal(8)
	assert_int(SaveMigrations.CURRENT_SCHEMA_VERSION).is_equal(8)


func test_the_schema_five_fixture_still_loads_and_gains_a_tactical_section() -> void:
	var prepared: Dictionary = saves._prepare_for_load(_fixture(SCHEMA_FIVE_FIXTURE_PATH))
	assert_bool(prepared["ok"]).is_true()
	assert_int(prepared["payload"]["schema_version"]).is_equal(8)
	var tactical: Dictionary = prepared["payload"]["tactical"]
	for table_key in ["units", "unit_jobs", "unit_attunement", "unit_loadout"]:
		assert_bool(tactical.has(table_key)).is_true()
	# That fixture has an empty game_state, so it has no party to project.
	assert_bool((tactical["units"] as Dictionary).is_empty()).is_true()


func test_migration_derives_units_from_the_party_already_in_a_schema_five_save() -> void:
	var payload := _fixture(SCHEMA_FIVE_FIXTURE_PATH)
	payload["game_state"] = {
		"party": [
			{"id": "vex", "display_name": "Vex", "max_hp": 28},
			{"id": "", "display_name": "Iris Illepah", "max_hp": 20},
		]
	}
	var migration: Dictionary = SaveMigrations.prepare(payload)
	assert_bool(migration["ok"]).is_true()
	var units: Dictionary = migration["payload"]["tactical"]["units"]
	assert_int(units.size()).is_equal(2)
	assert_bool(units.has("vex")).is_true()
	assert_bool(units.has("iris-illepah")).is_true()
	assert_int(int(units["vex"]["base_hp"])).is_equal(28)
	# Every derived unit gets a complete, neutral attunement row.
	var attunement: Dictionary = migration["payload"]["tactical"]["unit_attunement"]["vex"]
	assert_int((attunement["values"] as Dictionary).size()).is_equal(ElementWheel.ORDER.size())


func test_migration_does_not_overwrite_an_existing_tactical_section() -> void:
	var payload := _fixture(SCHEMA_SIX_FIXTURE_PATH)
	payload["schema_version"] = 5
	var migration: Dictionary = SaveMigrations.prepare(payload)
	assert_bool(migration["ok"]).is_true()
	var units: Dictionary = migration["payload"]["tactical"]["units"]
	assert_bool(units.has("fixture-unit")).is_true()


func test_the_schema_six_fixture_round_trips_through_disk() -> void:
	var prepared: Dictionary = saves._prepare_for_load(_fixture(SCHEMA_SIX_FIXTURE_PATH))
	assert_bool(prepared["ok"]).is_true()

	var file := FileAccess.open(saves.save_path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	file.store_var(prepared["payload"])
	file.close()

	var round_trip: Dictionary = saves._prepare_for_load(saves._read_payload(saves.save_path))
	assert_bool(round_trip["ok"]).is_true()
	assert_int(round_trip["payload"]["schema_version"]).is_equal(8)
	var roster := UnitRoster.from_dict(round_trip["payload"]["tactical"])
	assert_object(roster).is_not_null()
	assert_array(Array(roster.unit_ids())).is_equal(["fixture-unit"])
	assert_int(roster.unit("fixture-unit").base_hp).is_equal(24)
	# The signed extremes must survive a save/load round trip intact.
	assert_int(roster.attunement("fixture-unit").value_for(&"sul")).is_equal(3)
	assert_int(roster.attunement("fixture-unit").value_for(&"vekh")).is_equal(-3)
	assert_int(roster.attunement("fixture-unit").value_for(&"zhem")).is_equal(-2)


func test_an_out_of_range_attunement_value_fails_the_whole_load() -> void:
	var payload := _fixture(SCHEMA_SIX_FIXTURE_PATH)
	payload["tactical"]["unit_attunement"]["fixture-unit"]["values"]["sul"] = 4
	var prepared: Dictionary = saves._prepare_for_load(payload)
	assert_bool(prepared["ok"]).is_false()
	assert_str(prepared["error"]).contains("tactical")


func test_an_element_outside_the_wheel_fails_the_whole_load() -> void:
	var payload := _fixture(SCHEMA_SIX_FIXTURE_PATH)
	payload["tactical"]["unit_attunement"]["fixture-unit"]["values"]["eleventh"] = 0
	assert_bool(saves._prepare_for_load(payload)["ok"]).is_false()


func test_a_built_payload_carries_a_roster_reconciled_against_the_live_party() -> void:
	var member := PartyMember.new()
	member.id = "synthetic-lead"
	member.display_name = "Synthetic Lead"
	member.max_hp = 33
	GameState.set_party([member])

	var payload: Dictionary = saves._build_payload()
	assert_int(payload["schema_version"]).is_equal(8)
	var units: Dictionary = payload["tactical"]["units"]
	assert_bool(units.has("synthetic-lead")).is_true()
	assert_int(int(units["synthetic-lead"]["base_hp"])).is_equal(33)
	assert_bool(saves.validate_payload(payload)).is_true()


func test_new_game_resets_the_roster_to_the_seeded_party() -> void:
	saves.unit_roster = UnitMigration.roster_from_party_rows(
		[{"id": "stale-unit", "display_name": "Stale", "max_hp": 1}]
	)
	saves.new_game()
	assert_bool(saves.unit_roster.units.has("stale-unit")).is_false()
	assert_int(saves.unit_roster.units.size()).is_equal(GameState.party.size())
