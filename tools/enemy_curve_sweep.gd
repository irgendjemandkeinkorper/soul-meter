extends SceneTree
## Enemy derived-stat sweep — #412.
##
## Canonical invocation:
##   godot --headless --path . --script res://tools/enemy_curve_sweep.gd
##
## READ-ONLY. It prints the grids `docs/enemy-curve-packet.md` is written from:
## the shipped archetype table, the proposed curves against it, and what a
## per-instance variation band does to each archetype. It changes nothing, and in
## particular it does NOT touch `canon/dom/characters/*.json`.
##
## Pure and deterministic, like `tools/dramgid_derived_sweep.gd`. The packet's
## tables are only worth reading if re-running this reproduces them exactly.
##
## No autoload is referenced anywhere in this file. `--script` runs have no
## autoloads, so the archetype rows are READ FROM CANON rather than mirrored —
## there is nothing here to drift out of date.
##
## #412 says (a) archetype derivation must not land without (b) per-instance
## variation, because deriving the numbers with no variation on top re-solves the
## question the owner wants left open at the cost of a full rebalance. This tool
## is neither: it prints what (a) and (b) WOULD do so the four open owner
## questions can be answered with numbers in front of them.

const CHARACTER_DIRECTORY := "res://canon/dom/characters"

## Proposed curves, fitted against the six shipped archetypes by minimising
## worst-case PERCENT drift rather than absolute drift — a 3 HP miss on the
## 14 HP boar matters more than the same miss on the 36 HP guard, and an
## absolute-error fit picks a curve that is kindest to the biggest enemy.
##
## `max_hp` takes a second term. Every single-driver fit tried leaves at least
## one archetype 14%+ out; grit alone cannot separate the bog-wight from the
## rift-scavenger, which share grit 2 and are authored 4 HP apart. Adding muster
## does separate them and drops worst-case drift to 12.5%.
const HP_BASE := 2.0
const HP_PER_GRIT := 6.0
const HP_PER_MUSTER := 2.0

## 4 of 6 archetypes exact; the two misses are 1 point each.
const ATTACK_BASE := 1.0
const ATTACK_PER_MUSTER := 1.5

## 5 of 6 exact. Note this rides GRIT, where the party's defense rides ALACRITY
## (`DramgidDerived.defense`). That divergence is real and deliberate in the
## authored data, not a fitting artifact — see the packet's §4.
const DEFENSE_BASE := -2.5
const DEFENSE_PER_GRIT := 1.25

## The bands the packet asks the owner to choose between.
const BANDS: Array[float] = [0.10, 0.15]

## Enough draws that the observed range converges on the band's real reach. At 8
## draws the bog-wight showed a NARROWER range at +/-15% than at +/-10%, which is
## sampling noise reported as a finding — the exact mistake a review packet is
## most damaging place to make.
const SAMPLE_SEEDS := 512


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var archetypes := _load_archetypes()
	if archetypes.is_empty():
		push_error("enemy_curve_sweep: no archetypes found under %s" % CHARACTER_DIRECTORY)
		quit(1)
		return
	_print_shipped_table(archetypes)
	_print_curve_fit(archetypes)
	_print_variation_bands(archetypes)
	_print_determinism_proof(archetypes)
	quit()


static func derived_max_hp(grit: int, muster: int) -> int:
	return int(roundf(HP_BASE + HP_PER_GRIT * grit + HP_PER_MUSTER * muster))


static func derived_attack(muster: int) -> int:
	return int(roundf(ATTACK_BASE + ATTACK_PER_MUSTER * muster))


static func derived_defense(grit: int) -> int:
	return maxi(int(roundf(DEFENSE_BASE + DEFENSE_PER_GRIT * grit)), 0)


## The variation seam, stated as one pure function so #412's implementation has
## nothing left to invent. Rolled ONCE at spawn and frozen into the BattleActor —
## never re-rolled inside `Resolution.resolve()`, or forecast stops equalling
## resolution and Gate T-7 (#173) breaks.
static func varied(base_value: int, band: float, rng_seed: int, salt: int) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed ^ salt
	var factor := 1.0 + rng.randf_range(-band, band)
	return maxi(int(roundf(base_value * factor)), 1)


