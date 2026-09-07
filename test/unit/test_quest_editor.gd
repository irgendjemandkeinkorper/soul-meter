extends GdUnitTestSuite

const CampaignQuestLoaderScript: Script = preload("res://globals/campaign_quest_loader.gd")
const QuestEditorScript: Script = preload("res://globals/quest_editor.gd")
const CAMPAIGN_ID: String = "gdunit-quest-editor"
const SCRATCH_CAMPAIGNS_ROOT: String = "user://gdunit-quest-editor-campaigns"
const PACKAGE_PATH: String = SCRATCH_CAMPAIGNS_ROOT + "/" + CAMPAIGN_ID
const ESCAPE_PATH: String = "user://gdunit-quest-editor-escape.json"

var _editor: Node = null
var _incoming_runtime: Dictionary = {}


func before_test() -> void:
	_incoming_runtime = SaveGame.capture_runtime_state()
	QuestRegistry.clear_runtime_quests()
	_remove_tree(SCRATCH_CAMPAIGNS_ROOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ESCAPE_PATH))
	_editor = auto_free(QuestEditorScript.new()) as Node
	add_child(_editor)
	_editor.set("campaigns_root_for_tests", SCRATCH_CAMPAIGNS_ROOT)
	_editor.set("force_enabled_for_tests", true)


func after_test() -> void:
	if _editor != null:
		_editor.call("close_overlay")
		_editor.set("force_enabled_for_tests", false)
	QuestRegistry.clear_runtime_quests()
	assert_bool(SaveGame.restore_runtime_state(_incoming_runtime)).is_true()
	_remove_tree(SCRATCH_CAMPAIGNS_ROOT)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(ESCAPE_PATH))


func test_in_memory_validation_uses_the_loader_error_contract() -> void:
	var campaign: Dictionary = {
		"id": CAMPAIGN_ID,
		"title": "Quest Editor Test",
		"entry_location": "dom",
		"locations": ["dom"],
	}
	var quest: Dictionary = _quest("invalid-dialogue")
	quest["dialogue_title"] = "not_an_authored_dialogue_title"
	var documents: Array[Dictionary] = [{
		"file": PACKAGE_PATH + "/quests/invalid-dialogue.json",
		"data": quest,
	}]

	var result: Dictionary = CampaignQuestLoaderScript.validate_package_data(
		PACKAGE_PATH, campaign, documents
	)
	var errors: Array = result.get("errors", [])

	assert_int(errors.size()).is_equal(1)
	assert_str(str((errors[0] as Dictionary).get("field", ""))).is_equal("dialogue_title")
	assert_str(str((errors[0] as Dictionary).get("code", ""))).is_equal(
		"unknown_dialogue_title"
	)
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(PACKAGE_PATH))).is_false()


func test_dialogue_title_picker_distinguishes_campaign_and_committed_titles() -> void:
	var campaign_title: String = "campaign_picker_title"
	var quest: Dictionary = _quest("campaign-picker")
	quest["dialogue_title"] = campaign_title
	_write_package(PACKAGE_PATH, _campaign(), [quest])
	_write_text(
		PACKAGE_PATH + "/dialogue/picker.dialogue",
		"~ %s\nCampaign Tester: Picker words.\n=> END\n" % campaign_title
	)

	_editor.call("open_overlay")
	var layer: CanvasLayer = _editor.get("_overlay_layer") as CanvasLayer
	assert_object(layer).is_not_null()
	if layer == null:
		return
	var overlay: Control = layer.get_child(0) as Control
	var picker: OptionButton = overlay.get("_dialogue_picker") as OptionButton
	var campaign_label_found: bool = false
	var committed_label_found: bool = false
	for index: int in picker.item_count:
		var label: String = picker.get_item_text(index)
		var title: String = str(picker.get_item_metadata(index))
		if title == campaign_title and label.contains("CAMPAIGN"):
			campaign_label_found = true
		if title == "dom_side_dishonest_casks" and label.contains("COMMITTED"):
			committed_label_found = true

	assert_bool(campaign_label_found).is_true()
	assert_bool(committed_label_found).is_true()


func test_disabled_editor_is_not_drivable_and_writes_nothing() -> void:
	var campaign: Dictionary = _campaign()
	var quests: Array[Dictionary] = [_quest("disabled")]
	_editor.set("force_enabled_for_tests", false)

	_editor.call("open_overlay")
	var validation: Dictionary = _editor.call("validate_draft", campaign, quests)
	var save_result: Dictionary = _editor.call("save_campaign", campaign, quests)
	var reload_result: Dictionary = _editor.call("reload_campaign", CAMPAIGN_ID)
	var draft: Dictionary = _editor.call("campaign_draft", CAMPAIGN_ID)

	assert_bool(validation.is_empty()).is_true()
	assert_bool(save_result.is_empty()).is_true()
	assert_bool(reload_result.is_empty()).is_true()
	assert_bool(draft.is_empty()).is_true()
	assert_object(_editor.get("_overlay_layer")).is_null()
	assert_int(_editor.get_child_count()).is_equal(0)
	assert_bool(_editor.is_processing_unhandled_key_input()).is_false()
	assert_bool(DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(PACKAGE_PATH))).is_false()


