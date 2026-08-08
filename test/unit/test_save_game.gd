extends GdUnitTestSuite

const SaveGameScript := preload("res://globals/save_game.gd")
const SAVE_GAME_SOURCE_PATH := "res://globals/save_game.gd"
const SCHEMA_FIVE_FIXTURE_PATH := "res://test/fixtures/save_game_schema_5.json"
var saves
var test_save_paths: Array[String] = []
var diagnostics: Array[Dictionary] = []
var save_diagnostics: Array[Dictionary] = []
var game_state_before_test: Dictionary = {}
var reputation_before_test: Dictionary = {}
var renown_before_test: Dictionary = {}
var quests_before_test: Dictionary = {}
var target_scene_before_test := ""
var target_spawn_id_before_test: StringName = &"default"


func before_test() -> void:
	game_state_before_test = GameState.to_dict()
	reputation_before_test = Reputation.to_dict()
	renown_before_test = Renown.to_dict()
	quests_before_test = QuestRegistry.to_dict()
	target_scene_before_test = GameFlow._target_scene
	target_spawn_id_before_test = GameFlow._target_spawn_id
	saves = auto_free(SaveGameScript.new())
	var test_save_prefix := OS.get_temp_dir().path_join(
		"soul-meter-gdunit-save-%s" % Time.get_ticks_usec()
	)
	saves.save_path = test_save_prefix + ".save"
	saves.temp_path = test_save_prefix + ".save.tmp"
	saves.backup_path = test_save_prefix + ".save.bak"
	test_save_paths = [saves.save_path, saves.temp_path, saves.backup_path]
	diagnostics.clear()
	save_diagnostics.clear()
	saves.spawn_marker_diagnostic.connect(_record_spawn_diagnostic)
	saves.save_diagnostic.connect(_record_save_diagnostic)
	_remove_test_saves()


func after_test() -> void:
	_remove_test_saves()
	GameState.from_dict(game_state_before_test)
	Reputation.from_dict(reputation_before_test)
	Renown.from_dict(renown_before_test)
	QuestRegistry.from_dict(quests_before_test)
	GameFlow._target_scene = target_scene_before_test
	GameFlow._target_spawn_id = target_spawn_id_before_test


func test_validation_accepts_a_complete_current_payload() -> void:
	var payload := {
		"version": SaveGameScript.FORMAT_VERSION,
		"scene": GameFlow.TOWN_SCENE,
		"game_state": {},
		"reputation": {},
		"renown": {},
		"quests": {},
	}
	assert_bool(saves.validate_payload(payload)).is_true()


func test_validation_rejects_unknown_versions_and_partial_payloads() -> void:
	assert_bool(saves.validate_payload({"version": 999})).is_false()
	assert_bool(saves.validate_payload({"version": 1})).is_false()
	assert_bool(saves.validate_payload(null)).is_false()
	assert_bool(saves.validate_payload({"schema_version": 999})).is_false()


func test_current_envelope_has_schema_manifest_and_ng_plus_defaults() -> void:
	var payload: Dictionary = saves._build_payload()
	assert_int(payload["schema_version"]).is_equal(SaveGameScript.SCHEMA_VERSION)
	assert_str(payload["location_id"]).is_equal("dom")
	assert_bool(payload.has("id_schemas")).is_true()
	assert_int(payload["ng_plus"]["style_points"]).is_equal(0)
	assert_array(payload["ng_plus"]["purchased_carry_overs"]).is_empty()
	assert_bool(payload["zhavar"] is Dictionary).is_true()


func test_save_game_does_not_access_private_game_flow_members() -> void:
	var source_file := FileAccess.open(SAVE_GAME_SOURCE_PATH, FileAccess.READ)
	assert_object(source_file).is_not_null()
	var source := source_file.get_as_text()
	source_file.close()
	assert_str(source).not_contains("GameFlow._")


