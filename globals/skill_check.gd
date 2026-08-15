class_name SkillCheckService
extends Node
## The single percentile resolution service for all game checks.
##
## `resolve()` is the commit-time path. `preview()` only derives the chance and
## never consumes random numbers or Expert rerolls. Dialogue Manager discovers
## `check()` as a top-level autoload method, so [if check("lore", 45) /] uses
## this same service without a second dialogue-only implementation.

const MAX_EFFECTIVE_PERCENT := 95.0
const MIN_ROLL := 1
const MAX_ROLL := 100
const EXPERT_REROLL_CAP := 1
const DEFAULT_FIZZLE_TABLE: FizzleTable = preload("res://globals/default_fizzle_table.tres")

const SKILL_DEFINITIONS: Dictionary = {
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
const TIER_BONUS: Dictionary = {
	"untrained": 0.0,
	"trained": 20.0,
	"expert": 35.0,
}

var fizzle_table: FizzleTable = DEFAULT_FIZZLE_TABLE
var random_number_generator := RandomNumberGenerator.new()
var _expert_rerolls_used: Dictionary = {}


func _ready() -> void:
	random_number_generator.randomize()


## Return the effective percentage without rolling or consuming a reroll.
func preview(
	skill_name: String,
	member: PartyMember = null,
	situational_modifiers: float = 0.0
) -> float:
	var normalized_skill := _normalize_skill_name(skill_name)
	if not SKILL_DEFINITIONS.has(normalized_skill):
		return 0.0
	var subject := member if member != null else _protagonist()
	if subject == null:
		return 0.0
	var definition: Dictionary = SKILL_DEFINITIONS[normalized_skill]
	var attribute_name: String = definition.attribute
	var attribute_value := float(subject.attributes.get(attribute_name, 0.0))
	var tier_name := _normalize_tier(str(subject.skill_tiers.get(normalized_skill, "untrained")))
	var tier_bonus := float(TIER_BONUS.get(tier_name, 0.0))
	var advancement_percent := float(subject.skill_percentages.get(normalized_skill, 0.0))
	return clampf(
		attribute_value * 8.0 + tier_bonus + advancement_percent + situational_modifiers,
		0.0,
		MAX_EFFECTIVE_PERCENT
	)


## Explicitly named alias for callers that want the derived value.
func effective_percent(
	skill_name: String,
	member: PartyMember = null,
	situational_modifiers: float = 0.0
) -> float:
	return preview(skill_name, member, situational_modifiers)


## Resolve a committed check. `forced_rolls` exists for deterministic tests and
## tools; production callers leave it empty and use the service RNG.
func resolve(
	skill_name: String,
	member: PartyMember = null,
	situational_modifiers: float = 0.0,
	scene_id: String = "",
	forced_rolls: Array[int] = []
) -> Dictionary:
	var normalized_skill := _normalize_skill_name(skill_name)
	var subject := member if member != null else _protagonist()
	var effective := preview(normalized_skill, subject, situational_modifiers)
	var rolls: Array[int] = forced_rolls.duplicate()
	var first_roll := _next_roll(rolls)
	var succeeded := _roll_succeeds(first_roll, effective)
	var used_reroll := false
	if not succeeded and subject != null and _is_expert(subject, normalized_skill):
		var reroll_key := _reroll_key(subject, normalized_skill, scene_id)
		var rerolls_used := clampi(int(_expert_rerolls_used.get(reroll_key, 0)), 0, EXPERT_REROLL_CAP)
		if rerolls_used < EXPERT_REROLL_CAP:
			_expert_rerolls_used[reroll_key] = rerolls_used + 1
			used_reroll = true
			var reroll := _next_roll(rolls)
			succeeded = _roll_succeeds(reroll, effective)
			first_roll = reroll
	return {
		"success": succeeded,
		"roll": first_roll,
		"effective_percent": effective,
		"rerolled": used_reroll,
	}


## Dialogue conditions are previews: evaluating a response must not roll before
## the player commits to it. `difficulty` is the minimum effective percentage
## required by the authored gate, while the eventual committed resolution still
## goes through resolve().
func check(skill_name: String, difficulty: float, member: PartyMember = null) -> bool:
	return preview(skill_name, member) >= clampf(difficulty, 0.0, MAX_EFFECTIVE_PERCENT)


func reset_scene_rerolls(scene_id: String = "") -> void:
	var prefix := scene_id + ":"
	for key: String in _expert_rerolls_used.keys():
		if key.begins_with(prefix):
			_expert_rerolls_used.erase(key)


func to_dict() -> Dictionary:
	return normalize_save_data({"expert_rerolls_used": _expert_rerolls_used})


func from_dict(data: Variant) -> void:
	var normalized := normalize_save_data(data)
	_expert_rerolls_used = normalized["expert_rerolls_used"].duplicate(true)


static func normalize_save_data(data: Variant) -> Dictionary:
	var normalized_used: Dictionary = {}
	if not data is Dictionary:
		return {"expert_rerolls_used": normalized_used}
	var raw_used: Variant = data.get("expert_rerolls_used", {})
	if not raw_used is Dictionary:
		return {"expert_rerolls_used": normalized_used}
	for key: Variant in raw_used:
		if not key is String:
			continue
		var raw_count: Variant = raw_used[key]
		var count := 0
		if raw_count is bool:
			count = 1 if raw_count else 0
		elif raw_count is int or raw_count is float:
			count = int(raw_count)
		normalized_used[String(key)] = clampi(count, 0, EXPERT_REROLL_CAP)
	return {"expert_rerolls_used": normalized_used}


## Calculate the casting-side fizzle chance from the tunable Resource table.
##
## The FORMULA IS THE SINGLE SOURCE OF TRUTH (ratified 2026-08-03). The table
## supplies inputs only — it must never carry precomputed outputs that could
## disagree with the formula. An earlier revision short-circuited to a stored
## `sanity_readings` lookup, which silently overrode the formula at named points;
## that path is deliberately gone. If a documented reading and the formula ever
## disagree again, the documentation is wrong, not the code.
##
## Percentages are rounded to the nearest integer; exact .5 values use the
## authored table's display convention (small Note values round upward, while
## larger Song/Refrain values truncate) so the ratified readings remain exact.
func fizzle_percent(
	agreement_integrity: float,
	breadth: String,
	strain_steps: int,
	magnitude: String,
	pitch: int,
	mastery: bool = false,
	patron: String = ""
) -> float:
	var breadth_key := breadth.to_lower()
	var magnitude_key := magnitude.to_lower()
	var base := clampf(100.0 - agreement_integrity, 0.0, 100.0)
	var breadth_add := float(fizzle_table.breadth_add.get(breadth_key, 0.0))
	var strain_add := float(fizzle_table.strain_add.get(str(strain_steps), 0.0))
	var multiplier := float(fizzle_table.magnitude_multiplier.get(magnitude_key, 1.0))
	var pitch_reduction := maxi(pitch - 2, 0) * 2.0
	var mastery_reduction := 0.0
	if mastery and magnitude_key in ["note", "phrase"]:
		mastery_reduction = 100.0
	var raw := clampf(
		(base + breadth_add + strain_add) * multiplier - pitch_reduction - mastery_reduction,
		0.0,
		MAX_EFFECTIVE_PERCENT
	)
	var rounded := _round_fizzle(raw, magnitude_key)
	if _is_fickah_or_locksmirk(patron):
		return maxf(5.0, rounded)
	return rounded


func calculate_fizzle(
	agreement_integrity: float,
	breadth: String,
	strain_steps: int,
	magnitude: String,
	pitch: int,
	mastery: bool = false,
	patron: String = ""
) -> float:
	return fizzle_percent(agreement_integrity, breadth, strain_steps, magnitude, pitch, mastery, patron)


func _round_fizzle(value: float, magnitude: String) -> float:
	var fractional := value - floorf(value)
	if is_equal_approx(fractional, 0.5) and magnitude in ["song", "refrain"]:
		return floorf(value)
	return floorf(value + 0.5)


func _roll_succeeds(roll: int, effective: float) -> bool:
	return roll >= MIN_ROLL and roll <= MAX_ROLL and roll <= effective


func _next_roll(forced_rolls: Array[int]) -> int:
	if not forced_rolls.is_empty():
		return clampi(forced_rolls.pop_front(), MIN_ROLL, MAX_ROLL)
	return random_number_generator.randi_range(MIN_ROLL, MAX_ROLL)


func _is_expert(member: PartyMember, skill_name: String) -> bool:
	return _normalize_tier(str(member.skill_tiers.get(skill_name, "untrained"))) == "expert"


func _reroll_key(member: PartyMember, skill_name: String, scene_id: String) -> String:
	var resolved_scene := scene_id
	if resolved_scene.is_empty() and is_inside_tree() and get_tree().current_scene != null:
		resolved_scene = get_tree().current_scene.scene_file_path
	if resolved_scene.is_empty():
		resolved_scene = "default"
	# `member.id` and NOT `get_instance_id()`: the latter is process-local and
	# allocation-order dependent, so the same encounter with the same inputs
	# produces a different key on a second run. Gate T criterion 7 requires
	# identical inputs to give identical results. `GameState` populates `id` for
	# every recruit; the display-name fallback only covers a hand-built member in
	# a test fixture.
	var member_key := member.id if not member.id.is_empty() else member.display_name
	return "%s:%s:%s" % [resolved_scene, member_key, skill_name]


func _normalize_skill_name(skill_name: String) -> String:
	return skill_name.to_lower().replace("-", "_").replace(" ", "_")


func _normalize_tier(tier_name: String) -> String:
	return tier_name.to_lower().replace("-", "_").replace(" ", "_")


func _is_fickah_or_locksmirk(patron: String) -> bool:
	var normalized := patron.to_lower().replace("-", "_")
	return normalized.contains("fickah") or normalized.contains("locksmirk")


func _protagonist() -> PartyMember:
	var state := get_node_or_null("/root/GameState")
	if state != null and state.has_method("protagonist"):
		return state.protagonist()
	return null
