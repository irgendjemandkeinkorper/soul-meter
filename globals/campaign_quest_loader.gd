class_name CampaignQuestLoader
extends RefCounted
## Explicit loader for campaign manifests and authored side-quest JSON.
## Nothing scans user:// automatically; callers choose when a package becomes active.
## This wave routes through Dom's committed side-quest dialogue resource, so every
## package dialogue_title must already be authored in that resource.

const QUEST_SCHEMA := 1
const RUNTIME_ID_MIN := StableIds.RUNTIME_QUEST_ID_MIN
const RUNTIME_ID_MAX := StableIds.RUNTIME_QUEST_ID_MAX


static func runtime_id_for(identity: String) -> int:
	return StableIds.runtime_quest_id(identity)


static func load_package(package_path: String, register_runtime: bool = true) -> Dictionary:
	var errors: Array[Dictionary] = []
	var quests: Array[DomSideQuest] = []
	var quest_entries: Array[Dictionary] = []
	var campaign_path: String = package_path.path_join("campaign.json")
	var raw_campaign: Variant = _read_json(campaign_path, errors)
	var campaign: Dictionary = {}
	if raw_campaign is Dictionary:
		campaign = (raw_campaign as Dictionary).duplicate(true)
		_validate_campaign(campaign, package_path, campaign_path, errors)
	else:
		return _result(campaign, quests, quest_entries, errors)

	var campaign_error_count: int = errors.size()
	if campaign_error_count > 0:
		return _result(campaign, quests, quest_entries, errors)
	var dialogue_titles: Dictionary = _load_routed_dialogue_titles(errors)
	if not errors.is_empty():
		return _result(campaign, quests, quest_entries, errors)

	var quest_directory_path: String = package_path.path_join("quests")
	var quest_directory: DirAccess = DirAccess.open(quest_directory_path)
	if quest_directory == null:
		_add_error(
			errors,
			quest_directory_path,
			"quests",
			"directory",
			"missing_quest_directory",
			"Expected a readable quests directory."
		)
		return _result(campaign, quests, quest_entries, errors)

	var file_names: PackedStringArray = quest_directory.get_files()
	file_names.sort()
	var id_entries: Dictionary = {}
	var invalid_runtime_ids: Dictionary = {}
	var identity_files: Dictionary = {}
	for file_name: String in file_names:
		if file_name.get_extension().to_lower() != "json":
			continue
		var file_path: String = quest_directory_path.path_join(file_name)
		var error_count_before: int = errors.size()
		var raw_quest: Variant = _read_json(file_path, errors)
		if not raw_quest is Dictionary:
			continue
		var quest_data: Dictionary = raw_quest as Dictionary
		_validate_quest(quest_data, file_path, dialogue_titles, errors)
		if errors.size() != error_count_before:
			continue

		var quest_id: String = str(quest_data["quest_id"])
		var identity: String = "%s/%s" % [str(campaign["id"]), quest_id]
		var runtime_id: int = runtime_id_for(identity)
		if identity_files.has(identity):
			_add_error(
				errors,
				file_path,
				"quest_id",
				"unique quest identity",
				"duplicate_quest_identity",
				"Quest identity '%s' is already authored by %s." % [identity, identity_files[identity]]
			)
			continue
		if invalid_runtime_ids.has(runtime_id):
			_add_runtime_collision_error(errors, file_path, identity, runtime_id)
			continue
		if id_entries.has(runtime_id):
			var previous_entry: Dictionary = id_entries[runtime_id]
			var previous_quest: DomSideQuest = previous_entry["quest"]
			_add_runtime_collision_error(
				errors, str(previous_entry["file"]), previous_quest.stable_id, runtime_id
			)
			_add_runtime_collision_error(errors, file_path, identity, runtime_id)
			quests.erase(previous_quest)
			quest_entries.erase(previous_entry)
			id_entries.erase(runtime_id)
			invalid_runtime_ids[runtime_id] = true
			continue

		var quest: DomSideQuest = _quest_from_data(quest_data, identity, runtime_id)
		var entry: Dictionary = {
			"file": file_path,
			"quest_id": quest_id,
			"identity": identity,
			"quest": quest,
		}
		quests.append(quest)
		quest_entries.append(entry)
		identity_files[identity] = file_path
		id_entries[runtime_id] = entry

	quest_entries = _reject_shared_state_collisions(quest_entries, errors)
	quests.clear()
	for entry: Dictionary in quest_entries:
		quests.append(entry["quest"] as DomSideQuest)

	if register_runtime and not QuestRegistry.register_runtime_quests(quests):
		_add_error(
			errors,
			package_path,
			"quests",
			"runtime quests with unique reserved ids",
			"runtime_registration_failed",
			"QuestRegistry refused the validated runtime quest set."
		)
	return _result(campaign, quests, quest_entries, errors)


