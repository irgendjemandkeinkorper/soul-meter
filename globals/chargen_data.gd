class_name ChargenData
extends RefCounted
## Character-creation tables (docs/architecture-chargen-dramgid.md §6–§7; canon: mono
## `04-world/systems/character-creation.md` + `ten-patron-classes.md`, read 2026-09-05).
##
## Stat ids come from DramgidSchema and class rows from ClassCatalog — this file holds
## only what is specific to creation: peoples, Backgrounds, Disciplines, likenesses and
## the pair rule. Nothing here re-states a formula: percentages come from
## SkillCheck.preview() on a ChargenBuild scratch member.

## Attribute constants, mirrored from the schema so existing callers keep one name.
const ATTRIBUTE_IDS: PackedStringArray = DramgidSchema.ATTRIBUTE_IDS
const ATTRIBUTE_FLOOR := DramgidSchema.ATTRIBUTE_FLOOR
const ATTRIBUTE_CAP := DramgidSchema.ATTRIBUTE_CAP
const ATTRIBUTE_BUDGET := DramgidSchema.ATTRIBUTE_BUDGET

## TRANSITIONAL — the character sheet still iterates the twelve legacy ids until W1
## (docs/handoff-chargen-workers.md) moves it onto DramgidSchema.SKILL_GROUPS. The wizard
## never reads these two tables.
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

## Chapter 1's production-scoped ancestries (character-creation.md "Soul Meter (CRPG) scope
## note") — 5 of the ~20 playable peoples. `leans` is informational: the canon ratifies that
## leanings are "nudges, not flat bonuses" and never quantifies the nudge, so no attribute
## delta is applied. The two traits that ARE mechanical in canon are data:
## `creation_bonus_points` (Vael: "extra skill point at creation") and `trained_skills`
## (Weftkin: "innate Weft-Sensing training" → sounding Trained).
const ANCESTRIES: Array[Dictionary] = [
	{"id": "vael", "name": "Vael", "leans": "Balanced", "lean_ids": [],
		"trait": "Extra skill point at creation (generalist).",
		"creation_bonus_points": 1, "trained_skills": []},
	{"id": "kaan", "name": "Kaan", "leans": "Muster / Grit", "lean_ids": ["muster", "grit"],
		"trait": "Vulnerable to Molm-adjacent effects; resistant to physical Discord.",
		"creation_bonus_points": 0, "trained_skills": []},
	{"id": "vaerin", "name": "Vaerin", "leans": "Reason / Intuition", "lean_ids": ["reason", "intuition"],
		"trait": "Access to the Fading resource regardless of class.",
		"creation_bonus_points": 0, "trained_skills": []},
	{"id": "weftkin", "name": "Weftkin", "leans": "Intuition / Decorum", "lean_ids": ["intuition", "decorum"],
		"trait": "Innate Weft-Sensing training (Sounding starts Trained).",
		"creation_bonus_points": 0, "trained_skills": ["sounding"]},
	{"id": "kes-reth", "name": "Kes'reth (Mirror-Veil)", "leans": "Decorum / Grit", "lean_ids": ["decorum", "grit"],
		"trait": "Mirrored Scars — once per encounter, spend vitality to negate one Discord-inflicted condition.",
		"creation_bonus_points": 0, "trained_skills": []},
]

## The five worked-example Backgrounds (character-creation.md). Skill packages are set
## Trained; `feature` is metadata (not yet wired, same boundary as the canon's "expansion
## point"); the starting Mastery is a Root Note of the player's choice among the held
## elements (ChargenBuild.mastery_element).
const BACKGROUNDS: Array[Dictionary] = [
	{
		"id": "sarkhollow-scavenger", "name": "Sarkhollow Scavenger",
		"skills": ["recall", "unweave"],
		"feature": "Advantage identifying relic function.",
		"mastery": "Root Note of choice",
	},
	{
		"id": "verlossen-miner", "name": "Verlossen Miner",
		"skills": ["strain", "wayfinding"],
		"feature": "Resistance to Feedback-tier Discord (mining-deep conditioning).",
		"mastery": "Root Note of choice",
	},
	{
		"id": "vervulling-kes-reth", "name": "Vervulling Kes'reth",
		"skills": ["sounding", "recall"],
		"feature": "+1 Intuition-linked fizzle reduction inside city Gauge-net zones.",
		"mastery": "Root Note of choice",
	},
	{
		"id": "wintervast-rimewalker", "name": "Wintervast Rimewalker-adjacent",
		"skills": ["undertone", "recall"],
		"feature": "Immune to the first Dissonance hit per encounter (\"unbothered stillness\").",
		"mastery": "Root Note of choice",
	},
	{
		"id": "dom-storm-coast", "name": "Dom Storm-Coast",
		"skills": ["wayfinding", "slip"],
		"feature": "Bonus vs. Ofshütje-flavored environmental hazards.",
		"mastery": "Root Note of choice",
	},
]

