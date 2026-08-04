extends SceneTree

## FR-501/FR-403 quest consequence audit.
##
## Run directly:
##   godot --headless --path . --script res://tools/quest_audit.gd
##
## Existing content is reported without failing by default. Set
## SOUL_METER_QUEST_AUDIT_STRICT=1 to make enforceable findings exit non-zero.
##
## KNOWN LIMITATIONS — read before trusting a green result (reviewed 2026-08-04):
##
## 1. Read-back detection can produce FALSE PASSES. Two of the three branches in
##    _has_flag_readback() test for co-occurrence anywhere in a source file rather
##    than proximity: a `get_flag("x"` and an outcome id appearing in unrelated
##    parts of the same file count as a read-back. Outcome ids that are common
##    words are the likely offenders. A reported read-back is evidence, not proof.
##
## 2. Flag names built by format string are invisible to the scanner. The regex
##    only captures a literal after `get_flag(`, so game code doing
##    `get_flag("quest_%d_resolution" % id)` is captured as the unsubstituted
##    template. This can both invent orphans and hide real ones.
##
## 3. The side-quest ratio denominator is per RESOLUTION across all side quests
##    combined, not per quest. A five-branch quest therefore weighs more than a
##    two-branch one. This is a deliberate choice, recorded here because it is
##    not self-evident from the output.
##
## Because of 1 and 2 this tool is a debt-finder, not a proof of compliance.
## FR-906's human playtest pass remains the check on whether consequences are
## meaningful; this only checks that they are wired.

const SCHEMA := "soul_meter.quest_audit.v1"
const STRICT_ENV := "SOUL_METER_QUEST_AUDIT_STRICT"
const REGISTRY_PATH := "res://globals/quest_registry.gd"
const QUEST_DIRECTORY := "res://quests"
const DIALOGUE_DIRECTORY := "res://dialogue"
const SIDE_READBACK_THRESHOLD := 0.6


func _initialize() -> void:
	var strict := strict_mode_from_value(OS.get_environment(STRICT_ENV))
	var report := audit_project(strict)
	print(JSON.stringify(report, "  ", false))
	quit(exit_code_for_report(report, strict))


static func strict_mode_from_value(value: String) -> bool:
	return value == "1"


static func exit_code_for_report(report: Dictionary, strict: bool) -> int:
	if not strict:
		return 0
	var summary: Dictionary = report.get("summary", {})
	var severity: Dictionary = summary.get("severity", {})
	return 1 if int(severity.get("error", 0)) + int(severity.get("warning", 0)) > 0 else 0


static func meets_readback_threshold(
	read_count: int, total_count: int, threshold: float = SIDE_READBACK_THRESHOLD
) -> bool:
	if total_count <= 0:
		return false
	return float(read_count) / float(total_count) + 0.000001 >= threshold


static func distinct_outcome_count(outcomes: Array[Dictionary]) -> int:
	var fingerprints := {}
	for outcome: Dictionary in outcomes:
		var state_writes := _sorted_strings(outcome.get("state_writes", []))
		var ledger_events := _sorted_strings(outcome.get("ledger_events", []))
		var fingerprint := JSON.stringify(
			{"state_writes": state_writes, "ledger_events": ledger_events}
		)
		if state_writes.is_empty() and ledger_events.is_empty():
			fingerprint = "id:%s" % str(outcome.get("id", "")).strip_edges()
		fingerprints[fingerprint] = true
	return fingerprints.size()


static func has_enough_outcomes(outcomes: Array[Dictionary]) -> bool:
	return distinct_outcome_count(outcomes) >= 2


static func audit_project(strict: bool = false) -> Dictionary:
	var registry_source := FileAccess.get_file_as_string(REGISTRY_PATH)
	var quest_metadata := _quest_metadata(registry_source)
	var dialogue_sources := _source_files(DIALOGUE_DIRECTORY, PackedStringArray(["dialogue"]))
	var quest_results := _collect_quest_results(quest_metadata, dialogue_sources)
	var readback_sources := _readback_sources(dialogue_sources)
	_classify_readbacks(quest_results, readback_sources)
	var flag_access := _project_flag_access(quest_results, dialogue_sources, readback_sources)
	return build_report(quest_results, flag_access, strict)