static func _validate_campaign(
	campaign: Dictionary, package_path: String, file_path: String, errors: Array[Dictionary]
) -> void:
	var valid_id: bool = _require_nonempty_string(campaign, "id", file_path, errors)
	_require_nonempty_string(campaign, "title", file_path, errors)
	var valid_entry: bool = _require_nonempty_string(
		campaign, "entry_location", file_path, errors
	)
	if valid_id:
		var campaign_id: String = str(campaign["id"])
		if not StableIds.is_valid(StableIds.QUEST, campaign_id):
			_add_error(
				errors,
				file_path,
				"id",
				StableIds.schema_for(StableIds.QUEST).get("format", "valid stable id"),
				"invalid_campaign_id",
				"Campaign id '%s' does not match the stable-id format." % campaign_id
			)
		var directory_id: String = package_path.trim_suffix("/").get_file()
		if campaign_id != directory_id:
			_add_error(
				errors,
				file_path,
				"id",
				"the package directory name '%s'" % directory_id,
				"campaign_directory_mismatch",
				"Campaign id '%s' does not match its package directory." % campaign_id
			)

	var locations_value: Variant = campaign.get("locations")
	if not locations_value is Array:
		_add_error(
			errors, file_path, "locations", "non-empty array of location ids",
			"invalid_field_type", "Expected 'locations' to be an array."
		)
		return
	var locations: Array = locations_value as Array
	if locations.is_empty():
		_add_error(
			errors, file_path, "locations", "non-empty array of location ids",
			"invalid_field_value", "Expected at least one ordered location."
		)
		return
	var valid_locations: bool = true
	for index: int in locations.size():
		if not locations[index] is String or str(locations[index]).is_empty():
			valid_locations = false
			_add_error(
				errors, file_path, "locations[%d]" % index, "non-empty string",
				"invalid_field_type", "Expected a non-empty location id."
			)
	if valid_entry and valid_locations and not locations.has(str(campaign["entry_location"])):
		_add_error(
			errors, file_path, "entry_location", "one of the ordered locations",
			"entry_location_not_listed", "Entry location is absent from 'locations'."
		)


static func _validate_quest(
	quest_data: Dictionary,
	file_path: String,
	dialogue_titles: Dictionary,
	errors: Array[Dictionary]
) -> void:
	var schema_value: Variant = quest_data.get("schema")
	if (
		(not schema_value is int and not schema_value is float)
		or float(schema_value) != float(QUEST_SCHEMA)
	):
		_add_error(
			errors, file_path, "schema", "integer 1", "unsupported_schema",
			"Expected quest schema 1."
		)
	if not quest_data.get("kind") is String or str(quest_data.get("kind", "")) != "side_quest":
		_add_error(
			errors, file_path, "kind", "string 'side_quest'", "unsupported_quest_kind",
			"Only side_quest is supported in this wave."
		)
	var valid_quest_id: bool = _require_nonempty_string(
		quest_data, "quest_id", file_path, errors
	)
	if valid_quest_id and not StableIds.is_valid(StableIds.QUEST, str(quest_data["quest_id"])):
		_add_error(
			errors,
			file_path,
			"quest_id",
			StableIds.schema_for(StableIds.QUEST).get("format", "valid stable id"),
			"invalid_quest_id",
			"Quest id '%s' does not match the StableIds quest format." % quest_data["quest_id"]
		)
	for field: String in ["name", "giver_actor_id", "decision_prompt", "resolution_flag"]:
		_require_nonempty_string(quest_data, field, file_path, errors)
	var valid_dialogue_title: bool = _require_nonempty_string(
		quest_data, "dialogue_title", file_path, errors
	)
	if valid_dialogue_title and not dialogue_titles.has(str(quest_data["dialogue_title"])):
		_add_error(
			errors,
			file_path,
			"dialogue_title",
			"title authored in %s" % QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH,
			"unknown_dialogue_title",
			"Dialogue title '%s' is absent from the routed dialogue resource."
			% quest_data["dialogue_title"]
		)

	var outcomes_value: Variant = quest_data.get("outcomes")
	if not outcomes_value is Array:
		_add_error(
			errors, file_path, "outcomes", "array of at least two outcome objects",
			"invalid_field_type", "Expected 'outcomes' to be an array."
		)
		return
	var outcomes: Array = outcomes_value as Array
	if outcomes.size() < 2:
		_add_error(
			errors, file_path, "outcomes", "array of at least two outcome objects",
			"incomplete_outcome_schema", "DomSideQuest requires at least two outcomes."
		)
	var outcome_ids: Dictionary = {}
	for index: int in outcomes.size():
		var field_prefix: String = "outcomes[%d]" % index
		if not outcomes[index] is Dictionary:
			_add_error(
				errors, file_path, field_prefix, "outcome object", "invalid_field_type",
				"Expected each outcome to be an object."
			)
			continue
		var outcome: Dictionary = outcomes[index]
		for field: String in ["id", "label", "faction_id", "cause", "readback"]:
			_require_nonempty_string(outcome, field, file_path, errors, field_prefix + ".")
		var delta: Variant = outcome.get("reputation_delta")
		if not delta is float and not delta is int:
			_add_error(
				errors, file_path, field_prefix + ".reputation_delta", "number",
				"invalid_field_type", "Expected a numeric reputation delta."
			)
		if outcome.get("id") is String and not str(outcome["id"]).is_empty():
			var outcome_id: String = str(outcome["id"])
			if outcome_ids.has(outcome_id):
				_add_error(
					errors, file_path, field_prefix + ".id", "unique outcome id",
					"duplicate_outcome_id", "Outcome id '%s' is duplicated." % outcome_id
				)
			outcome_ids[outcome_id] = true


