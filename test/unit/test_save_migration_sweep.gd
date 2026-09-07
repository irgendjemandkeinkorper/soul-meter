extends GdUnitTestSuite
## S6 (#300) — the save-integrity sweep.
##
## `test_save_migrations.gd` covers each hop in isolation with a small payload.
## This suite covers the thing a player actually does: take a save written by an
## older build, fully populated, and load it — through the whole chain at once,
## and off disk, in every manual slot.
##
## The three sections #300 names — `equipped_slots`, `class_resources.__deferred__`
## and the three manual slots — are the ones with no coverage today, and they
## share a failure mode: they are *additive* keys no migration function mentions,
## so nothing would notice if a future `duplicate()`/rebuild dropped them. Each is
## asserted by value here, not by presence.
##
## Version note: #300 was written when DRAMGID was expected to be the 6→7 hop. It
## is not — 6→7 is breath and 7→8 is the element rename (#371), both shipped, and
## the DRAMGID migration in `docs/architecture-dramgid.md` §3.8 still calls itself
## v7→v8 and will have to become 8→9. The sweep is written against the real chain.

const SaveGameScript := preload("res://globals/save_game.gd")

## Legacy element ids that must survive the schema-8 rename. Deliberately
## includes `khor`, the one id that does not change, so a rename that is too
## eager fails here too.
const LEGACY_MAJOR := "scor"
const LEGACY_MINOR := "khor"
const LEGACY_ATTUNEMENT_KEY := "aqua"

var saves
var game_state_before_test: Dictionary = {}
var reputation_before_test: Dictionary = {}
var renown_before_test: Dictionary = {}
var quests_before_test: Dictionary = {}
var skill_check_before_test: Dictionary = {}
var clock_before_test: Dictionary = {}


func before_test() -> void:
	game_state_before_test = GameState.to_dict()
	reputation_before_test = Reputation.to_dict()
	renown_before_test = Renown.to_dict()
	quests_before_test = QuestRegistry.to_dict()
	skill_check_before_test = SkillCheck.to_dict()
	clock_before_test = WorldClock.to_dict()
	saves = auto_free(SaveGameScript.new())
	var prefix := OS.get_temp_dir().path_join(
		"soul-meter-gdunit-sweep-%s" % Time.get_ticks_usec()
	)
	saves.save_path = prefix + ".save"
	saves.temp_path = prefix + ".save.tmp"
	saves.backup_path = prefix + ".save.bak"
	_remove_test_saves()


func after_test() -> void:
	_remove_test_saves()
	GameState.from_dict(game_state_before_test)
	Reputation.from_dict(reputation_before_test)
	Renown.from_dict(renown_before_test)
	QuestRegistry.from_dict(quests_before_test)
	SkillCheck.from_dict(skill_check_before_test)
	WorldClock.from_dict(clock_before_test)


func _remove_test_saves() -> void:
	var paths: Array[String] = [saves.save_path, saves.temp_path, saves.backup_path]
	for slot: int in range(1, SaveGameScript.MANUAL_SLOT_COUNT + 1):
		var slot_path: String = saves.manual_slot_path(slot)
		paths.append_array([slot_path, slot_path + ".tmp", slot_path + ".bak"])
	for path: String in paths:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


