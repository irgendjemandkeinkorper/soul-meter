class_name NpcReactions
extends RefCounted
## Read-only FR-504 flag/reputation reaction table for named NPCs.

const REACTION_CAP := 15

## npc_id -> ordered reaction rules. A rule may gate on a flag, reputation,
## or both, and may override presence and/or an existing dialogue route.
const REACTIONS: Dictionary = {
	"sella-varn": [
		{
			"flag": "dom_bellhouse_inspected",
			"flag_value": true,
			"reputation_faction": "dom",
			"minimum_reputation_band": &"neutral",
			"present": true,
			"dialogue_path": "res://dialogue/sella_varn.dialogue",
			"dialogue_title": "hub",
		},
	],
	"branek-coiljaw": [
		{
			"flag": "zhavar_tolling_wilds",
			"flag_value": true,
			"dialogue_path": "res://dialogue/marshal_coiljaw.dialogue",
			"dialogue_title": "hub",
		},
	],
}


static func has_reaction(npc_id: String) -> bool:
	return REACTIONS.has(npc_id)


static func rules_for(npc_id: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not REACTIONS.has(npc_id):
		return result
	for rule: Dictionary in REACTIONS[npc_id]:
		result.append(rule.duplicate(true))
	return result


static func resolve(npc_id: String) -> Dictionary:
	for rule: Dictionary in rules_for(npc_id):
		if _matches(rule):
			return rule
	return {}


static func rule_is_valid(rule: Dictionary) -> bool:
	var flag := str(rule.get("flag", ""))
	var faction := str(rule.get("reputation_faction", ""))
	var band := StringName(rule.get("minimum_reputation_band", &""))
	if flag.is_empty() and faction.is_empty():
		return false
	if faction.is_empty() != band.is_empty():
		return false
	if not band.is_empty() and not Reputation.BAND_RANK.has(band):
		return false
	if rule.has("present") and not rule["present"] is bool:
		return false
	var path := str(rule.get("dialogue_path", ""))
	var title := str(rule.get("dialogue_title", ""))
	if path.is_empty() != title.is_empty():
		return false
	return rule.has("present") or not path.is_empty()


static func reaction_count() -> int:
	return REACTIONS.size()


static func _matches(rule: Dictionary) -> bool:
	var flag := str(rule.get("flag", ""))
	if not flag.is_empty() and GameState.get_flag(flag, null) != rule.get("flag_value", true):
		return false
	var faction := str(rule.get("reputation_faction", ""))
	if faction.is_empty():
		return true
	# Reputation owns the band ordering. A local copy here could disagree with
	# doors and every other reputation consumer after a rebalance.
	var minimum := StringName(rule.get("minimum_reputation_band", &"neutral"))
	return Reputation.band_at_least(faction, minimum)