func test_editor_renders_the_exact_loader_validation_errors() -> void:
	var campaign: Dictionary = _campaign()
	var invalid: Dictionary = _quest("loader-error")
	invalid["dialogue_title"] = "not_an_authored_dialogue_title"
	var quests: Array[Dictionary] = [invalid]
	var documents: Array[Dictionary] = [{
		"file": PACKAGE_PATH + "/quests/loader-error.json",
		"data": invalid,
	}]
	var expected: Dictionary = CampaignQuestLoaderScript.validate_package_data(
		PACKAGE_PATH, campaign, documents
	)

	var actual: Dictionary = _editor.call("validate_draft", campaign, quests)

	assert_array(actual.get("errors", [])).is_equal(expected.get("errors", []))
	assert_str(str((actual["errors"][0] as Dictionary)["code"])).is_equal(
		"unknown_dialogue_title"
	)


func test_save_writes_only_the_runtime_package_then_reloads_and_registers() -> void:
	var quests: Array[Dictionary] = [_quest("round-trip")]
	var result: Dictionary = _editor.call(
		"save_campaign", _campaign(), quests
	)

	assert_bool(bool(result.get("saved", false))).is_true()
	assert_array(result.get("errors", [])).is_empty()
	var written_files: Array = result.get("written_files", [])
	assert_array(written_files).contains_exactly([
		PACKAGE_PATH + "/campaign.json",
		PACKAGE_PATH + "/quests/round-trip.json",
	])
	for path_value: Variant in written_files:
		var path: String = str(path_value)
		assert_str(path).starts_with(SCRATCH_CAMPAIGNS_ROOT + "/")
		assert_bool(FileAccess.file_exists(path)).is_true()
	var registered: Array[DomSideQuest] = QuestRegistry.runtime_quests()
	assert_int(registered.size()).is_equal(1)
	assert_str(registered[0].stable_id).is_equal(CAMPAIGN_ID + "/round-trip")
	var loaded_view: Array[Dictionary] = _editor.call("registered_view")
	assert_int(loaded_view.size()).is_equal(1)
	assert_str(str(loaded_view[0]["identity"])).is_equal(CAMPAIGN_ID + "/round-trip")
	var saved_quest_value: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(PACKAGE_PATH + "/quests/round-trip.json")
	)
	assert_bool(saved_quest_value is Dictionary).is_true()
	assert_bool((saved_quest_value as Dictionary).get("outcomes") is Array).is_true()
	assert_bool(((saved_quest_value as Dictionary)["outcomes"] as Array)[0] is Dictionary).is_true()

	var escape_campaign: Dictionary = _campaign()
	escape_campaign["id"] = "valid-prefix/../../quest-editor-escape"
	var escape_result: Dictionary = _editor.call("save_campaign", escape_campaign, quests)
	assert_bool(bool(escape_result.get("saved", false))).is_false()
	assert_bool(_has_error_code(escape_result.get("errors", []), "campaign_directory_mismatch")).is_true()
	assert_bool(FileAccess.file_exists("user://quest-editor-escape/campaign.json")).is_false()


func test_save_round_trips_existing_encounter_files_without_dropping_bytes() -> void:
	_write_package(PACKAGE_PATH, _campaign(), [_quest("round-trip")])
	var encounter_path: String = PACKAGE_PATH + "/encounters/nested/editor-fight.json"
	var encounter_text: String = (
		"{\n"
		+ "  \"encounter_id\": \"editor-fight\",\n"
		+ "  \"display_name\": \"Editor Fight\",\n"
		+ "  \"enemies\": [{\"archetype_id\": \"bog-wight\"}],\n"
		+ "  \"grid\": {\"dimensions\": [7, 5], \"cover\": [], \"elevation\": []},\n"
		+ "  \"weather_default\": \"mozh\",\n"
		+ "  \"spoils\": [{\"item_id\": \"materials/grave_salt\", \"quantity\": 7}],\n"
		+ "  \"outcomes\": {\"slain\": {\"faction\": \"iron-companies\"}},\n"
		+ "  \"loss\": {\"faction\": \"iron-companies\"}\n"
		+ "}\n"
	)
	_write_text(encounter_path, encounter_text)
	var quests: Array[Dictionary] = [_quest("round-trip")]

	var result: Dictionary = _editor.call(
		"save_campaign", _campaign(), quests
	)

	assert_bool(bool(result.get("saved", false))).is_true()
	assert_array(result.get("errors", [])).is_empty()
	assert_bool(FileAccess.file_exists(encounter_path)).is_true()
	assert_str(FileAccess.get_file_as_string(encounter_path)).is_equal(encounter_text)
	assert_array(result.get("written_files", [])).contains([encounter_path])
	assert_bool(EncounterCatalog.definition(&"editor-fight").is_empty()).is_false()


