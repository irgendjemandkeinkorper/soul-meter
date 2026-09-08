class_name Advancement
extends RefCounted
## Point-buy advancement (#98, FR-204; Phase-0 D3 + §2, owner rulings 2026-08-24).
##
## Ratified rules this file implements verbatim:
## - D3: point-buy on level; no use-based drift. Attributes are FIXED after creation
##   (owner 2026-08-24) — skill points are Chapter 1's only growth axis.
## - §2 costs: each +5% step costs 1 point while the RESULTING effective% is ≤ 50,
##   2 points while ≤ 75, 3 points while ≤ 95. Effective% is SkillCheckService's
##   derivation (attr × 8 + tier + advancement); the Chapter-1 cap of 95% is enforced
##   here on the resulting effective%, which is what "100% is a commitment" governs.
## - Owner 2026-08-24 (TUNABLE): POINTS_PER_LEVEL = 3.
## - SUPERSEDED 2026-09-02 by `docs/game-identity.md` ruling 9, re-affirmed by the
##   owner 2026-09-08: levels come from XP, and XP comes from COMBAT and QUESTS.
##   The earlier rule here — "levels come from authored story MILESTONES, never
##   from kill/use XP" (#98 D3, 2026-08-24) — no longer holds. Milestones survive
##   as an XP source rather than as a second, parallel way to gain a level; one
##   currency is the point. See `GameState.grant_milestone_level`.
## - D5: the Mirror Rewriting (once per chapter, see GameState) refunds every
##   advancement point ever spent and re-opens them; tiers and Masteries untouched.
##
## Bookkeeping: the per-skill ledger lives in `GameState.skills[member.id][skill_id]`
## = {percentage, tier, advancement_points_spent} — the exact shape the schema-6 save
## envelope already validates. `member.skill_percentages` remains the runtime value
## SkillCheckService reads; this service is the ONLY writer that moves both together.

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
const STEP_PERCENT := 5.0
const EFFECTIVE_CAP := 95.0
const COST_BANDS := [            # [resulting effective% ceiling, cost per +5% step]
	[50.0, 1],
	[75.0, 2],
	[95.0, 3],
]


## Pure cost-curve helper used by schema migration when a removed skill's bought
## percentage must be returned to the member's point pool.
static func points_spent_for_percentage(
	base_effective_percent: float,
	advancement_percent: float
) -> int:
	var step_count := floori(maxf(advancement_percent, 0.0) / STEP_PERCENT)
	var total := 0
	for step in range(1, step_count + 1):
		var resulting := base_effective_percent + step * STEP_PERCENT
		for band: Array in COST_BANDS:
			if resulting <= float(band[0]):
				total += int(band[1])
				break
	return total


## Cost of the member's next +5% step in `skill_id`, judged by the RESULTING
## effective percentage. Returns -1 when the step is not purchasable (cap reached).
static func step_cost(member: PartyMember, skill_id: String) -> int:
	var resulting := SkillCheck.preview(skill_id, member, 0.0) + STEP_PERCENT
	if resulting > EFFECTIVE_CAP:
		return -1
	for band: Array in COST_BANDS:
		if resulting <= float(band[0]):
			return int(band[1])
	return -1


static func can_buy(member: PartyMember, skill_id: String) -> bool:
	var cost := step_cost(member, skill_id)
	return cost > 0 and member.advancement_points >= cost


## Buys one +5% step. Returns the codebase's shared gate shape.
static func buy(member: PartyMember, skill_id: String) -> Dictionary:
	if not is_purchasable(member, skill_id):
		return {
			"allowed": false, "blocked_by": "unheld_tone",
			"message": "Only the Major and Minor tones can be trained in Chapter 1.",
		}
	var cost := step_cost(member, skill_id)
	if cost < 0:
		return {
			"allowed": false, "blocked_by": "effective_cap",
			"message": "Chapter 1 caps effective skill at %d%%." % int(EFFECTIVE_CAP),
		}
	if member.advancement_points < cost:
		return {
			"allowed": false, "blocked_by": "points",
			"message": "Needs %d advancement point%s." % [cost, "" if cost == 1 else "s"],
		}
	member.advancement_points -= cost
	member.skill_percentages[skill_id] = float(member.skill_percentages.get(skill_id, 0.0)) + STEP_PERCENT
	var ledger := _ledger_row(member, skill_id)
	ledger["percentage"] = float(ledger.get("percentage", 0.0)) + STEP_PERCENT
	ledger["advancement_points_spent"] = int(ledger.get("advancement_points_spent", 0)) + cost
	return {"allowed": true, "blocked_by": "", "cost": cost,
		"new_percentage": float(member.skill_percentages[skill_id])}


