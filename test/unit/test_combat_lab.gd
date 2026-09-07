extends GdUnitTestSuite

const CombatLabScript := preload("res://globals/combat_lab.gd")
const TEST_ENCOUNTER := &"combat-lab-catalog-probe"

var _game_state_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary
var _weather_before: Dictionary
var _spoils_before: Dictionary
var _definitions_before: Dictionary
var _matrix_before: Dictionary
var _wheel_before: Array[StringName]
var _catalog_file_before: String
var _ng_plus_before: Dictionary
var _skill_check_before: Dictionary
var _lab: Node


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	EncounterCatalog.definition(EncounterIds.BOG_WIGHT)
	_weather_before = EncounterCatalog._WEATHER_DEFAULTS.duplicate(true)
	_spoils_before = EncounterCatalog._SPOILS.duplicate(true)
	_definitions_before = EncounterCatalog._definitions.duplicate(true)
	_matrix_before = ElementMatrix.IDENTITY_ROW.duplicate(true)
	_wheel_before.assign(ElementWheel.ORDER)
	_catalog_file_before = FileAccess.get_file_as_string(EncounterCatalog.DATA_PATH)
	_ng_plus_before = SaveGame.ng_plus.duplicate(true)
	_skill_check_before = SkillCheck.to_dict().duplicate(true)
	_lab = auto_free(CombatLabScript.new()) as Node
	# Mutating entry points are gated on enablement, so a test that drives the
	# lab must go through the ratified seam rather than around it.
	add_child(_lab)
	_lab.set("force_enabled_for_tests", true)


func after_test() -> void:
	EncounterCatalog._definitions.erase(String(TEST_ENCOUNTER))
	if _lab != null:
		_lab.call("stop_test_session")
	var restored: bool = GameState.from_dict(_game_state_before)
	assert_bool(restored).is_true()
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	SaveGame.ng_plus = _ng_plus_before.duplicate(true)
	SkillCheck.from_dict(_skill_check_before)
	Battle.controller = null
	Battle.ended = true
	get_tree().paused = false


func test_encounter_ids_are_derived_from_the_catalog() -> void:
	EncounterCatalog._definitions[String(TEST_ENCOUNTER)] = {
		"display_name": "Combat Lab Probe",
		"enemies": [],
	}

	var encounter_ids: Array[StringName] = _lab.call("encounter_ids")
	var catalog_ids: Array[StringName] = []
	for key: Variant in EncounterCatalog._definitions.keys():
		catalog_ids.append(StringName(str(key)))
	catalog_ids.sort()

	assert_array(encounter_ids).is_equal(catalog_ids)
	assert_array(encounter_ids).contains([TEST_ENCOUNTER])


func test_weather_resolution_reports_authored_override_and_calm_sources() -> void:
	var authored: Dictionary = _lab.call("resolve_weather", EncounterIds.BOG_WIGHT, false, &"")
	var overridden: Dictionary = _lab.call(
		"resolve_weather", EncounterIds.BOG_WIGHT, true, &"strom"
	)
	var calm: Dictionary = _lab.call(
		"resolve_weather", EncounterIds.DORTHKOR_VANGUARD, false, &""
	)

	assert_str(str(authored["element_id"])).is_equal("molm")
	assert_str(str(authored["source"])).is_equal("authored")
	assert_str(str(overridden["element_id"])).is_equal("strom")
	assert_str(str(overridden["source"])).is_equal("override")
	assert_str(str(calm["element_id"])).is_empty()
	assert_str(str(calm["source"])).is_equal("calm")


func test_forecast_resolution_comparator_flags_only_a_divergence() -> void:
	var mismatch: Dictionary = _lab.call(
		"compare_forecast_resolution", {"damage": 14}, {"damage": 11}
	)
	var match_result: Dictionary = _lab.call(
		"compare_forecast_resolution", {"damage": 14}, {"damage": 14}
	)

	assert_bool(bool(mismatch["diverged"])).is_true()
	assert_array(mismatch["differences"]).is_not_empty()
	assert_bool(bool(match_result["diverged"])).is_false()
	assert_array(match_result["differences"]).is_empty()


func test_export_markdown_contains_setup_turn_rows_and_outcome() -> void:
	var setup := {
		"encounter_id": &"bog-wight",
		"party_ids": [&"vex", &"serai-lun"],
		"weather": {"element_id": &"strom", "source": &"override"},
		"tile_seed": {"cell": Vector2i(2, 1), "element_id": &"molm", "charge": 2},
		"seed": 42,
	}
	var turns: Array[Dictionary] = [{
		"turn": 1,
		"actor": "Vex",
		"action": "strike",
		"forecast": 14,
		"resolution": 14,
		"compared": true,
		"diverged": false,
	}]
	var markdown: String = _lab.call(
		"build_session_markdown", setup, turns, {"state": "victory", "outcome_id": "slain"}
	)

	assert_str(markdown).contains("# Combat Lab Session")
	assert_str(markdown).contains("bog-wight")
	assert_str(markdown).contains("| 1 | Vex | strike | 14 | 14 | MATCH |")
	assert_str(markdown).contains("victory")


