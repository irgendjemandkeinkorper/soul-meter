extends SceneTree
## Casting economy numeric sweep.
##
## Canonical invocation:
##   godot --headless --path . --script res://tools/casting_economy_sweep.gd
##
## This tool is read-only. It loads the tunable fizzle table and calls the
## ratified SkillCheck.fizzle_percent() formula to print a verification grid,
## then simulates the PROVISIONAL Breath economy from docs/casting-economy.md.
## It does not modify any runtime behavior.
##
## P2.2 (#595): the last section plays the approved set-pieces (R14) with KitAI on both
## sides and reports, per class, the round a caster's Breath runs dry against how long the
## fight lasts. R2's target is dry by PROVISIONAL round 3–4. Add `-- --set-pieces-only` to
## skip the first two sections, `-- --seeds=N` to change the fights per row (default 20).

const FIZZLE_TABLE_PATH := "res://globals/default_fizzle_table.tres"
## Loaded, not preloaded: `skill_check.gd` depends on scripts that name autoloads, and in a
## `--script` run those identifiers only exist once the tree has run a frame. A preload compiled
## that chain first and failed, so this tool printed compile errors instead of its grid.
const SKILL_CHECK_PATH := "res://globals/skill_check.gd"
const SET_PIECE_DRAIN_PATH := "res://tools/set_piece_drain.gd"

# PROVISIONAL — mirrors docs/casting-economy.md
const BREATH_COST := {
	"note": 3,
	"phrase": 6,
	"song": 12,
	"refrain": 24,
}
const BREATH_MAX := {
	"base": 15,
	"veteran": 30,
	"master": 60,
}
const LUTH_RESTORE := 6
const MOZH_RESTORE := 12
const SOUL_OVERREACH := {
	"note": 1,
	"phrase": 2,
	"song": 4,
	"refrain": 8,
}

const INTEGRITIES := [95.0, 80.0, 60.0, 40.0]
const BREADTHS := ["tone", "chord", "triad"]
const MAGNITUDES := ["note", "phrase", "song", "refrain"]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	# Autoload identifiers exist from the first frame on; everything below loads after it.
	await process_frame
	var args := OS.get_cmdline_user_args()
	if not args.has("--set-pieces-only"):
		var skill_check: Object = load(SKILL_CHECK_PATH).new()
		skill_check.set("fizzle_table", load(FIZZLE_TABLE_PATH))
		_print_fizzle_grid(skill_check)
		_print_breath_simulation()
	var seeds := 20
	for arg: String in args:
		if arg.begins_with("--seeds="):
			seeds = maxi(int(arg.trim_prefix("--seeds=")), 1)
	# P2.2: the set-piece section plays real fights. It is its own script for the same reason
	# skill_check is loaded: naming its classes here would compile them before the autoloads.
	(load(SET_PIECE_DRAIN_PATH).new() as RefCounted).call("print_report", seeds)
	quit()


func _print_fizzle_grid(skill_check: Object) -> void:
	print("integrity,breadth,magnitude,fizzle_percent")
	for integrity: float in INTEGRITIES:
		for breadth: String in BREADTHS:
			for magnitude: String in MAGNITUDES:
				var fizzle: float = skill_check.call("fizzle_percent",
					integrity, breadth, 0, magnitude, 2, false, ""
				)
				print("%.1f,%s,%s,%.1f" % [integrity, breadth, magnitude, fizzle])


func _print_breath_simulation() -> void:
	print("")
	print("Breath-per-battle simulation (PROVISIONAL)")
	print("breath_max base tier: %d" % BREATH_MAX["base"])
	print("")
	print("4-Note opening battle:")
	var breath: int = BREATH_MAX["base"]
	var soul_spent: int = 0
	for i: int in range(1, 5):
		var cost: int = BREATH_COST["note"]
		if breath >= cost:
			breath -= cost
		else:
			var missing: int = cost - breath
			breath = 0
			soul_spent += SOUL_OVERREACH["note"] * missing
		print("  cast %d: breath=%d soul_spent=%d" % [i, breath, soul_spent])
	print("")
	print("Single-Refrain battle:")
	breath = BREATH_MAX["base"]
	soul_spent = 0
	var refrain_cost: int = BREATH_COST["refrain"]
	if breath >= refrain_cost:
		breath -= refrain_cost
	else:
		var missing: int = refrain_cost - breath
		breath = 0
		soul_spent += SOUL_OVERREACH["refrain"] * missing
	print("  cast 1: breath=%d soul_spent=%d" % [breath, soul_spent])