static func build_report(
	quest_results: Array[Dictionary], flag_access: Dictionary, strict: bool
) -> Dictionary:
	var categories := {
		"outcome_count": _category(),
		"resolution_writes": _category(),
		"readbacks": _category(),
		"orphaned_flags": _category(),
	}
	var main_read := 0
	var main_total := 0
	var side_read := 0
	var side_total := 0
	var resolution_count := 0

	for quest: Dictionary in quest_results:
		var outcomes: Array[Dictionary] = _typed_dictionaries(quest.get("outcomes", []))
		resolution_count += outcomes.size()
		var distinct_count := distinct_outcome_count(outcomes)
		if distinct_count < 2:
			_add_finding(
				categories["outcome_count"],
				"warning",
				"quest_has_fewer_than_two_distinct_outcomes",
				{
					"quest_id": quest.get("quest_id", ""),
					"quest_name": quest.get("quest_name", ""),
					"outcome_count": outcomes.size(),
					"distinct_outcome_count": distinct_count,
				}
			)

		for outcome: Dictionary in outcomes:
			var has_write := not (outcome.get("state_writes", []) as Array).is_empty()
			has_write = has_write or not (outcome.get("ledger_events", []) as Array).is_empty()
			if not has_write:
				_add_finding(
					categories["resolution_writes"],
					"error",
					"resolution_has_no_flag_or_ledger_write",
					_resolution_identity(quest, outcome)
				)

			var read_back := bool(outcome.get("read_back", false))
			if str(quest.get("kind", "side")) == "main":
				main_total += 1
				main_read += 1 if read_back else 0
				if not read_back:
					_add_finding(
						categories["readbacks"],
						"error",
						"main_resolution_not_read_back",
						_resolution_identity(quest, outcome)
					)
			else:
				side_total += 1
				side_read += 1 if read_back else 0
				if not read_back:
					_add_finding(
						categories["readbacks"],
						"info",
						"side_resolution_not_read_back",
						_resolution_identity(quest, outcome)
					)

	if side_total > 0 and not meets_readback_threshold(side_read, side_total):
		_add_finding(
			categories["readbacks"],
			"error",
			"side_readback_coverage_below_threshold",
			{
				"read": side_read,
				"total": side_total,
				"ratio": float(side_read) / float(side_total),
				"required_ratio": SIDE_READBACK_THRESHOLD,
			}
		)

	for flag: String in flag_access.get("written_never_read", PackedStringArray()):
		_add_finding(
			categories["orphaned_flags"],
			"warning",
			"flag_written_never_read",
			{"flag": flag, "direction": "written_never_read"}
		)
	for flag: String in flag_access.get("read_never_written", PackedStringArray()):
		_add_finding(
			categories["orphaned_flags"],
			"error",
			"flag_read_never_written",
			{"flag": flag, "direction": "read_never_written"}
		)

	var severity := {"error": 0, "warning": 0, "info": 0}
	var findings_total := 0
	for category_value: Variant in categories.values():
		var category: Dictionary = category_value
		category["count"] = (category["findings"] as Array).size()
		findings_total += int(category["count"])
		var category_severity: Dictionary = category["severity"]
		for level: String in severity:
			severity[level] += int(category_severity.get(level, 0))

	return {
		"schema": SCHEMA,
		"mode": "strict" if strict else "reporting",
		"summary": {
			"quest_count": quest_results.size(),
			"resolution_count": resolution_count,
			"findings_total": findings_total,
			"severity": severity,
		},
		"metrics": {
			"readbacks": {
				"main": {
					"read": main_read,
					"total": main_total,
					"ratio": _ratio(main_read, main_total),
					"required_ratio": 1.0,
					"passes": main_read == main_total and main_total > 0,
				},
				"side": {
					"read": side_read,
					"total": side_total,
					"ratio": _ratio(side_read, side_total),
					"required_ratio": SIDE_READBACK_THRESHOLD,
					"passes": meets_readback_threshold(side_read, side_total),
				},
			},
			"flags": {
				"written": int(flag_access.get("written_count", 0)),
				"read": int(flag_access.get("read_count", 0)),
			},
		},
		"categories": categories,
	}