func test_loader_rejects_quest_ids_that_are_unsafe_file_names() -> void:
	var unsafe_ids: Array[String] = [
		"a/../../../../gdunit-quest-editor-escape",
		"a\\..\\..\\..\\..\\gdunit-quest-editor-escape",
		"/gdunit-quest-editor-escape",
		"a//gdunit-quest-editor-escape",
		"side/./quest",
		# Windows strips a trailing period from a path component, so "side." and
		# "side" alias there while staying distinct ids here.
		"side./quest",
		"quest.",
		"side:quest",
		"CON",
		"prn.txt",
		"side/AUX",
		"side/zhem.json",
		"COM1",
		"com9.notes",
		"LPT1",
		"side/lpt9.quest",
	]
	for quest_id: String in unsafe_ids:
		var quest: Dictionary = _quest(quest_id)
		var documents: Array[Dictionary] = [{
			"file": PACKAGE_PATH + "/quests/draft.json",
			"data": quest,
		}]
		var result: Dictionary = CampaignQuestLoaderScript.validate_package_data(
			PACKAGE_PATH, _campaign(), documents
		)
		assert_bool(_has_error_code(result.get("errors", []), "unsafe_quest_id_file_name")).is_true()
		var unsafe_quests: Array[Dictionary] = [_quest(quest_id)]
		var save_result: Dictionary = _editor.call(
			"save_campaign", _campaign(), unsafe_quests
		)
		assert_bool(bool(save_result.get("saved", false))).is_false()
		assert_bool(
			_has_error_code(save_result.get("errors", []), "unsafe_quest_id_file_name")
		).is_true()
		assert_bool(
			DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(PACKAGE_PATH))
		).is_false()
		assert_bool(FileAccess.file_exists(ESCAPE_PATH)).is_false()

	for safe_id: String in ["a..b", "side/baked-quest"]:
		var safe_documents: Array[Dictionary] = [{
			"file": PACKAGE_PATH + "/quests/" + safe_id + ".json",
			"data": _quest(safe_id),
		}]
		var validation: Dictionary = CampaignQuestLoaderScript.validate_package_data(
			PACKAGE_PATH, _campaign(), safe_documents
		)
		assert_array(validation.get("errors", [])).is_empty()

	var nested_path: String = PACKAGE_PATH + "/quests/side/baked-quest.json"
	var nested_quests: Array[Dictionary] = [_quest("side/baked-quest")]
	var nested_save: Dictionary = _editor.call("save_campaign", _campaign(), nested_quests)
	assert_bool(bool(nested_save.get("saved", false))).is_true()
	assert_bool(bool(nested_save.get("registered", false))).is_true()
	assert_bool(FileAccess.file_exists(nested_path)).is_true()
	assert_array(nested_save.get("written_files", [])).contains_exactly([
		PACKAGE_PATH + "/campaign.json",
		nested_path,
	])

	var reload_result: Dictionary = _editor.call("reload_campaign", CAMPAIGN_ID)
	assert_array(reload_result.get("errors", [])).is_empty()
	assert_bool(bool(reload_result.get("registered", false))).is_true()
	var registered: Array[DomSideQuest] = QuestRegistry.runtime_quests()
	assert_int(registered.size()).is_equal(1)
	if registered.is_empty():
		return
	assert_str(registered[0].stable_id).is_equal(CAMPAIGN_ID + "/side/baked-quest")

	var no_quests: Array[Dictionary] = []
	var removed_save: Dictionary = _editor.call(
		"save_campaign", _campaign(), no_quests
	)
	assert_bool(bool(removed_save.get("saved", false))).is_true()
	assert_bool(FileAccess.file_exists(nested_path)).is_false()
	assert_bool(FileAccess.file_exists(ESCAPE_PATH)).is_false()


