class_name FightDice
extends RefCounted
## Fresh dice for every fight (owner 2026-11-02, item 33: "every fight"). Battle draws one seed
## per fight here and hands it to the controller, which salts its roll keys with it; the
## controller itself never draws, so its resolution stays a pure function of the fight's seed.

## Tests: when 0 or more, every fight that Battle starts uses this seed instead of drawing one.
static var forced_seed := -1


## A fresh fight seed: `forced_seed` when a test pins one, 0 when `SOUL_METER_FIXED_DICE=1`
## (scripts/test.sh sets it, so suites keep their historical rolls), else a random draw.
static func draw() -> int:
	if forced_seed >= 0:
		return forced_seed
	if OS.get_environment("SOUL_METER_FIXED_DICE") == "1":
		return 0
	return randi_range(1, 0x7fffffff)
