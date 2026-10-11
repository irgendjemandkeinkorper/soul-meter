extends GdUnitTestSuite

const CampaignQuestLoaderScript: Script = preload("res://globals/campaign_quest_loader.gd")
const CombatLabScript := preload("res://weftlumin/panels/models/combat_lab.gd")
const FIRST_ID: String = "gdunit-campaign-encounters"
const SECOND_ID: String = "gdunit-campaign-encounters-second"
const ROOT: String = "user://gdunit-campaign-encounters-root"
const FIRST_PATH: String = ROOT + "/" + FIRST_ID
const SECOND_PATH: String = ROOT + "/" + SECOND_ID

## The combat lab model, unhosted until a test hosts it the way its Weftlumin panel does.
var _lab: Node = null


func before_test() -> void:
	_lab = CombatLabScript.new() as Node
	add_child(_lab)
	Battle.controller = null
	Battle.ended = true
	EncounterCatalog.clear_runtime_encounters()
	QuestRegistry.clear_runtime_quests()
	_remove_tree(ROOT)


func after_test() -> void:
	if _lab != null:
		_lab.call("stop_test_session")
		_lab.free()
		_lab = null
	EncounterCatalog.clear_runtime_encounters()
	QuestRegistry.clear_runtime_quests()
	Battle.controller = null
	Battle.ended = true
	_remove_tree(ROOT)


func test_campaign_encounter_registers_and_starts_through_battle_autoload() -> void:
	_write_package(FIRST_PATH, FIRST_ID, _encounter("campaign-fight"))
	var result: Dictionary = CampaignQuestLoaderScript.load_package(FIRST_PATH)

	assert_array(result.get("errors", [])).is_empty()
	Battle.start(&"campaign-fight")
	assert_bool(Battle.ended).is_false()
	assert_int(Battle.enemies.size()).is_equal(1)
	assert_str(Battle.enemies[0].display_name).is_equal("Bog Wight")


func test_encounter_only_package_needs_no_quest_directory_and_preserves_quests() -> void:
	var quest := DomSideQuest.new()
	quest.stable_id = "kind-test/keep-quest"
	quest.id = StableIds.runtime_quest_id(quest.stable_id)
	assert_bool(QuestRegistry.replace_runtime_quests([quest])).is_true()
	var campaign: Dictionary = _campaign(FIRST_ID)
	campaign["schema"] = "weftlumin.package.v1"
	campaign["kinds"] = ["encounters"]
	_write_json(FIRST_PATH + "/campaign.json", campaign)
	_write_json(FIRST_PATH + "/encounters/only.json", _encounter("encounter-only"))
	assert_bool(DirAccess.dir_exists_absolute(FIRST_PATH + "/quests")).is_false()
	var result: Dictionary = CampaignQuestLoaderScript.load_package(FIRST_PATH)
	assert_array(result.errors).is_empty()
	assert_array(result.applied_kinds).contains_exactly([&"encounters"])
	assert_object(QuestRegistry.runtime_quests()[0]).is_same(quest)
	assert_str(EncounterCatalog.definition(&"encounter-only").display_name).is_equal("Runtime Fight")


func test_campaign_dialogue_mutation_starts_registered_campaign_encounter() -> void:
	_write_package(FIRST_PATH, FIRST_ID, _encounter("dialogue-fight"))
	var title: String = "campaign_encounter_start"
	_write_text(
		FIRST_PATH + "/dialogue/start.dialogue",
		"~ %s\ndo Battle.start(\"dialogue-fight\")\nCampaign Tester: The fight begins.\n=> END\n"
		% title
	)
	var result: Dictionary = CampaignQuestLoaderScript.load_package(FIRST_PATH)
	var resource: DialogueResource = (result.get("dialogue_resources", {}) as Dictionary).get(
		title
	) as DialogueResource
	assert_array(result.get("errors", [])).is_empty()
	assert_object(resource).is_not_null()
	if resource == null:
		return

	var line: DialogueLine = await DialogueManager.get_next_dialogue_line(resource, title)

	assert_object(line).is_not_null()
	assert_str(String(Battle.encounter_id)).is_equal("dialogue-fight")
	assert_bool(Battle.ended).is_false()


func test_campaign_encounter_shadowing_committed_id_is_refused_with_attribution() -> void:
	var encounter: Dictionary = _encounter("bog-wight")
	var result: Dictionary = _validate(FIRST_PATH, FIRST_ID, encounter)

	_assert_error(result, "campaign_encounter_shadows_committed", "encounter_id")