static func scan_flag_sources(paths: PackedStringArray) -> Dictionary:
	var written := {}
	var read := {}
	var set_regex := _regex('(?:GameState\\.)?set_flag\\(\\s*["\\\']([^"\\\']+)["\\\']')
	var get_regex := _regex('(?:GameState\\.)?get_flag\\(\\s*["\\\']([^"\\\']+)["\\\']')
	for path: String in paths:
		var source := FileAccess.get_file_as_string(path)
		for result: RegExMatch in set_regex.search_all(source):
			written[result.get_string(1)] = true
		for result: RegExMatch in get_regex.search_all(source):
			read[result.get_string(1)] = true
	return _flag_access_result(written, read)


static func _collect_quest_results(
	metadata: Dictionary, dialogue_sources: Dictionary
) -> Array[Dictionary]:
	var quests_by_constant: Dictionary = metadata["by_constant"]
	var main_constants: Dictionary = metadata["main_constants"]
	var results_by_constant := {}
	for constant_name: String in quests_by_constant:
		var path := str(quests_by_constant[constant_name])
		var resource := load(path)
		if resource == null:
			continue
		var result := {
			"quest_id": path.get_file().get_basename(),
			"quest_name": str(resource.get("quest_name")),
			"constant": constant_name,
			"path": path,
			"kind": "main" if main_constants.has(constant_name) else "side",
			"resource": resource,
			"outcomes": [] as Array[Dictionary],
		}
		results_by_constant[constant_name] = result

	for constant_name: String in results_by_constant:
		var quest: Dictionary = results_by_constant[constant_name]
		var resource: Resource = quest["resource"]
		var resolution_flag := str(resource.get("resolution_flag"))
		var outcome_ids_value: Variant = resource.get("outcome_ids")
		if not resolution_flag.is_empty() and outcome_ids_value is PackedStringArray:
			quest["outcomes"] = _dom_side_outcomes(resource, resolution_flag)

	for path: String in dialogue_sources:
		_parse_dialogue_resolutions(path, dialogue_sources[path], results_by_constant)

	var results: Array[Dictionary] = []
	for value: Variant in results_by_constant.values():
		var quest: Dictionary = value
		quest.erase("resource")
		results.append(quest)
	results.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["quest_id"]) < str(right["quest_id"])
	)
	return results


static func _dom_side_outcomes(resource: Resource, resolution_flag: String) -> Array[Dictionary]:
	var outcomes: Array[Dictionary] = []
	var ids: PackedStringArray = resource.get("outcome_ids")
	var factions: PackedStringArray = resource.get("outcome_faction_ids")
	var deltas: PackedFloat32Array = resource.get("outcome_reputation_deltas")
	var causes: PackedStringArray = resource.get("outcome_causes")
	for index: int in ids.size():
		var faction := factions[index] if index < factions.size() else ""
		var delta := deltas[index] if index < deltas.size() else 0.0
		var cause := causes[index] if index < causes.size() else ""
		outcomes.append(
			{
				"id": ids[index],
				"state_writes": ["%s=%s" % [resolution_flag, ids[index]]],
				"ledger_events": ["%s:%s:%s" % [faction, delta, cause]],
				"readback_flag": resolution_flag,
				"read_back": false,
				"source": resource.resource_path,
				"line": 0,
			}
		)
	return outcomes


