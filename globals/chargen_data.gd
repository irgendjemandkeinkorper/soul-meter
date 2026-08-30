class_name ChargenData
extends RefCounted
## Ratified character-creation data (#98 / dramgid-vault `systems/character-creation.md`
## + `systems/ten-patron-classes.md`, read 2026-08-11). Nothing here is invented — every
## table mirrors the vault verbatim. See the header comment on
## `ui/screens/character_creation.gd` for the one place this build knowingly deviates
## from the literal text of GitHub issue #129 (the "Seven Measures" / D-R-A-M-G-I-D
## naming does not exist anywhere in ratified data; the vault's six attributes are
## Forge/Edge/Anchor/Spark/Pitch/Voice — see `character-creation.md` and
## `globals/skill_check.gd`, which already implements them).

## The six ratified attributes, in vault table order (Body / Mind / Soul pairs).
const ATTRIBUTE_IDS: PackedStringArray = ["forge", "edge", "anchor", "spark", "pitch", "voice"]
const ATTRIBUTE_LABELS: Dictionary = {
	"forge": "Forge",
	"edge": "Edge",
	"anchor": "Anchor",
	"spark": "Spark",
	"pitch": "Pitch",
	"voice": "Voice",
}
const ATTRIBUTE_HINTS: Dictionary = {
	"forge": "Raw physical power, carry weight.",
	"edge": "Precision, accuracy, evasion.",
	"anchor": "HP pool; resistance to Discord/backlash.",
	"spark": "Initiative, tactics, non-elemental checks.",
	"pitch": "Soul Gauge/Breath ceiling; base fizzle reduction.",
	"voice": "Consonance strength; Name-Ledger effectiveness; social leverage.",
}
const ATTRIBUTE_DOMAIN: Dictionary = {
	"forge": "body", "edge": "body",
	"anchor": "mind", "spark": "mind",
	"pitch": "soul", "voice": "soul",
}

## "6 attributes, base 2 each, 20 points to distribute, cap 5 at creation"
## (character-creation.md). Read as: the six final values sum to the budget,
## each individually floored at ATTRIBUTE_FLOOR and capped at ATTRIBUTE_CAP.
const ATTRIBUTE_FLOOR := 2
const ATTRIBUTE_CAP := 5
const ATTRIBUTE_BUDGET := 20

## The twelve ratified skills, mirrored from SkillCheckService.SKILL_DEFINITIONS
## so this file never disagrees with the resolution service.
const SKILL_IDS: PackedStringArray = [
	"athletics", "stealth", "sleight_of_hand", "beast_handling",
	"lore", "survival", "investigation", "alchemy",
	"persuasion", "weft_sensing", "performance", "insight",
]
const SKILL_LABELS: Dictionary = {
	"athletics": "Athletics", "stealth": "Stealth",
	"sleight_of_hand": "Sleight of Hand", "beast_handling": "Beast Handling",
	"lore": "Lore", "survival": "Survival",
	"investigation": "Investigation", "alchemy": "Alchemy",
	"persuasion": "Persuasion", "weft_sensing": "Weft-Sensing",
	"performance": "Performance", "insight": "Insight",
}

## Chapter 1's production-scoped ancestries (character-creation.md, "Soul Meter (CRPG)
## scope note") — 5 of the vault's ~20 playable peoples. `leans` is informational only:
## the vault ratifies that ancestry leanings are "nudges, not flat bonuses" but never
## quantifies the nudge, so this build does not auto-apply attribute deltas (flagged
## as an open question for #98 rather than invented here).
const ANCESTRIES: Array[Dictionary] = [
	{"id": "vael", "name": "Vael", "leans": "Balanced", "trait": "Extra skill point at creation (generalist)."},
	{"id": "kaan", "name": "Kaan", "leans": "Forge / Anchor", "trait": "Vulnerable to Molm-adjacent effects; resistant to physical Discord."},
	{"id": "vaerin", "name": "Vaerin", "leans": "Spark / Pitch", "trait": "Access to the Fading resource regardless of class."},
	{"id": "weftkin", "name": "Weftkin", "leans": "Pitch / Voice", "trait": "Innate Weft-Sensing training."},
	{"id": "kes-reth", "name": "Kes'reth (Mirror-Veil)", "leans": "Voice / Anchor", "trait": "Mirrored Scars — once per encounter, spend vitality to negate one Discord-inflicted condition."},
]

