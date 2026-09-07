extends SceneTree
## DRAMGID derived-stat sweep — `docs/architecture-dramgid.md` §6.
##
## Canonical invocation:
##   godot --headless --path . --script res://tools/dramgid_derived_sweep.gd
##
## READ-ONLY. It prints the grids `docs/dramgid-numbers.md` is written from:
## every derived stat across the point-buy range, the migration report against
## the shipped party, and a re-run of the ratified fizzle readings with
## Intuition in Pitch's seat. It changes nothing.
##
## Pure and deterministic, like `tools/class_resource_sweep.gd` — the doc's
## tables are only worth reading if re-running this reproduces them exactly,
## and `test/unit/test_dramgid_numbers.gd` asserts it does.
##
## No autoload is referenced anywhere in this file or in what it preloads.
## `Renown` and `GameState` are autoloads whose identifiers do not exist in a
## `--script` run, so the shipped party is mirrored in `SHIPPED_PARTY` below and
## the TEST — which runs inside a booted engine — asserts the mirror is honest.

const FIZZLE_TABLE_PATH := "res://globals/default_fizzle_table.tres"
const SKILL_CHECK_SCRIPT := preload("res://globals/skill_check.gd")
const DERIVED := preload("res://globals/stats/dramgid_derived.gd")
const SCHEMA := preload("res://globals/stats/dramgid_schema.gd")

## The seven authored `PartyMember`s, as `GameState._make_member()` builds them:
## `[id, max_hp, attack, defense]`. Mirrored, not read — see the header.
const SHIPPED_PARTY := [
	["vex", 44, 9, 5],
	["serai-lun", 30, 8, 2],
	["old-grumbrand", 38, 5, 6],
	["wyneth-hallow-tide", 34, 4, 5],
	["ressa-quickfingers", 28, 9, 1],
	["korrath-ninefold", 42, 7, 6],
	["maura-greyfen", 34, 6, 5],
]

## §6's stated tolerance for migrated party HP.
const HP_TOLERANCE := 0.15

## `docs/casting-economy.md`.
const BREATH_COSTS := {"note": 3, "phrase": 6, "song": 12, "refrain": 24}

const ACCORDS := [95.0, 80.0, 60.0, 40.0]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var skill_check: SkillCheckService = SKILL_CHECK_SCRIPT.new()
	skill_check.fizzle_table = load(FIZZLE_TABLE_PATH)
	_print_derived_grid()
	_print_hp_migration()
	_print_attack_defense_migration()
	_print_breath_budget()
	_print_ct_speed()
	_print_fizzle_reduction(skill_check)
	quit()


# --- pure models -------------------------------------------------------------

## Best fit of a formula to an authored value: the point-buy value whose derived
## stat is nearest, and the signed relative error of that choice.
static func nearest_point(authored: int, derived: Array) -> Dictionary:
	var best_point := SCHEMA.ATTRIBUTE_FLOOR
	var best_value := int(derived[0])
	var best_error := absf(float(best_value - authored) / maxf(float(authored), 1.0))
	for index in derived.size():
		var value := int(derived[index])
		var error := absf(float(value - authored) / maxf(float(authored), 1.0))
		if error < best_error:
			best_error = error
			best_value = value
			best_point = SCHEMA.ATTRIBUTE_FLOOR + index
	return {
		"point": best_point,
		"value": best_value,
		"error": float(best_value - authored) / maxf(float(authored), 1.0),
	}


## The derived values a formula produces across the whole point-buy range.
static func across_range(callable: Callable) -> Array:
	var values: Array = []
	for point in range(SCHEMA.ATTRIBUTE_FLOOR, SCHEMA.ATTRIBUTE_CAP + 1):
		values.append(int(callable.call(point)))
	return values


## How much of a Breath pool each magnitude costs, and how many fit.
static func breath_budget(pool: int) -> Dictionary:
	var budget: Dictionary = {}
	for magnitude: String in BREATH_COSTS:
		budget[magnitude] = pool / int(BREATH_COSTS[magnitude])
	return budget


