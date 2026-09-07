extends SceneTree
## Class-resource numeric sweep — Wave B item B11 (#234).
##
## Canonical invocation:
##   godot --headless --path . --script res://tools/class_resource_sweep.gd
##   (add `--quit-after 200` as a safety net; the tool calls quit() itself)
##
## READ-ONLY. It reads the ten shipped `ClassResource` subclasses' PROVISIONAL
## constants, calls the RATIFIED `SkillCheckService.fizzle_percent()` for every
## fizzle figure it needs, and prints CSV sections. It changes no behaviour and
## writes nothing. `docs/class-resources-numbers.md` is the human-readable
## reading of this output; `test/unit/test_class_resource_numbers.gd` pins the
## pure functions below so the doc's tables cannot drift from the code.
##
## Every model function here is PURE and DETERMINISTIC — no RNG, no engine
## state — precisely so the doc's numbers can be re-derived and asserted.
##
## The three battle lengths and the enemy HP band are ASSUMPTIONS, stated so
## they can be argued with: `data/generated/encounters.json` puts authored enemy
## HP between 14 and 36, and `PartyMember.max_hp` defaults to 10.

const FIZZLE_TABLE_PATH := "res://globals/default_fizzle_table.tres"
const SKILL_CHECK_SCRIPT := preload("res://globals/skill_check.gd")

## Accords swept: Dom, Wilds, Dorthkor Road, Wound Lip as proposed in
## `docs/thinning-gradient.md` (effective, after the per-tier penalty).
const ACCORDS := [95.0, 80.0, 60.0, 40.0]
const BATTLE_LENGTHS := [6, 10, 14]
const ENEMY_HP_BAND := [14, 36]
const PARTY_HP_DEFAULT := 10

## Candidate values swept for each PROVISIONAL constant. The SHIPPED value is
## always included so the grid shows what is live beside what is proposed.
const SCAR_CAPS := [2, 3, 5, 8]
const TOKEN_CAPS := [1, 2, 3, 5]
const HUNGER_CAPS := [3, 5, 8]
const CLARITY_CAPS := [2, 3, 5]
const ENTRY_CAPS := [2, 3, 5]
const THREAD_CAPS := [2, 3, 5]
const BREATH_REFUNDS := [1, 2, 3]
const BALANCE_MULTIPLIERS := [1.1, 1.25, 1.5]
const BALANCE_PENALTIES := [5.0, 10.0, 15.0, 25.0]

## Hits taken per round, for the Scar bank. A party member has 10 max HP and
## authored strikes land for a few points, so "one hit every other round" is
## the survivable end and "two a round" is the round before a wipe.
const HITS_PER_ROUND := [0.5, 1.0, 2.0]

## Candidate Attribution tables. `shipped` is the placeholder in
## `OfshutjeAttribution.EFFECT_TABLE`; the others add a floor and a tail.
const ATTRIBUTION_TABLES := {
	"shipped": [1, 2, 3],
	"floored": [2, 2, 3, 4],
	"tailed": [1, 1, 2, 2, 3, 6],
}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var skill_check: SkillCheckService = SKILL_CHECK_SCRIPT.new()
	skill_check.fizzle_table = load(FIZZLE_TABLE_PATH)
	_print_shipped_constants()
	_print_fickah_floor(skill_check)
	_print_maiiam_tradeoff(skill_check)
	_print_vhorr_curve()
	_print_vicoar_tokens(skill_check)
	_print_ironbrand_scars()
	_print_budget_caps()
	_print_attribution_tables()
	_print_haeren_refunds()
	quit()


# --- pure models -------------------------------------------------------------