static func _parse_dialogue_resolutions(
	path: String, source: String, results_by_constant: Dictionary
) -> void:
	var lines := source.split("\n")
	var turn_in_regex := _regex(
		'QuestRegistry\\.turn_in\\(QuestRegistry\\.([A-Z0-9_]+),\\s*"([^"]+)",\\s*(true|false)'
	)
	var resolver_regex := _regex(
		'QuestRegistry\\.(resolve_broken_muster|resolve_field_debt)\\("([^"]+)"'
	)
	for line_index: int in lines.size():
		var line := lines[line_index]
		var turn_in := turn_in_regex.search(line)
		if turn_in != null:
			var constant_name := turn_in.get_string(1)
			if results_by_constant.has(constant_name):
				var quest: Dictionary = results_by_constant[constant_name]
				var outcomes: Array[Dictionary] = quest["outcomes"]
				outcomes.append(
					_direct_outcome(
						quest, turn_in.get_string(2), turn_in.get_string(3) == "true",
						path, line_index, lines
					)
				)
				continue
		var resolver := resolver_regex.search(line)
		if resolver == null:
			continue
		var resolver_name := resolver.get_string(1)
		var target_constant := "DORTHKOR_ROAD" if resolver_name == "resolve_broken_muster" else "FIELD_DEBT"
		if not results_by_constant.has(target_constant):
			continue
		var target: Dictionary = results_by_constant[target_constant]
		var target_outcomes: Array[Dictionary] = target["outcomes"]
		var flag := "chapter_one_resolution" if target_constant == "DORTHKOR_ROAD" else "field_debt_reward"
		target_outcomes.append(
			{
				"id": resolver.get_string(2),
				"state_writes": ["%s=%s" % [flag, resolver.get_string(2)]],
				"ledger_events": ["%s:ledger" % resolver_name],
				"readback_flag": flag,
				"read_back": false,
				"source": path,
				"line": line_index + 1,
			}
		)


static func _direct_outcome(
	quest: Dictionary,
	outcome_id: String,
	grant_default_reward: bool,
	path: String,
	line_index: int,
	lines: PackedStringArray
) -> Dictionary:
	var state_writes: Array[String] = []
	var ledger_events: Array[String] = []
	var readback_flag := ""
	var quest_id := int((quest["resource"] as Resource).get("id"))
	var item_id := str((quest["resource"] as Resource).get("item_id"))
	if not item_id.is_empty():
		readback_flag = "quest_%d_resolution" % quest_id
		state_writes.append("%s=%s" % [readback_flag, outcome_id])
		var reward_faction := str((quest["resource"] as Resource).get("reward_faction"))
		if grant_default_reward and not reward_faction.is_empty():
			ledger_events.append("fetch_default_reward:%s" % reward_faction)
	for index: int in range(line_index + 1, mini(lines.size(), line_index + 9)):
		var consequence_line := lines[index].strip_edges()
		if consequence_line.begins_with("-"):
			break
		if "Reputation.record(" in consequence_line or "Renown.gain_" in consequence_line:
			ledger_events.append(consequence_line)
		var flag_match := _regex('GameState\\.set_flag\\("([^"]+)",\\s*"([^"]+)"').search(
			consequence_line
		)
		if flag_match != null:
			readback_flag = flag_match.get_string(1)
			state_writes.append("%s=%s" % [readback_flag, flag_match.get_string(2)])
	return {
		"id": outcome_id,
		"state_writes": state_writes,
		"ledger_events": ledger_events,
		"readback_flag": readback_flag,
		"read_back": false,
		"source": path,
		"line": line_index + 1,
	}


static func _classify_readbacks(
	quest_results: Array[Dictionary], sources: Dictionary
) -> void:
	for quest: Dictionary in quest_results:
		var outcomes: Array[Dictionary] = quest["outcomes"]
		for outcome: Dictionary in outcomes:
			var flag := str(outcome.get("readback_flag", ""))
			var outcome_id := str(outcome.get("id", ""))
			var has_readback := false
			if not flag.is_empty():
				has_readback = _has_flag_readback(flag, outcome_id, sources)
			if not has_readback and outcomes.size() == 1:
				has_readback = _has_later_completion_readback(quest, outcome, sources)
			outcome["read_back"] = has_readback


static func _has_flag_readback(flag: String, outcome_id: String, sources: Dictionary) -> bool:
	var escaped_flag := flag.replace(".", "\\.")
	var escaped_outcome := outcome_id.replace("-", "\\-")
	var exact_regex := _regex(
		'get_flag\\("%s"[^\\n]*==\\s*"%s"' % [escaped_flag, escaped_outcome]
	)
	for source_value: Variant in sources.values():
		var source := str(source_value)
		if exact_regex.search(source) != null:
			return true
		if "FLAG_NON_EMPTY" in source and '"%s"' % flag in source:
			return true
		if 'get_flag("%s"' % flag in source and '"%s"' % outcome_id in source:
			return true
	return false