func test_schema_five_scene_path_fixture_round_trips_with_stable_location_id() -> void:
	var fixture_file := FileAccess.open(SCHEMA_FIVE_FIXTURE_PATH, FileAccess.READ)
	assert_object(fixture_file).is_not_null()
	var fixture: Variant = JSON.parse_string(fixture_file.get_as_text())
	fixture_file.close()
	assert_bool(fixture is Dictionary).is_true()
	# JSON represents every number as a float; restore the integer fields used
	# by the binary save envelope before exercising the compatibility adapter.
	fixture["version"] = int(fixture["version"])
	fixture["schema_version"] = int(fixture["schema_version"])
	fixture["elapsed_seconds"] = int(fixture["elapsed_seconds"])
	fixture["ng_plus"]["style_points"] = int(fixture["ng_plus"]["style_points"])

	var prepared: Dictionary = saves._prepare_for_load(fixture)
	assert_bool(prepared["ok"]).is_true()
	# The schema-5 fixture still loads; it is now migrated forward to the current
	# schema rather than staying at 5 (issue #141 added the schema-6 tactical section).
	assert_int(prepared["payload"]["schema_version"]).is_equal(SaveGameScript.SCHEMA_VERSION)
	assert_str(prepared["payload"]["location_id"]).is_equal("wilds")

	var round_trip_file := FileAccess.open(saves.save_path, FileAccess.WRITE)
	assert_object(round_trip_file).is_not_null()
	round_trip_file.store_var(prepared["payload"])
	round_trip_file.close()
	var round_trip: Dictionary = saves._prepare_for_load(saves._read_payload(saves.save_path))
	assert_bool(round_trip["ok"]).is_true()
	assert_str(round_trip["payload"]["location_id"]).is_equal("wilds")
	assert_str(round_trip["payload"]["scene"]).is_equal("res://world/test_room.tscn")
	assert_str(round_trip["payload"]["spawn_id"]).is_equal("from_dom")


func test_legacy_schema_migrates_without_losing_existing_values() -> void:
	var current: Dictionary = saves._build_payload()
	current["version"] = SaveGameScript.FORMAT_VERSION
	current.erase("schema_version")
	current.erase("id_schemas")
	# A genuine v2/v3 payload predates Defining Strikes, so it cannot carry
	# combat_knowledge. _build_payload() snapshots the LIVE GameState, which an
	# earlier suite may have populated — without erasing this the assertion below
	# becomes order-dependent and passes or fails on suite ordering alone.
	current["game_state"].erase("combat_knowledge")
	current["game_state"]["skills"] = {
		"vex": {"persuasion": {"percentage": 61, "tier": "Expert", "advancement_points_spent": 4}}
	}
	current["game_state"]["var_harmony"] = {"vex": -3}
	current["zhavar"] = {"dom": "tolling"}
	current["ng_plus"] = {
		"style_points": 17,
		"purchased_carry_overs": ["keep-skill-persuasion"],
		"completion_metadata": {"ending": "stillpoint"},
	}
	assert_bool(saves.validate_payload(current)).is_true()
	var prepared: Dictionary = saves._prepare_for_load(current)
	var migrated: Dictionary = prepared["payload"]
	assert_int(migrated["schema_version"]).is_equal(SaveGameScript.SCHEMA_VERSION)
	assert_int(migrated["game_state"]["skills"]["vex"]["persuasion"]["advancement_points_spent"]).is_equal(4)
	assert_int(migrated["game_state"]["var_harmony"]["vex"]).is_equal(-3)
	assert_bool(migrated["game_state"]["combat_knowledge"].is_empty()).is_true()
	assert_bool(migrated["game_state"]["vendor_stock"].is_empty()).is_true()
	assert_bool(migrated["game_state"]["vendor_restock_cycles"].is_empty()).is_true()
	assert_bool(migrated["id_schemas"].has("vendor")).is_true()
	assert_str(migrated["zhavar"]["dom"]).is_equal("tolling")
	assert_int(migrated["ng_plus"]["style_points"]).is_equal(17)


