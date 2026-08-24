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
## - Owner 2026-08-24 (TUNABLE): POINTS_PER_LEVEL = 3; levels come from authored story
##   MILESTONES (see GameState.grant_milestone_level), never from kill/use XP.
## - D5: the Mirror Rewriting (once per chapter, see GameState) refunds every
##   advancement point ever spent and re-opens them; tiers and Masteries untouched.
##
## Bookkeeping: the per-skill ledger lives in `GameState.skills[member.id][skill_id]`
## = {percentage, tier, advancement_points_spent} — the exact shape the schema-6 save
## envelope already validates. `member.skill_percentages` remains the runtime value
## SkillCheckService reads; this service is the ONLY writer that moves both together.

const POINTS_PER_LEVEL := 3      # PROVISIONAL / TUNABLE (owner 2026-08-24)
const STEP_PERCENT := 5.0
const EFFECTIVE_CAP := 95.0
const COST_BANDS := [            # [resulting effective% ceiling, cost per +5% step]
	[50.0, 1],
	[75.0, 2],
	[95.0, 3],
]


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


static func grant_level(member: PartyMember) -> void:
	member.level += 1
	member.advancement_points += POINTS_PER_LEVEL


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
			"tier": str(member.skill_tiers.get(skill_id, "untrained")),
			"advancement_points_spent": 0,
		}
	return actor_ledger[skill_id]
