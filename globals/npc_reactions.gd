class_name NpcReactions
extends RefCounted
## Read-only FR-504 flag/reputation reaction table for named NPCs.

const REACTION_CAP := 15

## The hand-authored home for FR-402 band routes. Kept out of
## `dialogue/dom_townsfolk.dialogue`, which `tools/generate_gloot.gd` owns.
const BAND_REACTION_DIALOGUE := "res://dialogue/dom_band_reactions.dialogue"

## FR-308 rumor routes: what Dom says about a zone it can hear getting louder.
const ZHAVAR_RUMOR_DIALOGUE := "res://dialogue/dom_zhavar_rumors.dialogue"

## npc_id -> ordered reaction rules. A rule may gate on a flag, reputation, the
## protagonist's hollowing state, or any combination, and may override presence
## and/or an existing dialogue route.
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
	# #286, the NPC-read surface. The registry clerk does not ask how you are;
	# he annotates. Ordered FIRST so a hollowed witness is read as hollowed
	# before any flag- or band-gated route gets a look — a hollowing outranks
	# whatever errand brought you to the desk.
	"hadrik-vale": [
		{
			"hollowing": true,
			"dialogue_path": "res://dialogue/hadrik_vale.dialogue",
			"dialogue_title": "hollowed",
		},
	],
	# FR-402 / #257 band-gated reactions. Each of these five NPCs is already
	# declared `"involvement": "reputation_reaction"` in
	# `canon/dom/characters/*.json`, with a `hook_summary` naming BOTH the
	# faction and the band — canon authored the reaction and nothing read it.
	# The faction below is the NPC's own `faction_id`; the band is the "warm"
	# every one of those hook summaries says out loud.
	#
	# The route replaces the generated townsfolk fallback rather than editing
	# it: `dialogue/dom_townsfolk.dialogue` is written by
	# `tools/generate_gloot.gd` and a hand-edit there is lost on the next
	# regeneration.
	"raika-toll": [
		{
			"reputation_faction": "ironbrand-sentinels",
			"minimum_reputation_band": &"warm",
			"dialogue_path": BAND_REACTION_DIALOGUE,
			"dialogue_title": "dom_raika_toll_warm",
		},
	],
	"edda-broadmark": [
		{
			"reputation_faction": "iron-companies",
			"minimum_reputation_band": &"warm",
			"dialogue_path": BAND_REACTION_DIALOGUE,
			"dialogue_title": "dom_edda_broadmark_warm",
		},
	],
	"drann-wetiron": [
		{
			"reputation_faction": "shattersteel-concord",
			"minimum_reputation_band": &"warm",
			"dialogue_path": BAND_REACTION_DIALOGUE,
			"dialogue_title": "dom_drann_wetiron_warm",
		},
	],
	"venn-ashcord": [
		{
			"reputation_faction": "rennen",
			"minimum_reputation_band": &"warm",
			"dialogue_path": BAND_REACTION_DIALOGUE,
			"dialogue_title": "dom_venn_ashcord_warm",
		},
	],
	"holst-brinevein": [
		{
			"reputation_faction": "wayfare-menders",
			"minimum_reputation_band": &"warm",
			"dialogue_path": BAND_REACTION_DIALOGUE,
			"dialogue_title": "dom_holst_brinevein_warm",
		},
	],
	# --- FR-308 Zhavar rumor routes -------------------------------------------
	# The Zhavar is how far a zone "can be heard" (PRD FR-308), so the people who
	# hear it for a living are the ones who notice first: two signalers, a sentry
	# who decides when the north road opens, and a fisher who works in silence.
	# None of them explains the ladder. Chapter 1 TELEGRAPHS the Zhavar; the
	# dragon-response systemization it points at is Chapter 2+.
	#
	# Nalla carries both rungs, and the LOUDER rule is listed first on purpose:
	# `resolve()` returns the first match and the gate is a floor, so a
	# rising-first order would pin her to the quieter line forever.
	"nalla-gatebeat": [
		{
			"zhavar_zone": "wilds",
			"minimum_zhavar_rung": "tolling",
			"dialogue_path": ZHAVAR_RUMOR_DIALOGUE,
			"dialogue_title": "dom_nalla_gatebeat_tolling",
		},
		{
			"zhavar_zone": "wilds",
			"minimum_zhavar_rung": "rising",
			"dialogue_path": ZHAVAR_RUMOR_DIALOGUE,
			"dialogue_title": "dom_nalla_gatebeat_rising",
		},
	],
	"kessa-nightrail": [
		{
			"zhavar_zone": "wilds",
			"minimum_zhavar_rung": "rising",
			"dialogue_path": ZHAVAR_RUMOR_DIALOGUE,
			"dialogue_title": "dom_kessa_nightrail_rising",
		},
	],
	"tern-hollowbeat": [
		{
			"zhavar_zone": "wilds",
			"minimum_zhavar_rung": "tolling",
			"dialogue_path": ZHAVAR_RUMOR_DIALOGUE,
			"dialogue_title": "dom_tern_hollowbeat_tolling",
		},
	],
	"yssra-coldnet": [
		{
			"zhavar_zone": "wilds",
			"minimum_zhavar_rung": "tolling",
			"dialogue_path": ZHAVAR_RUMOR_DIALOGUE,
			"dialogue_title": "dom_yssra_coldnet_tolling",
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
	var zone := str(rule.get("zhavar_zone", ""))
	var rung := str(rule.get("minimum_zhavar_rung", ""))
	if rule.has("hollowing") and not rule["hollowing"] is bool:
		return false
	if (
		flag.is_empty() and faction.is_empty() and zone.is_empty()
		and not rule.has("hollowing")
	):
		return false
	if faction.is_empty() != band.is_empty():
		return false
	if not band.is_empty() and not Reputation.BAND_RANK.has(band):
		return false
	# Half a rung gate is the failure mode this catches: a zone with no floor
	# would fire at "low", which is every save from its first frame, and a floor
	# with no zone would silently never fire at all.
	if zone.is_empty() != rung.is_empty():
		return false
	if not rung.is_empty() and not SaveGame.ZHAVAR_RUNGS.has(rung):
		return false
	if not zone.is_empty() and not StableIds.is_valid(StableIds.ZONE, zone):
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
	# GameState owns the hollowing state; this only reads it. A rule that names
	# `hollowing` must match it exactly, so `false` is a usable gate too — an
	# NPC may have something to say only once you are NOT hollowed.
	if rule.has("hollowing") and GameState.is_hollowing() != bool(rule["hollowing"]):
		return false
	var flag := str(rule.get("flag", ""))
	if not flag.is_empty() and GameState.get_flag(flag, null) != rule.get("flag_value", true):
		return false
	# FR-308. The rumor gate is a FLOOR on the ladder, like the reputation band
	# above it: "rising or worse". A rumor is not retracted when the zone gets
	# louder — the town keeps talking, it just talks about something nearer.
	# SaveGame owns the ladder and its order; reading the rung through it is what
	# stops a second copy of ZHAVAR_RUNGS drifting out of step with the save.
	var zone := str(rule.get("zhavar_zone", ""))
	if not zone.is_empty() and not _zhavar_at_least(
		zone, str(rule.get("minimum_zhavar_rung", ""))
	):
		return false
	var faction := str(rule.get("reputation_faction", ""))
	if faction.is_empty():
		return true
	# Reputation owns the band ordering. A local copy here could disagree with
	# doors and every other reputation consumer after a rebalance.
	var minimum := StringName(rule.get("minimum_reputation_band", &"neutral"))
	return Reputation.band_at_least(faction, minimum)


static func _zhavar_at_least(zone_id: String, minimum_rung: String) -> bool:
	var rungs: Array = SaveGame.ZHAVAR_RUNGS
	var wanted := rungs.find(minimum_rung)
	if wanted < 0:
		return false
	return rungs.find(SaveGame.zhavar_rung(zone_id)) >= wanted