## A schema-5 save from a real playthrough: a party mid-run, custom recruits,
## equipment in slots, deferred class-resource entries, and tactical attunement
## keyed by the old element ids. Schema 5 is chosen because it is the oldest
## version that exercises every hop still in `prepare()`.
func _legacy_payload() -> Dictionary:
	return {
		"schema_version": 5,
		"saved_at": 1_700_000_000,
		"elapsed_seconds": 4321,
		"location_id": "dom",
		# The destination key is `scene`, not `scene_path` — `_destination_from_payload`
		# reads it, and a payload without it fails the whole load as "not a gameplay scene".
		"scene": "res://world/starting_town.tscn",
		"spawn_id": "default",
		"game_state": {
			# A real serialized inventory: `GameState.from_dict` runs it through
			# `inventory.deserialize()`, which rejects an empty dictionary, so a
			# hand-written `{}` here fails the whole load rather than defaulting.
			"inventory": game_state_before_test.get("inventory", {}),
			"soul_meter": 42.0,
			"flags": {"chapter_one_started": true, "met_iris": true},
			"equipped_slots": {
				"vex": {"weapon": "taubstummer-axe", "relic": "quine-shard"},
				"korrath": {"weapon": "split-anvil"},
			},
			# Keyed by ACTOR, with the skill map one level down — the shape
			# `GameState._validate_save_data` enforces, and the one the schema-8
			# rename has to reach through.
			"skills": {
				"vex": {
					"tone_scor": {"percentage": 30.0, "tier": "Trained"},
					"tone_khor": {"percentage": 12.0},
					"sway": {"percentage": 45.0},
				},
				"ardyn": {
					"tone_strom": {"percentage": 20.0},
				},
			},
			"party": [
				{
					"id": "vex",
					"display_name": "Vex the Unbowed",
					"level": 7,
					"hp": 45,
					"max_hp": 60,
					"major_element": LEGACY_MAJOR,
					"minor_element": LEGACY_MINOR,
					"skill_percentages": {"tone_scor": 30, "tone_aqua": 10},
					"skill_tiers": {"tone_scor": "practised"},
				},
			],
			"custom_recruits": [
				{
					"id": "ardyn",
					"display_name": "Ardyn",
					"level": 6,
					"hp": 30,
					"max_hp": 30,
					"major_element": "strom",
					"skill_percentages": {"tone_strom": 20},
					"skill_tiers": {"tone_strom": "practised"},
				},
			],
		},
		"reputation": {"log": []},
		"renown": {"log": [], "next_order": 0},
		"quests": {},
		"class_resources": {
			"__deferred__": [
				{"class_id": "vicoar", "entry": "instructive_failure", "fires_at_tick": 48},
			],
			"vicoar": {"armed": true, "charges": 2},
		},
		"tactical": {
			# `UnitRoster.from_dict` rejects an attunement row whose unit is not in
			# `units`, and rejects the whole payload rather than dropping the row —
			# so the roster entry is required for this fixture to load off disk, not
			# just to migrate.
			"units": {
				"vex": {
					"display_name": "Vex the Unbowed",
					"base_hp": 60, "base_mp": 15, "base_spd": 8, "move": 4, "jump": 2,
				},
			},
			"unit_attunement": {
				"vex": {"values": {LEGACY_ATTUNEMENT_KEY: 3, "khor": 1}},
			},
		},
	}


func _migrated() -> Dictionary:
	var result := SaveMigrations.prepare(_legacy_payload())
	assert_bool(bool(result.get("ok", false))).override_failure_message(
		"a populated schema-5 payload failed to migrate: %s" % result.get("error", "")
	).is_true()
	return result["payload"]


# --- the additive keys nothing migrates ------------------------------------


func test_equipped_slots_survive_the_whole_chain_by_value() -> void:
	# `equipped_slots` rides schema 6 as an additive key with no migration of its
	# own (the loader just defaults it to {}), so nothing would catch it being
	# dropped except a test that reads it back.
	var slots: Dictionary = _migrated()["game_state"]["equipped_slots"]
	assert_int(slots.size()).is_equal(2)
	assert_str(str(slots["vex"]["weapon"])).is_equal("taubstummer-axe")
	assert_str(str(slots["vex"]["relic"])).is_equal("quine-shard")
	assert_str(str(slots["korrath"]["weapon"])).is_equal("split-anvil")


func test_deferred_class_resource_entries_survive_the_whole_chain() -> void:
	# Wave B persists deferred entries under `class_resources.__deferred__`; they
	# fire at a CT tick, so losing one silently drops a queued consequence rather
	# than erroring.
	var resources: Dictionary = _migrated()["class_resources"]
	var deferred: Array = resources["__deferred__"]
	assert_int(deferred.size()).is_equal(1)
	var entry: Dictionary = deferred[0]
	assert_str(str(entry["class_id"])).is_equal("vicoar")
	assert_str(str(entry["entry"])).is_equal("instructive_failure")
	assert_int(int(entry["fires_at_tick"])).is_equal(48)
	assert_bool(bool(resources["vicoar"]["armed"])).is_true()


func test_the_populated_roster_keeps_its_levels_and_pools() -> void:
	var party: Array = _migrated()["game_state"]["party"]
	assert_int(party.size()).is_equal(1)
	var vex: Dictionary = party[0]
	assert_int(int(vex["level"])).is_equal(7)
	assert_int(int(vex["hp"])).is_equal(45)
	assert_int(int(vex["max_hp"])).is_equal(60)
	assert_str(str(vex["display_name"])).is_equal("Vex the Unbowed")


func test_flags_and_the_soul_meter_are_untouched() -> void:
	var state: Dictionary = _migrated()["game_state"]
	assert_int(int(state["soul_meter"])).is_equal(42)
	assert_bool(bool(state["flags"]["chapter_one_started"])).is_true()
	assert_bool(bool(state["flags"]["met_iris"])).is_true()


# --- the element rename, across every collection it touches -----------------