## Scars banked over a battle. Every HP loss banks one, capped. Returns the
## banked total, how many were LOST to the cap, and the round the cap was first
## reached (0 when it never was).
static func scar_bank(rounds: int, hits_per_round: float, cap: int) -> Dictionary:
	var banked := 0
	var wasted := 0
	var capped_at := 0
	var pending := 0.0
	for round_index in range(1, rounds + 1):
		pending += hits_per_round
		while pending >= 1.0:
			pending -= 1.0
			if banked >= cap:
				wasted += 1
				continue
			banked += 1
			if banked == cap and capped_at == 0:
				capped_at = round_index
	return {"banked": banked, "wasted": wasted, "capped_at_round": capped_at}


## Failure Tokens banked by a battle's fizzles. Deterministic: the fizzle rate
## is accumulated rather than rolled, so `casts` casts at 25% bank exactly
## `casts / 4` tokens. `spend_every` models the player spending one as soon as
## that many are banked; 0 means hoarding.
static func token_bank(casts: int, fizzle_percent: float, cap: int, spend_every: int) -> Dictionary:
	var held := 0
	var banked := 0
	var wasted := 0
	var spent := 0
	var pending := 0.0
	for _cast in casts:
		pending += fizzle_percent / 100.0
		while pending >= 1.0:
			pending -= 1.0
			banked += 1
			if held >= cap:
				wasted += 1
				continue
			held += 1
		if spend_every > 0 and held >= spend_every:
			held -= 1
			spent += 1
	return {"banked": banked, "wasted": wasted, "held": held, "spent": spent}


## Husk-bearer's Hunger curve against ONE target. The owner lands one action a
## round (+1 Hunger); the queued DoT fires the round after at the Hunger it was
## queued with and re-queues itself while the target lives, so the tick in round
## r is `min(r - 1, cap)`. Returns the peak Hunger, the cumulative DoT damage,
## and the round the cumulative total passes each end of the enemy HP band.
static func hunger_curve(rounds: int, cap: int) -> Dictionary:
	var total := 0
	var kills_low := 0
	var kills_high := 0
	for round_index in range(2, rounds + 1):
		total += mini(round_index - 1, cap)
		if kills_low == 0 and total >= ENEMY_HP_BAND[0]:
			kills_low = round_index
		if kills_high == 0 and total >= ENEMY_HP_BAND[1]:
			kills_high = round_index
	return {
		"peak_hunger": mini(rounds, cap),
		"total_dot": total,
		"kills_14hp_by_round": kills_low,
		"kills_36hp_by_round": kills_high,
	}


## Mirrorblade's Balance trade-off. Unbalanced multiplies damage and subtracts
## accord, so the question is whether expected damage per cast RISES. Both EVs
## are `damage x landed fraction`, with balanced damage normalised to 1.0.
static func balance_tradeoff(
	balanced_fizzle: float, unbalanced_fizzle: float, multiplier: float
) -> Dictionary:
	var balanced_ev := 1.0 * (1.0 - balanced_fizzle / 100.0)
	var unbalanced_ev := multiplier * (1.0 - unbalanced_fizzle / 100.0)
	return {
		"balanced_ev": balanced_ev,
		"unbalanced_ev": unbalanced_ev,
		"delta": unbalanced_ev - balanced_ev,
		"worth_it": unbalanced_ev > balanced_ev,
	}


## A cap expressed as a per-battle budget: uses available, and how much of a
## battle each use has to cover.
static func budget_row(cap: int, rounds: int) -> Dictionary:
	return {
		"cap": cap,
		"rounds": rounds,
		"rounds_per_use": float(rounds) / float(maxi(cap, 1)),
	}


## Hidden-draw table shape: what the storm can pay, and how wide the swing is.
static func table_stats(rows: Array) -> Dictionary:
	if rows.is_empty():
		return {"rows": 0, "min": 0, "max": 0, "mean": 0.0, "spread": 0}
	var lowest := int(rows[0])
	var highest := int(rows[0])
	var total := 0
	for value: Variant in rows:
		var row := int(value)
		lowest = mini(lowest, row)
		highest = maxi(highest, row)
		total += row
	return {
		"rows": rows.size(),
		"min": lowest,
		"max": highest,
		"mean": float(total) / float(rows.size()),
		"spread": highest - lowest,
	}