func test_loader_rejects_quest_ids_that_collide_under_ascii_case_folding() -> void:
	var documents: Array[Dictionary] = [
		{
			"file": PACKAGE_PATH + "/quests/side/Quest.json",
			"data": _quest("side/Quest"),
		},
		{
			"file": PACKAGE_PATH + "/quests/side/quest.json",
			"data": _quest("side/quest"),
		},
	]

	var result: Dictionary = CampaignQuestLoaderScript.validate_package_data(
		PACKAGE_PATH, _campaign(), documents
	)

	assert_bool(
		_has_error_code(result.get("errors", []), "case_insensitive_quest_id_collision")
	).is_true()
	assert_bool(_has_error_code(result.get("errors", []), "duplicate_quest_identity")).is_false()


func test_loader_attributes_quest_discovery_depth_limit() -> void:
	var campaign_id: String = "gdunit-quest-depth-limit"
	var package_path: String = SCRATCH_CAMPAIGNS_ROOT.path_join(campaign_id)
	var quest_directory: String = package_path.path_join("quests")
	var offending_path: String = quest_directory
	for depth: int in 9:
		offending_path = offending_path.path_join("level-%d" % depth)
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(offending_path)
	)
	assert_int(make_error).is_equal(OK)
	_write_json(package_path.path_join("campaign.json"), _campaign(campaign_id))
	_write_json(offending_path.path_join("too-deep.json"), _quest("too-deep"))

	var result: Dictionary = CampaignQuestLoaderScript.load_package(package_path, false)
	var error: Dictionary = _error_with_code(
		result.get("errors", []), "quest_discovery_depth_exceeded"
	)

	assert_bool(error.is_empty()).is_false()
	assert_str(str(error.get("file", ""))).is_equal(offending_path)


func test_loader_attributes_quest_discovery_file_limit() -> void:
	var campaign_id: String = "gdunit-quest-file-limit"
	var package_path: String = SCRATCH_CAMPAIGNS_ROOT.path_join(campaign_id)
	var quest_directory: String = package_path.path_join("quests")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(quest_directory)
	)
	assert_int(make_error).is_equal(OK)
	_write_json(package_path.path_join("campaign.json"), _campaign(campaign_id))
	for index: int in 513:
		_write_json(quest_directory.path_join("quest-%04d.json" % index), {})
	var offending_path: String = quest_directory.path_join("quest-0512.json")

	var result: Dictionary = CampaignQuestLoaderScript.load_package(package_path, false)
	var error: Dictionary = _error_with_code(
		result.get("errors", []), "quest_discovery_file_limit_exceeded"
	)

	assert_bool(error.is_empty()).is_false()
	assert_str(str(error.get("file", ""))).is_equal(offending_path)


func test_authorized_reload_resets_active_quest_and_applies_encounter_changes() -> void:
	var authored: Dictionary = _quest("encounter-progress")
	authored["required_flags"] = ["editor_kind_first", "editor_kind_second"]
	authored["objectives"] = ["First objective", "Second objective"]
	_write_package(PACKAGE_PATH, _campaign(), [authored])
	var encounter_path: String = PACKAGE_PATH + "/encounters/editor-kind-fight.json"
	var encounter: Dictionary = {
		"encounter_id": "editor-kind-fight", "display_name": "Original Fight",
		"enemies": [{"archetype_id": "bog-wight"}],
		"grid": {"dimensions": [7, 5], "cover": [], "elevation": []},
		"weather_default": "",
	}
	_write_text(encounter_path, JSON.stringify(encounter))
	var initial: Dictionary = _editor.call("reload_campaign", CAMPAIGN_ID)
	assert_array(initial.get("errors", [])).is_empty()
	assert_bool(bool(initial.get("registered", false))).is_true()
	var active_quest: DomSideQuest = QuestRegistry.runtime_quests()[0]
	QuestSystem.mark_quest_as_available(active_quest)
	QuestSystem.start_quest(active_quest)
	GameState.set_flag("editor_kind_first", true)
	GameState.set_flag("editor_kind_second", false)
	QuestSystem.update_quest(active_quest)
	assert_bool(QuestRegistry.is_active(active_quest)).is_true()
	assert_int(active_quest.current_stage).is_equal(1)

	encounter["display_name"] = "Revised Fight"
	_write_text(encounter_path, JSON.stringify(encounter))
	var refused: Dictionary = _editor.call("reload_campaign", CAMPAIGN_ID)
	var identities: Array[String] = _conflict_identities(
		refused.get("registration_conflicts", [])
	)
	assert_array(refused.get("errors", [])).is_empty()
	assert_bool(bool(refused.get("registered", true))).is_false()
	assert_array(identities).contains_exactly([CAMPAIGN_ID + "/encounter-progress"])
	var no_identities: Array[String] = []
	var unauthorized: Dictionary = _editor.call("reload_campaign", CAMPAIGN_ID, true, no_identities)
	assert_bool(bool(unauthorized.get("registered", true))).is_false()
	assert_array(_conflict_identities(
		unauthorized.get("registration_conflicts", [])
	)).contains_exactly(identities)
	assert_object(QuestRegistry.runtime_quests()[0]).is_same(active_quest)
	assert_bool(QuestRegistry.is_active(active_quest)).is_true()
	assert_int(active_quest.current_stage).is_equal(1)
	assert_str(EncounterCatalog.definition(&"editor-kind-fight").display_name).is_equal(
		"Original Fight"
	)

	var applied: Dictionary = _editor.call("reload_campaign", CAMPAIGN_ID, true, identities)
	assert_array(applied.get("errors", [])).is_empty()
	assert_bool(bool(applied.get("registered", false))).is_true()
	assert_array(applied.get("applied_kinds", [])).contains_exactly([&"quests", &"encounters"])
	assert_bool(QuestRegistry.is_active(active_quest)).is_false()
	assert_int(active_quest.current_stage).is_equal(0)
	assert_bool(active_quest.objective_completed).is_false()
	var replacement: DomSideQuest = QuestRegistry.runtime_quests()[0]
	assert_bool(replacement == active_quest).is_false()
	assert_str(replacement.stable_id).is_equal(active_quest.stable_id)
	assert_bool(QuestRegistry.is_active(replacement)).is_false()
	assert_str(EncounterCatalog.definition(&"editor-kind-fight").display_name).is_equal(
		"Revised Fight"
	)
	var unchanged: Dictionary = _editor.call("reload_campaign", CAMPAIGN_ID)
	assert_array(unchanged.get("errors", [])).is_empty()
	assert_bool(bool(unchanged.get("registered", false))).is_true()
	assert_array(unchanged.get("applied_kinds", [])).is_empty()
	assert_object(QuestRegistry.runtime_quests()[0]).is_same(replacement)
	assert_bool(QuestRegistry.is_active(replacement)).is_false()
	assert_int(replacement.current_stage).is_equal(0)