static func _has_later_completion_readback(
	quest: Dictionary, outcome: Dictionary, sources: Dictionary
) -> bool:
	var needle := "QuestRegistry.is_done(QuestRegistry.%s)" % str(quest.get("constant", ""))
	var origin_path := str(outcome.get("source", ""))
	var origin_line := int(outcome.get("line", 0))
	for path: String in sources:
		var source := str(sources[path])
		if path != origin_path and needle in source:
			return true
		if path == origin_path:
			var lines := source.split("\n")
			for index: int in range(maxi(origin_line, 0), lines.size()):
				if needle in lines[index]:
					return true
	return false


static func _project_flag_access(
	quest_results: Array[Dictionary], dialogue_sources: Dictionary, readback_sources: Dictionary
) -> Dictionary:
	var quest_flag_paths := PackedStringArray([REGISTRY_PATH, "res://quests/fetch_quest.gd"])
	quest_flag_paths.append_array(PackedStringArray(dialogue_sources.keys()))
	var access := scan_flag_sources(quest_flag_paths)
	var written := {}
	var read := {}
	for flag: String in access["written"]:
		written[flag] = true
	for flag: String in access["read"]:
		read[flag] = true
	for quest: Dictionary in quest_results:
		for outcome: Dictionary in quest["outcomes"]:
			for write_value: Variant in outcome.get("state_writes", []):
				var write := str(write_value)
				var separator := write.find("=")
				if separator > 0:
					written[write.left(separator)] = true
			if bool(outcome.get("read_back", false)):
				var readback_flag := str(outcome.get("readback_flag", ""))
				if not readback_flag.is_empty():
					read[readback_flag] = true

	# Encounter consequence maps write flags indirectly through Battle. Treat
	# authored `flags` keys as writes without executing or mutating game data.
	var pandora_source := FileAccess.get_file_as_string("res://data.pandora")
	var escaped_flag_regex := _regex('\\\\"([a-z][a-z0-9_]+)\\\\":\\\\"\\$')
	for result: RegExMatch in escaped_flag_regex.search_all(pandora_source):
		written[result.get_string(1)] = true

	# Non-dialogue consumers include fact requirements, prices, encounters, and
	# presence/presentation scripts. Literal flag references there count as reads.
	for source_value: Variant in readback_sources.values():
		var source := str(source_value)
		for flag_value: Variant in written.keys():
			var flag := str(flag_value)
			if _source_reads_flag(source, flag):
				read[flag] = true

	# A read whose name is authored in runtime data has a data-driven writer even
	# when the actual set_flag call receives the key through a variable.
	for flag_value: Variant in read.keys():
		var flag := str(flag_value)
		if not written.has(flag) and _has_authored_runtime_value(flag, readback_sources, pandora_source):
			written[flag] = true
	return _flag_access_result(written, read)


static func _source_reads_flag(source: String, flag: String) -> bool:
	if 'get_flag("%s"' % flag in source:
		return true
	if "FLAG_NON_EMPTY" in source and '"%s"' % flag in source:
		return true
	if "required_flags" in source and '"%s"' % flag in source:
		return true
	return false


static func _has_authored_runtime_value(
	flag: String, sources: Dictionary, pandora_source: String
) -> bool:
	if flag in pandora_source:
		return true
	var quoted := '"%s"' % flag
	var occurrences := 0
	for source_value: Variant in sources.values():
		occurrences += str(source_value).count(quoted)
		if occurrences > 1:
			return true
	return false


static func _quest_metadata(registry_source: String) -> Dictionary:
	var by_constant := {}
	var preload_regex := _regex(
		'const\\s+([A-Z0-9_]+)[^\\n]*preload\\("(res://quests/[^"]+\\.tres)"\\)'
	)
	for result: RegExMatch in preload_regex.search_all(registry_source):
		by_constant[result.get_string(1)] = result.get_string(2)
	var main_constants := {}
	var story_start := registry_source.find("const STORY_QUESTS")
	if story_start >= 0:
		# The declaration is `const STORY_QUESTS: Array[Quest] = [DEEP_TRIAL, ...]`,
		# so the first "]" after the name closes the TYPE HINT, not the array
		# literal. Anchor on the assignment before scanning for the closing
		# bracket, or every story quest is silently classified as a side quest.
		var array_open := registry_source.find("[", registry_source.find("=", story_start))
		var story_end := registry_source.find("]", array_open) if array_open >= 0 else -1
		if array_open < 0 or story_end < 0:
			push_warning("quest_audit: could not parse STORY_QUESTS array; main quests unclassified")
			return {"by_constant": by_constant, "main_constants": main_constants}
		var story_block := registry_source.substr(array_open, story_end - array_open + 1)
		for result: RegExMatch in _regex("[A-Z][A-Z0-9_]+").search_all(story_block):
			var name := result.get_string()
			if by_constant.has(name):
				main_constants[name] = true
	return {"by_constant": by_constant, "main_constants": main_constants}


