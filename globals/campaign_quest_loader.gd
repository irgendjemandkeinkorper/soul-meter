class_name CampaignQuestLoader
extends RefCounted
## Explicit loader for campaign manifests and authored side-quest JSON.
## Nothing scans user:// automatically; callers choose when a package becomes active.
## Campaign dialogue is plain text compiled at package load; committed dialogue
## remains an imported resource resolved through ResourceLoader.

const QUEST_SCHEMA := 1
const RUNTIME_ID_MIN := StableIds.RUNTIME_QUEST_ID_MIN
const RUNTIME_ID_MAX := StableIds.RUNTIME_QUEST_ID_MAX
const QUEST_DISCOVERY_MAX_DEPTH: int = 8
const QUEST_DISCOVERY_MAX_FILES: int = 512


static func runtime_id_for(identity: String) -> int:
	return StableIds.runtime_quest_id(identity)


static func validate_package_data(
	package_path: String, campaign_data: Dictionary, quest_documents: Array[Dictionary]
) -> Dictionary:
	var errors: Array[Dictionary] = []
	var quests: Array[DomSideQuest] = []
	var quest_entries: Array[Dictionary] = []
	var campaign: Dictionary = campaign_data.duplicate(true)
	var campaign_path: String = package_path.path_join("campaign.json")
	_validate_campaign(campaign, package_path, campaign_path, errors)
	if not errors.is_empty():
		return _result(campaign, quests, quest_entries, errors)
	var dialogue_context: Dictionary = _load_dialogue_context(package_path, errors)
	if not errors.is_empty():
		return _result(
			campaign, quests, quest_entries, errors,
			dialogue_context.get("campaign_resources", {})
		)
	var validated: Dictionary = _validate_quest_documents(
		campaign, quest_documents, dialogue_context.get("titles", {}), errors
	)
	quests.assign(validated.get("quests", []))
	quest_entries.assign(validated.get("quest_entries", []))
	return _result(
		campaign, quests, quest_entries, errors,
		dialogue_context.get("campaign_resources", {})
	)


static func routed_dialogue_titles() -> Array[String]:
	var errors: Array[Dictionary] = []
	var title_lookup: Dictionary = _load_routed_dialogue_titles(errors)
	if not errors.is_empty():
		return []
	var titles: Array[String] = []
	for title_value: Variant in title_lookup.keys():
		titles.append(str(title_value))
	titles.sort()
	return titles


static func dialogue_title_options(package_path: String) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var dialogue_context: Dictionary = _load_dialogue_context(package_path, errors)
	var options: Array[Dictionary] = []
	options.assign(dialogue_context.get("options", []))
	return options


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
	var dialogue_context: Dictionary = _load_dialogue_context(package_path, errors)
	if not errors.is_empty():
		return _result(
			campaign, quests, quest_entries, errors,
			dialogue_context.get("campaign_resources", {})
		)

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

	var quest_documents: Array[Dictionary] = []
	var discovery_state: Dictionary = {"file_count": 0, "stopped": false}
	var quest_file_paths: Array[String] = _package_files(
		quest_directory_path,
		quest_directory_path,
		"json",
		"quests",
		"quest",
		"Quest",
		errors,
		0,
		discovery_state,
		false
	)
	if not errors.is_empty():
		return _result(campaign, quests, quest_entries, errors)
	for file_path: String in quest_file_paths:
		var raw_quest: Variant = _read_json(file_path, errors)
		if not raw_quest is Dictionary:
			continue
		quest_documents.append({"file": file_path, "data": raw_quest as Dictionary})

	var validated: Dictionary = _validate_quest_documents(
		campaign, quest_documents, dialogue_context.get("titles", {}), errors
	)
	quests.assign(validated.get("quests", []))
	quest_entries.assign(validated.get("quest_entries", []))

	var campaign_dialogue_resources: Dictionary = dialogue_context.get(
		"campaign_resources", {}
	)
	if (
		register_runtime
		and not QuestRegistry.register_runtime_quests(quests, campaign_dialogue_resources)
	):
		_add_error(
			errors,
			package_path,
			"quests",
			"runtime quests with unique reserved ids",
			"runtime_registration_failed",
			"QuestRegistry refused the validated runtime quest set."
		)
	return _result(
		campaign, quests, quest_entries, errors, campaign_dialogue_resources
	)


