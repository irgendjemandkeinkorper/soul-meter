class_name MeasureEffects
extends RefCounted
## What each DRAMGID measure does for one character, in live numbers (calling and measures S2,
## docs/design/calling-and-measures-2026-11-25.md). Chargen's MEASURES tab and the character sheet
## read it so a point placed is a number the player can see.
##
## Pure, and it restates no formula: every number comes from the code that uses it in play —
## DramgidDerived (HP, Breath, attack, defense), CombatRules (turn speed), Resolution (to-hit per
## point), SkillCheckService (skill base, Intuition's fizzle reduction), DramgidSchema (creation
## pool), Renown (Karma scale) and the class resource itself (the patron measure's readout).

const RenownScript := preload("res://globals/renown.gd")
const RULES_PATH := "res://data/combat/combat_rules.tres"

static var _rules: CombatRules = null


## One entry per line: `{"key", "text"}`. `key` is stable across values, so `next_point()` can say
## which lines a point would move. `class_id` adds the patron-measure line to its measure's list.
static func lines(attribute_id: String, value: int, class_id: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match attribute_id:
		"doctrine":
			result.append(_line("karma", "Karma moves ×%.1f" % karma_scale(value)))
		"reason":
			result.append(_line("speed", "Turn speed %d" % turn_speed(value)))
		"alacrity":
			result.append(_line("defense", "Defense %d (each hit on you −%d)" % [
				DramgidDerived.defense(value), DramgidDerived.defense(value)]))
			result.append(_line("to_hit", "Hit and dodge %+d%% vs Alacrity 3" % to_hit_points(value)))
		"muster":
			result.append(_line("attack", "Weapon attack %d" % DramgidDerived.attack(value)))
		"grit":
			result.append(_line("hp", "HP %d" % DramgidDerived.max_hp(value)))
		"intuition":
			result.append(_line("breath", "Breath %d" % DramgidDerived.breath_max(value)))
			var fizzle := SkillCheckService.intuition_fizzle_reduction(value)
			if fizzle > 0.0:
				result.append(_line("fizzle", "Fizzle −%d%%" % int(fizzle)))
	var governed := skills_governed_by(attribute_id)
	if not governed.is_empty():
		result.append(_line("skills", "%d skill%s from %d%%" % [
			governed.size(), "" if governed.size() == 1 else "s", skill_base(value)]))
	if attribute_id == String(DramgidSchema.ATTR_INTUITION):
		result.append(_line("tones", "Tones from %d%%" % skill_base(value)))
	if attribute_id in [String(DramgidSchema.ATTR_REASON), String(DramgidSchema.ATTR_DECORUM)]:
		result.append(_line("pool", "+%d creation points" % value))
	var patron := patron_line(attribute_id, value, class_id)
	if not patron.is_empty():
		result.append(_line("patron", patron))
	return result


## The lines joined for one row of the MEASURES tab.
static func summary(attribute_id: String, value: int, class_id: String = "") -> String:
	var texts: PackedStringArray = []
	for line: Dictionary in lines(attribute_id, value, class_id):
		texts.append(str(line["text"]))
	return "  ·  ".join(texts)


## What one more point would change, as "HP 42 · 2 skills from 32%"; "" at the creation cap.
static func next_point(attribute_id: String, value: int, class_id: String = "") -> String:
	if value >= DramgidSchema.ATTRIBUTE_CAP:
		return ""
	var now := {}
	for line: Dictionary in lines(attribute_id, value, class_id):
		now[line["key"]] = line["text"]
	var changed: PackedStringArray = []
	for line: Dictionary in lines(attribute_id, value + 1, class_id):
		if str(now.get(line["key"], "")) != str(line["text"]):
			changed.append(str(line["text"]))
	return "  ·  ".join(changed)


## The class loop at `value` of its patron measure, from the resource combat attaches
## ("Ironbrand: Scars bank up to 4"); "" when `attribute_id` is not the class's measure.
static func patron_line(attribute_id: String, value: int, class_id: String) -> String:
	if class_id.is_empty() or ClassCatalog.patron_measure(class_id) != attribute_id:
		return ""
	var readout := _readout(class_id, value)
	return "%s: %s" % [ClassCatalog.by_id(class_id).get("name", class_id), readout] if not readout.is_empty() else ""


## The class card's line: the loop now, then at each higher value up to the creation cap
## ("Reason 3 now: 3 Clarity each battle. At 4: 4 Clarity each battle. At 5: 5 Clarity each battle.").
static func patron_ladder(class_id: String, value: int) -> String:
	var measure := ClassCatalog.patron_measure(class_id)
	if measure.is_empty():
		return ""
	var parts: PackedStringArray = ["%s %d now: %s." % [
		DramgidSchema.attribute_label(measure), value, _readout(class_id, value)]]
	for higher in range(maxi(value + 1, ClassCatalog.MEASURE_THRESHOLD + 1), DramgidSchema.ATTRIBUTE_CAP + 1):
		parts.append("At %d: %s." % [higher, _readout(class_id, higher)])
	if value >= DramgidSchema.ATTRIBUTE_CAP:
		parts.append("The most a measure reaches at creation.")
	return "  ".join(parts)


static func _readout(class_id: String, value: int) -> String:
	var resource := ClassResourceRegistry.for_patron(ClassCatalog.patron_for(class_id))
	resource.apply_measure(value)
	return resource.measure_readout()


static func turn_speed(value: int) -> int:
	return _combat_rules().charge_speed_at(value)


## The to-hit term against a foe whose Alacrity is 3, the middle of the point-buy.
static func to_hit_points(value: int) -> int:
	return (value - 3) * int(Resolution.PROVISIONAL_TO_HIT["alacrity_mod_per_point"])


static func skill_base(value: int) -> int:
	return roundi(float(value) * SkillCheckService.PERCENT_PER_ATTRIBUTE_POINT)


static func karma_scale(value: int) -> float:
	return float(value) / RenownScript.KARMA_SCALE_DIVISOR


## Field and ARMS skills the attribute governs, in schema order. Tones are one line of their own:
## all ten are Intuition's, but a character holds two.
static func skills_governed_by(attribute_id: String) -> PackedStringArray:
	var result := PackedStringArray()
	for skill_id: String in DramgidSchema.SKILL_IDS:
		if DramgidSchema.is_tone_skill(skill_id):
			continue
		if DramgidSchema.governing_attribute(skill_id) == attribute_id:
			result.append(skill_id)
	return result


static func _combat_rules() -> CombatRules:
	if _rules == null:
		_rules = load(RULES_PATH) as CombatRules
	return _rules


static func _line(key: String, text: String) -> Dictionary:
	return {"key": key, "text": text}