func test_force_proceeds_when_runtime_conflict_set_is_unchanged() -> void:
	var initial_quests: Array[Dictionary] = [_quest("live-progress")]
	var initial_result: Dictionary = _editor.call("save_campaign", _campaign(), initial_quests)
	assert_bool(bool(initial_result.get("saved", false))).is_true()
	var initial_runtime: Array[DomSideQuest] = QuestRegistry.runtime_quests()
	assert_int(initial_runtime.size()).is_equal(1)
	var active_quest: DomSideQuest = initial_runtime[0]
	QuestRegistry.offer(active_quest)
	active_quest.current_stage = 1
	active_quest.objective_completed = true

	var replacement: Dictionary = _quest("live-progress")
	replacement["name"] = "Replacement Quest"
	var replacement_quests: Array[Dictionary] = [replacement]
	var refused: Dictionary = _editor.call(
		"save_campaign", _campaign(), replacement_quests
	)
	var conflicts: Array = refused.get("registration_conflicts", [])

	assert_bool(bool(refused.get("registered", true))).is_false()
	assert_int(conflicts.size()).is_equal(1)
	assert_str(str((conflicts[0] as Dictionary).get("identity", ""))).is_equal(
		CAMPAIGN_ID + "/live-progress"
	)
	assert_bool(QuestRegistry.runtime_quests()[0] == active_quest).is_true()
	assert_bool(QuestRegistry.is_active(active_quest)).is_true()
	assert_int(active_quest.current_stage).is_equal(1)
	assert_bool(active_quest.objective_completed).is_true()

	var forced: Dictionary = _editor.call(
		"save_campaign", _campaign(), replacement_quests, true, _conflict_identities(conflicts)
	)
	assert_bool(bool(forced.get("saved", false))).is_true()
	assert_bool(bool(forced.get("registered", false))).is_true()
	assert_bool(QuestRegistry.is_active(active_quest)).is_false()
	assert_int(active_quest.current_stage).is_equal(0)
	assert_bool(active_quest.objective_completed).is_false()