# --- printers ----------------------------------------------------------------

func _print_shipped_constants() -> void:
	print("## shipped_constants")
	print("patron,class,constant,shipped_value")
	print("kero,Ironbrand,MAX_SCARS,%d" % IronbrandScars.MAX_SCARS)
	print("vicoar,Flamebinder,MAX_TOKENS,%d" % VicoarInstructiveFailure.MAX_TOKENS)
	print("vhorr,Husk-bearer,MAX_HUNGER,%d" % VhorrHunger.MAX_HUNGER)
	print("vhorr,Husk-bearer,BREATH_REFUND,%d" % VhorrHunger.BREATH_REFUND)
	print("haeren,River-Mother,BREATH_REFUND,%d" % HaerenNameLedger.BREATH_REFUND)
	print("stuid,Lensbearer,MAX_CLARITY,%d" % StuidClarity.MAX_CLARITY)
	print("pazzah,Oathclock,MAX_ENTRIES,%d" % PazzahLedger.MAX_ENTRIES)
	print("izhakel,Threadwalker,MAX_THREADS,%d" % IzhakelThreads.MAX_THREADS)
	print("maiiam,Mirrorblade,UNBALANCED_AFTER_STREAK,%d" % MaiiamBalance.UNBALANCED_AFTER_STREAK)
	print("maiiam,Mirrorblade,UNBALANCED_DAMAGE_MULTIPLIER,%s"
		% str(MaiiamBalance.UNBALANCED_DAMAGE_MULTIPLIER))
	print("maiiam,Mirrorblade,UNBALANCED_FIZZLE_INTEGRITY_PENALTY,%s"
		% str(MaiiamBalance.UNBALANCED_FIZZLE_INTEGRITY_PENALTY))
	print("fickah,Locksmirk,FIZZLE_FLOOR_PERCENT,%s" % str(FickahRuleBreaker.FIZZLE_FLOOR_PERCENT))
	print("ofshutje,Stormbearer,EFFECT_TABLE_ROWS,%d" % OfshutjeAttribution.EFFECT_TABLE.size())
	print("")


func _print_fickah_floor(skill_check: SkillCheckService) -> void:
	print("## fickah_fizzle_floor")
	print("accord,breadth,magnitude,mastery,other_patron,locksmirk")
	for accord: float in ACCORDS:
		for breadth: String in ["tone", "chord", "triad"]:
			for magnitude: String in ["note", "phrase", "song"]:
				for mastery: bool in [false, true]:
					var other := skill_check.fizzle_percent(
						accord, breadth, 0, magnitude, 2, mastery, "Ironbrand"
					)
					var locksmirk := skill_check.fizzle_percent(
						accord, breadth, 0, magnitude, 2, mastery, "Locksmirk"
					)
					print("%s,%s,%s,%s,%s,%s"
						% [accord, breadth, magnitude, mastery, other, locksmirk])
	print("")


func _print_maiiam_tradeoff(skill_check: SkillCheckService) -> void:
	print("## maiiam_balance_tradeoff")
	print("accord,magnitude,penalty,multiplier,balanced_fizzle,unbalanced_fizzle,"
		+ "balanced_ev,unbalanced_ev,delta,worth_it")
	for accord: float in ACCORDS:
		for magnitude: String in ["note", "phrase", "song", "refrain"]:
			var balanced := skill_check.fizzle_percent(accord, "tone", 0, magnitude, 2, false, "")
			for penalty: float in BALANCE_PENALTIES:
				var unbalanced := skill_check.fizzle_percent(
					maxf(accord - penalty, 0.0), "tone", 0, magnitude, 2, false, ""
				)
				for multiplier: float in BALANCE_MULTIPLIERS:
					var row := balance_tradeoff(balanced, unbalanced, multiplier)
					print("%s,%s,%s,%s,%s,%s,%.3f,%.3f,%.3f,%s" % [
						accord, magnitude, penalty, multiplier, balanced, unbalanced,
						row["balanced_ev"], row["unbalanced_ev"], row["delta"], row["worth_it"],
					])
	print("")