## The five worked-example Backgrounds (character-creation.md). Each grants a skill
## package (set to Trained), a minor mechanical feature (metadata only — the feature
## is not yet wired into a system, same boundary as the vault's own "expansion point"
## framing), and a starting Mastery.
const BACKGROUNDS: Array[Dictionary] = [
	{
		"id": "sarkhollow-scavenger", "name": "Sarkhollow Scavenger",
		"skills": ["lore", "investigation"],
		"feature": "Advantage identifying relic function.",
		"mastery": "Root Note of choice",
	},
	{
		"id": "verlossen-miner", "name": "Verlossen Miner",
		"skills": ["athletics", "survival"],
		"feature": "Resistance to Feedback-tier Discord (mining-deep conditioning).",
		"mastery": "Root Note of choice",
	},
	{
		"id": "vervulling-kes-reth", "name": "Vervulling Kes'reth",
		"skills": ["weft_sensing", "lore"],
		"feature": "+1 Pitch-linked fizzle reduction inside city Gauge-net zones.",
		"mastery": "Root Note of choice",
	},
	{
		"id": "wintervast-rimewalker", "name": "Wintervast Rimewalker-adjacent",
		"skills": ["insight", "lore"],
		"feature": "Immune to the first Dissonance hit per encounter (\"unbothered stillness\").",
		"mastery": "Root Note of choice",
	},
	{
		"id": "dom-storm-coast", "name": "Dom Storm-Coast",
		"skills": ["survival", "sleight_of_hand"],
		"feature": "Bonus vs. Ofshütje-flavored environmental hazards.",
		"mastery": "Root Note of choice",
	},
]

## Combat Disciplines (ten-patron-classes.md §Combat Disciplines) — chosen before
## Patron; no numeric baseline is ratified yet ("expansion point"), so this is
## identity-only metadata.
const DISCIPLINES: Array[Dictionary] = [
	{"id": "chordblade", "name": "Chordblade", "blurb": "Vanguard footwork, favouring Khor's tempo."},
	{"id": "terrashaper", "name": "Terrashaper", "blurb": "The engineer's stance, favouring Terra's weight."},
	{"id": "hushwarden", "name": "Hushwarden", "blurb": "Denial and stillness, favouring Nul's quiet."},
]

## The Ten Patron Classes (ten-patron-classes.md). `char_class` mirrors the existing
## "ClassName (Patron)" convention already used by GameState's recruit roster.
const PATRONS: Array[Dictionary] = [
	{"id": "mirrorblade", "name": "Mirrorblade", "patron": "Maiiam", "role": "Duelist"},
	{"id": "river-mother", "name": "River-Mother", "patron": "Haeren", "role": "Support"},
	{"id": "ironbrand", "name": "Ironbrand", "patron": "Kero", "role": "Berserker"},
	{"id": "lensbearer", "name": "Lensbearer", "patron": "Stuid", "role": "Buffer/Debuffer"},
	{"id": "husk-bearer", "name": "Husk-bearer", "patron": "Vhorr", "role": "DoT controller"},
	{"id": "flamebinder", "name": "Flamebinder", "patron": "Vicoar", "role": "Artificer"},
	{"id": "stormbearer", "name": "Stormbearer", "patron": "Ofshütje", "role": "Skirmisher"},
	{"id": "oathclock", "name": "Oathclock", "patron": "Pazzah", "role": "Controller"},
	{"id": "locksmirk", "name": "Locksmirk", "patron": "Fickah", "role": "Trickster"},
	{"id": "threadwalker", "name": "Threadwalker", "patron": "Izhakel", "role": "Summoner/Debuffer"},
]

## The Wheel's five opposed (Clash) pairs (ui/theme/ds.gd header comment) — Major and
## Minor element picks may never be an opposed pair (ten-patron-classes.md).
const WHEEL_CLASH_PAIRS: Dictionary = {
	"suul": "daar", "daar": "suul",
	"bloei": "molm", "molm": "bloei",
	"aqua": "scor", "scor": "aqua",
	"khor": "nul", "nul": "khor",
	"terra": "strom", "strom": "terra",
}

## Portrait choices for the likeness grid. Reuses existing dedicated crowd-figure
## art (globals/unit_art.gd FALLBACK_POOL) rather than adding new content — no new
## art asset was in scope for this build.
const LIKENESS_UNIT_IDS: PackedStringArray = [
	"crowd-acolyte-a", "crowd-guard-a", "crowd-merchant-a", "crowd-laborer-a",
]

