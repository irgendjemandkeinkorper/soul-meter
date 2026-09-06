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
## 4. Skill-check route detection is indentation- and token-based. It rejects
##    obvious checked, completed, final-resolution, and prerequisite-gated
##    alternatives, but cannot prove that every runtime state can reach a route.
##
## Because of 1 and 2 this tool is a debt-finder, not a proof of compliance.
## FR-906's human playtest pass remains the check on whether consequences are
## meaningful; this only checks that they are wired.

const SCHEMA := "soul_meter.quest_audit.v1"
const STRICT_ENV := "SOUL_METER_QUEST_AUDIT_STRICT"
const REGISTRY_PATH := "res://globals/quest_registry.gd"
const QUEST_DIRECTORY := "res://quests"
const DIALOGUE_DIRECTORY := "res://dialogue"
## Keep the standalone SceneTree entrypoint free of autoload-dependent gameplay classes.
const ACT_OF_AGREEMENT_TAG := "act_of_agreement"
## Template conformance (docs/templates/*.md) scans every LocationDefinition here.
const LOCATION_DIRECTORY := "res://world/locations"
const SIDE_READBACK_THRESHOLD := 0.6

## Flag grammar: <domain>_<subject>_<predicate>, lower snake case.
##
## Underscores, not dots. Every shipped flag is already underscore-separated and
## is written into save files, quest `.tres` resources, `data.pandora` and scene
## files. A shipped flag id is permanent: renaming one is a save migration, not
## an edit. The grammar therefore describes what the content already does.
##
## A domain must appear here before content may use it. That is the whole point:
## the check catches a typo (`dom_` against `domm_`) and a missing namespace,
## both of which currently fail silently.
const FLAG_DOMAINS := [
	"chapter",
	"deep_trial",
	"dom",
	"dorthkor",
	"encounter",
	"field_debt",
	"party",
	"soul",
	"tutorial",
	"undertakers",
	"zhavar",
]

## Flags that predate the grammar. Each one ships in saves already, so it is
## grandfathered rather than renamed. Do NOT add to this list to silence a new
## flag: a new flag has no save to protect, so it must satisfy the grammar.
const LEGACY_FLAGS := {
	"defeated_bog_wight": "verb-first; encounter defeat flags predate the domain rule",
	"defeated_breach_hound": "verb-first; encounter defeat flags predate the domain rule",
	"defeated_mustered_dead": "verb-first; encounter defeat flags predate the domain rule",
	"prototype_extended_content": "build toggle, not quest state; no domain applies",
	"reached": "chapter-stage shorthand written by seed tooling",
	"read_only": "audit self-test fixture name",
	"reported_bloodbellow": "predates the domain rule; ships in Chapter One saves",
	"safe_flag": "audit self-test fixture name",
	"write_only": "audit self-test fixture name",
	"written_and_read": "audit self-test fixture name",
}

## Directories scanned for the grammar check.
##
## SCOPE, stated because it is not self-evident: this is deliberately a WIDER
## scan than the orphan check, which only reads the quest registry and the
## dialogue files. Grammar findings are reported in their own category and never
## feed the orphan metrics, so widening the scan here cannot move the existing
## numbers. `test/` is excluded: test fixtures use throwaway names on purpose.
const GRAMMAR_SCAN_DIRECTORIES := [
	"res://actors",
	"res://dialogue",
	"res://globals",
	"res://quests",
	"res://ui",
	"res://world",
]

const GRAMMAR_SCAN_EXTENSIONS := ["gd", "dialogue"]


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
	var read_back_coverage := _build_read_back_coverage(quest_results, readback_sources, dialogue_sources)
	var flag_access := _project_flag_access(quest_results, dialogue_sources, readback_sources)
	return build_report(
		quest_results,
		flag_access,
		strict,
		scan_grammar_flags(),
		quest_critical_npc_ids(),
		dialogue_sources,
		template_conformance_violations(
			_source_files(QUEST_DIRECTORY, PackedStringArray(["tres"])),
			_source_files(LOCATION_DIRECTORY, PackedStringArray(["tres"]))
		),
		read_back_coverage
	)