## Spec §4.9 / F0 D8: the grid derives from the field's tiles and weather is the location's.
## A package that still authors either is refused with attribution, never quietly accepted.
func test_an_encounter_that_authors_a_grid_is_refused_with_attribution() -> void:
	var encounter: Dictionary = _encounter("gridded")
	encounter["grid"] = {"dimensions": [7, 5], "cover": [], "elevation": []}
	_write_package(FIRST_PATH, FIRST_ID, encounter)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(FIRST_PATH)

	_assert_error(result, "refused_encounter_field", "grid")
	assert_bool(EncounterCatalog.definition(&"gridded").is_empty()).is_true()


func test_an_encounter_that_authors_weather_is_refused_with_attribution() -> void:
	var encounter: Dictionary = _encounter("weathered")
	encounter["weather_default"] = "mozh"

	_assert_error(
		_validate(FIRST_PATH, FIRST_ID, encounter), "refused_encounter_field", "weather_default"
	)
	# An empty (calm) weather_default still claims the location's weather for the encounter.
	encounter["weather_default"] = ""
	_assert_error(
		_validate(FIRST_PATH, FIRST_ID, encounter), "refused_encounter_field", "weather_default"
	)


## #283: an enemy row names an archetype and nothing else. Every former ENEMY_FIELDS stat on a
## row — alone or beside an archetype id — is refused, so no row can shadow its archetype.
func test_six_stat_enemy_fields_are_refused_with_attribution() -> void:
	var inline: Dictionary = _encounter("inline-stats")
	inline["enemies"] = [_complete_enemy(10, "mozh")]
	var inline_result: Dictionary = _validate(FIRST_PATH, FIRST_ID, inline)
	for stat: String in [
		"id", "display_name", "max_hp", "attack", "defense", "balance_affinity",
		"balance_pressure", "element_id", "edge",
	]:
		_assert_error(inline_result, "refused_enemy_field", "enemies[0].%s" % stat)
	_assert_error(inline_result, "missing_required_field", "enemies[0].archetype_id")

	var shadowed: Dictionary = _encounter("shadowed-archetype")
	shadowed["enemies"] = [{"archetype_id": "bog-wight", "max_hp": 999}]
	_assert_error(
		_validate(FIRST_PATH, FIRST_ID, shadowed), "refused_enemy_field", "enemies[0].max_hp"
	)


func test_set_piece_cells_are_validated_and_normalised() -> void:
	var valid: Dictionary = _encounter("set-piece-fight")
	valid["set_piece"] = {"ally_cells": [[1, 2], [2, 2], {"x": 3, "y": 2}]}
	valid["group_id"] = "set-piece-group"
	var loaded: Dictionary = _validate(FIRST_PATH, FIRST_ID, valid)
	assert_array(loaded.get("errors", [])).is_empty()
	var definition: Dictionary = (loaded["encounters"] as Dictionary)["set-piece-fight"]
	assert_array(definition["set_piece"]["ally_cells"]).is_equal(
		[Vector2i(1, 2), Vector2i(2, 2), Vector2i(3, 2)]
	)

	var broken: Dictionary = _encounter("set-piece-broken")
	broken["set_piece"] = {
		"ally_cells": [[1, 2], [1, 2], [1.5, 2], "here"], "enemy_cells": [[4, 4]],
	}
	broken["group_id"] = ""
	var result: Dictionary = _validate(FIRST_PATH, FIRST_ID, broken)
	_assert_error(result, "duplicate_set_piece_cell", "set_piece.ally_cells[1]")
	_assert_error(result, "invalid_set_piece_cell", "set_piece.ally_cells[2]")
	_assert_error(result, "invalid_set_piece_cell", "set_piece.ally_cells[3]")
	_assert_error(result, "refused_encounter_field", "set_piece.enemy_cells")
	_assert_error(result, "missing_required_field", "group_id")

	var empty: Dictionary = _encounter("set-piece-empty")
	empty["set_piece"] = {"ally_cells": []}
	_assert_error(
		_validate(FIRST_PATH, FIRST_ID, empty), "invalid_field_type", "set_piece.ally_cells"
	)


