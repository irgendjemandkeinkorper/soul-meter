extends SceneTree
## Gate T-2 to-hit candidate sweep (#169 ruling, 2026-08-24).
##
## The owner ratified building a to-hit system so the FR-105a facing hit bonuses (+0/+8/+15,
## already ratified) and height actually resolve, followed by ONE rerun of the unchanged
## Gate T-2 harness. This sweep produces the evidence for ratifying the to-hit numbers that
## are NOT yet ratified: base hit chance, height hit modifier per step, and the clamp.
##
## Every number here is CANDIDATE, not canon. The sweep exists so the ratified pick is made
## against data, not vibes — the same discipline as the #133 gamble-curve sweep.
##
## Model (pre-registered, stylized):
##   hit% = clamp(base + facing_bonus + height_mod * dh, 5, 95), dh attacker-relative (+/-).
##   Duel race: positional unit A (back facing, +2 height) vs naive unit N (front, -2 height),
##   alternating attacks (A first), both 131 HP, 42 base power, damage uses the live FR-105a
##   multipliers (back x1.25, +10%/step height). Seeded Monte-Carlo, TRIALS per candidate.
##   This is an upper-bound stylization of what positioning can earn — candidate RANKING
##   evidence, not gate evidence. The gate reruns the real harness after implementation.
##
## Run:  godot --headless --path . --script res://tools/to_hit_sweep.gd
## Judge printed output, never the exit code (headless teardown aborts ~20-30% here).

const FACING_HIT := {"FRONT": 0, "SIDE": 8, "BACK": 15}          # ratified FR-105a
const FACING_DMG := {"FRONT": 1.00, "SIDE": 1.10, "BACK": 1.25}  # ratified FR-105a (PROVISIONAL magnitudes)
const HEIGHT_DMG_PER_STEP := 0.10                                 # live FR-105a
const BASE_POWER := 42.0
const HP := 131.0
const CLAMP_LO := 5.0
const CLAMP_HI := 95.0
const TRIALS := 20000
const SWEEP_SEED := 1692002  # same registered seed family as the gate harness

const BASES := [70.0, 75.0, 80.0, 85.0, 90.0]
const HEIGHT_MODS := [0.0, 4.0, 6.0, 8.0]


func _init() -> void:
	print("=== TO-HIT CANDIDATE SWEEP — ALL VALUES CANDIDATE, NOT CANON ===")
	print("model: hit%% = clamp(base + facing + h_mod*dh, %.0f, %.0f); duel A(back,+2h) vs N(front,-2h)"
		% [CLAMP_LO, CLAMP_HI])
	print("power %.0f · HP %.0f · trials %d · seed %d" % [BASE_POWER, HP, TRIALS, SWEEP_SEED])
	print("")
	print("base | hmod | A hit%% | N hit%% | A dmg | N dmg | A EV | N EV | EV ratio | P(A wins duel) | note")
	print("-----|------|--------|--------|-------|-------|------|------|----------|----------------|-----")
	for base: float in BASES:
		for hmod: float in HEIGHT_MODS:
			_report_candidate(base, hmod)
	print("")
	_report_baseline_feel()
	print("\n=== END SWEEP ===")
	quit()


func _hit_chance(base: float, facing: String, hmod: float, dh: float) -> float:
	return clampf(base + float(FACING_HIT[facing]) + hmod * dh, CLAMP_LO, CLAMP_HI) / 100.0


func _report_candidate(base: float, hmod: float) -> void:
	var a_hit := _hit_chance(base, "BACK", hmod, 2.0)
	var n_hit := _hit_chance(base, "FRONT", hmod, -2.0)
	var a_dmg := BASE_POWER * float(FACING_DMG["BACK"]) * (1.0 + 2.0 * HEIGHT_DMG_PER_STEP)
	var n_dmg := BASE_POWER  # front, no favorable steps (unfavorable height adds no damage)
	var a_ev := a_hit * a_dmg
	var n_ev := n_hit * n_dmg
	var p_win := _duel_win_rate(a_hit, a_dmg, n_hit, n_dmg)
	var note := ""
	if is_equal_approx(base + float(FACING_HIT["BACK"]) + hmod * 2.0, CLAMP_HI) \
			or base + float(FACING_HIT["BACK"]) + hmod * 2.0 > CLAMP_HI:
		note = "cap eats bonus"
	print("%4.0f | %4.0f | %5.1f%% | %5.1f%% | %5.1f | %5.1f | %4.1f | %4.1f | %8.2f | %13.1f%% | %s"
		% [base, hmod, a_hit * 100.0, n_hit * 100.0, a_dmg, n_dmg, a_ev, n_ev,
			a_ev / n_ev, p_win * 100.0, note])


## Alternating-attack race, A first. Returns P(A kills N before N kills A).
func _duel_win_rate(a_hit: float, a_dmg: float, n_hit: float, n_dmg: float) -> float:
	var rng := RandomNumberGenerator.new()
	rng.seed = SWEEP_SEED
	var a_wins := 0
	for _t in TRIALS:
		var a_hp := HP
		var n_hp := HP
		while true:
			if rng.randf() < a_hit:
				n_hp -= a_dmg
			if n_hp <= 0.0:
				a_wins += 1
				break
			if rng.randf() < n_hit:
				a_hp -= n_dmg
			if a_hp <= 0.0:
				break
	return float(a_wins) / float(TRIALS)


func _report_baseline_feel() -> void:
	print("baseline feel (front, flat ground — what ordinary unpositioned play whiffs at):")
	for base: float in BASES:
		var ttk := ceilf(HP / BASE_POWER)  # hits needed
		var expected_casts := ttk / (base / 100.0)
		print("  base %2.0f%% -> front/flat hit %2.0f%%, expected casts for a %0.f-hit kill: %.1f"
			% [base, base, ttk, expected_casts])
