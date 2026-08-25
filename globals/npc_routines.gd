class_name NpcRoutines
extends RefCounted
## FR-504a §2 routine registry (`docs/prd-amendment-living-world.md`).
##
## A routine is a TABLE: per named hub NPC, a position and a state for each
## WorldClock phase. Nothing computes it, nothing pathfinds to it — the NPC is
## in one place before the phase change and in the other after it (§2.2).
##
## This is DATA, deliberately a read-only GDScript registry like
## FastTravelRegistry (Pandora has no ratified routine schema). Reversibility
## (§7): deleting a row returns that NPC to FR-504 flag/rep reactivity;
## deleting the whole table returns every NPC to it.
##
## The cap is a NUMBER, not a principle (§2.2): 15 routines across all three
## hubs. Routine 16 requires a further amendment, not a judgement call here.
## `test/unit/test_npc_routines.gd` enforces the cap and §5 criterion 4
## (every routine NPC findable-or-declared-absent in every phase).

const ROUTINE_CAP := 15

## Routine positions below are authored in THIS scene's coordinates. An NPC
## node in any other scene ignores the table even if its id matches, so a
## future interior placement cannot inherit town coordinates.
const HUB_SCENE := "res://world/starting_town.tscn"

## Marker meaning "not in the hub this phase" — hidden, non-interactable,
## out of the nav occupancy group. §5 criterion 4 requires absence to be
## DECLARED (a null row), never accidental (a missing key).
const ABSENT := &"absent"

## npc_id → phase → {"position": Vector2, "state": StringName} | null (absent).
## Positions are `world/starting_town.tscn` coordinates (Dom is hub 1 of 3;
## hubs 2–3 get their rows during M7 region production — §6.3 fixes the count
## now and the names then).
##
## Sella Varn gives BELLHOUSE_REPAIR, so FR-905/§3.4 applies: she is present
## (interactable) in three phases — comfortably over the two-phase floor.
const ROUTINES: Dictionary = {
	# Bell-keeper: at her bell-house post in the morning, the market row by the
	# notice board in the afternoon, the Four Arms forecourt in the evening,
	# home (absent) at night.
	"sella-varn": {
		&"morning": {"position": Vector2(2820, 1525), "state": &"working"},
		&"afternoon": {"position": Vector2(1480, 1250), "state": &"buying"},
		&"evening": {"position": Vector2(1700, 1560), "state": &"drinking"},
		&"night": null,
	},
	# Reed-cutter: on the harbor arm early, at his authored spot midday, at the
	# Four Arms in the evening, absent at night.
	"toma-reedhand": {
		&"morning": {"position": Vector2(1100, 1450), "state": &"working"},
		&"afternoon": {"position": Vector2(1820, 1280), "state": &"working"},
		&"evening": {"position": Vector2(1640, 1620), "state": &"drinking"},
		&"night": null,
	},
	# Registry clerk: at his ledger desk through the working phases, and still
	# there — by lamplight — in the evening; absent only at night.
	"hadrik-vale": {
		&"morning": {"position": Vector2(700, 535), "state": &"working"},
		&"afternoon": {"position": Vector2(700, 535), "state": &"working"},
		&"evening": {"position": Vector2(760, 560), "state": &"working"},
		&"night": null,
	},
}

## §3.3 back-fill: named Dom NPCs WITHOUT a routine, declared phase-agnostic
## on purpose (FR-504a item 4 — flag/rep reactivity only IS the design, not a
## fallback). Marshal Coiljaw anchors the Broken Muster ruling, so he stays
## findable in every phase rather than gaining a routine.
const DECLARED_PHASE_AGNOSTIC: Array[String] = [
	"branek-coiljaw",
]


static func has_routine(npc_id: String) -> bool:
	return ROUTINES.has(npc_id)


## The placement for one NPC in one phase.
## Returns {} when the NPC has no routine (FR-504 behaviour applies),
## {"present": false} for a declared absence, and
## {"present": true, "position": Vector2, "state": StringName} otherwise.
static func placement(npc_id: String, phase: StringName) -> Dictionary:
	if not ROUTINES.has(npc_id):
		return {}
	var routine: Dictionary = ROUTINES[npc_id]
	var row: Variant = routine.get(phase)
	if row == null:
		return {"present": false, "state": ABSENT}
	return {
		"present": true,
		"position": row["position"],
		"state": row["state"],
	}


## Phases in which the NPC is present and interactable — the FR-905 §3.4
## reachability surface (quest-critical NPCs need this ≥ 2, or no routine).
static func present_phase_count(npc_id: String) -> int:
	if not ROUTINES.has(npc_id):
		return WorldClock.PHASES.size()
	var count := 0
	for phase: StringName in ROUTINES[npc_id]:
		if ROUTINES[npc_id][phase] != null:
			count += 1
	return count


static func routine_count() -> int:
	return ROUTINES.size()