static func build_report(
	quest_results: Array[Dictionary],
	flag_access: Dictionary,
	strict: bool,
	grammar_flags: PackedStringArray = PackedStringArray(),
	quest_critical_ids: PackedStringArray = PackedStringArray(),
	dialogue_sources: Dictionary = {},
	template_violations: Array[Dictionary] = [],
	read_back_coverage: Array[Dictionary] = []
) -> Dictionary:
	if read_back_coverage.is_empty() and not quest_results.is_empty():
		var readback_sources := _readback_sources(dialogue_sources)
		read_back_coverage = _build_read_back_coverage(quest_results, readback_sources, dialogue_sources)
	var categories := {
		"outcome_count": _category(),
		"resolution_writes": _category(),
		"readbacks": _category(),
		"orphaned_flags": _category(),
		"flag_grammar": _category(),
		"phase_reachability": _category(),
		"check_softlocks": _category(),
		"template_conformance": _category(),
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

	var grammar_violations := flag_grammar_violations(grammar_flags)
	for violation: Dictionary in grammar_violations:
		_add_finding(
			categories["flag_grammar"],
			"warning",
			"flag_violates_grammar",
			violation
		)

	var reachability_violations := phase_reachability_violations(quest_critical_ids)
	for violation: Dictionary in reachability_violations:
		_add_finding(
			categories["phase_reachability"],
			"error",
			"quest_critical_npc_reachable_in_fewer_than_two_phases",
			violation
		)

	var check_findings := check_softlock_violations(dialogue_sources)
	for finding: Dictionary in check_findings:
		var details := finding.duplicate()
		var finding_severity := str(details.get("severity", "error"))
		var finding_code := str(details.get("code", "invalid_checked_response"))
		details.erase("severity")
		details.erase("code")
		_add_finding(categories["check_softlocks"], finding_severity, finding_code, details)
	var template_error_count := 0
	for violation: Dictionary in template_violations:
		var details := violation.duplicate()
		var violation_severity := str(details.get("severity", "warning"))
		var violation_code := str(details.get("code", "template_field_missing"))
		details.erase("severity")
		details.erase("code")
		if violation_severity == "error":
			template_error_count += 1
		_add_finding(categories["template_conformance"], violation_severity, violation_code, details)
	var routined_critical_count := 0
	for npc_id: String in quest_critical_ids:
		if NpcRoutines.has_routine(npc_id):
			routined_critical_count += 1

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
			"flag_grammar": {
				"scanned": grammar_flags.size(),
				"violations": grammar_violations.size(),
				"grandfathered": LEGACY_FLAGS.size(),
				"registered_domains": PackedStringArray(FLAG_DOMAINS),
				"passes": grammar_violations.is_empty(),
			},
			"phase_reachability": {
				"quest_critical_npcs": quest_critical_ids.size(),
				"routined": routined_critical_count,
				"required_phases": 2,
				"violations": reachability_violations.size(),
				"passes": reachability_violations.is_empty(),
			},
			"template_conformance": {
				"violations": template_violations.size(),
				"errors": template_error_count,
				"passes": template_error_count == 0,
			},
		},
		"categories": categories,
		"read_back_coverage": read_back_coverage,
	}


## Split a flag into <domain>_[<subject>_]<predicate>, or return an empty
## dictionary when no registered domain matches.
##
## The subject is OPTIONAL, because shipped content uses both shapes and neither
## is wrong: `dom_dishonest_casks_resolution` names a subject, `field_debt_open`
## does not need one. Requiring a subject would have made four shipped flags
## violations, and the only honest fix for a shipped flag is a save migration.
##
## Domains are matched longest-first so that `deep_trial` wins over a shorter
## domain that happens to prefix it.
static func split_flag(flag: String) -> Dictionary:
	var sorted := FLAG_DOMAINS.duplicate()
	sorted.sort_custom(func(a: String, b: String) -> bool: return a.length() > b.length())
	for domain_value: Variant in sorted:
		var domain := str(domain_value)
		if not flag.begins_with(domain + "_"):
			continue
		var remainder := flag.substr(domain.length() + 1)
		if remainder.is_empty():
			return {}
		var separator := remainder.rfind("_")
		if separator <= 0 or separator >= remainder.length() - 1:
			return {"domain": domain, "subject": "", "predicate": remainder}
		return {
			"domain": domain,
			"subject": remainder.left(separator),
			"predicate": remainder.substr(separator + 1),
		}
	return {}


