class_name DramgidSchema
extends RefCounted
## Canonical, data-only definition of DRAMGID attributes and skills.
##
## This is the ONLY file that may enumerate a stat id (docs/architecture-dramgid.md §1).
## Skills carry a `group` (docs/architecture-chargen-dramgid.md §3.1): the four field
## groups (body/mind/soul/voice) are RFC-0005's 22-row table (PROVISIONAL, owner ruling
## R1); ARMS (weapon skills) and TONES (one per Wheel element) are the chargen-on-DRAMGID
## proposal (owner rulings R2/R3) and carry `"source": "sm-chargen-proposal"` so a canon
## pass can find every unratified id. Consumers iterate SKILL_GROUPS / skills_in_group(),
## never a literal id list.

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

## Every skill id, field rows first (schema order), then ARMS, then TONES.
const SKILL_IDS: PackedStringArray = [
	"strain", "lilt", "slip", "tread", "beastbond", "varlore", "unweave", "recall",
	"wildlore", "devotion", "undertone", "mending", "ear", "wayfinding", "sounding",
	"falsetto", "bellow", "varum", "sway", "downbeat", "brace", "vantage",
	"keen", "heft", "reach", "loose", "grip",
	"tone_sul", "tone_vel", "tone_luth", "tone_khor", "tone_tham",
	"tone_vekh", "tone_mozh", "tone_khash", "tone_zhem", "tone_zhur",
]

const FIELD_SKILL_IDS: PackedStringArray = [
	"strain", "lilt", "slip", "tread", "beastbond", "varlore", "unweave", "recall",
	"wildlore", "devotion", "undertone", "mending", "ear", "wayfinding", "sounding",
	"falsetto", "bellow", "varum", "sway", "downbeat", "brace", "vantage",
]
const ARMS_SKILL_IDS: PackedStringArray = ["keen", "heft", "reach", "loose", "grip"]
const TONE_SKILL_IDS: PackedStringArray = [
	"tone_sul", "tone_vel", "tone_luth", "tone_khor", "tone_tham",
	"tone_vekh", "tone_mozh", "tone_khash", "tone_zhem", "tone_zhur",
]
const TONE_SKILL_PREFIX := "tone_"

const GROUP_BODY := "body"
const GROUP_MIND := "mind"
const GROUP_SOUL := "soul"
const GROUP_VOICE := "voice"
const GROUP_ARMS := "arms"
const GROUP_TONES := "tones"

## Sheet / wizard order. ARMS and TONES lead because they are what a build is *for*.
const SKILL_GROUPS: PackedStringArray = ["arms", "tones", "body", "mind", "soul", "voice"]
const GROUP_LABELS: Dictionary = {
	"arms": "Arms", "tones": "Tones", "body": "Body", "mind": "Mind", "soul": "Soul", "voice": "Voice",
}
const FIELD_GROUPS: PackedStringArray = ["body", "mind", "soul", "voice"]

## Creation skill pool (canon step 7 "Reason/Decorum-scaled pool"; formula PROVISIONAL,
## owner ruling R5): CREATION_POOL_BASE + reason + decorum + ancestry/flaw bonuses.
const CREATION_POOL_BASE := 6