## Painterly likeness plates (Wave S art lane, 2 per ratified ancestry) at
## assets/generated/portraits/player/<id>.png. `unit` names the existing crowd
## field sprite that stands in wherever a plate is missing or a world-sprite
## representation is needed — plates never replace field art.
const LIKENESSES: Array[Dictionary] = [
	{"id": "likeness_01", "label": "Vael Ledger Courier", "unit": "crowd-acolyte-a"},
	{"id": "likeness_02", "label": "Vael Hospice Wayfarer", "unit": "crowd-merchant-b"},
	{"id": "likeness_03", "label": "Kaan Deep-Forge Mason", "unit": "crowd-laborer-a"},
	{"id": "likeness_04", "label": "Kaan Liftwright", "unit": "crowd-laborer-b"},
	{"id": "likeness_05", "label": "Vaerin Field Archivist", "unit": "crowd-acolyte-b"},
	{"id": "likeness_06", "label": "Vaerin Canopy Surveyor", "unit": "crowd-dockworker-a"},
	{"id": "likeness_07", "label": "Weftkin Loam-Tender", "unit": "crowd-dockworker-b"},
	{"id": "likeness_08", "label": "Weftkin Road Cultivator", "unit": "crowd-merchant-a"},
	{"id": "likeness_09", "label": "Mirror-Veil Mirrorwright", "unit": "crowd-guard-a"},
	{"id": "likeness_10", "label": "Mirror-Veil Canal Craftswoman", "unit": "crowd-guard-b"},
]


static func likeness_by_id(id: String) -> Dictionary:
	for entry: Dictionary in LIKENESSES:
		if str(entry.get("id", "")) == id:
			return entry
	return {}


static func likeness_fallback_unit(id: String) -> String:
	var entry := likeness_by_id(id)
	# Pre-gallery likeness ids WERE unit ids; keep them resolving as themselves.
	return str(entry.get("unit", "")) if not entry.is_empty() else id


static func attribute_label(id: String) -> String:
	return str(ATTRIBUTE_LABELS.get(id, id))


static func skill_label(id: String) -> String:
	return str(SKILL_LABELS.get(id, id))


static func background_by_id(id: String) -> Dictionary:
	for entry in BACKGROUNDS:
		if entry["id"] == id:
			return entry
	return {}


static func ancestry_by_id(id: String) -> Dictionary:
	for entry in ANCESTRIES:
		if entry["id"] == id:
			return entry
	return {}


static func patron_by_id(id: String) -> Dictionary:
	for entry in PATRONS:
		if entry["id"] == id:
			return entry
	return {}


## The governing attribute for each skill, mirrored from SkillCheckService so a
## preview panel never has to reach into the resolution service just to label a row.
static func governing_attribute(skill_id: String) -> String:
	var definitions: Dictionary = SkillCheckService.SKILL_DEFINITIONS
	var definition: Dictionary = definitions.get(skill_id, {})
	return str(definition.get("attribute", ""))


## True if `attributes` is a complete, in-budget point-buy: all six ids present,
## each within [ATTRIBUTE_FLOOR, ATTRIBUTE_CAP], summing to exactly ATTRIBUTE_BUDGET.
static func is_valid_point_buy(attributes: Dictionary) -> bool:
	if attributes.size() != ATTRIBUTE_IDS.size():
		return false
	var total := 0
	for id in ATTRIBUTE_IDS:
		if not attributes.has(id):
			return false
		var value: Variant = attributes[id]
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
		var int_value := int(value)
		if int_value < ATTRIBUTE_FLOOR or int_value > ATTRIBUTE_CAP:
			return false
		total += int_value
	return total == ATTRIBUTE_BUDGET


static func remaining_points(attributes: Dictionary) -> int:
	var total := 0
	for id in ATTRIBUTE_IDS:
		total += int(attributes.get(id, ATTRIBUTE_FLOOR))
	return ATTRIBUTE_BUDGET - total


## True if a Major/Minor element pick is legal (never an opposed Clash pair; a
## character may leave either unset).
static func is_valid_element_pair(major_id: String, minor_id: String) -> bool:
	if major_id.is_empty() or minor_id.is_empty():
		return true
	if major_id == minor_id:
		return false
	return WHEEL_CLASH_PAIRS.get(major_id, "") != minor_id


## Default (floor-value) attribute map, used to seed a fresh chargen session.
static func default_attributes() -> Dictionary:
	var result := {}
	for id in ATTRIBUTE_IDS:
		result[id] = ATTRIBUTE_FLOOR
	return result


## Derives the twelve skill percentages a build would carry once ACCEPTed, mirroring
## SkillCheckService's formula (`attribute x 8 + tier_bonus`) without needing a live
## PartyMember/scene — used by the screen's live preview panel.
static func preview_skill_percentages(attributes: Dictionary, trained_skills: Array) -> Dictionary:
	var result := {}
	for skill_id in SKILL_IDS:
		var attribute_id := governing_attribute(skill_id)
		var attribute_value := int(attributes.get(attribute_id, ATTRIBUTE_FLOOR))
		var tier_bonus := 20.0 if skill_id in trained_skills else 0.0
		result[skill_id] = clampf(attribute_value * 8.0 + tier_bonus, 0.0, SkillCheckService.MAX_EFFECTIVE_PERCENT)
	return result