func test_lab_session_never_mutates_authored_balance_data() -> void:
	var setup := {
		"encounter_id": EncounterIds.BOG_WIGHT,
		"party_ids": _current_party_ids(),
		"weather_override_enabled": true,
		"weather_override": &"strom",
		"tile_seed": {"cell": Vector2i(0, 0), "element_id": &"molm", "charge": 2},
		"seed": 77,
	}

	_lab.call("start_test_session", setup)

	assert_dict(EncounterCatalog._WEATHER_DEFAULTS).is_equal(_weather_before)
	assert_dict(EncounterCatalog._SPOILS).is_equal(_spoils_before)
	assert_dict(EncounterCatalog._definitions).is_equal(_definitions_before)
	assert_dict(ElementMatrix.IDENTITY_ROW).is_equal(_matrix_before)
	assert_array(ElementWheel.ORDER).is_equal(_wheel_before)
	assert_str(FileAccess.get_file_as_string(EncounterCatalog.DATA_PATH)).is_equal(_catalog_file_before)


func test_a_lab_session_does_not_leave_progression_behind() -> void:
	# Gate finding 1: a finished lab battle runs the PRODUCTION end-of-battle
	# path, which accrues style points into SaveGame.ng_plus and can consume
	# persistent expert rerolls — and Battle then requests a save checkpoint.
	# Restoring only GameState/Reputation/Renown let sandbox progress reach the
	# player's next real save.
	SaveGame.ng_plus = NGPlus.default_block()
	var clean_ng_plus := SaveGame.ng_plus.duplicate(true)
	var clean_skill_check := SkillCheck.to_dict().duplicate(true)

	_lab.call("start_test_session", {"encounter_id": EncounterIds.BOG_WIGHT, "seed": 5})
	# Dirty both persistence surfaces the way a finished battle would.
	# CombatStyleTracker is a Node: auto_free it, and type the var explicitly
	# because gdUnit treats `:=` inference from auto_free() as a parse error.
	var tracker: CombatStyleTracker = auto_free(CombatStyleTracker.new())
	SaveGame.ng_plus = tracker.accrue_into(SaveGame.ng_plus)
	SkillCheck.from_dict({"expert_rerolls_used": {"lab/test/insight": 1}})
	_lab.call("stop_test_session")

	assert_dict(SaveGame.ng_plus) \
		.override_failure_message("Lab style points must not survive the session") \
		.is_equal(clean_ng_plus)
	assert_dict(SkillCheck.to_dict()) \
		.override_failure_message("Lab expert-reroll consumption must not survive the session") \
		.is_equal(clean_skill_check)


func test_a_disabled_lab_cannot_be_driven_into_starting_a_battle() -> void:
	# Gate finding 3: inertness must mean "not drivable", not merely "does
	# nothing unprompted" — otherwise force_enabled_for_tests is decorative.
	var disabled := auto_free(CombatLabScript.new()) as Node
	add_child(disabled)
	disabled.set("force_enabled_for_tests", false)
	Battle.controller = null
	Battle.ended = true

	disabled.call("start_test_session", {"encounter_id": EncounterIds.BOG_WIGHT, "seed": 1})

	assert_object(Battle.controller) \
		.override_failure_message("A disabled Combat Lab must not start a Battle") \
		.is_null()
	assert_str(str(disabled.call("export_session"))) \
		.override_failure_message("A disabled Combat Lab must not write an export") \
		.is_empty()


func test_a_forecast_is_never_compared_against_a_different_target() -> void:
	# Gate finding 2: damage depends on the target's defence, so comparing a
	# forecast for enemy A against a resolution on enemy B reports MATCH on
	# coincidentally equal damage and a FALSE divergence when defences differ.
	var event := CombatEvent.new()
	event.actor_id = &"ally-1"
	event.target_id = &"enemy-2"
	event.data = {"action_id": &"strike", "damage": 7}
	_lab.set("_pending_forecast", {
		"actor_id": &"ally-1",
		"target_id": &"enemy-1",
		"action_id": &"strike",
		"damage": 7,
	})

	_lab.call("_record_resolution", event)

	var rows: Array = _lab.get("_turn_rows")
	assert_int(rows.size()).is_equal(1)
	assert_bool(bool(rows[0].get("compared", false))) \
		.override_failure_message(
			"A target mismatch must read as NOT COMPARED, never as a parity pass"
		) \
		.is_false()