const SKILLS: Dictionary = {
	"strain": {"group": "body", "label": "Strain", "attribute": "muster", "loom": LoomSensitivity.NONE, "replaces": "athletics", "mono_token": "SKILL.STRAIN"},
	"lilt": {"group": "body", "label": "Lilt", "attribute": "alacrity", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.LILT"},
	"slip": {"group": "body", "label": "Slip", "attribute": "alacrity", "loom": LoomSensitivity.NONE, "replaces": "sleight_of_hand", "mono_token": "SKILL.SLIP"},
	"tread": {"group": "body", "label": "Tread", "attribute": "alacrity", "loom": LoomSensitivity.NONE, "replaces": "stealth", "mono_token": "SKILL.TREAD"},
	"beastbond": {"group": "soul", "label": "Beastbond", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "beast_handling", "mono_token": "SKILL.BEASTBOND"},
	"varlore": {"group": "mind", "label": "Varlore", "attribute": "reason", "loom": LoomSensitivity.FULL, "replaces": "", "mono_token": "SKILL.VARLORE"},
	"unweave": {"group": "mind", "label": "Unweave", "attribute": "reason", "loom": LoomSensitivity.FULL, "replaces": "investigation", "mono_token": "SKILL.UNWEAVE"},
	"recall": {"group": "mind", "label": "Recall", "attribute": "reason", "loom": LoomSensitivity.NONE, "replaces": "lore", "mono_token": "SKILL.RECALL"},
	"wildlore": {"group": "mind", "label": "Wildlore", "attribute": "reason", "loom": LoomSensitivity.PARTIAL, "loom_note": "Pozor exception", "replaces": "", "mono_token": "SKILL.WILDLORE"},
	"devotion": {"group": "mind", "label": "Devotion", "attribute": "reason", "loom": LoomSensitivity.PARTIAL, "loom_note": "Provisional until owner ruling", "replaces": "", "mono_token": "SKILL.DEVOTION"},
	"undertone": {"group": "soul", "label": "Undertone", "attribute": "intuition", "loom": LoomSensitivity.FULL, "replaces": "insight", "mono_token": "SKILL.UNDERTONE"},
	"mending": {"group": "soul", "label": "Mending", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.MENDING"},
	"ear": {"group": "soul", "label": "Ear", "attribute": "intuition", "loom": LoomSensitivity.PARTIAL, "replaces": "", "mono_token": "SKILL.EAR"},
	"wayfinding": {"group": "soul", "label": "Wayfinding", "attribute": "intuition", "loom": LoomSensitivity.PARTIAL, "loom_note": "Pozor exception", "replaces": "survival", "mono_token": "SKILL.WAYFINDING"},
	"sounding": {"group": "soul", "label": "Sounding", "attribute": "intuition", "loom": LoomSensitivity.FULL, "replaces": "weft_sensing", "mono_token": "SKILL.SOUNDING"},
	"falsetto": {"group": "voice", "label": "Falsetto", "attribute": "decorum", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.FALSETTO"},
	"bellow": {"group": "voice", "label": "Bellow", "attribute": "decorum", "loom": LoomSensitivity.NONE, "karma_direction": -1, "replaces": "", "mono_token": "SKILL.BELLOW"},
	"varum": {"group": "voice", "label": "Vārum", "attribute": "decorum", "loom": LoomSensitivity.NONE, "replaces": "performance", "mono_token": "SKILL.VARUM"},
	"sway": {"group": "voice", "label": "Sway", "attribute": "decorum", "loom": LoomSensitivity.NONE, "karma_direction": 1, "replaces": "persuasion", "mono_token": "SKILL.SWAY"},
	"downbeat": {"group": "voice", "label": "Downbeat", "attribute": "decorum", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.DOWNBEAT"},
	"brace": {"group": "body", "label": "Brace", "attribute": "grit", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.BRACE"},
	"vantage": {"group": "mind", "label": "Vantage", "attribute": "reason", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "SKILL.VANTAGE"},
	# ARMS — weapon skills (PROVISIONAL, owner ruling R2). loom NONE is a canon guard: a
	# class Kit works at full strength in the Hush, so the Loom never taxes a weapon.
	"keen": {"group": "arms", "label": "Keen", "attribute": "alacrity", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "covers": "paired daggers, cleaver, sickle, whip-dagger, knives, short blades"},
	"heft": {"group": "arms", "label": "Heft", "attribute": "muster", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "covers": "greatsword, greatclub, war pick, axes, mauls"},
	"reach": {"group": "arms", "label": "Reach", "attribute": "muster", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "covers": "quarterstaff, halberd, spear, net-and-whip"},
	"loose": {"group": "arms", "label": "Loose", "attribute": "alacrity", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "covers": "blowgun, sling, bow, thrown"},
	"grip": {"group": "arms", "label": "Grip", "attribute": "muster", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "covers": "spiked gauntlet, fists, wrestling, lockpicking-as-combat"},
	# TONES — one per Wheel element, the caster's Resonance in that element (PROVISIONAL,
	# owner ruling R3). Intuition-governed so an Untrained tone reproduces the canon
	# Intuition fizzle reduction exactly; loom NONE because the zone already enters fizzle
	# through agreement_integrity. Only the held (Major/Minor) tones are purchasable in
	# Chapter 1 — see Advancement.buy.
	"tone_sul": {"group": "tones", "label": "Sul Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "sul"},
	"tone_vel": {"group": "tones", "label": "Vel Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "vel"},
	"tone_luth": {"group": "tones", "label": "Luth Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "luth"},
	"tone_khor": {"group": "tones", "label": "Khor Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "khor"},
	"tone_tham": {"group": "tones", "label": "Tham Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "tham"},
	"tone_vekh": {"group": "tones", "label": "Vekh Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "vekh"},
	"tone_mozh": {"group": "tones", "label": "Mozh Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "mozh"},
	"tone_khash": {"group": "tones", "label": "Khash Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "khash"},
	"tone_zhem": {"group": "tones", "label": "Zhem Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "zhem"},
	"tone_zhur": {"group": "tones", "label": "Zhur Tone", "attribute": "intuition", "loom": LoomSensitivity.NONE, "replaces": "", "mono_token": "", "source": "sm-chargen-proposal", "element": "zhur"},
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


## "forge" → "muster"; a DRAMGID id answers itself; unknown → "".
static func canonical_attribute_id(attribute_id: String) -> String:
	if ATTRIBUTES.has(attribute_id):
		return attribute_id
	return str(ATTRIBUTE_RENAMES.get(attribute_id, ""))


## "muster" → "forge"; "doctrine" (no legacy twin) and unknown ids → "".
static func legacy_attribute_id(attribute_id: String) -> String:
	for legacy_id: String in ATTRIBUTE_RENAMES.keys():
		if str(ATTRIBUTE_RENAMES[legacy_id]) == attribute_id:
			return legacy_id
	return ""


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


static func is_skill(skill_id: String) -> bool:
	return SKILLS.has(skill_id)


static func skill_label(skill_id: String) -> String:
	return str(SKILLS.get(skill_id, {}).get("label", skill_id))


static func skill_group(skill_id: String) -> String:
	return str(SKILLS.get(skill_id, {}).get("group", ""))


static func group_label(group: String) -> String:
	return str(GROUP_LABELS.get(group, group))


## Skill ids of one group, in SKILL_IDS order.
static func skills_in_group(group: String) -> PackedStringArray:
	var result := PackedStringArray()
	for skill_id: String in SKILL_IDS:
		if skill_group(skill_id) == group:
			result.append(skill_id)
	return result


static func governing_attribute(skill_id: String) -> String:
	return str(SKILLS.get(skill_id, {}).get("attribute", ""))


static func attribute_label(attribute_id: String) -> String:
	return str(ATTRIBUTES.get(attribute_id, {}).get("label", attribute_id))


static func is_arms_skill(skill_id: String) -> bool:
	return skill_group(skill_id) == GROUP_ARMS


static func is_tone_skill(skill_id: String) -> bool:
	return skill_group(skill_id) == GROUP_TONES


## "khash" → "tone_khash"; empty/unknown → "".
static func tone_skill_for(element: Variant) -> String:
	var skill_id := TONE_SKILL_PREFIX + str(element).strip_edges().to_lower()
	return skill_id if is_tone_skill(skill_id) else ""


## "tone_khash" → "khash"; non-tone → "".
static func element_for_tone(skill_id: String) -> String:
	return str(SKILLS.get(skill_id, {}).get("element", "")) if is_tone_skill(skill_id) else ""


## The tone opposed on the Wheel ("tone_khash" → "tone_luth"); "" for non-tones.
static func opposed_tone(skill_id: String) -> String:
	var element := element_for_tone(skill_id)
	if element.is_empty():
		return ""
	return tone_skill_for(ElementWheel.opposite(element))


## Canon step 7 pool (PROVISIONAL R5). `bonus_points` carries ancestry/flaw grants.
static func creation_skill_pool(attributes: Dictionary, bonus_points: int = 0) -> int:
	var reason := int(attributes.get(String(ATTR_REASON), ATTRIBUTE_FLOOR))
	var decorum := int(attributes.get(String(ATTR_DECORUM), ATTRIBUTE_FLOOR))
	return maxi(CREATION_POOL_BASE + reason + decorum + bonus_points, 0)