func test_custom_recruits_are_renamed_as_well_as_the_party() -> void:
	# `custom_recruits` is the collection most likely to be forgotten: it is
	# structurally identical to `party` but written by a different code path.
	var state: Dictionary = _migrated()["game_state"]
	var vex: Dictionary = state["party"][0]
	assert_str(str(vex["major_element"])).is_equal("khash")
	assert_str(str(vex["minor_element"])).override_failure_message(
		"khor is the one element that did not change; a rename that touches it is too eager"
	).is_equal("khor")

	var ardyn: Dictionary = state["custom_recruits"][0]
	assert_str(str(ardyn["major_element"])).is_equal("zhur")
	assert_bool(ardyn["skill_percentages"].has("tone_zhur")).is_true()
	assert_bool(ardyn["skill_tiers"].has("tone_zhur")).is_true()


func test_tone_skill_ids_are_renamed_at_both_the_state_and_member_level() -> void:
	var state: Dictionary = _migrated()["game_state"]
	# `game_state.skills` is keyed by actor, so the rename has to reach one level
	# down. Renaming its top level instead would rename the ACTOR ids and leave
	# every tone skill untouched — see `_rename_actor_skill_keys`.
	var vex_skills: Dictionary = state["skills"]["vex"]
	assert_bool(vex_skills.has("tone_khash")).override_failure_message(
		"the schema-8 rename did not reach the per-actor skill map"
	).is_true()
	assert_bool(vex_skills.has("tone_scor")).is_false()
	assert_float(float(vex_skills["tone_khash"]["percentage"])).is_equal_approx(30.0, 0.001)
	assert_str(str(vex_skills["tone_khash"]["tier"])).is_equal("Trained")
	# khor keeps its id, and a non-tone skill in the same map is not touched.
	assert_bool(vex_skills.has("tone_khor")).is_true()
	assert_float(float(vex_skills["sway"]["percentage"])).is_equal_approx(45.0, 0.001)
	# Every actor is reached, not just the first.
	assert_bool((state["skills"]["ardyn"] as Dictionary).has("tone_zhur")).is_true()
	# The actor ids themselves must survive untouched.
	assert_bool(state["skills"].has("vex")).is_true()
	assert_bool(state["skills"].has("ardyn")).is_true()

	var vex: Dictionary = state["party"][0]
	assert_int(int(vex["skill_percentages"]["tone_khash"])).is_equal(30)
	assert_int(int(vex["skill_percentages"]["tone_luth"])).is_equal(10)
	assert_str(str(vex["skill_tiers"]["tone_khash"])).is_equal("practised")


func test_tactical_attunement_keys_are_renamed() -> void:
	# UnitAttunement.from_dict rejects a whole row on an unknown element key, so
	# missing this rename loses every unit's attunement silently.
	var values: Dictionary = _migrated()["tactical"]["unit_attunement"]["vex"]["values"]
	assert_int(int(values["luth"])).is_equal(3)
	assert_int(int(values["khor"])).is_equal(1)
	assert_bool(values.has(LEGACY_ATTUNEMENT_KEY)).is_false()


# --- chain properties -------------------------------------------------------


func test_the_chain_lands_on_the_current_schema() -> void:
	assert_int(int(_migrated()["schema_version"])).is_equal(
		SaveMigrations.CURRENT_SCHEMA_VERSION
	)


func test_migrating_an_already_migrated_payload_changes_nothing() -> void:
	# Idempotence is what makes a re-save safe: load, save, load again must not
	# double-apply a rename or a default.
	var once := _migrated()
	var twice_result := SaveMigrations.prepare(once)
	assert_bool(bool(twice_result.get("ok", false))).is_true()
	assert_dict(twice_result["payload"]).is_equal(once)


func test_the_hops_add_their_defaults_to_a_populated_payload() -> void:
	# The v6→v7 breath default and the v5→v6 world clock both have to reach a
	# payload that already has real content in those sections' neighbours.
	var migrated := _migrated()
	assert_bool(migrated.has("world_clock")).is_true()
	var vex: Dictionary = migrated["game_state"]["party"][0]
	assert_int(int(vex["breath_max"])).is_equal(PartyMember.DEFAULT_BREATH_MAX)
	assert_int(int(vex["breath"])).is_equal(PartyMember.DEFAULT_BREATH_MAX)
	var ardyn: Dictionary = migrated["game_state"]["custom_recruits"][0]
	assert_int(int(ardyn["breath_max"])).is_equal(PartyMember.DEFAULT_BREATH_MAX)