## Chapter-1 rule (docs/architecture-chargen-dramgid.md §3.3, R3): a `tone_*` skill is
## purchasable only while it is one of the member's held tones (Major or Minor). Every
## field and ARMS skill is always purchasable; the cost bands decide the rest.
static func is_purchasable(member: PartyMember, skill_id: String) -> bool:
	if not DramgidSchema.is_tone_skill(skill_id):
		return true
	return skill_id in held_tones(member)


static func held_tones(member: PartyMember) -> PackedStringArray:
	var result := PackedStringArray()
	for element in [member.major_element, member.minor_element]:
		var skill_id := DramgidSchema.tone_skill_for(element)
		if not skill_id.is_empty() and not result.has(skill_id):
			result.append(skill_id)
	return result


## Writes the creation-time purchases into the ledger once the member has its final id
## (docs/architecture-chargen-dramgid.md §5, R8). `rows` is skill_id →
## {percentage, tier, advancement_points_spent}, the exact ledger row shape, so the Mirror
## Rewriting refunds creation points like any other advancement point. The member's
## `skill_percentages` are expected to carry the percentages already
## (ChargenBuild.to_party_member does that); this only records them.
static func seed_creation_ledger(member: PartyMember, rows: Dictionary) -> void:
	if member.id.is_empty():
		push_warning("Advancement.seed_creation_ledger: member has no id; ledger not written")
		return
	for skill_id: String in rows.keys():
		var source: Dictionary = rows[skill_id]
		var ledger := _ledger_row(member, skill_id)
		ledger["percentage"] = float(source.get("percentage", 0.0))
		ledger["tier"] = str(source.get("tier", ledger.get("tier", "untrained"))).to_lower()
		ledger["advancement_points_spent"] = int(source.get("advancement_points_spent", 0))


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
static func award_xp(member: PartyMember, amount: int) -> int:
	if member == null or amount <= 0:
		return 0
	member.xp = maxi(member.xp, 0) + amount
	var gained := 0
	while member.xp >= xp_for_next_level(member.level):
		member.xp -= xp_for_next_level(member.level)
		grant_level(member)
		gained += 1
	return gained


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


## D5: refund every advancement point ever spent by this member and remove the
## bought percentages. Tier purchases and Masteries are untouched by design.
static func mirror_rewriting(member: PartyMember) -> Dictionary:
	var actor_ledger: Dictionary = GameState.skills.get(member.id, {})
	var refunded := 0
	for skill_id: String in actor_ledger.keys():
		var row: Dictionary = actor_ledger[skill_id]
		var bought := float(row.get("percentage", 0.0))
		var spent := int(row.get("advancement_points_spent", 0))
		if spent <= 0 and bought <= 0.0:
			continue
		refunded += spent
		member.skill_percentages[skill_id] = maxf(
			float(member.skill_percentages.get(skill_id, 0.0)) - bought, 0.0
		)
		row["percentage"] = 0.0
		row["advancement_points_spent"] = 0
	member.advancement_points += refunded
	return {"allowed": true, "refunded_points": refunded}


static func total_points_spent(member: PartyMember) -> int:
	var actor_ledger: Dictionary = GameState.skills.get(member.id, {})
	var total := 0
	for skill_id: String in actor_ledger.keys():
		total += int((actor_ledger[skill_id] as Dictionary).get("advancement_points_spent", 0))
	return total


static func _ledger_row(member: PartyMember, skill_id: String) -> Dictionary:
	if not GameState.skills.has(member.id):
		GameState.skills[member.id] = {}
	var actor_ledger: Dictionary = GameState.skills[member.id]
	if not actor_ledger.has(skill_id):
		actor_ledger[skill_id] = {
			"percentage": 0.0,
			"tier": str(member.skill_tiers.get(skill_id, "untrained")).to_lower(),
			"advancement_points_spent": 0,
		}
	return actor_ledger[skill_id]