## Report every flag that does not satisfy the grammar and is not grandfathered.
##
## Returns findings-shaped dictionaries so the caller can add them directly.
static func flag_grammar_violations(flags: PackedStringArray) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var seen := {}
	for flag: String in flags:
		if seen.has(flag):
			continue
		seen[flag] = true
		if LEGACY_FLAGS.has(flag):
			continue
		# Limitation 2 in the header: a flag built by format string is captured
		# as its unsubstituted template. Reporting `quest_%d_resolution` as a
		# grammar violation would be blaming content for a scanner artifact.
		if flag.contains("%"):
			continue
		if flag != flag.to_lower() or flag.contains("."):
			violations.append(
				{
					"flag": flag,
					"reason": "flag must be lower snake case with underscores, not dots",
				}
			)
			continue
		var parts := split_flag(flag)
		if parts.is_empty():
			violations.append(
				{
					"flag": flag,
					"reason": (
						"expected <domain>_<subject>_<predicate> with a registered domain; "
						+ "registered domains are %s" % ", ".join(PackedStringArray(FLAG_DOMAINS))
					),
				}
			)
	violations.sort_custom(
		func(a: Dictionary, b: Dictionary) -> bool: return str(a["flag"]) < str(b["flag"])
	)
	return violations


## Collect every flag literal in GRAMMAR_SCAN_DIRECTORIES for the grammar check.
static func scan_grammar_flags() -> PackedStringArray:
	var paths := PackedStringArray()
	for directory_value: Variant in GRAMMAR_SCAN_DIRECTORIES:
		var directory := str(directory_value)
		paths.append_array(
			PackedStringArray(_source_files(directory, PackedStringArray(GRAMMAR_SCAN_EXTENSIONS)).keys())
		)
	var access := scan_flag_sources(paths)
	var flags := {}
	for flag: String in access["written"]:
		flags[flag] = true
	for flag: String in access["read"]:
		flags[flag] = true
	var result := PackedStringArray(flags.keys())
	result.sort()
	return result


## FR-905 §3.4 (docs/prd-amendment-living-world.md): the quest-critical NPC surface —
## every authored side-quest giver (`giver_actor_id` in quests/*.tres) plus every NPC
## whose own dialogue file calls `QuestRegistry.offer(` (dialogue stems are the npc id
## in snake case, e.g. sella_varn.dialogue → sella-varn).
##
## The stem→id mapping is a heuristic with the same fail-safe shape as limitation 1:
## a wrong or unmapped id has no routine, so it counts as phase-agnostic and passes.
## Only NPCs that DO carry an NpcRoutines row can violate, and those come from a
## hand-authored table — a routined giver missed here means the offer lives in a
## dialogue file not named after the giver, which is itself worth noticing.
static func quest_critical_npc_ids() -> PackedStringArray:
	var ids := {}
	var giver_regex := _regex('giver_actor_id\\s*=\\s*"([^"]+)"')
	for source: Variant in _source_files(QUEST_DIRECTORY, PackedStringArray(["tres"])).values():
		for giver_match: RegExMatch in giver_regex.search_all(str(source)):
			ids[giver_match.get_string(1)] = true
	var dialogue_sources := _source_files(DIALOGUE_DIRECTORY, PackedStringArray(["dialogue"]))
	for path: String in dialogue_sources:
		if str(dialogue_sources[path]).contains("QuestRegistry.offer("):
			ids[path.get_file().get_basename().replace("_", "-")] = true
	var result := PackedStringArray(ids.keys())
	result.sort()
	return result