## Ratio between the strongest and weakest derived value a formula can produce.
## The design question a 2..5 point buy raises is not the endpoints, it is this.
static func spread(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var lowest := int(values[0])
	var highest := int(values[0])
	for value: Variant in values:
		lowest = mini(lowest, int(value))
		highest = maxi(highest, int(value))
	return float(highest) / maxf(float(lowest), 1.0)


# --- printers ----------------------------------------------------------------

func _print_derived_grid() -> void:
	print("## derived_grid")
	print("point,max_hp,breath_max,attack,defense")
	for point in range(SCHEMA.ATTRIBUTE_FLOOR, SCHEMA.ATTRIBUTE_CAP + 1):
		print("%d,%d,%d,%d,%d" % [
			point,
			DERIVED.max_hp(point),
			DERIVED.breath_max(point),
			DERIVED.attack(point),
			DERIVED.defense(point),
		])
	print("spread,%.2f,%.2f,%.2f,%.2f" % [
		spread(across_range(DERIVED.max_hp)),
		spread(across_range(DERIVED.breath_max)),
		spread(across_range(DERIVED.attack)),
		spread(across_range(DERIVED.defense)),
	])
	print("")


func _print_hp_migration() -> void:
	print("## hp_migration")
	print("member,authored_hp,grit,derived_hp,error_percent,within_15pct")
	var derived := across_range(DERIVED.max_hp)
	for row: Array in SHIPPED_PARTY:
		var fit := nearest_point(int(row[1]), derived)
		print("%s,%d,%d,%d,%.1f,%s" % [
			row[0], int(row[1]), int(fit["point"]), int(fit["value"]),
			float(fit["error"]) * 100.0, absf(float(fit["error"])) <= HP_TOLERANCE,
		])
	print("")


func _print_attack_defense_migration() -> void:
	print("## attack_defense_migration")
	print("member,authored_attack,muster,derived_attack,authored_defense,alacrity,derived_defense")
	var attacks := across_range(DERIVED.attack)
	var defenses := across_range(DERIVED.defense)
	for row: Array in SHIPPED_PARTY:
		var attack_fit := nearest_point(int(row[2]), attacks)
		var defense_fit := nearest_point(int(row[3]), defenses)
		print("%s,%d,%d,%d,%d,%d,%d" % [
			row[0],
			int(row[2]), int(attack_fit["point"]), int(attack_fit["value"]),
			int(row[3]), int(defense_fit["point"]), int(defense_fit["value"]),
		])
	print("")


func _print_breath_budget() -> void:
	print("## breath_budget")
	print("intuition,breath_max,notes,phrases,songs,refrains")
	for point in range(SCHEMA.ATTRIBUTE_FLOOR, SCHEMA.ATTRIBUTE_CAP + 1):
		var pool := DERIVED.breath_max(point)
		var budget := breath_budget(pool)
		print("%d,%d,%d,%d,%d,%d" % [
			point, pool,
			int(budget["note"]), int(budget["phrase"]),
			int(budget["song"]), int(budget["refrain"]),
		])
	print("")


func _print_ct_speed() -> void:
	# §6 asks to confirm or propose `6 + reason/2`. It is NOT applied here:
	# `CombatRules.charge_speed_attribute` is still `edge`, and moving it is
	# §3.9 (F3b, blocked on #281). This grid is the evidence for that decision.
	print("## ct_speed_candidates")
	print("reason,six_plus_half,five_plus_reason,four_plus_double")
	for point in range(SCHEMA.ATTRIBUTE_FLOOR, SCHEMA.ATTRIBUTE_CAP + 1):
		print("%d,%d,%d,%d" % [point, 6 + point / 2, 5 + point, 4 + point * 2])
	print("spread,%.2f,%.2f,%.2f" % [
		float(6 + SCHEMA.ATTRIBUTE_CAP / 2) / float(6 + SCHEMA.ATTRIBUTE_FLOOR / 2),
		float(5 + SCHEMA.ATTRIBUTE_CAP) / float(5 + SCHEMA.ATTRIBUTE_FLOOR),
		float(4 + SCHEMA.ATTRIBUTE_CAP * 2) / float(4 + SCHEMA.ATTRIBUTE_FLOOR * 2),
	])
	print("")


func _print_fizzle_reduction(skill_check: SkillCheckService) -> void:
	# §6: re-run the ratified fizzle readings with Intuition in Pitch's seat and
	# report any reading that changes. The formula is byte-identical
	# (`max(x - 2, 0) * 2`); this grid is the proof, not the assertion.
	print("## fizzle_with_intuition")
	print("accord,breadth,magnitude,intuition,fizzle_percent")
	for accord: float in ACCORDS:
		for breadth: String in ["tone", "chord", "triad"]:
			for magnitude: String in ["note", "phrase", "song", "refrain"]:
				for intuition in range(SCHEMA.ATTRIBUTE_FLOOR, SCHEMA.ATTRIBUTE_CAP + 1):
					print("%s,%s,%s,%d,%s" % [
						accord, breadth, magnitude, intuition,
						skill_check.fizzle_percent(
							accord, breadth, 0, magnitude, intuition, false, ""
						),
					])
	print("")