func test_force_refuses_when_runtime_conflict_set_grows_since_authorization() -> void:
	var initial_quests: Array[Dictionary] = [_quest("first-live"), _quest("second-live")]
	var initial_result: Dictionary = _editor.call("save_campaign", _campaign(), initial_quests)
	assert_bool(bool(initial_result.get("registered", false))).is_true()
	var runtime_quests: Array[DomSideQuest] = QuestRegistry.runtime_quests()
	var first_quest: DomSideQuest = runtime_quests[0]
	var second_quest: DomSideQuest = runtime_quests[1]
	QuestRegistry.offer(first_quest)
	first_quest.current_stage = 1

	var replacement: Dictionary = _quest("first-live")
	replacement["name"] = "Replacement Quest"
	var replacement_quests: Array[Dictionary] = [replacement, _quest("second-live")]
	var refused: Dictionary = _editor.call(
		"save_campaign", _campaign(), replacement_quests
	)
	var displayed_conflicts: Array = refused.get("registration_conflicts", [])
	assert_array(_conflict_identities(displayed_conflicts)).contains_exactly([
		CAMPAIGN_ID + "/first-live",
	])

	QuestRegistry.offer(second_quest)
	second_quest.current_stage = 1
	var forced: Dictionary = _editor.call(
		"save_campaign",
		_campaign(),
		replacement_quests,
		true,
		_conflict_identities(displayed_conflicts)
	)
	var refreshed_conflicts: Array = forced.get("registration_conflicts", [])

	assert_bool(bool(forced.get("registered", true))).is_false()
	assert_array(_conflict_identities(refreshed_conflicts)).contains_exactly([
		CAMPAIGN_ID + "/first-live",
		CAMPAIGN_ID + "/second-live",
	])
	assert_bool(QuestRegistry.is_active(first_quest)).is_true()
	assert_bool(QuestRegistry.is_active(second_quest)).is_true()
	assert_int(first_quest.current_stage).is_equal(1)
	assert_int(second_quest.current_stage).is_equal(1)


func test_ui_names_live_progress_and_requires_confirmation_before_force() -> void:
	var quests: Array[Dictionary] = [_quest("ui-live-progress")]
	var initial_result: Dictionary = _editor.call("save_campaign", _campaign(), quests)
	assert_bool(bool(initial_result.get("registered", false))).is_true()
	var runtime_quests: Array[DomSideQuest] = QuestRegistry.runtime_quests()
	var active_quest: DomSideQuest = runtime_quests[0]
	QuestRegistry.offer(active_quest)
	active_quest.current_stage = 1
	_editor.call("open_overlay")
	var layer: CanvasLayer = _editor.get("_overlay_layer") as CanvasLayer
	assert_object(layer).is_not_null()
	if layer == null:
		return
	var overlay: Control = layer.get_child(0) as Control

	overlay.call("_save_current")

	var status: Label = overlay.get("_status") as Label
	var confirm: Button = overlay.get("_force_registration_button") as Button
	assert_str(status.text).contains(CAMPAIGN_ID + "/ui-live-progress")
	assert_str(status.text).contains("Would reset live progress")
	assert_bool(confirm.visible).is_true()
	assert_bool(QuestRegistry.is_active(active_quest)).is_true()
	assert_int(active_quest.current_stage).is_equal(1)

	overlay.call("_confirm_force_registration")

	assert_bool(confirm.visible).is_false()
	assert_bool(QuestRegistry.is_active(active_quest)).is_false()
	assert_int(active_quest.current_stage).is_equal(0)


func test_editor_reload_with_any_loader_error_registers_nothing() -> void:
	var original_quests: Array[Dictionary] = [_quest("previously-registered")]
	var original_result: Dictionary = _editor.call("save_campaign", _campaign(), original_quests)
	assert_bool(bool(original_result.get("registered", false))).is_true()
	var previous_runtime: Array[DomSideQuest] = QuestRegistry.runtime_quests()
	var mixed_campaign_id: String = "gdunit-mixed-quest-editor"
	var mixed_package_path: String = SCRATCH_CAMPAIGNS_ROOT.path_join(mixed_campaign_id)
	var invalid: Dictionary = _quest("invalid")
	invalid["outcomes"] = [(invalid["outcomes"] as Array)[0]]
	var mixed_quests: Array[Dictionary] = [_quest("valid"), invalid]
	_write_package(
		mixed_package_path,
		_campaign(mixed_campaign_id),
		mixed_quests
	)

	var rejected: Dictionary = _editor.call("reload_campaign", mixed_campaign_id)

	assert_bool(_has_error_code(rejected.get("errors", []), "incomplete_outcome_schema")).is_true()
	assert_bool(bool(rejected.get("registered", true))).is_false()
	var runtime_after: Array[DomSideQuest] = QuestRegistry.runtime_quests()
	assert_int(runtime_after.size()).is_equal(1)
	assert_bool(runtime_after[0] == previous_runtime[0]).is_true()
	assert_str(runtime_after[0].stable_id).is_equal(CAMPAIGN_ID + "/previously-registered")
	var registered_view: Array[Dictionary] = _editor.call("registered_view")
	assert_str(str(registered_view[0].get("identity", ""))).is_equal(
		CAMPAIGN_ID + "/previously-registered"
	)