func test_a_save_from_a_newer_build_is_refused_rather_than_loaded() -> void:
	# Refusing is the safe answer: a forward save may contain sections this build
	# would drop on the next write, so half-loading it destroys the player's run.
	var future := _legacy_payload()
	future["schema_version"] = SaveMigrations.CURRENT_SCHEMA_VERSION + 1
	var result := SaveMigrations.prepare(future)
	assert_bool(bool(result.get("ok", false))).is_false()
	assert_str(str(result.get("error", ""))).contains("newer")


func test_a_save_older_than_the_supported_floor_is_refused() -> void:
	var ancient := _legacy_payload()
	ancient["schema_version"] = SaveMigrations.LEGACY_SCHEMA_VERSION - 1
	var result := SaveMigrations.prepare(ancient)
	assert_bool(bool(result.get("ok", false))).is_false()


func test_a_payload_with_no_schema_version_is_refused() -> void:
	var headerless := _legacy_payload()
	headerless.erase("schema_version")
	assert_bool(bool(SaveMigrations.prepare(headerless).get("ok", false))).is_false()


# --- all three manual slots, off disk ---------------------------------------


func _write_legacy_slot(slot: int) -> void:
	var path: String = saves.manual_slot_path(slot)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_object(file).override_failure_message(
		"could not write the legacy fixture for slot %d" % slot
	).is_not_null()
	var payload := _legacy_payload()
	# Distinguish the slots so a cross-slot read shows up as a wrong value rather
	# than an accidental pass.
	payload["elapsed_seconds"] = 1000 + slot
	payload["game_state"]["soul_meter"] = float(40 + slot)
	# Saves are binary Variant, not JSON: `_write_current_payload` uses store_var
	# and `_read_payload` uses get_var(false). A JSON fixture reads back as null.
	file.store_var(payload)
	file.close()


func test_every_manual_slot_loads_a_legacy_payload_from_disk() -> void:
	for slot: int in range(1, SaveGameScript.MANUAL_SLOT_COUNT + 1):
		_write_legacy_slot(slot)

	for slot: int in range(1, SaveGameScript.MANUAL_SLOT_COUNT + 1):
		assert_bool(saves.has_manual_save(slot)).override_failure_message(
			"slot %d should exist after writing its fixture" % slot
		).is_true()
		assert_bool(saves.load_slot(slot)).override_failure_message(
			"slot %d refused a populated schema-5 payload" % slot
		).is_true()
		assert_float(GameState.soul_meter).override_failure_message(
			"slot %d loaded another slot's state" % slot
		).is_equal_approx(float(40 + slot), 0.001)


func test_a_migrated_slot_reports_its_header_to_the_slot_picker() -> void:
	# The picker reads the header without applying state, so it has its own path
	# through the payload and its own way to be wrong.
	_write_legacy_slot(2)
	var summary: Dictionary = saves.manual_slot_summary(2)
	assert_bool(bool(summary["exists"])).is_true()
	assert_int(int(summary["elapsed_seconds"])).is_equal(1002)
	assert_str(str(summary["location_id"])).is_equal("dom")


func test_an_empty_slot_reports_absent_rather_than_failing() -> void:
	var summary: Dictionary = saves.manual_slot_summary(3)
	assert_bool(bool(summary["exists"])).is_false()
	assert_bool(saves.has_manual_save(3)).is_false()
	assert_bool(saves.load_slot(3)).is_false()


func test_a_legacy_slot_resaves_at_the_current_schema() -> void:
	# The upgrade only sticks if the next write carries the new version — this is
	# what stops a player's save from migrating forever on every load.
	_write_legacy_slot(1)
	assert_bool(saves.load_slot(1)).is_true()
	assert_bool(saves.save_to_slot(1)).is_true()

	var file := FileAccess.open(saves.manual_slot_path(1), FileAccess.READ)
	assert_object(file).is_not_null()
	var written: Variant = file.get_var(false)
	file.close()
	assert_bool(written is Dictionary).is_true()
	var payload: Dictionary = written
	assert_int(int(payload["schema_version"])).is_equal(
		SaveMigrations.CURRENT_SCHEMA_VERSION
	)


func test_a_corrupt_slot_falls_back_to_its_own_backup() -> void:
	# Slot isolation has to hold on the recovery path too: slot 2's backup must
	# never answer for slot 1.
	_write_legacy_slot(1)
	var slot_path: String = saves.manual_slot_path(1)
	DirAccess.rename_absolute(slot_path, slot_path + ".bak")
	var broken := FileAccess.open(slot_path, FileAccess.WRITE)
	broken.store_string("this is not a stored Variant")
	broken.close()

	assert_bool(saves.load_slot(1)).override_failure_message(
		"a corrupt primary should fall through to the slot's backup"
	).is_true()
	assert_float(GameState.soul_meter).is_equal_approx(41.0, 0.001)