static func _quest_from_data(
	quest_data: Dictionary, identity: String, runtime_id: int
) -> DomSideQuest:
	var quest: DomSideQuest = DomSideQuest.new()
	quest.id = runtime_id
	quest.stable_id = identity
	quest.quest_name = str(quest_data["name"])
	quest.giver_actor_id = str(quest_data["giver_actor_id"])
	quest.quest_giver = quest.giver_actor_id
	quest.dialogue_title = str(quest_data["dialogue_title"])
	quest.decision_prompt = str(quest_data["decision_prompt"])
	quest.resolution_flag = str(quest_data["resolution_flag"])
	var outcomes: Array = quest_data["outcomes"] as Array
	for outcome_value: Variant in outcomes:
		var outcome: Dictionary = outcome_value as Dictionary
		quest.outcome_ids.append(str(outcome["id"]))
		quest.outcome_labels.append(str(outcome["label"]))
		quest.outcome_faction_ids.append(str(outcome["faction_id"]))
		quest.outcome_reputation_deltas.append(float(outcome["reputation_delta"]))
		quest.outcome_causes.append(str(outcome["cause"]))
		quest.outcome_readbacks.append(str(outcome["readback"]))
	return quest


static func _read_json(file_path: String, errors: Array[Dictionary]) -> Variant:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_add_error(
			errors, file_path, "$", "readable JSON file", "file_unreadable",
			"Could not open file (FileAccess error %d)." % FileAccess.get_open_error()
		)
		return null
	var parser: JSON = JSON.new()
	var parse_error: Error = parser.parse(file.get_as_text())
	if parse_error != OK:
		_add_error(
			errors, file_path, "$", "valid JSON object", "invalid_json",
			"JSON parse error on line %d: %s" % [parser.get_error_line(), parser.get_error_message()]
		)
		return null
	var value: Variant = parser.data
	if not value is Dictionary:
		_add_error(
			errors, file_path, "$", "JSON object", "invalid_document_type",
			"Expected the document root to be an object."
		)
		return null
	return value


static func _require_nonempty_string(
	data: Dictionary,
	field: String,
	file_path: String,
	errors: Array[Dictionary],
	field_prefix: String = ""
) -> bool:
	var value: Variant = data.get(field)
	if value is String and not str(value).is_empty():
		return true
	_add_error(
		errors, file_path, field_prefix + field, "non-empty string", "invalid_field_type",
		"Expected '%s' to be a non-empty string." % (field_prefix + field)
	)
	return false