func test_envelope_round_trip_preserves_all_ratified_save_sections() -> void:
	var payload: Dictionary = saves._build_payload()
	payload["game_state"]["flags"] = {"chapter_dorthkor_commissioned": true}
	payload["game_state"]["skills"] = {
		"vex": {"persuasion": {"percentage": 74.5, "tier": "Trained", "advancement_points_spent": 9}}
	}
	payload["game_state"]["var_harmony"] = {"vex": 5}
	payload["game_state"]["combat_knowledge"] = {
		"mustered-bloodbellow": {
			"encounters": 2,
			"weaknesses": ["mustered-bloodbellow/binding-oath"],
		}
	}
	payload["reputation"] = {
		"log": [{"actor": "player", "faction": "mirror-choir", "delta": 12.0}],
		"next_order": 1,
	}
	payload["renown"] = {
		"log": [{"actor": "player", "kind": "infamy", "delta": 3.0}],
		"next_order": 1,
	}
	payload["quests"] = {"available": [], "active": [], "completed": []}
	payload["zhavar"] = {"dom": "rising", "dorthkor": "unprecedented"}
	payload["ng_plus"] = {
		"style_points": 31,
		"purchased_carry_overs": ["keep-renown"],
		"completion_metadata": {"ending_family": "stillpoint"},
	}
	var prepared: Dictionary = saves._prepare_for_load(payload)
	assert_bool(prepared["ok"]).is_true()
	var restored: Dictionary = prepared["payload"]
	assert_bool(restored["game_state"]["flags"]["chapter_dorthkor_commissioned"]).is_true()
	assert_float(restored["game_state"]["skills"]["vex"]["persuasion"]["percentage"]).is_equal_approx(74.5, 0.001)
	assert_str(restored["game_state"]["skills"]["vex"]["persuasion"]["tier"]).is_equal("Trained")
	assert_int(restored["game_state"]["skills"]["vex"]["persuasion"]["advancement_points_spent"]).is_equal(9)
	assert_int(restored["game_state"]["var_harmony"]["vex"]).is_equal(5)
	assert_int(
		restored["game_state"]["combat_knowledge"]["mustered-bloodbellow"]["encounters"]
	).is_equal(2)
	assert_array(
		restored["game_state"]["combat_knowledge"]["mustered-bloodbellow"]["weaknesses"]
	).contains("mustered-bloodbellow/binding-oath")
	assert_float(restored["reputation"]["log"][0]["delta"]).is_equal_approx(12.0, 0.001)
	assert_str(restored["renown"]["log"][0]["kind"]).is_equal("infamy")
	assert_str(restored["zhavar"]["dorthkor"]).is_equal("unprecedented")
	assert_int(restored["ng_plus"]["style_points"]).is_equal(31)


func test_schema_four_save_migrates_vendor_state_and_stable_id_manifest() -> void:
	var payload: Dictionary = saves._build_payload()
	payload["schema_version"] = 4
	payload["id_schemas"].erase("vendor")
	payload["game_state"].erase("vendor_stock")
	payload["game_state"].erase("vendor_restock_cycles")
	var prepared: Dictionary = saves._prepare_for_load(payload)
	assert_bool(prepared["ok"]).is_true()
	var migrated: Dictionary = prepared["payload"]
	assert_int(migrated["schema_version"]).is_equal(SaveGameScript.SCHEMA_VERSION)
	assert_bool(migrated["id_schemas"].has("vendor")).is_true()
	assert_bool(migrated["game_state"]["vendor_stock"].is_empty()).is_true()
	assert_bool(migrated["game_state"]["vendor_restock_cycles"].is_empty()).is_true()


func test_envelope_round_trip_preserves_var_harmony_boundaries() -> void:
	for boundary in [-5, 5]:
		var payload: Dictionary = saves._build_payload()
		payload["game_state"]["var_harmony"] = {"vex": boundary}

		var prepared: Dictionary = saves._prepare_for_load(payload)
		assert_bool(prepared["ok"]).is_true()
		assert_int(prepared["payload"]["game_state"]["var_harmony"]["vex"]).is_equal(
			boundary
		)


func test_weakness_discovery_survives_a_save_round_trip() -> void:
	GameState.combat_knowledge.clear()
	assert_bool(
		GameState.discover_weakness(
			&"mustered-bloodbellow", &"mustered-bloodbellow/binding-oath"
		)
	).is_true()
	GameState.record_archetype_encounter(&"mustered-bloodbellow")
	var payload: Dictionary = saves._build_payload()
	var prepared: Dictionary = saves._prepare_for_load(payload)
	assert_bool(prepared["ok"]).is_true()

	GameState.combat_knowledge.clear()
	assert_bool(GameState.from_dict(prepared["payload"]["game_state"])).is_true()
	assert_bool(
		GameState.has_discovered_weakness(
			&"mustered-bloodbellow", &"mustered-bloodbellow/binding-oath"
		)
	).is_true()
	assert_int(GameState.prior_archetype_encounters(&"mustered-bloodbellow")).is_equal(1)


