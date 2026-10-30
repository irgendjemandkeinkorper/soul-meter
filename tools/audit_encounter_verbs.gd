extends SceneTree
## PRD §3: "combat encounters using ≥ 3 verbs (attack / cast / speech / position) ≥ 80%".
## The 2026-10-16 ship-readiness assessment marked that row UNMEASURED because nothing
## counted it. This counts it.
##
## Attack and cast are the party's verbs and every encounter admits them, so the row turns
## on what the ENCOUNTER authors: `speech_hooks` (speech), `context_actions` (the context
## verb the assessment counted alongside speech), and `zone_layout` (position: zones the
## fight is placed around). An encounter clears the PRD bar when it authors at least one.
## The report also prints the stricter "speech or context" count the assessment used, so
## both readings stay visible until the owner picks one (roadmap 2026-10-30, Phase 2).
##
## Run:  godot --headless --path . --script res://tools/audit_encounter_verbs.gd
## Judge the printed report, never the exit code (see CLAUDE.md on headless teardown).

const PRD_TARGET_SHARE := 0.8
const GIVEN_VERBS: PackedStringArray = ["attack", "cast"]
## Authored verb → encounter row key.
const AUTHORED_VERB_KEYS := {
	"speech": "speech_hooks",
	"context": "context_actions",
	"position": "zone_layout",
}


func _init() -> void:
	print(report(audit()))
	quit()


## One row per encounter: `id`, `verbs` (given plus authored), `authored` (the authored
## subset), `prd_pass` (≥ 3 verbs), `speech_or_context`.
static func audit() -> Dictionary:
	var rows: Array[Dictionary] = []
	var prd_passing := 0
	var speech_or_context := 0
	for id: StringName in EncounterCatalog.all_ids():
		var definition := EncounterCatalog.definition(id)
		var authored: PackedStringArray = []
		for verb: String in AUTHORED_VERB_KEYS:
			if _is_authored(definition.get(AUTHORED_VERB_KEYS[verb])):
				authored.append(verb)
		var verbs: PackedStringArray = GIVEN_VERBS.duplicate()
		verbs.append_array(authored)
		var row := {
			"id": String(id),
			"verbs": verbs,
			"authored": authored,
			"prd_pass": verbs.size() >= 3,
			"speech_or_context": authored.has("speech") or authored.has("context"),
		}
		if row["prd_pass"]:
			prd_passing += 1
		if row["speech_or_context"]:
			speech_or_context += 1
		rows.append(row)
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["id"] < b["id"])
	var total := rows.size()
	return {
		"rows": rows,
		"total": total,
		"prd_passing": prd_passing,
		"prd_share": float(prd_passing) / float(total) if total > 0 else 0.0,
		"speech_or_context": speech_or_context,
		"meets_target": total > 0 and float(prd_passing) / float(total) >= PRD_TARGET_SHARE,
	}


static func report(result: Dictionary) -> String:
	var lines := PackedStringArray(["encounter verb audit (PRD §3)", ""])
	for row: Dictionary in result["rows"]:
		var authored: PackedStringArray = row["authored"]
		lines.append(
			"%-28s %-4s  verbs %d  authored: %s"
			% [
				row["id"],
				"PASS" if row["prd_pass"] else "FAIL",
				(row["verbs"] as PackedStringArray).size(),
				", ".join(authored) if not authored.is_empty() else "-",
			]
		)
	lines.append("")
	lines.append(
		"≥ 3 verbs (attack + cast given): %d / %d = %d%%  (PRD target ≥ %d%%) — %s"
		% [
			result["prd_passing"],
			result["total"],
			roundi(float(result["prd_share"]) * 100.0),
			roundi(PRD_TARGET_SHARE * 100.0),
			"MET" if result["meets_target"] else "NOT MET",
		]
	)
	lines.append(
		"speech or context verb authored: %d / %d"
		% [result["speech_or_context"], result["total"]]
	)
	return "\n".join(lines)


static func _is_authored(value: Variant) -> bool:
	if value is Array:
		return not (value as Array).is_empty()
	if value is Dictionary:
		return not (value as Dictionary).is_empty()
	if value is String:
		return not (value as String).is_empty()
	return false
