class_name SteamAchievements
extends RefCounted
## The one table of Steam achievements (issue #299).
##
## `id` is the Steamworks "API Name" and must match the partner site exactly.
## The ids are deliberately neutral: display names, descriptions and icons live
## on the partner site and are the owner's call, so renaming an achievement
## never touches code. To retune a trigger, edit its row here — nothing else
## hard-codes these conditions. See docs/steam-integration.md.
##
## PROVISIONAL: issue #299 reserves the achievement names for the owner and
## the five trigger conditions below have not been put to them yet. They are
## the agent's proposal (every one is reachable in Chapter One); the owner's
## ruling may replace any row. The proposal to post on the issue is in
## docs/steam-integration.md, "Proposed achievements (for owner ruling)".

## Unlocks when QuestSystem completes any quest whose resource path is listed
## in `quests`.
const TRIGGER_QUEST_COMPLETED := &"quest_completed"
## Unlocks when any faction's standing reaches the Reputation band in `band`
## (or better).
const TRIGGER_REPUTATION_BAND := &"reputation_band"
## Unlocks when Renown's Fame tier index reaches `tier_index` (or higher).
const TRIGGER_FAME_TIER := &"fame_tier"

const TABLE: Array[Dictionary] = [
	{
		# The Broken Muster ruling — the Chapter One main-quest decision.
		"id": &"ACH_01",
		"trigger": TRIGGER_QUEST_COMPLETED,
		"quests": ["res://quests/dorthkor_road.tres"],
	},
	{
		# The Unanswered Roar ruling — Act I closes and the Chapter Two hook opens.
		"id": &"ACH_02",
		"trigger": TRIGGER_QUEST_COMPLETED,
		"quests": ["res://quests/main/the_unanswered_roar.tres"],
	},
	{
		# Any one companion personal quest resolved.
		"id": &"ACH_03",
		"trigger": TRIGGER_QUEST_COMPLETED,
		"quests": [
			"res://quests/serai_lun_mirror_line.tres",
			"res://quests/wyneth_hallow_tide_kept_name.tres",
			"res://quests/old_grumbrand_the_last_reading.tres",
			"res://quests/ressa_quickfingers_open_hand.tres",
			"res://quests/korrath_ninefold_proof_asked.tres",
			"res://quests/maura_greyfen_name_and_deed.tres",
		],
	},
	{
		# Any faction's standing reaches the Warm band.
		"id": &"ACH_04",
		"trigger": TRIGGER_REPUTATION_BAND,
		"band": &"warm",
	},
	{
		# Fame leaves "Unknown": tier index 1 is "Whispered" in Renown.FAME_TIER_NAMES.
		"id": &"ACH_05",
		"trigger": TRIGGER_FAME_TIER,
		"tier_index": 1,
	},
]


static func ids() -> Array[StringName]:
	var result: Array[StringName] = []
	for row: Dictionary in TABLE:
		result.append(row["id"] as StringName)
	return result