func test_corrupt_payload_fails_loudly_before_state_application() -> void:
	var corrupt: Dictionary = saves._build_payload()
	corrupt["game_state"]["skills"] = ["not-a-skill-map"]
	assert_bool(saves.validate_payload(corrupt)).is_false()
	assert_str(saves._prepare_for_load(corrupt)["error"]).contains("game_state")
	corrupt["game_state"] = "not-a-dictionary"
	assert_bool(saves.validate_payload(corrupt)).is_false()


func test_ng_plus_transform_is_idempotent_and_preserves_metadata() -> void:
	var initial := {"game_state": {"flags": {"new_game": true}}}
	var block := {
		"style_points": 23,
		"purchased_carry_overs": ["keep-renown", "keep-renown", "signature-item"],
		"completion_metadata": {"chapter": 1},
	}
	var once: Dictionary = saves.apply_ng_plus_to_new_game(initial, block)
	var twice: Dictionary = saves.apply_ng_plus_to_new_game(once, block)
	assert_int(once["ng_plus"]["style_points"]).is_equal(23)
	assert_int(twice["ng_plus"]["style_points"]).is_equal(23)
	assert_array(once["ng_plus"]["purchased_carry_overs"]).is_equal([
		"keep-renown", "signature-item"
	])
	assert_array(twice["ng_plus"]["purchased_carry_overs"]).is_equal([
		"keep-renown", "signature-item"
	])


func test_validation_rejects_malicious_or_invalid_payload_fields() -> void:
	var base_payload := {
		"version": SaveGameScript.FORMAT_VERSION,
		"scene": GameFlow.TOWN_SCENE,
		"game_state": {},
		"reputation": {},
		"renown": {},
		"quests": {},
	}

	# Test with too long spawn_id
	var payload_long_spawn := base_payload.duplicate()
	payload_long_spawn["spawn_id"] = "a".repeat(100)
	assert_bool(saves.validate_payload(payload_long_spawn)).is_false()

	# Test with non-string spawn_id
	var payload_invalid_spawn := base_payload.duplicate()
	payload_invalid_spawn["spawn_id"] = 123
	assert_bool(saves.validate_payload(payload_invalid_spawn)).is_false()

	# Test with non-numeric elapsed_seconds
	var payload_invalid_elapsed := base_payload.duplicate()
	payload_invalid_elapsed["elapsed_seconds"] = "not a number"
	assert_bool(saves.validate_payload(payload_invalid_elapsed)).is_false()


func test_security_validation_rejects_malicious_keys_and_field_lengths() -> void:
	var base_payload := {
		"version": SaveGameScript.FORMAT_VERSION,
		"scene": GameFlow.TOWN_SCENE,
		"game_state": {},
		"reputation": {},
		"renown": {},
		"quests": {},
	}

	# 1. Test overly long ledger fields
	var payload_bad_ledger := base_payload.duplicate()
	payload_bad_ledger["reputation"] = {
		"log": [{
			"actor": "player",
			"faction": "mirror-choir",
			"delta": 10.0,
			"cause": "a".repeat(300), # too long
			"scene": "dom",
			"at": 1234567,
			"order": 1
		}],
		"next_order": 1
	}
	assert_bool(saves.validate_payload(payload_bad_ledger)).is_false()

	# 2. Test invalid / malicious Zhavar keys (Zone ID not in stable format or too long)
	var payload_bad_zhavar_key := base_payload.duplicate()
	payload_bad_zhavar_key["zhavar"] = {
		"a".repeat(100): "rising"
	}
	assert_bool(saves.validate_payload(payload_bad_zhavar_key)).is_false()

	# 3. Test invalid Zhavar value
	var payload_bad_zhavar_val := base_payload.duplicate()
	payload_bad_zhavar_val["zhavar"] = {
		"dom": "invalid_rung"
	}
	assert_bool(saves.validate_payload(payload_bad_zhavar_val)).is_false()