## The FR-905 soft-lock check: a quest-critical NPC with a world-clock routine must be
## present (interactable) in at least two phases. NPCs without a routine are
## phase-agnostic by design (FR-504a item 4) and always reachable.
static func phase_reachability_violations(npc_ids: PackedStringArray) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	for npc_id: String in npc_ids:
		if not NpcRoutines.has_routine(npc_id):
			continue
		var present := NpcRoutines.present_phase_count(npc_id)
		if present < 2:
			violations.append(
				{
					"npc_id": npc_id,
					"present_phases": present,
					"required_phases": 2,
				}
			)
	return violations


static func scan_flag_sources(paths: PackedStringArray) -> Dictionary:
	var written := {}
	var read := {}
	var set_regex := _regex('(?:GameState\\.)?set_flag\\(\\s*["\\\']([^"\\\']+)["\\\']')
	var get_regex := _regex('(?:GameState\\.)?get_flag\\(\\s*["\\\']([^"\\\']+)["\\\']')
	# resolve_companion_quest() writes its completion flag through a variable
	# looked up in COMPANION_QUEST_COMPLETION_FLAGS, which the literal-only
	# set_flag regex cannot see (limitation 2 above). Count that dict's values
	# as write-sites so the six party flags don't surface as orphans.
	var completion_dict_regex := _regex(
		'COMPANION_QUEST_COMPLETION_FLAGS\\s*:?=\\s*\\{([^}]*)\\}'
	)
	var dict_value_regex := _regex('["\\\'][^"\\\']+["\\\']\\s*:\\s*["\\\']([^"\\\']+)["\\\']')
	# SaveGame.raise_zhavar() writes its tolling flag through a format string
	# ("zhavar_tolling_%s" % zone_id), invisible to the literal-only set_flag
	# regex (same limitation class as the companion dict above). Count a
	# format-string write-site as writing every READ flag that matches its
	# prefix, so per-zone flags don't surface as orphans while an unread typo
	# still would.
	var format_set_regex := _regex('(?:GameState\\.)?set_flag\\(\\s*["\\\']([^"\\\']+)%s["\\\']')
	var written_prefixes := {}
	for path: String in paths:
		var source := FileAccess.get_file_as_string(path)
		for result: RegExMatch in set_regex.search_all(source):
			# A "%s" literal is a format-string site; the prefix rule below owns it.
			if "%s" in result.get_string(1):
				continue
			written[result.get_string(1)] = true
		for result: RegExMatch in get_regex.search_all(source):
			read[result.get_string(1)] = true
		for result: RegExMatch in format_set_regex.search_all(source):
			written_prefixes[result.get_string(1)] = true
		var dict_match := completion_dict_regex.search(source)
		if dict_match != null:
			for result: RegExMatch in dict_value_regex.search_all(dict_match.get_string(1)):
				written[result.get_string(1)] = true
	for flag: String in read:
		for prefix: String in written_prefixes:
			if flag.begins_with(prefix):
				written[flag] = true
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
	var tags: Array[PackedStringArray] = resource.get("outcome_tags")
	var soul_deltas: PackedFloat32Array = resource.get("outcome_soul_deltas")
	for index: int in ids.size():
		var faction := factions[index] if index < factions.size() else ""
		var delta := deltas[index] if index < deltas.size() else 0.0
		var cause := causes[index] if index < causes.size() else ""
		var ledger_events := ["%s:%s:%s" % [faction, delta, cause]]
		if (
			index < tags.size()
			and tags[index].has(ACT_OF_AGREEMENT_TAG)
			and index < soul_deltas.size()
		):
			ledger_events.append(
				"soul:%s:%s" % [soul_deltas[index], ACT_OF_AGREEMENT_TAG]
			)
		outcomes.append(
			{
				"id": ids[index],
				"state_writes": ["%s=%s" % [resolution_flag, ids[index]]],
				"ledger_events": ledger_events,
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


static func _build_read_back_coverage(
	quest_results: Array[Dictionary], sources: Dictionary, dialogue_sources: Dictionary
) -> Array[Dictionary]:
	var coverage: Array[Dictionary] = []
	var reaction_flag_map := _npc_reaction_flags(sources)
	for quest: Dictionary in quest_results:
		var quest_id := str(quest.get("quest_id", ""))
		var quest_name := str(quest.get("quest_name", ""))
		var kind := str(quest.get("kind", "side"))
		var outcomes: Array[Dictionary] = _typed_dictionaries(quest.get("outcomes", []))

		var written_flags_map := {}
		var outcomes_summary: Array[Dictionary] = []
		for outcome: Dictionary in outcomes:
			outcomes_summary.append({
				"id": str(outcome.get("id", "")),
				"read_back": bool(outcome.get("read_back", false)),
				"readback_flag": str(outcome.get("readback_flag", "")),
				"state_writes": _sorted_strings(outcome.get("state_writes", [])),
			})
			for write_val: Variant in outcome.get("state_writes", []):
				var write := str(write_val)
				var sep := write.find("=")
				var flag_name := write.left(sep) if sep > 0 else write
				if not flag_name.is_empty():
					written_flags_map[flag_name] = true
			var readback_flag := str(outcome.get("readback_flag", ""))
			if not readback_flag.is_empty():
				written_flags_map[readback_flag] = true

		var flags_written := PackedStringArray(written_flags_map.keys())
		flags_written.sort()

		var read_backs: Array[Dictionary] = []
		for flag: String in flags_written:
			read_backs.append(
				_find_flag_locations(flag, quest, outcomes, sources, dialogue_sources, reaction_flag_map)
			)

		coverage.append({
			"quest_id": quest_id,
			"quest_name": quest_name,
			"kind": kind,
			"outcomes": outcomes_summary,
			"flags_written": flags_written,
			"read_backs": read_backs,
		})
	return coverage


static func _npc_reaction_flags(sources: Dictionary = {}) -> Dictionary:
	var map := {}
	var source := ""
	if sources.has("res://globals/npc_reactions.gd"):
		source = str(sources["res://globals/npc_reactions.gd"])
	else:
		source = FileAccess.get_file_as_string("res://globals/npc_reactions.gd")
	if source.is_empty():
		return map
	var lines := source.split("\n")
	var current_npc := ""
	var npc_header_regex := _regex('"([a-z0-9_-]+)"\\s*:\\s*\\[')
	var flag_regex := _regex('"flag"\\s*:\\s*"([^"]+)"')
	for line in lines:
		var npc_match := npc_header_regex.search(line)
		if npc_match != null:
			current_npc = npc_match.get_string(1)
		if line.strip_edges().begins_with("],"):
			current_npc = ""
			continue
		if not current_npc.is_empty():
			var flag_match := flag_regex.search(line)
			if flag_match != null:
				var flag := flag_match.get_string(1)
				if not map.has(flag):
					map[flag] = [] as Array[String]
				var list: Array[String] = map[flag]
				var label := "NpcReactions:%s" % current_npc
				if not list.has(label):
					list.append(label)
				map[flag] = list
	return map


static func _find_flag_locations(
	flag: String,
	quest: Dictionary,
	outcomes: Array[Dictionary],
	sources: Dictionary,
	dialogue_sources: Dictionary,
	reaction_flag_map: Dictionary = {}
) -> Dictionary:
	var dialogue_conditions := PackedStringArray()
	var reaction_rows := PackedStringArray()
	var encounter_gates := PackedStringArray()
	var other_locations := PackedStringArray()

	if reaction_flag_map.has(flag):
		for label_value: Variant in reaction_flag_map[flag]:
			var label := str(label_value)
			if not (label in reaction_rows):
				reaction_rows.append(label)

	var escaped_flag := flag.replace(".", "\\.")
	var flag_read_regex := _regex('get_flag\\("%s"' % escaped_flag)

	for path: String in sources:
		var source := str(sources[path])
		if source.is_empty():
			continue

		var is_dialogue := dialogue_sources.has(path)
		var is_encounter := (
			path.contains("encounter")
			or path.contains("data.pandora")
			or path.begins_with("res://world/")
			or path.begins_with("res://actors/")
			or path.begins_with("res://quests/")
		)

		var lines := source.split("\n")
		var needle := "QuestRegistry.is_done(QuestRegistry.%s)" % str(quest.get("constant", ""))
		var check_is_done := outcomes.size() == 1 and not needle.is_empty() and needle in source

		for line_index in lines.size():
			var line := lines[line_index]
			var line_num := line_index + 1
			var matches_flag := false

			if flag_read_regex.search(line) != null:
				matches_flag = true
			elif "FLAG_NON_EMPTY" in line and '"%s"' % flag in line:
				matches_flag = true
			elif "required_flags" in line and '"%s"' % flag in line:
				matches_flag = true
			elif check_is_done and needle in line:
				matches_flag = true

			if matches_flag:
				var location := "%s:%d" % [path, line_num]
				if is_dialogue:
					if not (location in dialogue_conditions):
						dialogue_conditions.append(location)
				elif is_encounter:
					if not (location in encounter_gates):
						encounter_gates.append(location)
				else:
					if not (location in other_locations):
						other_locations.append(location)

	dialogue_conditions.sort()
	reaction_rows.sort()
	encounter_gates.sort()
	other_locations.sort()

	var is_read := (
		not dialogue_conditions.is_empty()
		or not reaction_rows.is_empty()
		or not encounter_gates.is_empty()
		or not other_locations.is_empty()
	)

	return {
		"flag": flag,
		"read_back": is_read,
		"dialogue_conditions": dialogue_conditions,
		"reaction_rows": reaction_rows,
		"encounter_gates": encounter_gates,
		"other_locations": other_locations,
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
	# save_game.gd carries the FR-308 raise_zhavar() write-site (a format-string
	# set_flag the prefix rule in scan_flag_sources resolves against reads).
	var quest_flag_paths := PackedStringArray(
		[REGISTRY_PATH, "res://quests/fetch_quest.gd", "res://globals/save_game.gd"]
	)
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


## Template conformance (docs/templates/location.md, side-quest.md).
##
## Text-level checks over authored `.tres` sources so a worker's handoff can be
## screened before anyone loads the resource. Both arguments are
## {path: source text} maps (see _source_files), which keeps the checks
## testable from a string and free of ResourceLoader side effects.
##
## Severity: a structural break (a scene that does not exist, a default spawn
## that no alias resolves) is an "error"; a missing authoring field is a
## "warning". Reporting mode never fails on either; STRICT fails on both, like
## every other category.
##
## Limitations: fields are matched at line start (`quest_name = "..."`), which
## is how Godot serializes them; a hand-edited resource with unusual whitespace
## is reported as missing, not silently accepted. `objectives` is only required
## of FlagQuest-derived resources (FetchQuest has none). A quest giver is
## satisfied by either `quest_giver` (FlagQuest) or `giver_actor_id`
## (DomSideQuest) — the two shipped conventions.
static func template_conformance_violations(
	quest_sources: Dictionary, location_sources: Dictionary
) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var class_regex := _regex('script_class="([A-Za-z0-9_]+)"')
	var quest_paths: Array = quest_sources.keys()
	quest_paths.sort()
	for path_value: Variant in quest_paths:
		var path := str(path_value)
		var source := str(quest_sources[path])
		var class_match := class_regex.search(source)
		if class_match == null:
			continue
		var script_class := class_match.get_string(1)
		if _tres_string_field(source, "quest_name").is_empty():
			violations.append(_template_violation(path, "warning", "quest_missing_name", {
				"field": "quest_name", "script_class": script_class,
			}))
		if (
			_tres_string_field(source, "quest_giver").is_empty()
			and _tres_string_field(source, "giver_actor_id").is_empty()
		):
			violations.append(_template_violation(path, "warning", "quest_missing_giver", {
				"field": "quest_giver|giver_actor_id", "script_class": script_class,
			}))
		var requires_objectives := script_class == "FlagQuest" or script_class == "DomSideQuest"
		if requires_objectives and _tres_packed_strings(source, "objectives").is_empty():
			violations.append(_template_violation(path, "warning", "quest_missing_objectives", {
				"field": "objectives", "script_class": script_class,
			}))

	var location_paths: Array = location_sources.keys()
	location_paths.sort()
	for path_value: Variant in location_paths:
		var path := str(path_value)
		var source := str(location_sources[path])
		if not source.contains('script_class="LocationDefinition"'):
			continue
		var scene_path := _tres_string_field(source, "scene_path")
		if scene_path.is_empty() or not FileAccess.file_exists(scene_path):
			violations.append(_template_violation(path, "error", "location_scene_missing", {
				"field": "scene_path", "scene_path": scene_path,
			}))
		var arrival_flag := _tres_string_field(source, "arrival_flag")
		if not arrival_flag.is_empty():
			var grammar := flag_grammar_violations(PackedStringArray([arrival_flag]))
			if not grammar.is_empty():
				violations.append(_template_violation(path, "warning", "location_arrival_flag_grammar", {
					"field": "arrival_flag",
					"flag": arrival_flag,
					"reason": str(grammar[0].get("reason", "")),
				}))
		var default_spawn := _tres_string_name_field(source, "default_spawn_id")
		if default_spawn.is_empty():
			default_spawn = "default"
		if default_spawn != "default":
			var aliases := _tres_dictionary_keys(source, "spawns")
			if not aliases.has(default_spawn):
				violations.append(_template_violation(path, "error", "location_default_spawn_unaliased", {
					"field": "default_spawn_id",
					"default_spawn_id": default_spawn,
					"spawns": aliases,
				}))
	return violations


static func _template_violation(
	path: String, severity: String, code: String, details: Dictionary
) -> Dictionary:
	var violation := details.duplicate()
	violation["path"] = path
	violation["severity"] = severity
	violation["code"] = code
	return violation


## `field = "value"` at line start; empty when absent or empty.
static func _tres_string_field(source: String, field: String) -> String:
	var found := _regex('(?m)^%s\\s*=\\s*"([^"]*)"' % field).search(source)
	return "" if found == null else found.get_string(1).strip_edges()


## `field = &"value"` at line start.
static func _tres_string_name_field(source: String, field: String) -> String:
	var found := _regex('(?m)^%s\\s*=\\s*&"([^"]*)"' % field).search(source)
	return "" if found == null else found.get_string(1).strip_edges()


## `field = PackedStringArray("a", "b")` at line start → ["a", "b"].
static func _tres_packed_strings(source: String, field: String) -> PackedStringArray:
	var result := PackedStringArray()
	var found := _regex('(?m)^%s\\s*=\\s*PackedStringArray\\(([^)]*)\\)' % field).search(source)
	if found == null:
		return result
	for item: RegExMatch in _regex('"([^"]*)"').search_all(found.get_string(1)):
		var value := item.get_string(1).strip_edges()
		if not value.is_empty():
			result.append(value)
	return result


## Keys of `field = { "k": "v", ... }` (Godot's multi-line Dictionary form).
static func _tres_dictionary_keys(source: String, field: String) -> PackedStringArray:
	var keys := PackedStringArray()
	var found := _regex('(?ms)^%s\\s*=\\s*\\{(.*?)^\\}' % field).search(source)
	if found == null:
		return keys
	for item: RegExMatch in _regex('(?m)^\\s*"([^"]+)"\\s*:').search_all(found.get_string(1)):
		keys.append(item.get_string(1))
	return keys


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


## Heuristic dialogue audit for build-gated checks. Conditions are identified on
## response lines, then the response's indented branch is inspected. The quest
## constant cross-reference rejects checked, completed, final-resolution, and
## prerequisite-gated responses, but remains a heuristic and only emits a warning.
static func check_softlock_violations(dialogue_sources: Dictionary) -> Array[Dictionary]:
	var findings: Array[Dictionary] = []
	for path: String in dialogue_sources:
		var source := str(dialogue_sources[path])
		var lines := source.split("\n")
		var line_index := 0
		while line_index < lines.size():
			var response_line := str(lines[line_index])
			var stripped := response_line.strip_edges()
			if not stripped.begins_with("- ") or "[if " not in response_line or "check(" not in response_line:
				line_index += 1
				continue

			var response_indent := _leading_indent(response_line)
			var branch_end := _response_branch_end(lines, line_index, response_indent)
			var branch_lines := PackedStringArray()
			for branch_index in range(line_index + 1, branch_end):
				branch_lines.append(str(lines[branch_index]))
			var branch := "\n".join(branch_lines)
			var identity := {
				"source": path,
				"line": line_index + 1,
				"response": stripped,
			}

			if "SkillCheck.resolve(" not in branch:
				var missing_resolve := identity.duplicate()
				missing_resolve["code"] = "checked_response_missing_resolve"
				missing_resolve["severity"] = "error"
				findings.append(missing_resolve)

			var success_line := -1
			var success_indent := -1
			var else_line := -1
			for branch_index in branch_lines.size():
				var branch_stripped := branch_lines[branch_index].strip_edges()
				if "last_check_succeeded()" in branch_stripped:
					success_line = branch_index
					success_indent = _leading_indent(branch_lines[branch_index])
				elif (
					success_line >= 0
					and branch_stripped == "else"
					and _leading_indent(branch_lines[branch_index]) == success_indent
				):
					# Indentation must match the check's if-line: a nested else
					# inside the success branch is not the failure branch.
					else_line = branch_index
					break
			var has_success_continuation := success_line >= 0 and else_line > success_line
			if has_success_continuation:
				has_success_continuation = _has_check_continuation(
					branch_lines, success_line + 1, else_line
				)
			var has_failure_continuation := else_line >= 0
			if has_failure_continuation:
				has_failure_continuation = _has_check_continuation(
					branch_lines, else_line + 1, branch_lines.size()
				)
			if not has_success_continuation or not has_failure_continuation:
				var missing_outcomes := identity.duplicate()
				missing_outcomes["code"] = "checked_response_missing_outcomes"
				missing_outcomes["severity"] = "error"
				missing_outcomes["has_success_continuation"] = has_success_continuation
				missing_outcomes["has_failure_continuation"] = has_failure_continuation
				findings.append(missing_outcomes)

			var quest_match := _regex("QuestRegistry\\.([A-Z][A-Z0-9_]*)").search(response_line)
			var quest_constant := quest_match.get_string(1) if quest_match != null else ""
			if quest_constant.is_empty() or not _has_alternate_quest_response(
				lines, line_index, branch_end, quest_constant
			):
				var possible_softlock := identity.duplicate()
				possible_softlock["code"] = "checked_response_may_be_only_acquisition_route"
				possible_softlock["severity"] = "warning"
				possible_softlock["quest_constant"] = quest_constant
				findings.append(possible_softlock)

			line_index = branch_end
	return findings


static func _has_check_continuation(lines: PackedStringArray, start: int, end: int) -> bool:
	for line_index in range(start, end):
		var stripped := lines[line_index].strip_edges()
		if stripped.begins_with("=>") and stripped != "=> END":
			return true
		if stripped.begins_with("do GameState.set_flag("):
			return true
		if stripped.begins_with("do QuestRegistry."):
			return true
	return false


static func _has_alternate_quest_response(
	lines: PackedStringArray, checked_start: int, checked_end: int, quest_constant: String
) -> bool:
	var needle := "QuestRegistry.%s" % quest_constant
	for line_index in lines.size():
		if line_index >= checked_start and line_index < checked_end:
			continue
		var line := lines[line_index]
		if not line.strip_edges().begins_with("- ") or needle not in line:
			continue
		if "check(" in line:
			continue
		if "not QuestRegistry.is_active(%s)" % needle in line:
			continue
		if "QuestRegistry.is_done(%s)" % needle in line:
			continue
		if "QuestRegistry.flags_met(%s)" % needle in line:
			continue
		var response_end := _response_branch_end(lines, line_index, _leading_indent(line))
		var branch := "\n".join(lines.slice(line_index + 1, response_end))
		if "QuestRegistry.resolve_side_quest(" in branch:
			continue
		if _has_check_continuation(lines, line_index + 1, response_end):
			return true
	return false


static func _response_branch_end(
	lines: PackedStringArray, response_index: int, response_indent: int
) -> int:
	var line_index := response_index + 1
	while line_index < lines.size():
		var line := lines[line_index]
		var stripped := line.strip_edges()
		if stripped.begins_with("~ "):
			break
		if stripped.begins_with("- ") and _leading_indent(line) <= response_indent:
			break
		line_index += 1
	return line_index


static func _leading_indent(line: String) -> int:
	return line.length() - line.lstrip(" \t").length()


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
