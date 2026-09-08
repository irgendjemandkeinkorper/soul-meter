class_name DramgidDerived
extends RefCounted
## DRAMGID derived stats — `docs/architecture-dramgid.md` §6.
##
## Four of §6's seven items are FROZEN here with evidence: `max_hp`,
## `breath_max`, `attack` and `defense`. Each has a live consumer today
## (`ChargenBuild.to_party_member()` calls `recompute()`; `battle.gd`'s damage
## rule reads `attack`/`defense`), so these are not a seam waiting for one.
##
## The other three items — CT speed on Reason, the to-hit table on Alacrity, and
## the damage power term on Muster — are NOT here, deliberately.
##
## Their ATTRIBUTE moved on 2026-09-07 (owner ruling): `CombatRules` and
## `Resolution` now read `alacrity`, which is DRAMGID's name for the old `edge`.
## Their FORMULAS did not. Keying CT speed on Reason rather than Alacrity is a
## different claim from renaming the stat, and it is still §3.9: F3b, after #281.
## Landing a formula ahead of its consumer would strand it, which is the same
## mistake §3.6 is being held back to avoid.
##
## Nothing here applies to ENEMIES. They carry DRAMGID attributes now, but their
## max_hp/attack/defense stay authored: this file's curves are the party's
## point-buy range (2..5), and running the shipped enemies through them would
## rebalance every encounter. See `tools/seed_pandora.gd`'s archetype note.
##
## Reasoning, grids and the migration report: `docs/dramgid-numbers.md`.
## Sweep: `tools/dramgid_derived_sweep.gd`. Pinned: `test/unit/test_dramgid_numbers.gd`.
##
## The shape of every formula below is `base + point x step`, never `point x step`.
## DRAMGID point-buys attributes 2..5 (`DramgidSchema.ATTRIBUTE_FLOOR`/`ATTRIBUTE_CAP`),
## so a bare multiplication gives the floor 40% of the cap — a 2.5x spread that
## makes one attribute mandatory rather than meaningful. A base term is what
## keeps a minimum-Grit character playable.

const DramgidSchemaScript := preload("res://globals/stats/dramgid_schema.gd")

## 24 / 30 / 36 / 42 across the point-buy range (§6: shipped party HP stays
## within +/-15%; the worst fit is +7.1%). The floor of 24 is deliberately above
## the weakest authored enemy's 14 HP — under `grit * 8` a minimum-Grit
## character started on 16.
const HP_BASE := 12
const HP_PER_GRIT := 6

## 15 / 18 / 21 / 24. Intuition 2 reproduces today's flat 15 exactly, so no
## existing caster regresses; Intuition 5 buys exactly one Refrain (24 Breath,
## `docs/casting-economy.md`). This is the BASE pool — the veteran/master
## ceilings in that document are progression tiers and belong to F5.
const BREATH_BASE := 9
const BREATH_PER_INTUITION := 3

## 4 / 6 / 8 / 10, spanning the authored party's 4..9. Under `attack = muster` a
## maxed-Muster created character had attack 5 against the pre-made
## protagonist's 9 — strictly worse than a character the player did not build.
const ATTACK_PER_MUSTER := 2


static func max_hp(grit: int) -> int:
	return HP_BASE + grit * HP_PER_GRIT


static func attack(muster: int) -> int:
	return muster * ATTACK_PER_MUSTER


## Unchanged. `battle.gd`'s legacy rule is `max(1, attack - defense)`, so any
## base term added here would push high-Alacrity characters straight into the
## damage floor against the authored enemies (attack 5). See
## `docs/dramgid-numbers.md` §6 — the floor itself is a §3.9 question, not a
## number this file can fix.
static func defense(alacrity: int) -> int:
	return alacrity


static func breath_max(intuition: int) -> int:
	return BREATH_BASE + intuition * BREATH_PER_INTUITION


static func recompute(member: PartyMember) -> void:
	member.max_hp = max_hp(member.attribute_value(DramgidSchemaScript.ATTR_GRIT))
	member.attack = attack(member.attribute_value(DramgidSchemaScript.ATTR_MUSTER))
	member.defense = defense(member.attribute_value(DramgidSchemaScript.ATTR_ALACRITY))
	member.breath_max = breath_max(member.attribute_value(DramgidSchemaScript.ATTR_INTUITION))
	member.hp = clampi(member.hp, 0, member.max_hp)
	member.breath = clampi(member.breath, 0, member.breath_max)
