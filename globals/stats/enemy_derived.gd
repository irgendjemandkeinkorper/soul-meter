class_name EnemyDerived
extends RefCounted
## #412: enemy `max_hp` / `attack` / `defense` come off their DRAMGID attributes, and wild
## spawns vary per instance.
##
## Owner rulings: 2026-09-07 (*"I don't want it to be a 'solved' kinda question"*) and
## 2026-10-06 (recorded on #412): every enemy derives from the curve, set-pieces included; wild
## spawns roll a ±15% gradient on all three numbers; the roll is silent in text but the tails
## carry a subtle visual tell.
##
## **Not `DramgidDerived`.** The party's curve spans point-buy grit 2..5 and would turn the 14 HP
## boar into 18; enemies run wider and lower. The curves below are the fit in
## `docs/enemy-curve-packet.md` §2, printed by `tools/enemy_curve_sweep.gd`.
##
## Determinism (Gate T-7, #173): a variation is a pure function of one seed, rolled once when
## `SpawnDirector` instantiates the unit and frozen into the `BattleActor`. Nothing here is called
## from `Resolution.resolve()`, so forecast == resolution holds by construction.

const HP_BASE := 2.0
const HP_PER_GRIT := 6.0
const HP_PER_MUSTER := 2.0
const ATTACK_BASE := 1.0
const ATTACK_PER_MUSTER := 1.5
const DEFENSE_BASE := -2.5
const DEFENSE_PER_GRIT := 1.25

## ±15%, symmetric, on each of the three numbers independently (owner, 2026-10-06).
const VARIATION_BAND := 0.15

## The visual tell fires when the mean of the three rolls (as a share of the band) passes this.
## 0.3 puts about 19% of wild spawns in each tail and leaves the middle ~62% unremarked.
## PROVISIONAL.
const TELL_THRESHOLD := 0.3

enum Tier { WEAK = -1, TYPICAL = 0, STRONG = 1 }


static func max_hp(grit: int, muster: int) -> int:
	return maxi(roundi(HP_BASE + HP_PER_GRIT * grit + HP_PER_MUSTER * muster), 1)


static func attack(muster: int) -> int:
	return maxi(roundi(ATTACK_BASE + ATTACK_PER_MUSTER * muster), 1)


static func defense(grit: int) -> int:
	return maxi(roundi(DEFENSE_BASE + DEFENSE_PER_GRIT * grit), 0)


## Overwrites an enemy actor's three combat numbers from its attributes and refills its HP.
static func derive(actor: BattleActor) -> void:
	var grit := actor.attribute_value(&"grit")
	var muster := actor.attribute_value(&"muster")
	actor.max_hp = max_hp(grit, muster)
	actor.hp = actor.max_hp
	actor.attack = attack(muster)
	actor.defense = defense(grit)


## One instance's roll: three independent factors in `[-band, band]`, drawn in a fixed order
## (hp, attack, defense) from one generator, plus the tier the tell shows.
static func roll(rng_seed: int, band: float = VARIATION_BAND) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var hp_factor := rng.randf_range(-band, band)
	var attack_factor := rng.randf_range(-band, band)
	var defense_factor := rng.randf_range(-band, band)
	var score := 0.0
	if band > 0.0:
		score = (hp_factor + attack_factor + defense_factor) / (3.0 * band)
	var tier := Tier.TYPICAL
	if score >= TELL_THRESHOLD:
		tier = Tier.STRONG
	elif score <= -TELL_THRESHOLD:
		tier = Tier.WEAK
	return {
		"hp": hp_factor,
		"attack": attack_factor,
		"defense": defense_factor,
		"score": score,
		"tier": tier,
	}


## Applies a `roll()` on top of an actor's derived numbers. HP and attack never drop below 1;
## defense never below 0.
static func apply(actor: BattleActor, variation: Dictionary) -> void:
	actor.max_hp = maxi(roundi(actor.max_hp * (1.0 + float(variation["hp"]))), 1)
	actor.hp = actor.max_hp
	actor.attack = maxi(roundi(actor.attack * (1.0 + float(variation["attack"]))), 1)
	actor.defense = maxi(roundi(actor.defense * (1.0 + float(variation["defense"]))), 0)


## The seed for one wild spawn: the world, the day-stamped slot group, and the member's place in
## the pack, so two wights in one pack differ and a reloaded wight is the same wight.
static func spawn_seed(world_seed: int, group_id: StringName, member_index: int) -> int:
	return hash([world_seed, String(group_id), member_index])