static func _load_routed_dialogue_titles(errors: Array[Dictionary]) -> Dictionary:
	## Read through ResourceLoader, NOT FileAccess.
	##
	## `.dialogue` is an IMPORTED asset: Dialogue Manager compiles it to a binary
	## resource, and an exported build ships the compiled cues without the raw
	## `~ title` source lines. Scraping the source text therefore works from the
	## project tree and silently rejects EVERY campaign quest after export.
	## `DialogueResource.get_cues()` is the same accessor `DialogueLab` uses.
	var dialogue_path: String = QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH
	var resource := ResourceLoader.load(dialogue_path, "", ResourceLoader.CACHE_MODE_REUSE)
	var dialogue := resource as DialogueResource
	if dialogue == null:
		_add_error(
			errors,
			dialogue_path,
			"dialogue_title",
			"loadable routed dialogue resource",
			"dialogue_resource_unreadable",
			"Could not load the routed dialogue resource."
		)
		return {}
	var titles: Dictionary = {}
	for cue: String in dialogue.get_cues():
		if not cue.is_empty():
			titles[cue] = true
	return titles


static func _reject_shared_state_collisions(
	quest_entries: Array[Dictionary], errors: Array[Dictionary]
) -> Array[Dictionary]:
	var rejected_identities: Dictionary = {}
	_reject_shared_field_collisions(
		quest_entries, "giver_actor_id", rejected_identities, errors
	)
	_reject_shared_field_collisions(
		quest_entries, "resolution_flag", rejected_identities, errors
	)
	var accepted: Array[Dictionary] = []
	for entry: Dictionary in quest_entries:
		if not rejected_identities.has(str(entry["identity"])):
			accepted.append(entry)
	return accepted


static func _reject_shared_field_collisions(
	quest_entries: Array[Dictionary],
	field: String,
	rejected_identities: Dictionary,
	errors: Array[Dictionary]
) -> void:
	var committed_owners: Dictionary = {}
	for committed_quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		committed_owners[_shared_field_value(committed_quest, field)] = committed_quest

	var package_owners: Dictionary = {}
	for entry: Dictionary in quest_entries:
		var quest: DomSideQuest = entry["quest"] as DomSideQuest
		var value: String = _shared_field_value(quest, field)
		if not package_owners.has(value):
			package_owners[value] = []
		(package_owners[value] as Array).append(entry)
		if committed_owners.has(value):
			var committed_quest: DomSideQuest = committed_owners[value] as DomSideQuest
			rejected_identities[quest.stable_id] = true
			_add_error(
				errors,
				str(entry["file"]),
				field,
				"value not owned by a committed quest",
				"committed_%s_collision" % field,
				"Quest '%s' uses %s '%s', already owned by committed quest '%s'."
				% [quest.stable_id, field, value, committed_quest.stable_id]
			)

	for value: String in package_owners:
		var owners: Array = package_owners[value] as Array
		if owners.size() < 2:
			continue
		var identities: PackedStringArray = []
		for entry: Dictionary in owners:
			identities.append(str(entry["identity"]))
		for entry: Dictionary in owners:
			var identity: String = str(entry["identity"])
			rejected_identities[identity] = true
			_add_error(
				errors,
				str(entry["file"]),
				field,
				"value unique within the package",
				"duplicate_%s" % field,
				"Quest '%s' shares %s '%s' with package quests %s."
				% [identity, field, value, ", ".join(identities)]
			)


static func _shared_field_value(quest: DomSideQuest, field: String) -> String:
	if field == "giver_actor_id":
		return quest.giver_actor_id
	return quest.resolution_flag


static func _add_runtime_collision_error(
	errors: Array[Dictionary], file_path: String, identity: String, runtime_id: int
) -> void:
	_add_error(
		errors,
		file_path,
		"quest_id",
		"identity with a unique deterministic runtime id",
		"runtime_id_collision",
		"Quest identity '%s' collides on runtime id %d; refusing all colliding quests."
		% [identity, runtime_id]
	)


static func _add_error(
	errors: Array[Dictionary],
	file_path: String,
	field: String,
	expected: String,
	code: String,
	message: String
) -> void:
	errors.append({
		"file": file_path,
		"field": field,
		"expected": expected,
		"code": code,
		"message": message,
	})


static func _result(
	campaign: Dictionary,
	quests: Array[DomSideQuest],
	quest_entries: Array[Dictionary],
	errors: Array[Dictionary]
) -> Dictionary:
	return {
		"campaign": campaign,
		"quests": quests,
		"quest_entries": quest_entries,
		"errors": errors,
	}
