class_name DramgidSchema
extends RefCounted
## Canonical, data-only definition of DRAMGID attributes and skills.

enum LoomSensitivity { NONE, PARTIAL, FULL }

const LOOM_VALUES: Array[int] = [
	LoomSensitivity.NONE,
	LoomSensitivity.PARTIAL,
	LoomSensitivity.FULL,
]

const ATTRIBUTE_FLOOR := 2
const ATTRIBUTE_BUDGET := 22
const ATTRIBUTE_CAP := 5

const ATTR_DOCTRINE: StringName = &"doctrine"
const ATTR_REASON: StringName = &"reason"
const ATTR_ALACRITY: StringName = &"alacrity"
const ATTR_MUSTER: StringName = &"muster"
const ATTR_GRIT: StringName = &"grit"
const ATTR_INTUITION: StringName = &"intuition"
const ATTR_DECORUM: StringName = &"decorum"

const ATTRIBUTE_IDS: PackedStringArray = [
	"doctrine", "reason", "alacrity", "muster", "grit", "intuition", "decorum",
]

const ATTRIBUTES: Dictionary = {
	"doctrine": {
		"label": "Doctrine", "mono_token": "ATTR.DOCTRINE",
		"governs": "Karma volatility; no skills", "replaces": "",
	},
	"reason": {
		"label": "Reason", "mono_token": "ATTR.REASON",
		"governs": "Initiative/CT speed, tactics, non-elemental checks", "replaces": "spark",
	},
	"alacrity": {
		"label": "Alacrity", "mono_token": "ATTR.ALACRITY",
		"governs": "Accuracy, evasion, to-hit difference", "replaces": "edge",
	},
	"muster": {
		"label": "Muster", "mono_token": "ATTR.MUSTER",
		"governs": "Raw power and carry", "replaces": "forge",
	},
	"grit": {
		"label": "Grit", "mono_token": "ATTR.GRIT",
		"governs": "HP pool and Discord/backlash resistance", "replaces": "anchor",
	},
	"intuition": {
		"label": "Intuition", "mono_token": "ATTR.INTUITION",
		"governs": "Soul Gauge/Breath ceiling and base fizzle reduction", "replaces": "pitch",
	},
	"decorum": {
		"label": "Decorum", "mono_token": "ATTR.DECORUM",
		"governs": "Consonance, Name-Ledger, social leverage, Fame volatility", "replaces": "voice",
	},
}

const ATTRIBUTE_RENAMES: Dictionary = {
	"forge": "muster",
	"edge": "alacrity",
	"anchor": "grit",
	"pitch": "intuition",
	"voice": "decorum",
	"spark": "reason",
}

const SKILL_IDS: PackedStringArray = [
	"strain", "lilt", "slip", "tread", "beastbond", "varlore", "unweave", "recall",
	"wildlore", "devotion", "undertone", "mending", "ear", "wayfinding", "sounding",
	"falsetto", "bellow", "varum", "sway", "downbeat", "brace", "vantage",
]