## The fits-the-board check now runs against a scene (spec §4.9): deployable cells must hold the
## party and the hostiles, and authored set-piece cells must be deployable on that field.
func test_fits_the_board_is_judged_against_the_field() -> void:
	var scene: Node = (load("res://world/test_room.tscn") as PackedScene).instantiate()
	add_child(scene)
	auto_free(scene)
	await get_tree().process_frame
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	var deployable: Array[Vector2i] = CampaignEncounterLoader.deployable_cells(field)
	assert_int(deployable.size()).is_greater(4)
	var definition: Dictionary = {"enemies": [{}, {}]}

	var fits: Dictionary = CampaignEncounterLoader.fits_the_board(definition, field, 4)
	assert_bool(bool(fits["allowed"])).override_failure_message(str(fits)).is_true()
	assert_int(int(fits["required"])).is_equal(6)
	assert_int(int(fits["deployable"])).is_equal(deployable.size())

	var crowded: Dictionary = CampaignEncounterLoader.fits_the_board(
		definition, field, deployable.size()
	)
	assert_bool(bool(crowded["allowed"])).is_false()
	assert_str(str(crowded["blocked_by"])).is_equal("board_too_small")

	definition["set_piece"] = {"ally_cells": [deployable[0], Vector2i(-999, -999)]}
	var off_board: Dictionary = CampaignEncounterLoader.fits_the_board(definition, field, 2)
	assert_str(str(off_board["blocked_by"])).is_equal("set_piece_cell_not_deployable")

	definition["set_piece"] = {"ally_cells": [deployable[0]]}
	var short: Dictionary = CampaignEncounterLoader.fits_the_board(definition, field, 2)
	assert_str(str(short["blocked_by"])).is_equal("set_piece_cells_short")

	definition["set_piece"] = {"ally_cells": [deployable[0], deployable[1]]}
	var fitted: Dictionary = CampaignEncounterLoader.fits_the_board(definition, field, 2)
	assert_bool(bool(fitted["allowed"])).is_true()
	var no_field: Dictionary = CampaignEncounterLoader.fits_the_board(definition, null, 2)
	assert_str(str(no_field["blocked_by"])).is_equal("field_map")


func test_unknown_archetype_id_is_refused() -> void:
	var encounter: Dictionary = _encounter("unknown-archetype")
	encounter["enemies"] = [{"archetype_id": "missing-archetype"}]

	_assert_error(_validate(FIRST_PATH, FIRST_ID, encounter), "unknown_archetype_id", "enemies[0].archetype_id")


func test_unknown_item_id_is_refused() -> void:
	var encounter: Dictionary = _encounter("unknown-item")
	encounter["spoils"] = [{"item_id": "items/missing", "quantity": 99}]

	_assert_error(_validate(FIRST_PATH, FIRST_ID, encounter), "unknown_item_id", "spoils[0].item_id")


func test_unknown_outcome_and_loss_faction_ids_are_refused() -> void:
	var encounter: Dictionary = _encounter("unknown-factions")
	encounter["outcomes"] = {"slain": {"faction": "missing-faction"}}
	encounter["loss"] = {"faction": "also-missing"}
	var result: Dictionary = _validate(FIRST_PATH, FIRST_ID, encounter)

	_assert_error(result, "unknown_faction_id", "outcomes.slain.faction")
	_assert_error(result, "unknown_faction_id", "loss.faction")


func test_non_numeric_consequence_values_are_refused_at_load_with_attribution() -> void:
	var encounter: Dictionary = _encounter("invalid-consequence-numbers")
	encounter["outcomes"] = {
		"slain": {
			"faction": FactionIds.IRON_COMPANIES,
			"delta": {},
			"renown": "5",
		},
	}
	encounter["loss"] = {
		"faction": FactionIds.IRON_COMPANIES,
		"delta": [],
	}
	encounter["win_delta"] = true
	encounter["loss_delta"] = "-9.5"
	_write_package(FIRST_PATH, FIRST_ID, encounter)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(FIRST_PATH)

	_assert_error(result, "invalid_field_type", "outcomes.slain.delta", "number")
	_assert_error(result, "invalid_field_type", "outcomes.slain.renown", "number")
	_assert_error(result, "invalid_field_type", "loss.delta", "number")
	_assert_error(result, "invalid_field_type", "win_delta", "number")
	_assert_error(result, "invalid_field_type", "loss_delta", "number")
	assert_bool(EncounterCatalog.definition(&"invalid-consequence-numbers").is_empty()).is_true()


func test_spoils_quantity_that_runtime_would_coerce_is_refused_at_load() -> void:
	var encounter: Dictionary = _encounter("invalid-spoils-quantity")
	encounter["spoils"] = [{
		"item_id": ItemIds.MATERIALS_GRAVE_SALT,
		"quantity": "3",
	}]
	_write_package(FIRST_PATH, FIRST_ID, encounter)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(FIRST_PATH)

	_assert_error(result, "invalid_field_type", "spoils[0].quantity", "positive integer")
	assert_bool(EncounterCatalog.definition(&"invalid-spoils-quantity").is_empty()).is_true()