func test_mid_save_write_failure_preserves_previous_package_bytes() -> void:
	var original_quests: Array[Dictionary] = [_quest("original-a"), _quest("original-b")]
	var initial_result: Dictionary = _editor.call("save_campaign", _campaign(), original_quests)
	assert_bool(bool(initial_result.get("saved", false))).is_true()
	var bytes_before: Dictionary = _package_bytes(PACKAGE_PATH)
	var blocked_temp_path: String = PACKAGE_PATH + "/quests/blocked.json.tmp"
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(blocked_temp_path)
	)
	assert_int(make_error).is_equal(OK)

	var replacement_quests: Array[Dictionary] = [_quest("changed-a"), _quest("blocked")]
	var failed: Dictionary = _editor.call("save_campaign", _campaign(), replacement_quests)

	assert_bool(bool(failed.get("saved", true))).is_false()
	assert_bool(_has_error_code(failed.get("errors", []), "quest_editor_write_failed")).is_true()
	assert_dict(_package_bytes(PACKAGE_PATH)).is_equal(bytes_before)
	assert_array(failed.get("written_files", [])).contains_exactly(_package_json_files(PACKAGE_PATH))
	assert_bool(FileAccess.file_exists(PACKAGE_PATH + "/campaign.json.tmp")).is_false()
	assert_bool(FileAccess.file_exists(PACKAGE_PATH + "/quests/changed-a.json.tmp")).is_false()


func test_outcome_row_can_be_removed_below_loader_minimum_and_surfaces_error() -> void:
	var quests: Array[Dictionary] = [_quest("ui-outcomes")]
	var saved: Dictionary = _editor.call("save_campaign", _campaign(), quests)
	assert_bool(bool(saved.get("saved", false))).is_true()
	_editor.call("open_overlay")
	var layer: CanvasLayer = _editor.get("_overlay_layer") as CanvasLayer
	assert_object(layer).is_not_null()
	if layer == null:
		return
	var overlay: Control = layer.get_child(0) as Control
	var rows: Array = overlay.get("_outcome_rows")
	overlay.call("_remove_outcome_row", rows[0])
	rows = overlay.get("_outcome_rows")
	var remaining_remove: Button = (rows[0] as Dictionary).get("remove") as Button
	var requirement: Label = overlay.get("_outcome_requirement") as Label

	assert_int(rows.size()).is_equal(1)
	assert_bool(remaining_remove.disabled).is_false()
	assert_str(requirement.text).contains("Current: 1")
	overlay.call("_validate_current")
	var validation_container: VBoxContainer = overlay.get("_validation_container") as VBoxContainer
	assert_bool(_node_text_contains(validation_container, "DomSideQuest requires at least two outcomes")).is_true()


func test_loader_rejected_quest_is_not_written_or_registered() -> void:
	var invalid: Dictionary = _quest("rejected")
	invalid["outcomes"] = [(invalid["outcomes"] as Array)[0]]
	var quests: Array[Dictionary] = [invalid]

	var result: Dictionary = _editor.call("save_campaign", _campaign(), quests)

	assert_bool(bool(result.get("saved", false))).is_false()
	assert_bool(_has_error_code(result.get("errors", []), "incomplete_outcome_schema")).is_true()
	assert_bool(QuestRegistry.runtime_quests().is_empty()).is_true()
	assert_bool(FileAccess.file_exists(PACKAGE_PATH + "/quests/rejected.json")).is_false()


func test_authoring_and_registration_do_not_mutate_campaign_state_or_quest_pools() -> void:
	var state_before: Dictionary = {
		"game_state": GameState.to_dict().duplicate(true),
		"reputation": Reputation.to_dict().duplicate(true),
		"renown": Renown.to_dict().duplicate(true),
		"skill_check": SkillCheck.to_dict().duplicate(true),
		"quest_pools": QuestRegistry.to_dict().duplicate(true),
	}

	var quests: Array[Dictionary] = [_quest("state-safe")]
	var result: Dictionary = _editor.call("save_campaign", _campaign(), quests)

	assert_bool(bool(result.get("saved", false))).is_true()
	assert_dict(GameState.to_dict()).is_equal(state_before["game_state"])
	assert_dict(Reputation.to_dict()).is_equal(state_before["reputation"])
	assert_dict(Renown.to_dict()).is_equal(state_before["renown"])
	assert_dict(SkillCheck.to_dict()).is_equal(state_before["skill_check"])
	assert_dict(QuestRegistry.to_dict()).is_equal(state_before["quest_pools"])
	assert_int(QuestRegistry.runtime_quests().size()).is_equal(1)
	assert_bool(SaveGame.runtime_sandbox_is_armed()).is_false()