## Combat Disciplines (ten-patron-classes.md §Combat Disciplines) — chosen before Patron
## ("a body moves before a god notices it"); no numeric baseline is ratified, so this is
## identity metadata plus the element each favours.
const DISCIPLINES: Array[Dictionary] = [
	{"id": "chordblade", "name": "Chordblade", "favours": "khor",
		"blurb": "Vanguard footwork, favouring Khor's tempo.",
		"verbs": "Advance, feint, close — reach and rhythm over weight."},
	{"id": "terrashaper", "name": "Terrashaper", "favours": "terra",
		"blurb": "The engineer's stance, favouring Terra's weight.",
		"verbs": "Hold, brace, raise — elevation and footing over speed."},
	{"id": "hushwarden", "name": "Hushwarden", "favours": "nul",
		"blurb": "Denial and stillness, favouring Nul's quiet.",
		"verbs": "Deny, still, wait — the field taxes every Song inside it, the warden's included."},
]

## The Ten Patron Classes — a view over ClassCatalog (the one definition).
const PATRONS: Array[Dictionary] = ClassCatalog.ALL

## The Wheel's five opposed (Clash) pairs — Major and Minor may never be an opposed pair
## (ten-patron-classes.md). Kept as a table for the wizard's live clash hint; the rule
## itself is ElementWheel.opposite().
const WHEEL_CLASH_PAIRS: Dictionary = {
	"suul": "daar", "daar": "suul",
	"bloei": "molm", "molm": "bloei",
	"aqua": "scor", "scor": "aqua",
	"khor": "nul", "nul": "khor",
	"terra": "strom", "strom": "terra",
}

## Portrait choices for the likeness grid. Reuses existing dedicated crowd-figure
## art (globals/unit_art.gd FALLBACK_POOL) rather than adding new content.
const LIKENESS_UNIT_IDS: PackedStringArray = [
	"crowd-acolyte-a", "crowd-guard-a", "crowd-merchant-a", "crowd-laborer-a",
]

## Painterly likeness plates (Wave S art lane, 2 per ratified ancestry) at
## assets/generated/portraits/player/<id>.png. `unit` names the existing crowd
## field sprite that stands in wherever a plate is missing.
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
	return DramgidSchema.attribute_label(id)


static func attribute_hint(id: String) -> String:
	return str(DramgidSchema.ATTRIBUTES.get(id, {}).get("governs", ""))


## Schema label first; the transitional legacy table answers the sheet's twelve ids.
static func skill_label(id: String) -> String:
	if DramgidSchema.is_skill(id):
		return DramgidSchema.skill_label(id)
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


static func discipline_by_id(id: String) -> Dictionary:
	for entry in DISCIPLINES:
		if entry["id"] == id:
			return entry
	return {}


static func patron_by_id(id: String) -> Dictionary:
	return ClassCatalog.by_id(id)


static func governing_attribute(skill_id: String) -> String:
	if DramgidSchema.is_skill(skill_id):
		return DramgidSchema.governing_attribute(skill_id)
	# Transitional legacy ids resolve through the service's merged definitions.
	return str(SkillCheckService.SKILL_DEFINITIONS.get(skill_id, {}).get("attribute", ""))


## True if `attributes` is a complete, in-budget point-buy: all seven ids present, each
## within [floor, cap], summing to exactly the budget (DramgidSchema owns the rule).
static func is_valid_point_buy(attributes: Dictionary) -> bool:
	var normalized: Dictionary = {}
	for id in attributes.keys():
		var value: Variant = attributes[id]
		if typeof(value) != TYPE_INT and typeof(value) != TYPE_FLOAT:
			return false
		normalized[str(id)] = int(value)
	return DramgidSchema.is_valid_attribute_allocation(normalized)


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
	return String(ElementWheel.opposite(major_id)) != minor_id


## Default (floor-value) attribute map, used to seed a fresh chargen session.
static func default_attributes() -> Dictionary:
	return DramgidSchema.default_attributes()