func test_nearly_whole_spoils_quantity_is_refused_rather_than_rounded() -> void:
	# The refusal must be EXACT, not approximate. An earlier version compared with
	# is_equal_approx(), so 1.000001 passed and was then stored as 1 — a silent
	# coercion, which is the precise thing these rules exist to refuse. Non-finite
	# values matter for the same reason: floorf(INF) == INF.
	for quantity: Variant in [1.000001, 0.5, INF, NAN]:
		var encounter: Dictionary = _encounter("nearly-whole-spoils")
		encounter["spoils"] = [{
			"item_id": ItemIds.MATERIALS_GRAVE_SALT,
			"quantity": quantity,
		}]
		_write_package(FIRST_PATH, FIRST_ID, encounter)

		var nearly_result: Dictionary = CampaignQuestLoaderScript.load_package(FIRST_PATH)

		_assert_error(
			nearly_result, "invalid_field_type", "spoils[0].quantity", "positive integer"
		)
		assert_bool(
			EncounterCatalog.definition(&"nearly-whole-spoils").is_empty()
		).is_true()

	# A genuinely whole float is still accepted, so the tightened rule did not
	# make the valid authored case unreachable. Reuse the same encounter id so
	# this overwrites the rejected file rather than leaving it beside a new one —
	# the package is loaded whole, so a stale sibling would fail this assertion
	# for the wrong reason.
	var whole: Dictionary = _encounter("nearly-whole-spoils")
	whole["spoils"] = [{"item_id": ItemIds.MATERIALS_GRAVE_SALT, "quantity": 2.0}]
	_write_package(FIRST_PATH, FIRST_ID, whole)

	var whole_result: Dictionary = CampaignQuestLoaderScript.load_package(FIRST_PATH)

	assert_array(whole_result.get("errors", [])).is_empty()


func test_well_formed_numeric_consequences_load_and_start_battle() -> void:
	var encounter: Dictionary = _encounter("valid-consequence-numbers")
	encounter["outcomes"] = {
		"slain": {
			"faction": FactionIds.IRON_COMPANIES,
			"delta": -1_000_000.25,
			"renown": 2_000_000_000,
		},
	}
	encounter["loss"] = {
		"faction": FactionIds.IRON_COMPANIES,
		"delta": -3.5,
	}
	encounter["win_delta"] = 4
	encounter["loss_delta"] = -5_000_000.75
	_write_package(FIRST_PATH, FIRST_ID, encounter)

	var result: Dictionary = CampaignQuestLoaderScript.load_package(FIRST_PATH)

	assert_array(result.get("errors", [])).is_empty()
	Battle.start(&"valid-consequence-numbers")
	assert_bool(Battle.ended).is_false()
	assert_object(Battle.controller).is_not_null()
	assert_int(Battle.enemies.size()).is_equal(1)


func test_clear_cache_and_lazy_reload_do_not_disturb_runtime_overlay() -> void:
	assert_bool(EncounterCatalog.register_runtime_encounters({
		"overlay-fight": _runtime_definition("overlay-fight"),
	})).is_true()

	EncounterCatalog.clear_cache()
	assert_str(str(EncounterCatalog.definition(&"overlay-fight").get("display_name", ""))).is_equal("Runtime Fight")
	assert_bool(EncounterCatalog.definition(&"bog-wight").is_empty()).is_false()
	assert_str(str(EncounterCatalog.definition(&"overlay-fight").get("display_name", ""))).is_equal("Runtime Fight")


func test_registering_second_campaign_replaces_first_encounters() -> void:
	_write_package(FIRST_PATH, FIRST_ID, _encounter("first-fight"))
	_write_package(SECOND_PATH, SECOND_ID, _encounter("second-fight"))
	assert_array(CampaignQuestLoaderScript.load_package(FIRST_PATH).get("errors", [])).is_empty()
	assert_bool(EncounterCatalog.definition(&"first-fight").is_empty()).is_false()

	assert_array(CampaignQuestLoaderScript.load_package(SECOND_PATH).get("errors", [])).is_empty()
	assert_bool(EncounterCatalog.definition(&"first-fight").is_empty()).is_true()
	assert_bool(EncounterCatalog.definition(&"second-fight").is_empty()).is_false()