func _load_archetypes() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	var dir := DirAccess.open(CHARACTER_DIRECTORY)
	if dir == null:
		return rows
	dir.list_dir_begin()
	var entry := dir.get_next()
	var paths := PackedStringArray()
	while not entry.is_empty():
		if not dir.current_is_dir() and entry.get_extension().to_lower() == "json":
			paths.append(CHARACTER_DIRECTORY.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	paths.sort()
	for path: String in paths:
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary:
			continue
		var record := parsed as Dictionary
		if str(record.get("kind", "")) != "archetype":
			continue
		var stats: Dictionary = record.get("stats", {})
		rows.append(
			{
				"id": str(record.get("id", "")),
				"grit": int(stats.get("grit", 0)),
				"muster": int(stats.get("muster", 0)),
				"alacrity": int(stats.get("alacrity", 0)),
				"max_hp": int(stats.get("max_hp", 0)),
				"attack": int(stats.get("attack", 0)),
				"defense": int(stats.get("defense", 0)),
			}
		)
	return rows


func _print_shipped_table(archetypes: Array[Dictionary]) -> void:
	print("\n=== Shipped archetypes (canon/dom/characters, kind=archetype) ===")
	print("id                        grit mus ala | hp atk def")
	for row: Dictionary in archetypes:
		print(
			"%-25s %4d %3d %3d | %2d %3d %3d"
			% [
				row["id"], row["grit"], row["muster"], row["alacrity"],
				row["max_hp"], row["attack"], row["defense"],
			]
		)


func _print_curve_fit(archetypes: Array[Dictionary]) -> void:
	print("\n=== Proposed curves vs shipped ===")
	print(
		"max_hp  = round(%.1f + %.1f*grit + %.1f*muster)"
		% [HP_BASE, HP_PER_GRIT, HP_PER_MUSTER]
	)
	print("attack  = round(%.1f + %.1f*muster)" % [ATTACK_BASE, ATTACK_PER_MUSTER])
	print("defense = max(round(%.1f + %.2f*grit), 0)" % [DEFENSE_BASE, DEFENSE_PER_GRIT])
	print("")
	print("id                          hp  ->  hp'   d%    | atk -> atk' | def -> def'")
	var worst_hp := 0.0
	var exact := 0
	for row: Dictionary in archetypes:
		var hp := derived_max_hp(int(row["grit"]), int(row["muster"]))
		var atk := derived_attack(int(row["muster"]))
		var def := derived_defense(int(row["grit"]))
		var shipped_hp := int(row["max_hp"])
		# SIGNED, so the column says which way the curve missed. `worst_hp` takes
		# the magnitude — a `%+.1f` column fed an absolute value prints every row
		# as a gain, which is the most confident way to be wrong in a review packet.
		var drift := 0.0 if shipped_hp == 0 else float(hp - shipped_hp) / shipped_hp * 100.0
		worst_hp = maxf(worst_hp, absf(drift))
		if hp == shipped_hp:
			exact += 1
		print(
			"%-25s %3d -> %3d  %+5.1f%%  | %3d -> %3d  | %3d -> %3d"
			% [row["id"], shipped_hp, hp, drift, row["attack"], atk, row["defense"], def]
		)
	print("")
	print("worst-case HP drift: %.1f%%   exact HP matches: %d/%d" % [worst_hp, exact, archetypes.size()])
	print(
		"For contrast, reusing the PARTY curve (DramgidDerived: 12 + 6*grit) on the "
		+ "grit-1 boar gives 18 against an authored 14 (+28.6%), which is why #412 "
		+ "says the party's curve does not transfer."
	)


func _print_variation_bands(archetypes: Array[Dictionary]) -> void:
	print("\n=== Per-instance variation: what each band actually feels like ===")
	for band: float in BANDS:
		print("\n-- band +/-%d%% --" % int(band * 100.0))
		print(
			"id                        hp'  band bounds  observed over %d seeds"
			% SAMPLE_SEEDS
		)
		for row: Dictionary in archetypes:
			var base_hp := derived_max_hp(int(row["grit"]), int(row["muster"]))
			# Seeded from the DRAWS, not from `base_hp`. Seeding the range with the
			# unrolled value quietly widens every band to include a number the
			# sample may never have produced.
			var lowest := -1
			var highest := -1
			for draw in SAMPLE_SEEDS:
				var value := varied(base_hp, band, draw, str(row["id"]).hash())
				lowest = value if lowest < 0 else mini(lowest, value)
				highest = maxi(highest, value)
			# The bounds are what the packet quotes; the observed range says whether
			# the sample actually reaches them.
			var floor_bound := maxi(int(roundf(base_hp * (1.0 - band))), 1)
			var ceiling_bound := maxi(int(roundf(base_hp * (1.0 + band))), 1)
			print(
				"%-25s %3d  [%2d..%2d]     [%2d..%2d]"
				% [row["id"], base_hp, floor_bound, ceiling_bound, lowest, highest]
			)


func _print_determinism_proof(archetypes: Array[Dictionary]) -> void:
	print("\n=== Determinism (Gate T-7, #173) ===")
	var row: Dictionary = archetypes[0]
	var base_hp := derived_max_hp(int(row["grit"]), int(row["muster"]))
	var salt := str(row["id"]).hash()
	var first := varied(base_hp, BANDS[0], 4242, salt)
	var stable := true
	for _repeat in 32:
		if varied(base_hp, BANDS[0], 4242, salt) != first:
			stable = false
	print(
		"%s at seed 4242 rolled %d, and %s across 32 re-rolls."
		% [row["id"], first, "held" if stable else "DRIFTED"]
	)
	print(
		"Two containers of the same archetype differ because the salt differs: "
		+ "seed 4242 salt A -> %d, salt B -> %d."
		% [varied(base_hp, BANDS[0], 4242, salt), varied(base_hp, BANDS[0], 4242, salt + 1)]
	)