func _print_vhorr_curve() -> void:
	print("## vhorr_hunger_curve")
	print("cap,rounds,peak_hunger,total_dot,kills_14hp_by_round,kills_36hp_by_round")
	for cap: int in HUNGER_CAPS:
		for rounds: int in BATTLE_LENGTHS:
			var row := hunger_curve(rounds, cap)
			print("%d,%d,%d,%d,%d,%d" % [
				cap, rounds, row["peak_hunger"], row["total_dot"],
				row["kills_14hp_by_round"], row["kills_36hp_by_round"],
			])
	print("")


func _print_vicoar_tokens(skill_check: SkillCheckService) -> void:
	print("## vicoar_token_bank")
	print("accord,magnitude,fizzle_percent,casts,cap,banked,wasted,held")
	for accord: float in ACCORDS:
		for magnitude: String in ["note", "song"]:
			var fizzle := skill_check.fizzle_percent(accord, "tone", 0, magnitude, 2, false, "")
			for rounds: int in BATTLE_LENGTHS:
				for cap: int in TOKEN_CAPS:
					var row := token_bank(rounds, fizzle, cap, 0)
					print("%s,%s,%s,%d,%d,%d,%d,%d" % [
						accord, magnitude, fizzle, rounds, cap,
						row["banked"], row["wasted"], row["held"],
					])
	print("")


func _print_ironbrand_scars() -> void:
	print("## ironbrand_scar_bank")
	print("party_max_hp,hits_per_round,rounds,cap,banked,wasted,capped_at_round")
	for hits: float in HITS_PER_ROUND:
		for rounds: int in BATTLE_LENGTHS:
			for cap: int in SCAR_CAPS:
				var row := scar_bank(rounds, hits, cap)
				print("%d,%s,%d,%d,%d,%d,%d" % [
					PARTY_HP_DEFAULT, hits, rounds, cap,
					row["banked"], row["wasted"], row["capped_at_round"],
				])
	print("")


func _print_budget_caps() -> void:
	print("## budget_caps")
	print("patron,constant,cap,rounds,rounds_per_use")
	var budgets := {
		"stuid/MAX_CLARITY": CLARITY_CAPS,
		"pazzah/MAX_ENTRIES": ENTRY_CAPS,
		"izhakel/MAX_THREADS": THREAD_CAPS,
	}
	for key: String in budgets:
		var parts := key.split("/")
		for cap: int in budgets[key]:
			for rounds: int in BATTLE_LENGTHS:
				var row := budget_row(cap, rounds)
				print("%s,%s,%d,%d,%.2f"
					% [parts[0], parts[1], cap, rounds, row["rounds_per_use"]])
	print("")


func _print_attribution_tables() -> void:
	print("## ofshutje_attribution_tables")
	print("table,rows,min,max,mean,spread")
	for name: String in ATTRIBUTION_TABLES:
		var stats := table_stats(ATTRIBUTION_TABLES[name])
		print("%s,%d,%d,%d,%.2f,%d" % [
			name, stats["rows"], stats["min"], stats["max"], stats["mean"], stats["spread"],
		])
	print("")


func _print_haeren_refunds() -> void:
	print("## haeren_breath_refunds")
	print("refund,names_recorded,breath_returned,breath_max,notes_bought")
	# A Note costs 3 Breath (docs/casting-economy.md); the base pool is 15.
	var note_cost := 3
	var breath_max := PartyMember.DEFAULT_BREATH_MAX
	for refund: int in BREATH_REFUNDS:
		for names in range(1, 5):
			var returned := refund * names
			print("%d,%d,%d,%d,%.2f" % [
				refund, names, returned, breath_max, float(returned) / float(note_cost),
			])
	print("")