static func _readback_sources(dialogue_sources: Dictionary) -> Dictionary:
	var sources := dialogue_sources.duplicate()
	for directory: String in ["res://globals", "res://ui", "res://world", "res://actors", QUEST_DIRECTORY]:
		var directory_sources := _source_files(directory, PackedStringArray(["gd", "tres", "tscn"]))
		for path: String in directory_sources:
			sources[path] = directory_sources[path]
	return sources


static func _source_files(directory: String, extensions: PackedStringArray) -> Dictionary:
	var sources := {}
	_collect_source_files(directory, extensions, sources)
	return sources


static func _collect_source_files(
	directory: String, extensions: PackedStringArray, sources: Dictionary
) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		var path := directory.path_join(entry)
		if dir.current_is_dir():
			_collect_source_files(path, extensions, sources)
		elif extensions.has(entry.get_extension().to_lower()):
			sources[path] = FileAccess.get_file_as_string(path)
		entry = dir.get_next()
	dir.list_dir_end()


static func _flag_access_result(written: Dictionary, read: Dictionary) -> Dictionary:
	var written_flags := PackedStringArray(written.keys())
	var read_flags := PackedStringArray(read.keys())
	written_flags.sort()
	read_flags.sort()
	var written_never_read := PackedStringArray()
	var read_never_written := PackedStringArray()
	for flag: String in written_flags:
		if not read.has(flag):
			written_never_read.append(flag)
	for flag: String in read_flags:
		if not written.has(flag):
			read_never_written.append(flag)
	return {
		"written": written_flags,
		"read": read_flags,
		"written_count": written_flags.size(),
		"read_count": read_flags.size(),
		"written_never_read": written_never_read,
		"read_never_written": read_never_written,
	}


static func _category() -> Dictionary:
	return {
		"count": 0,
		"severity": {"error": 0, "warning": 0, "info": 0},
		"findings": [] as Array[Dictionary],
	}


static func _add_finding(
	category: Dictionary, severity: String, code: String, details: Dictionary
) -> void:
	var finding := details.duplicate()
	finding["code"] = code
	finding["severity"] = severity
	(category["findings"] as Array[Dictionary]).append(finding)
	var split: Dictionary = category["severity"]
	split[severity] = int(split.get(severity, 0)) + 1


static func _resolution_identity(quest: Dictionary, outcome: Dictionary) -> Dictionary:
	return {
		"quest_id": quest.get("quest_id", ""),
		"quest_name": quest.get("quest_name", ""),
		"resolution_id": outcome.get("id", ""),
		"source": outcome.get("source", quest.get("path", "")),
		"line": outcome.get("line", 0),
	}


static func _typed_dictionaries(values: Variant) -> Array[Dictionary]:
	var typed: Array[Dictionary] = []
	if values is Array:
		for value: Variant in values:
			if value is Dictionary:
				typed.append(value)
	return typed


static func _sorted_strings(values: Variant) -> Array[String]:
	var strings: Array[String] = []
	if values is Array or values is PackedStringArray:
		for value: Variant in values:
			strings.append(str(value))
	strings.sort()
	return strings


static func _regex(expression: String) -> RegEx:
	var regex := RegEx.new()
	var error := regex.compile(expression)
	assert(error == OK, "Invalid quest audit regular expression: %s" % expression)
	return regex


static func _ratio(numerator: int, denominator: int) -> float:
	return 0.0 if denominator <= 0 else float(numerator) / float(denominator)