## RenownEvent.kind is a StringName, and `StringName is String` is false in
## GDScript — a length check written only against String rejects every genuine
## renown row, so any save carrying renown history stops loading. The bad
## version of this passed in isolation and only broke in a full run, where an
## earlier suite had already put rows in the ledger; assert on a real
## Renown.to_dict() so the trap cannot come back unnoticed.
func test_ledger_validation_accepts_real_renown_rows_with_stringname_kind() -> void:
	Renown.gain_infamy("player", 3.0, "Broke the compact", "dom")
	var renown_payload := Renown.to_dict()
	assert_int(renown_payload["log"].size()).is_greater(0)
	assert_bool(renown_payload["log"][0]["kind"] is StringName).is_true()

	var payload := {
		"version": SaveGameScript.FORMAT_VERSION,
		"scene": GameFlow.TOWN_SCENE,
		"game_state": {},
		"reputation": {},
		"renown": renown_payload,
		"quests": {},
	}
	assert_bool(saves.validate_payload(payload)).is_true()

	# The length bound still has to bite on an oversized kind.
	var oversized := payload.duplicate(true)
	oversized["renown"]["log"][0]["kind"] = "a".repeat(100)
	assert_bool(saves.validate_payload(oversized)).is_false()

	# 4. Test invalid Var Harmony keys (Actor ID too long / not stable format)
	var raw_data: Dictionary = GameState.to_dict()
	raw_data["var_harmony"] = {
		"a".repeat(100): 3
	}
	assert_bool(GameState.validate_save_data(raw_data)).is_false()

	# 5. Test invalid Var Harmony values
	var raw_data_val: Dictionary = GameState.to_dict()
	raw_data_val["var_harmony"] = {
		"vex": 99 # too high
	}
	assert_bool(GameState.validate_save_data(raw_data_val)).is_false()


func test_flags_validation_and_coercion() -> void:
	# Test that game state successfully filters malicious or overly long flags.
	# Build on a REAL serialized GameState rather than a hand-rolled minimal
	# dictionary: from_dict deserializes the inventory, and GLoot rejects an
	# empty {} payload, so a minimal literal fails for reasons unrelated to the
	# security property under test.
	var raw_data: Dictionary = GameState.to_dict()
	raw_data["flags"] = {
		"safe_flag": true,
		"a".repeat(200): true, # overly long key — filtered
	}
	# A non-String key (integer) — filtered. Note "123" as a *String* key would
	# be kept and should be: it is a legal short string, not an attack.
	raw_data["flags"][123] = "invalid_key_type"

	assert_bool(GameState.from_dict(raw_data)).is_true()
	assert_bool(GameState.get_flag("safe_flag", false)).is_true()
	assert_bool(GameState.get_flag("a".repeat(200), false)).is_false()
	assert_bool(GameState.flags.has(123)).is_false()


func test_validation_rejects_non_gameplay_scene_injection() -> void:
	var payload := {
		"version": SaveGameScript.FORMAT_VERSION,
		"scene": "res://ui/screens/main_menu.tscn",
		"game_state": {},
		"reputation": {},
		"renown": {},
		"quests": {},
	}
	assert_bool(saves.validate_payload(payload)).is_false()


func test_format_two_is_an_intentional_clean_break() -> void:
	assert_int(SaveGameScript.FORMAT_VERSION).is_equal(2)


func test_named_spawn_ids_map_to_scene_marker_names() -> void:
	assert_str(saves._pascal_case("from_dorthkor")).is_equal("FromDorthkor")


func test_checkpoint_contract_names_player_visible_recovery_moments() -> void:
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.NEW_GAME]).is_equal(
		"initial-spawn"
	)
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.PARTY_FORMED]).is_equal(
		"party-formed"
	)
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.COMMISSION]).is_equal(
		"commission-accepted"
	)
	assert_str(
		saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.LOCATION_ARRIVAL]
	).is_equal("arrived")
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.ENCOUNTER_RESOLUTION]).is_equal(
		"encounter"
	)
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.RULING]).is_equal("ruling")
	assert_str(saves.CHECKPOINT_NAMES[SaveGameScript.Checkpoint.FREE_ROAM_UNLOCK]).is_equal(
		"free-roam-unlocked"
	)