static func _validate_quest_documents(
	campaign: Dictionary,
	quest_documents: Array[Dictionary],
	dialogue_titles: Dictionary,
	errors: Array[Dictionary]
) -> Dictionary:
	var quests: Array[DomSideQuest] = []
	var quest_entries: Array[Dictionary] = []
	var id_entries: Dictionary = {}
	var invalid_runtime_ids: Dictionary = {}
	var identity_files: Dictionary = {}
	var ascii_case_quest_id_entries: Dictionary = {}
	for document: Dictionary in quest_documents:
		var file_path: String = str(document.get("file", ""))
		var quest_value: Variant = document.get("data")
		if not quest_value is Dictionary:
			_add_error(
				errors, file_path, "$", "quest object", "invalid_document_type",
				"Expected the quest document to be an object."
			)
			continue
		var error_count_before: int = errors.size()
		var quest_data: Dictionary = quest_value as Dictionary
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
		var ascii_case_quest_id: String = _ascii_case_fold(quest_id)
		if ascii_case_quest_id_entries.has(ascii_case_quest_id):
			var previous_case_entry: Dictionary = ascii_case_quest_id_entries[
				ascii_case_quest_id
			] as Dictionary
			_add_error(
				errors,
				file_path,
				"quest_id",
				"quest id unique under ASCII case folding",
				"case_insensitive_quest_id_collision",
				(
					"Quest id '%s' differs only by ASCII case from '%s', already authored by %s."
					% [quest_id, previous_case_entry["quest_id"], previous_case_entry["file"]]
				)
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
		ascii_case_quest_id_entries[ascii_case_quest_id] = {
			"file": file_path,
			"quest_id": quest_id,
		}
		id_entries[runtime_id] = entry

	quest_entries = _reject_shared_state_collisions(quest_entries, errors)
	quests.clear()
	for entry: Dictionary in quest_entries:
		quests.append(entry["quest"] as DomSideQuest)
	return {"quests": quests, "quest_entries": quest_entries}


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
	if valid_quest_id:
		var quest_id: String = str(quest_data["quest_id"])
		if not StableIds.is_valid(StableIds.QUEST, quest_id):
			_add_error(
				errors,
				file_path,
				"quest_id",
				StableIds.schema_for(StableIds.QUEST).get("format", "valid stable id"),
				"invalid_quest_id",
				"Quest id '%s' does not match the StableIds quest format." % quest_id
			)
		if not _relative_package_path_is_safe(quest_id):
			_add_error(
				errors,
				file_path,
				"quest_id",
				"portable relative package path",
				"unsafe_quest_id_file_name",
				(
					"Quest id '%s' must produce a relative JSON path inside the campaign package; "
					+ "segments must be non-empty, may not be '.' or '..' or a Windows reserved "
					+ "device name, and ':' and backslashes are not allowed."
				) % quest_id
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
			"title authored in campaign dialogue or %s"
			% QuestRegistry.DOM_SIDE_QUEST_DIALOGUE_PATH,
			"unknown_dialogue_title",
			"Dialogue title '%s' is absent from campaign and committed dialogue."
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


static func _relative_package_path_is_safe(relative_path: String) -> bool:
	if (
		relative_path.begins_with("/")
		or relative_path.contains("\\")
		or relative_path.contains(":")
	):
		return false
	var segments: PackedStringArray = relative_path.split("/", true)
	if segments.is_empty():
		return false
	for segment: String in segments:
		if segment.is_empty() or segment == "." or segment == "..":
			return false
		# Windows strips a trailing period or space from a path component, so
		# "side." and "side" name the SAME directory there while remaining
		# distinct paths here. That breaks the one-identity/one-file guarantee for
		# both quest ids and package dialogue sources.
		if segment.ends_with(".") or segment.ends_with(" "):
			return false
		var stem: String = segment.get_slice(".", 0)
		if _is_windows_reserved_file_stem(stem):
			return false
	return true


static func _is_windows_reserved_file_stem(stem: String) -> bool:
	var upper_stem: String = stem.to_upper()
	if upper_stem in ["CON", "PRN", "AUX", "NUL"]:
		return true
	if upper_stem.length() != 4:
		return false
	var prefix: String = upper_stem.left(3)
	var device_number: int = upper_stem.unicode_at(3)
	return (prefix == "COM" or prefix == "LPT") and device_number >= 49 and device_number <= 57


static func _ascii_case_fold(value: String) -> String:
	var folded: String = ""
	for index: int in value.length():
		var codepoint: int = value.unicode_at(index)
		if codepoint >= 65 and codepoint <= 90:
			folded += String.chr(codepoint + 32)
		else:
			folded += value.substr(index, 1)
	return folded


static func _package_files(
	root_path: String,
	directory_path: String,
	extension: String,
	field: String,
	code_prefix: String,
	label: String,
	errors: Array[Dictionary],
	depth: int,
	discovery_state: Dictionary,
	validate_relative_paths: bool
) -> Array[String]:
	var result: Array[String] = []
	if bool(discovery_state.get("stopped", false)):
		return result
	var directory: DirAccess = DirAccess.open(directory_path)
	if directory == null:
		return result
	var file_names: PackedStringArray = directory.get_files()
	file_names.sort()
	for file_name: String in file_names:
		if directory.is_link(file_name):
			continue
		var file_path: String = directory_path.path_join(file_name)
		var file_count: int = int(discovery_state.get("file_count", 0)) + 1
		discovery_state["file_count"] = file_count
		if file_count > QUEST_DISCOVERY_MAX_FILES:
			_add_error(
				errors,
				file_path,
				field,
				"at most %d regular files" % QUEST_DISCOVERY_MAX_FILES,
				"%s_discovery_file_limit_exceeded" % code_prefix,
				"%s discovery exceeded the %d-file package limit at '%s'."
				% [label, QUEST_DISCOVERY_MAX_FILES, file_path]
			)
			discovery_state["stopped"] = true
			return result
		if file_name.get_extension().to_lower() != extension:
			continue
		var relative_path: String = file_path.trim_prefix(root_path.trim_suffix("/") + "/")
		if validate_relative_paths and not _relative_package_path_is_safe(relative_path):
			_add_error(
				errors,
				file_path,
				field,
				"portable relative package path",
				"unsafe_%s_file_path" % code_prefix,
				"%s file '%s' is not a safe portable path inside the campaign package."
				% [label, relative_path]
			)
			continue
		result.append(file_path)
	var directory_names: PackedStringArray = directory.get_directories()
	directory_names.sort()
	for directory_name: String in directory_names:
		if directory.is_link(directory_name):
			continue
		var child_path: String = directory_path.path_join(directory_name)
		var child_depth: int = depth + 1
		if child_depth > QUEST_DISCOVERY_MAX_DEPTH:
			_add_error(
				errors,
				child_path,
				field,
				"package tree no deeper than %d directories" % QUEST_DISCOVERY_MAX_DEPTH,
				"%s_discovery_depth_exceeded" % code_prefix,
				"%s discovery exceeded the depth limit at '%s'." % [label, child_path]
			)
			discovery_state["stopped"] = true
			return result
		result.append_array(
			_package_files(
				root_path,
				child_path,
				extension,
				field,
				code_prefix,
				label,
				errors,
				child_depth,
				discovery_state,
				validate_relative_paths
			)
		)
		if bool(discovery_state.get("stopped", false)):
			return result
	return result


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
	var resource: Resource = ResourceLoader.load(
		dialogue_path, "", ResourceLoader.CACHE_MODE_REUSE
	)
	var dialogue: DialogueResource = resource as DialogueResource
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


static func _load_dialogue_context(
	package_path: String, errors: Array[Dictionary]
) -> Dictionary:
	var committed_titles: Dictionary = _load_routed_dialogue_titles(errors)
	var campaign_resources: Dictionary = {}
	if errors.is_empty() and not package_path.is_empty():
		campaign_resources = _load_campaign_dialogue_resources(
			package_path, committed_titles, errors
		)

	var all_titles: Dictionary = committed_titles.duplicate()
	for title_value: Variant in campaign_resources.keys():
		all_titles[str(title_value)] = true

	var options: Array[Dictionary] = []
	var campaign_titles: Array[String] = []
	for title_value: Variant in campaign_resources.keys():
		campaign_titles.append(str(title_value))
	campaign_titles.sort()
	for title: String in campaign_titles:
		options.append({
			"title": title,
			"source": "campaign",
			"label": "[CAMPAIGN] %s" % title,
		})
	var committed_title_values: Array[String] = []
	for title_value: Variant in committed_titles.keys():
		committed_title_values.append(str(title_value))
	committed_title_values.sort()
	for title: String in committed_title_values:
		options.append({
			"title": title,
			"source": "committed",
			"label": "[COMMITTED] %s" % title,
		})
	return {
		"titles": all_titles,
		"campaign_resources": campaign_resources,
		"options": options,
	}


static func _load_campaign_dialogue_resources(
	package_path: String,
	committed_titles: Dictionary,
	errors: Array[Dictionary]
) -> Dictionary:
	var dialogue_directory_path: String = package_path.path_join("dialogue")
	if not DirAccess.dir_exists_absolute(
		ProjectSettings.globalize_path(dialogue_directory_path)
	):
		return {}

	var discovery_state: Dictionary = {"file_count": 0, "stopped": false}
	var dialogue_file_paths: Array[String] = _package_files(
		dialogue_directory_path,
		dialogue_directory_path,
		"dialogue",
		"dialogue",
		"dialogue",
		"Dialogue",
		errors,
		0,
		discovery_state,
		true
	)
	if bool(discovery_state.get("stopped", false)):
		return {}

	var resources: Dictionary = {}
	var title_sources: Dictionary = {}
	var duplicate_titles: Dictionary = {}
	for file_path: String in dialogue_file_paths:
		var text_value: Variant = _read_dialogue_text(file_path, errors)
		if not text_value is String:
			continue
		var source_text: String = text_value as String
		# Do not replace this with DialogueManager.create_resource_from_text(). That
		# helper asserts on author errors and halts debug builds. Packages are
		# untrusted author input, so compile directly, attribute every error, and
		# construct a resource only after this source compiles cleanly.
		var compilation: DMCompilerResult = DMCompiler.compile_string(source_text, "")
		if not compilation.errors.is_empty():
			for compile_error: DMError in compilation.errors:
				var line_number: int = _dialogue_compile_error_line(compile_error)
				_add_error(
					errors,
					file_path,
					"dialogue",
					"valid Dialogue Manager source at line %d" % line_number,
					"dialogue_compile_error",
					"Dialogue compile error on line %d: %s"
					% [line_number, DMConstants.get_error_message(compile_error.error)],
					line_number
				)
			continue

		var resource: DialogueResource = DialogueResource.new()
		resource.using_states = compilation.using_states
		resource.cues = compilation.cues
		resource.first_cue = compilation.first_cue
		resource.character_names = compilation.character_names
		resource.lines = compilation.lines
		resource.set_meta(&"campaign_source", file_path)

		var cue_titles: Array[String] = []
		for cue: String in resource.get_cues():
			if not cue.is_empty():
				cue_titles.append(cue)
		cue_titles.sort()
		for title: String in cue_titles:
			if committed_titles.has(title):
				_add_error(
					errors,
					file_path,
					"dialogue_title",
					"campaign title distinct from every committed title",
					"campaign_dialogue_title_shadows_committed",
					"Campaign dialogue title '%s' shadows a committed conversation."
					% title
				)
				continue
			if duplicate_titles.has(title):
				_add_duplicate_campaign_dialogue_title_error(errors, file_path, title)
				continue
			if title_sources.has(title):
				_add_duplicate_campaign_dialogue_title_error(
					errors, str(title_sources[title]), title
				)
				_add_duplicate_campaign_dialogue_title_error(errors, file_path, title)
				resources.erase(title)
				title_sources.erase(title)
				duplicate_titles[title] = true
				continue
			resources[title] = resource
			title_sources[title] = file_path
	return resources


static func _dialogue_compile_error_line(compile_error: DMError) -> int:
	# Dialogue Manager's DMCompilation is internally inconsistent: build_line_tree()
	# assigns DMTreeLine.line_number = i + 1 and almost every error uses that 1-based
	# value, but find_imported_cues() passes its raw id and ERR_EMPTY_CUE passes raw i.
	# Normalize only those four 0-based call sites; adding one to every error shifts
	# condition, other cue-validation, expression, and indentation failures too far.
	match compile_error.error:
		DMConstants.ERR_FILE_ALREADY_IMPORTED, \
		DMConstants.ERR_DUPLICATE_IMPORT_NAME, \
		DMConstants.ERR_ERRORS_IN_IMPORTED_FILE, \
		DMConstants.ERR_EMPTY_CUE:
			return compile_error.line_number + 1
		_:
			return compile_error.line_number


static func _read_dialogue_text(
	file_path: String, errors: Array[Dictionary]
) -> Variant:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		_add_error(
			errors,
			file_path,
			"dialogue",
			"readable campaign dialogue text",
			"dialogue_file_unreadable",
			"Could not open dialogue file (FileAccess error %d)."
			% FileAccess.get_open_error()
		)
		return null
	return file.get_as_text()


static func _add_duplicate_campaign_dialogue_title_error(
	errors: Array[Dictionary], file_path: String, title: String
) -> void:
	_add_error(
		errors,
		file_path,
		"dialogue_title",
		"title unique within campaign dialogue",
		"duplicate_campaign_dialogue_title",
		"Campaign dialogue title '%s' is authored by more than one file." % title
	)


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
	message: String,
	line_number: int = -1
) -> void:
	var error: Dictionary = {
		"file": file_path,
		"field": field,
		"expected": expected,
		"code": code,
		"message": message,
	}
	if line_number > 0:
		error["line"] = line_number
	errors.append(error)


static func _result(
	campaign: Dictionary,
	quests: Array[DomSideQuest],
	quest_entries: Array[Dictionary],
	errors: Array[Dictionary],
	dialogue_resources: Dictionary = {}
) -> Dictionary:
	return {
		"campaign": campaign,
		"quests": quests,
		"quest_entries": quest_entries,
		"dialogue_resources": dialogue_resources,
		"errors": errors,
	}
