class_name KarmaActs
extends RefCounted
## The Karma writers (owner item 21, `karma acts: approved`, 2026-10-24). Every act and its base
## is in `docs/karma-acts-draft.md` §2; this is the one seam game code calls so the two rules
## that table adds live in one place:
## - a 0 base writes nothing (the ledger stays append-only and small, §3.2);
## - petty theft is capped per scene (`karma theft cap: 25`), so a looting pass cannot outweigh
##   a quest.
## `Renown.gain_karma()` applies the Doctrine multiplier; the bases here are what the table says.

const THEFT_BASE := -5.0
## Owner item 21: the most base Karma petty theft can cost in one scene.
const THEFT_CAP_PER_SCENE := 25.0
## Every theft cause starts with this, so the cap can find this scene's earlier thefts in the
## ledger instead of keeping a second counter that a save could disagree with.
const THEFT_CAUSE_PREFIX := "Took goods from "
const CAUGHT_PICKPOCKETING_BASE := -10.0


static func record(base: float, cause: String, scene: String = "") -> RenownEvent:
	if is_zero_approx(base):
		return null
	return Renown.gain_karma("player", base, cause, scene)


## Records one act of petty theft at `THEFT_BASE`, or less once this scene's thefts near the
## cap, or nothing once they reach it. `cause` must start with `THEFT_CAUSE_PREFIX`.
static func record_theft(cause: String, scene: String) -> RenownEvent:
	var spent := theft_spent_in(scene)
	var remaining := THEFT_CAP_PER_SCENE - spent
	if remaining <= 0.0:
		return null
	return record(-minf(absf(THEFT_BASE), remaining), cause, scene)


## Base Karma already lost to petty theft in `scene`, read back from the ledger.
static func theft_spent_in(scene: String) -> float:
	var spent := 0.0
	for event: RenownEvent in Renown.history():
		if (
			event.kind == &"karma" and event.scene == scene
			and event.cause.begins_with(THEFT_CAUSE_PREFIX) and event.base < 0.0
		):
			spent += -event.base
	return spent