func test_new_quest_ui_makes_the_two_outcome_minimum_visible() -> void:
	_editor.call("open_overlay")
	var layer: CanvasLayer = _editor.get("_overlay_layer") as CanvasLayer
	assert_object(layer).is_not_null()
	if layer == null:
		return
	var overlay: Control = layer.get_child(0) as Control
	overlay.call("start_new_campaign")
	overlay.call("create_new_quest")
	var outcome_rows: Array = overlay.get("_outcome_rows")
	var requirement: Label = overlay.get("_outcome_requirement") as Label

	assert_int(outcome_rows.size()).is_equal(2)
	assert_object(requirement).is_not_null()
	assert_str(requirement.text).contains("Minimum 2 outcomes")


func _campaign(campaign_id: String = CAMPAIGN_ID) -> Dictionary:
	return {
		"id": campaign_id,
		"title": "Quest Editor Test",
		"entry_location": "dom",
		"locations": ["dom"],
	}


func _quest(quest_id: String) -> Dictionary:
	return {
		"schema": 1,
		"quest_id": quest_id,
		"kind": "side_quest",
		"name": "Editor Quest",
		"giver_actor_id": "editor-giver-%s" % quest_id,
		"dialogue_title": "dom_side_dishonest_casks",
		"decision_prompt": "Choose.",
		"resolution_flag": "editor_%s_resolution" % quest_id.replace("-", "_"),
		"outcomes": [
			{
				"id": "first",
				"label": "First",
				"faction_id": "the-registry",
				"reputation_delta": 1.0,
				"cause": "First cause",
				"readback": "First readback",
			},
			{
				"id": "second",
				"label": "Second",
				"faction_id": "iron-companies",
				"reputation_delta": -1.0,
				"cause": "Second cause",
				"readback": "Second readback",
			},
		],
	}


func _has_error_code(errors: Array, code: String) -> bool:
	for error_value: Variant in errors:
		if error_value is Dictionary and str((error_value as Dictionary).get("code", "")) == code:
			return true
	return false


func _error_with_code(errors: Array, code: String) -> Dictionary:
	for error_value: Variant in errors:
		if error_value is Dictionary and str((error_value as Dictionary).get("code", "")) == code:
			return error_value as Dictionary
	return {}


func _conflict_identities(conflicts: Array) -> Array[String]:
	var identities: Array[String] = []
	for conflict_value: Variant in conflicts:
		if conflict_value is Dictionary:
			identities.append(str((conflict_value as Dictionary).get("identity", "")))
	return identities


func _write_package(
	package_path: String, campaign: Dictionary, quests: Array[Dictionary]
) -> void:
	var quest_directory: String = package_path.path_join("quests")
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(quest_directory)
	)
	assert_int(make_error).is_equal(OK)
	_write_json(package_path.path_join("campaign.json"), campaign)
	for quest: Dictionary in quests:
		_write_json(
			quest_directory.path_join(str(quest.get("quest_id", "")) + ".json"),
			quest
		)


func _write_json(file_path: String, value: Dictionary) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file == null:
		return
	file.store_string(JSON.stringify(value, "  ") + "\n")
	file.close()


func _write_text(file_path: String, text: String) -> void:
	var make_error: Error = DirAccess.make_dir_recursive_absolute(
		ProjectSettings.globalize_path(file_path.get_base_dir())
	)
	assert_bool(make_error == OK or make_error == ERR_ALREADY_EXISTS).is_true()
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	assert_object(file).is_not_null()
	if file == null:
		return
	file.store_string(text)
	file.close()


func _package_bytes(package_path: String) -> Dictionary:
	var result: Dictionary = {}
	for file_path: String in _package_json_files(package_path):
		result[file_path] = FileAccess.get_file_as_bytes(file_path)
	return result


func _package_json_files(package_path: String) -> Array[String]:
	var result: Array[String] = []
	var campaign_path: String = package_path.path_join("campaign.json")
	if FileAccess.file_exists(campaign_path):
		result.append(campaign_path)
	var quest_directory: String = package_path.path_join("quests")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(quest_directory)):
		var file_names: PackedStringArray = DirAccess.get_files_at(quest_directory)
		file_names.sort()
		for file_name: String in file_names:
			if file_name.get_extension().to_lower() == "json":
				result.append(quest_directory.path_join(file_name))
	return result


func _node_text_contains(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text.contains(expected):
		return true
	for child: Node in node.get_children():
		if _node_text_contains(child, expected):
			return true
	return false


func _remove_tree(path: String) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	if not DirAccess.dir_exists_absolute(absolute):
		return
	var directory: DirAccess = DirAccess.open(absolute)
	if directory == null:
		return
	directory.list_dir_begin()
	var entry: String = directory.get_next()
	while not entry.is_empty():
		var child: String = absolute.path_join(entry)
		if directory.current_is_dir():
			_remove_tree(child)
		else:
			DirAccess.remove_absolute(child)
		entry = directory.get_next()
	directory.list_dir_end()
	DirAccess.remove_absolute(absolute)