func test_checkpoint_request_keeps_detail_in_autosave_reason() -> void:
	saves.request_checkpoint(SaveGameScript.Checkpoint.LOCATION_ARRIVAL, "dorthkor_reached")
	assert_str(saves._pending_autosave_reason).is_equal("arrived-dorthkor_reached")


func test_invalid_primary_payload_can_be_rejected_before_fallback() -> void:
	var invalid := {"version": SaveGameScript.FORMAT_VERSION, "scene": "user://broken"}
	assert_bool(saves.validate_payload(invalid)).is_false()
	assert_object(saves._read_payload("user://file-that-does-not-exist.save")).is_null()


func test_corrupted_primary_save_loads_from_last_known_good_backup() -> void:
	GameState.flags = {"save_generation": "first"}
	GameState.soul_meter = 17.5
	GameState.gp = 111
	assert_bool(saves.save()).is_true()
	GameState.flags = {"save_generation": "second"}
	GameState.soul_meter = 82.5
	GameState.gp = 222
	assert_bool(saves.save()).is_true()
	assert_bool(FileAccess.file_exists(saves.backup_path)).is_true()

	_corrupt_save(saves.save_path)

	assert_bool(saves.load_save()).is_true()
	assert_int(save_diagnostics.size()).is_equal(1)
	assert_str(save_diagnostics[0]["severity"]).is_equal("warning")
	assert_str(save_diagnostics[0]["message"]).contains("Primary save was invalid")
	assert_str(save_diagnostics[0]["message"]).contains("backup save")
	assert_str(GameState.flags["save_generation"]).is_equal("first")
	assert_float(GameState.soul_meter).is_equal_approx(17.5, 0.001)
	assert_int(GameState.gp).is_equal(111)
	assert_bool(FileAccess.file_exists(saves.save_path)).is_true()
	assert_bool(FileAccess.file_exists(saves.backup_path)).is_true()


func test_corrupted_primary_and_backup_fail_cleanly_without_rotating_files() -> void:
	assert_bool(saves.save()).is_true()
	assert_bool(saves.save()).is_true()
	_corrupt_save(saves.save_path)
	_corrupt_save(saves.backup_path)
	monitor_signals(saves)

	assert_bool(saves.load_save()).is_false()
	await assert_signal(saves).is_emitted("save_failed", any())
	assert_str(saves.last_error).contains("Could not load save")
	assert_bool(FileAccess.file_exists(saves.save_path)).is_true()
	assert_bool(FileAccess.file_exists(saves.backup_path)).is_true()


func test_missing_spawn_markers_emit_warning_and_error_diagnostics() -> void:
	var scene := Node2D.new()
	scene.name = "MissingSpawnScene"
	var player := Node2D.new()
	player.name = "Player"
	scene.add_child(player)
	add_child(scene)
	saves.has_pending_player_position = false
	saves.pending_spawn_id = &"missing_arrival"

	saves.apply_pending_location(scene)
	assert_vector(player.global_position).is_equal(Vector2.ZERO)
	assert_int(diagnostics.size()).is_equal(2)
	assert_str(diagnostics[0]["severity"]).is_equal("warning")
	assert_str(diagnostics[0]["marker_name"]).is_equal("SpawnMissingArrival")
	assert_str(diagnostics[0]["scene_path"]).is_equal("MissingSpawnScene")
	assert_str(diagnostics[1]["severity"]).is_equal("error")
	assert_str(diagnostics[1]["marker_name"]).is_equal("SpawnDefault")
	assert_str(diagnostics[1]["scene_path"]).is_equal("MissingSpawnScene")


func _corrupt_save(path: String) -> void:
	var corrupted := FileAccess.open(path, FileAccess.WRITE)
	assert_object(corrupted).is_not_null()
	corrupted.store_string("truncated save")
	corrupted.close()


func _remove_test_saves() -> void:
	for path in test_save_paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _record_spawn_diagnostic(severity: String, marker_name: String, scene_path: String) -> void:
	diagnostics.append(
		{
			"severity": severity,
			"marker_name": marker_name,
			"scene_path": scene_path,
		}
	)


func _record_save_diagnostic(severity: String, message: String) -> void:
	save_diagnostics.append({"severity": severity, "message": message})