func test_combat_lab_lists_and_starts_registered_campaign_encounter() -> void:
	assert_bool(EncounterCatalog.register_runtime_encounters({
		"lab-fight": _runtime_definition("lab-fight"),
	})).is_true()

	var listed: Array[StringName] = _lab.call("encounter_ids")
	assert_array(listed).contains([&"lab-fight"])
	assert_bool(bool(_lab.call("host_in_panel", CombatLabScript.SANDBOX_OWNER))).is_true()
	# A lab session opens on the live field through Battle.start_set_piece, like production.
	var scene: Node = (load("res://world/test_room.tscn") as PackedScene).instantiate()
	add_child(scene)
	auto_free(scene)
	await get_tree().process_frame
	_lab.call("start_test_session", {
		"encounter_id": &"lab-fight",
		"party_ids": [],
		"seed": 42,
	})
	assert_str(String(Battle.encounter_id)).is_equal("lab-fight")
	assert_bool(Battle.ended).is_false()
	assert_bool(Battle.session_active).is_true()


func _validate(package_path: String, campaign_id: String, encounter: Dictionary) -> Dictionary:
	var quest_documents: Array[Dictionary] = []
	var encounter_documents: Array[Dictionary] = [
		{"file": package_path + "/encounters/test.json", "data": encounter},
	]
	return CampaignQuestLoaderScript.validate_package_data(
		package_path,
		_campaign(campaign_id),
		quest_documents,
		encounter_documents
	)


func _encounter(encounter_id: String) -> Dictionary:
	return {
		"encounter_id": encounter_id,
		"display_name": "Runtime Fight",
		"enemies": [{"archetype_id": "bog-wight"}],
		"spoils": [{"item_id": ItemIds.MATERIALS_GRAVE_SALT, "quantity": 3}],
		"outcomes": {"slain": {"faction": FactionIds.IRON_COMPANIES}},
		"loss": {"faction": FactionIds.IRON_COMPANIES},
	}


func _complete_enemy(max_hp: int, element_id: String) -> Dictionary:
	return {
		"id": "campaign-creature",
		"display_name": "Campaign Creature",
		"max_hp": max_hp,
		"attack": 4,
		"defense": 1,
		"balance_affinity": 0,
		"balance_pressure": 12,
		"element_id": element_id,
		"edge": 0,
	}


func _runtime_definition(encounter_id: String) -> Dictionary:
	var definition: Dictionary = _encounter(encounter_id)
	definition["enemies"] = [EncounterCatalog.committed_archetype("bog-wight")]
	return definition


func _campaign(campaign_id: String) -> Dictionary:
	return {
		"id": campaign_id,
		"title": "Campaign Encounters Test",
		"entry_location": "dom",
		"locations": ["dom"],
	}


func _write_package(package_path: String, campaign_id: String, encounter: Dictionary) -> void:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(package_path + "/quests")
	)
	assert_bool(make_error == OK or make_error == ERR_ALREADY_EXISTS).is_true()
	_write_json(package_path + "/campaign.json", _campaign(campaign_id))
	_write_json(package_path + "/encounters/" + str(encounter["encounter_id"]) + ".json", encounter)


func _write_json(file_path: String, value: Dictionary) -> void:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(file_path.get_base_dir())
	)
	assert_bool(make_error == OK or make_error == ERR_ALREADY_EXISTS).is_true()
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file != null:
		file.store_string(JSON.stringify(value, "  ") + "\n")
		file.close()


func _write_text(file_path: String, value: String) -> void:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(file_path.get_base_dir())
	)
	assert_bool(make_error == OK or make_error == ERR_ALREADY_EXISTS).is_true()
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file != null:
		file.store_string(value)
		file.close()


func _assert_error(
	result: Dictionary, code: String, field: String, expected: String = ""
) -> void:
	for error_value: Variant in result.get("errors", []):
		if not error_value is Dictionary:
			continue
		var error: Dictionary = error_value as Dictionary
		if str(error.get("code", "")) == code and str(error.get("field", "")) == field:
			assert_str(str(error.get("file", ""))).contains("/encounters/")
			if not expected.is_empty():
				assert_str(str(error.get("expected", ""))).is_equal(expected)
			return
	fail("Missing attributed error %s at %s" % [code, field])


func _remove_tree(path: String) -> void:
	var directory: DirAccess = DirAccess.open(path)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)
	for directory_name: String in directory.get_directories():
		_remove_tree(path.path_join(directory_name))
		directory.remove(directory_name)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
