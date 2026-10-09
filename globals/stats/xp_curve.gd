class_name XpCurve
extends RefCounted
## The XP curve, level cap and kill-XP scaling: pure numbers with no autoload, so
## `tools/progression_sweep.gd` can run them under `--script`. `Advancement` re-exports
## every name here; game code keeps calling `Advancement.*`.

const POINTS_PER_LEVEL := 3      # PROVISIONAL / TUNABLE (owner 2026-08-24)

## PROVISIONAL — #285 hands the curve to DeepSeek. Cost to reach level N+1 is
## XP_BASE * N, so the curve is LINEAR in level and total XP is quadratic: 100 to
## reach 2, 200 more for 3, 300 more for 4. Linear rather than exponential
## because Chapter 1 is short; an exponential curve spends its interesting range
## outside the content that exists.
const XP_BASE := 100

## PROVISIONAL. A quest is worth roughly two average kills at the shipped
## archetype spread, which keeps questing clearly the better rate per minute
## without making combat XP pointless.
const XP_PER_QUEST := 40

## PROVISIONAL. Floor and per-point value of a kill.
const XP_PER_KILL_BASE := 2
const XP_PER_KILL_PER_POINT := 4

## PROVISIONAL. A milestone is worth one level's XP at the level the member is
## already at, so a story beat still reads as "you levelled" without introducing
## a second way to gain levels.
const MILESTONE_XP_LEVELS := 1

## Owner 2026-10-09: wild respawns stay farmable, but grinding must not outrun the
## campaign's presumed difficulty. Two bounds, signed off by the owner 2026-10-09 in
## `docs/progression-bound-packet.md` (numbers from `tools/progression_sweep.gd`):
## - a hard Chapter 1 level cap: one level above what a thorough, non-grinding run reaches;
## - kill XP scaled per member by the gap between their level and the foe's, so an
##   out-levelled foe pays a trickle and a member behind the curve catches up.
## Quest and milestone XP are never scaled; only the cap applies to them.
const CHAPTER_LEVEL_CAP := 7
## A foe's level is read off the same two attributes its XP is: grit + muster - 2.
const ENEMY_LEVEL_OFFSET := 2
## Each level the member is ABOVE the foe takes this share off the kill...
const KILL_XP_PENALTY_PER_LEVEL := 0.3
## ...down to this floor, so a kill never pays literally nothing.
const KILL_XP_FLOOR := 0.1
## Each level the member is BELOW the foe adds this share, up to the catch-up ceiling.
const KILL_XP_BONUS_PER_LEVEL := 0.25
const KILL_XP_CEILING := 1.5


static func grant_level(member: PartyMember) -> void:
	member.level += 1
	member.advancement_points += POINTS_PER_LEVEL


## XP needed to go from `level` to `level + 1`. Never zero, so no amount of XP can
## grant infinite levels in the loop below.
static func xp_for_next_level(level: int) -> int:
	return XP_BASE * maxi(level, 1)


## Awards XP and takes every level it pays for. Returns the number of levels
## gained, so callers can report "and Vex reached 3" without recomputing it.
##
## The remainder CARRIES: overshooting a threshold banks the excess rather than
## discarding it, so two half-levels of work are worth one level. Discarding it
## would silently penalise players who fight one more encounter than they needed.
##
## At CHAPTER_LEVEL_CAP the bar stops filling: XP past the cap is dropped, not banked,
## or lifting the cap in a later chapter would pay the grind out all at once.
static func award_xp(member: PartyMember, amount: int) -> int:
	if member == null or amount <= 0:
		return 0
	if member.level >= CHAPTER_LEVEL_CAP:
		member.xp = 0
		return 0
	member.xp = maxi(member.xp, 0) + amount
	var gained := 0
	while member.level < CHAPTER_LEVEL_CAP and member.xp >= xp_for_next_level(member.level):
		member.xp -= xp_for_next_level(member.level)
		grant_level(member)
		gained += 1
	if member.level >= CHAPTER_LEVEL_CAP:
		member.xp = 0
	return gained


## The level a defeated combatant counts as for kill-XP scaling.
static func enemy_level(grit: int, muster: int) -> int:
	return maxi(maxi(grit, 0) + maxi(muster, 0) - ENEMY_LEVEL_OFFSET, 1)


## Share of a kill's base XP that a member at `member_level` earns from a foe at
## `foe_level`: 1.0 when even, falling toward KILL_XP_FLOOR above it, rising toward
## KILL_XP_CEILING below it.
static func kill_xp_multiplier(member_level: int, foe_level: int) -> float:
	var gap := member_level - foe_level
	if gap > 0:
		return maxf(1.0 - KILL_XP_PENALTY_PER_LEVEL * gap, KILL_XP_FLOOR)
	return minf(1.0 + KILL_XP_BONUS_PER_LEVEL * -gap, KILL_XP_CEILING)


## What one member earns for one defeated foe. Never below 1, so the floor is felt.
static func kill_xp_for(member_level: int, grit: int, muster: int) -> int:
	var base := xp_for_defeated(grit, muster)
	var share := kill_xp_multiplier(member_level, enemy_level(grit, muster))
	return maxi(roundi(base * share), 1)


## PROVISIONAL — #285 hands the curve to DeepSeek. What a defeated combatant is
## worth, read off its DRAMGID attributes: `grit` is how hard it was to kill and
## `muster` is how hard it hit, so XP tracks the difficulty the party actually
## faced. Deriving it beats a hand-authored per-enemy number, which drifts from
## the stats the moment either is tuned and gives no signal that it has.
static func xp_for_defeated(grit: int, muster: int) -> int:
	return maxi(XP_PER_KILL_BASE + XP_PER_KILL_PER_POINT * (maxi(grit, 0) + maxi(muster, 0)), 1)


## What a story milestone is worth to this member: a FIXED award of one level's
## XP at their current level, scaling with level so a milestone reached late is
## not a rounding error against the XP already earned.
##
## Deliberately NOT "however much is still owed to reach the next level". That
## variant also levels everyone exactly once, which looks equivalent and is not:
## a member sitting at 99 of 100 would receive 1 XP and level — the same level
## they were about to earn anyway — so their 99 points of work bought them
## nothing. A fixed award levels them AND leaves the 99 banked toward the level
## after. Reaching a story beat should never be worth less for having played more.
static func milestone_xp(member: PartyMember) -> int:
	var total := 0
	for offset in MILESTONE_XP_LEVELS:
		total += xp_for_next_level(member.level + offset)
	return maxi(total, 1)