func test_the_lab_refuses_to_open_or_start_over_a_running_production_battle() -> void:
	# Gate r2 additional finding: F3 during a real encounter called Battle.start()
	# unconditionally, destroying the live battle — and GameFlow's journey
	# listener would then advance journey state from the LAB's result.
	Battle.start(EncounterIds.BOG_WIGHT)
	var production_controller: CombatController = Battle.controller
	assert_object(production_controller).is_not_null()
	assert_bool(Battle.ended).is_false()

	_lab.call("start_test_session", {"encounter_id": EncounterIds.LOAM_BOAR, "seed": 3})

	assert_object(Battle.controller) \
		.override_failure_message("The lab must not replace a running production battle") \
		.is_same(production_controller)
	# The refusal must be AUDIBLE, not silent — a developer pressing F3 and
	# seeing nothing happen has no way to tell the lab from a broken hotkey.
	await assert_error(Callable(_lab, "open_setup")) \
		.is_push_warning(CombatLabScript.REFUSAL_WARNING)
	assert_bool(bool(_lab.get("_lab_battle_running"))).is_false()
	assert_object(_lab.get("_overlay_layer")) \
		.override_failure_message("open_setup() must refuse over a live production battle") \
		.is_null()

	# The hotkey is a SECOND entry point: a finished lab session keeps _setup,
	# so F3 during a later real battle took the "reopen the inspector" branch,
	# which did not go through open_setup()'s guard at all.
	_lab.set("_setup", {"encounter_id": EncounterIds.LOAM_BOAR, "seed": 3})
	var key := InputEventKey.new()
	key.pressed = true
	key.physical_keycode = CombatLabScript.TOGGLE_HOTKEY

	await assert_error(Callable(_lab, "_unhandled_key_input").bind(key)) \
		.is_push_warning(CombatLabScript.REFUSAL_WARNING)

	assert_object(_lab.get("_overlay_layer")) \
		.override_failure_message("F3 must not reopen a stale lab session over a live battle") \
		.is_null()


func test_the_progression_snapshot_does_not_reach_past_its_own_session() -> void:
	# Gate r2 finding 1 (second order): containment must be scoped to the
	# session. An armed snapshot that outlives the lab battle would roll back
	# progression the player legitimately earned after returning to normal play
	# — trading a leak for silent data loss.
	SaveGame.ng_plus = NGPlus.default_block()

	_lab.call("start_test_session", {"encounter_id": EncounterIds.BOG_WIGHT, "seed": 9})
	_lab.call("stop_test_session")

	# Progress earned AFTER the lab session ended.
	var tracker: CombatStyleTracker = auto_free(CombatStyleTracker.new())
	SaveGame.ng_plus = tracker.accrue_into(SaveGame.ng_plus)
	var earned_after := SaveGame.ng_plus.duplicate(true)

	# A second stop must not resurrect the stale pre-lab snapshot.
	_lab.call("stop_test_session")

	assert_dict(SaveGame.ng_plus) \
		.override_failure_message(
			"Post-session progression must survive; the snapshot must disarm after one restore"
		) \
		.is_equal(earned_after)


func test_a_restarted_session_is_still_contained() -> void:
	# Gate r3: restore-once disarmed the snapshot, and _start_session restored
	# WITHOUT re-capturing, so the restarted session ran uncontained — the very
	# leak restore-once was added to close, reintroduced by the fix for it.
	# Every session must begin armed, so restore and capture always run as a pair.
	SaveGame.ng_plus = NGPlus.default_block()
	var clean_ng_plus := SaveGame.ng_plus.duplicate(true)

	_lab.call("start_test_session", {"encounter_id": EncounterIds.BOG_WIGHT, "seed": 11})
	assert_bool(bool(_lab.call("sandbox_is_armed"))).is_true()

	# Restart, then dirty progression the way a finished battle would.
	_lab.call("restart_same_setup")
	assert_bool(bool(_lab.call("sandbox_is_armed"))) \
		.override_failure_message("A restarted session must be re-armed, not left uncontained") \
		.is_true()
	var tracker: CombatStyleTracker = auto_free(CombatStyleTracker.new())
	SaveGame.ng_plus = tracker.accrue_into(SaveGame.ng_plus)

	_lab.call("stop_test_session")

	assert_dict(SaveGame.ng_plus) \
		.override_failure_message("Progression from a RESTARTED lab session must not survive") \
		.is_equal(clean_ng_plus)


func test_restart_controls_cannot_replace_a_running_production_battle() -> void:
	# Gate r3: the restart buttons were the last two unguarded entry points into
	# Battle.start(). The inspector outlives the lab battle that opened it, so a
	# restart pressed once a real encounter has begun would destroy it.
	_lab.call("start_test_session", {"encounter_id": EncounterIds.BOG_WIGHT, "seed": 4})
	_lab.call("stop_test_session")
	_lab.set("_setup", {"encounter_id": EncounterIds.BOG_WIGHT, "seed": 4})

	Battle.start(EncounterIds.LOAM_BOAR)
	var production_controller: CombatController = Battle.controller
	assert_object(production_controller).is_not_null()

	_lab.call("restart_same_setup")
	_lab.call("restart_new_seed")

	assert_object(Battle.controller) \
		.override_failure_message("A restart must not replace a running production battle") \
		.is_same(production_controller)


func _current_party_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for member: PartyMember in GameState.party:
		ids.append(StringName(member.id))
	return ids
