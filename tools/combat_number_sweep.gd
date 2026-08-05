extends SceneTree
## FR-102a / FR-105a provisional-number sweep (amendment §7, owner decision 2026-08-05).
##
## Sweeps facing × elevation × wheel distance against the damage curve and reports turns-to-kill
## bands, so the transcribed multipliers stop being assertions before they harden into content.
##
## Every multiplier here is PROVISIONAL. They were transcribed from the Elemental Architecture
## doc and the #133 gamble curve; nobody has validated them against real damage numbers. This
## script exists to produce the evidence, not to bless them.
##
## Run:  godot --headless --path . --script res://tools/combat_number_sweep.gd
## Note: this project's headless scripts abort at teardown ~20–30% of the time (see CLAUDE.md).
## Judge the printed report, never the exit code.

# ---- provisional inputs ----

const FACING := {"FRONT": 1.00, "SIDE": 1.10, "BACK": 1.25}
const FACING_HIT := {"FRONT": 0, "SIDE": 8, "BACK": 15}
const ELEV_PER_STEP := 0.10          # +10% damage per step of height advantage
const ELEV_STEPS := [0, 1, 2, 3]     # elevation 0-3
## #133 gamble curve, indexed by wheel distance 0-5.
const RELATION_DAMAGE := [0.50, 0.75, 1.00, 1.10, 1.20, 1.35]
const RELATION_FIZZLE := [0, 3, 6, 9, 12, 15]
const RELATION_NAME := ["SAME", "NEIGHBOUR", "d2", "d3", "d4", "OPPOSED"]

## Reference combatant. Deliberately plain: the point is the multiplier stack, not stat design.
const BASE_POWER := 42.0
const TARGET_HP := 131.0
const BASE_FIZZLE := 15.0            # a Dom-ish zone, Chord/Phrase tier


func _init() -> void:
	print("=== COMBAT NUMBER SWEEP — ALL VALUES PROVISIONAL ===")
	print("base power %.0f · target HP %.0f · base fizzle %.0f%%"
		% [BASE_POWER, TARGET_HP, BASE_FIZZLE])
	_report_multiplier_range()
	_report_stack_concern()
	_report_ttk_bands()
	_report_expected_ttk()
	print("\n=== END SWEEP ===")
	quit()


func _multiplier(facing: String, elev: int, distance: int) -> float:
	return (
		FACING[facing]
		* (1.0 + ELEV_PER_STEP * float(elev))
		* RELATION_DAMAGE[distance]
	)


## Turns to kill, ignoring misses — the raw damage view.
func _ttk(mult: float) -> int:
	var per_hit := BASE_POWER * mult
	if per_hit <= 0.0:
		return 9999
	return int(ceil(TARGET_HP / per_hit))


## Turns to kill including fizzle — what the player actually experiences.
func _expected_ttk(mult: float, distance: int) -> float:
	var fizzle := clampf(BASE_FIZZLE + float(RELATION_FIZZLE[distance]), 0.0, 95.0)
	var land_rate := (100.0 - fizzle) / 100.0
	var per_hit := BASE_POWER * mult
	if per_hit <= 0.0 or land_rate <= 0.0:
		return 9999.0
	return TARGET_HP / (per_hit * land_rate)


func _report_multiplier_range() -> void:
	print("\n--- multiplier range across the whole sweep ---")
	var lowest := 999.0
	var highest := 0.0
	var low_label := ""
	var high_label := ""
	for facing in FACING:
		for elev in ELEV_STEPS:
			for distance in RELATION_DAMAGE.size():
				var mult := _multiplier(facing, elev, distance)
				var label := "%s + %d elev + %s" % [facing, elev, RELATION_NAME[distance]]
				if mult < lowest:
					lowest = mult
					low_label = label
				if mult > highest:
					highest = mult
					high_label = label
	print("  floor   ×%.3f  (%s)" % [lowest, low_label])
	print("  ceiling ×%.3f  (%s)" % [highest, high_label])
	print("  spread  ×%.2f between best and worst single hit" % (highest / lowest))


func _report_stack_concern() -> void:
	# The specific stack the owner flagged: BACK × 2 elevation steps × OPPOSED.
	print("\n--- FLAGGED STACK: BACK x 2 elevation x OPPOSED ---")
	var mult := _multiplier("BACK", 2, 5)
	print("  1.25 (BACK) x 1.20 (2 elev) x 1.35 (OPPOSED) = x%.4f" % mult)
	print("  claimed approx x2.0 -> measured x%.3f  (%s)"
		% [mult, "CONFIRMED" if absf(mult - 2.0) < 0.06 else "DIVERGES from the estimate"])
	var at_three := _multiplier("BACK", 3, 5)
	print("  worst case at 3 elevation steps: x%.3f" % at_three)
	print("  damage per hit: %.0f vs %.0f baseline (FRONT/flat/d2)"
		% [BASE_POWER * mult, BASE_POWER * _multiplier("FRONT", 0, 2)])
	print("  TTK: %d turns vs %d baseline" % [_ttk(mult), _ttk(_multiplier("FRONT", 0, 2))])
	var fizzle := BASE_FIZZLE + float(RELATION_FIZZLE[5])
	print("  but fizzle is %.0f%% at OPPOSED, so expected TTK is %.2f turns"
		% [fizzle, _expected_ttk(mult, 5)])
	print("  -> the gamble curve is what keeps this honest; without the fizzle term")
	print("     the stack would be strictly dominant.")


func _report_ttk_bands() -> void:
	print("\n--- TTK bands, misses ignored (raw damage) ---")
	print("  rows = facing x elevation, cols = wheel distance 0-5")
	var header := "  %-16s" % "facing/elev"
	for name in RELATION_NAME:
		header += "%10s" % name
	print(header)
	for facing in FACING:
		for elev in ELEV_STEPS:
			var row := "  %-16s" % ("%s+%d" % [facing, elev])
			for distance in RELATION_DAMAGE.size():
				row += "%10d" % _ttk(_multiplier(facing, elev, distance))
			print(row)


func _report_expected_ttk() -> void:
	print("\n--- EXPECTED TTK, fizzle included (what the player feels) ---")
	var header := "  %-16s" % "facing/elev"
	for name in RELATION_NAME:
		header += "%10s" % name
	print(header)
	var best_expected := 9999.0
	var best_label := ""
	for facing in FACING:
		for elev in ELEV_STEPS:
			var row := "  %-16s" % ("%s+%d" % [facing, elev])
			for distance in RELATION_DAMAGE.size():
				var expected := _expected_ttk(_multiplier(facing, elev, distance), distance)
				row += "%10.2f" % expected
				if expected < best_expected:
					best_expected = expected
					best_label = "%s+%d %s" % [facing, elev, RELATION_NAME[distance]]
			print(row)
	print("\n  fastest expected kill: %.2f turns (%s)" % [best_expected, best_label])
	print("  -- if the fastest line is always OPPOSED, the curve is not a gamble,")
	print("     it is a ramp, and the fizzle side needs to be steeper.")