const SKILLS: Dictionary = {
	"strain": {"label": "Strain", "attribute": "muster", "loom": LoomSensitivity.NONE, "replaces": "athletics", "mono_token": "SKILL.STRAIN"},
	"lilt": {"label": "Lilt", "attribute": "alacrity", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.LILT"},
	"slip": {"label": "Slip", "attribute": "alacrity", "loom": LoomSensitivity.NONE, "replaces": "sleight_of_hand", "mono_token": "SKILL.SLIP"},
	"tread": {"label": "Tread", "attribute": "alacrity", "loom": LoomSensitivity.NONE, "replaces": "stealth", "mono_token": "SKILL.TREAD"},
	"beastbond": {"label": "Beastbond", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "beast_handling", "mono_token": "SKILL.BEASTBOND"},
	"varlore": {"label": "Varlore", "attribute": "reason", "loom": LoomSensitivity.FULL, "replaces": "", "mono_token": "SKILL.VARLORE"},
	"unweave": {"label": "Unweave", "attribute": "reason", "loom": LoomSensitivity.FULL, "replaces": "investigation", "mono_token": "SKILL.UNWEAVE"},
	"recall": {"label": "Recall", "attribute": "reason", "loom": LoomSensitivity.NONE, "replaces": "lore", "mono_token": "SKILL.RECALL"},
	"wildlore": {"label": "Wildlore", "attribute": "reason", "loom": LoomSensitivity.PARTIAL, "loom_note": "Pozor exception", "replaces": "", "mono_token": "SKILL.WILDLORE"},
	"devotion": {"label": "Devotion", "attribute": "reason", "loom": LoomSensitivity.PARTIAL, "loom_note": "Provisional until owner ruling", "replaces": "", "mono_token": "SKILL.DEVOTION"},
	"undertone": {"label": "Undertone", "attribute": "intuition", "loom": LoomSensitivity.FULL, "replaces": "insight", "mono_token": "SKILL.UNDERTONE"},
	"mending": {"label": "Mending", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.MENDING"},
	"ear": {"label": "Ear", "attribute": "intuition", "loom": LoomSensitivity.PARTIAL, "replaces": "", "mono_token": "SKILL.EAR"},
	"wayfinding": {"label": "Wayfinding", "attribute": "intuition", "loom": LoomSensitivity.PARTIAL, "loom_note": "Pozor exception", "replaces": "survival", "mono_token": "SKILL.WAYFINDING"},
	"sounding": {"label": "Sounding", "attribute": "intuition", "loom": LoomSensitivity.FULL, "replaces": "weft_sensing", "mono_token": "SKILL.SOUNDING"},
	"falsetto": {"label": "Falsetto", "attribute": "decorum", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.FALSETTO"},
	"bellow": {"label": "Bellow", "attribute": "decorum", "loom": LoomSensitivity.NONE, "karma_direction": -1, "replaces": "", "mono_token": "SKILL.BELLOW"},
	"varum": {"label": "Vārum", "attribute": "decorum", "loom": LoomSensitivity.NONE, "replaces": "performance", "mono_token": "SKILL.VARUM"},
	"sway": {"label": "Sway", "attribute": "decorum", "loom": LoomSensitivity.NONE, "karma_direction": 1, "replaces": "persuasion", "mono_token": "SKILL.SWAY"},
	"downbeat": {"label": "Downbeat", "attribute": "decorum", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.DOWNBEAT"},
	"brace": {"label": "Brace", "attribute": "grit", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.BRACE"},
	"vantage": {"label": "Vantage", "attribute": "reason", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.VANTAGE"},
}

const SKILL_RENAMES: Dictionary = {
	"athletics": "strain",
	"stealth": "tread",
	"sleight_of_hand": "slip",
	"beast_handling": "beastbond",
	"lore": "recall",
	"survival": "wayfinding",
	"investigation": "unweave",
	"alchemy": "",
	"persuasion": "sway",
	"weft_sensing": "sounding",
	"performance": "varum",
	"insight": "undertone",
}

## Transitional definitions keep pre-schema-8 callers working while later F3a PRs
## migrate dialogue, chargen, and authored data. They live here so legacy stat ids
## do not leak into consumers of the canonical schema.
const LEGACY_SKILL_DEFINITIONS: Dictionary = {
	"athletics": {"domain": "body", "attribute": "forge"},
	"stealth": {"domain": "body", "attribute": "edge"},
	"sleight_of_hand": {"domain": "body", "attribute": "edge"},
	"beast_handling": {"domain": "body", "attribute": "forge"},
	"lore": {"domain": "mind", "attribute": "spark"},
	"survival": {"domain": "mind", "attribute": "anchor"},
	"investigation": {"domain": "mind", "attribute": "spark"},
	"alchemy": {"domain": "mind", "attribute": "anchor"},
	"persuasion": {"domain": "soul", "attribute": "voice"},
	"weft_sensing": {"domain": "soul", "attribute": "pitch"},
	"performance": {"domain": "soul", "attribute": "voice"},
	"insight": {"domain": "soul", "attribute": "pitch"},
}


static func skill_check_definitions() -> Dictionary:
	var definitions: Dictionary = SKILLS.duplicate(true)
	definitions.merge(LEGACY_SKILL_DEFINITIONS, false)
	return definitions


static func default_attributes() -> Dictionary:
	var result: Dictionary = {}
	for attribute_id: String in ATTRIBUTE_IDS:
		result[attribute_id] = ATTRIBUTE_FLOOR
	return result


static func is_valid_attribute_allocation(attributes: Dictionary) -> bool:
	if attributes.size() != ATTRIBUTE_IDS.size():
		return false
	var total := 0
	for attribute_id: String in ATTRIBUTE_IDS:
		if not attributes.has(attribute_id):
			return false
		var value: Variant = attributes[attribute_id]
		if typeof(value) != TYPE_INT:
			return false
		var attribute_value := int(value)
		if attribute_value < ATTRIBUTE_FLOOR or attribute_value > ATTRIBUTE_CAP:
			return false
		total += attribute_value
	return total == ATTRIBUTE_BUDGET
