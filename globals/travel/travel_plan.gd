class_name TravelPlan
extends Resource
## Serializable runtime state for one journey.

enum State {
	EN_ROUTE,
	AVOID_PROMPT,
	IN_BATTLE,
	ARRIVED,
	CANCELLED,
}

@export var origin_id: StringName = &""
@export var destination_id: StringName = &""
@export var progress_step: int = 0
@export var total_steps: int = 0
@export var elapsed_phases: int = 0
@export var rng_seed: int = 0
@export var state: State = State.EN_ROUTE
var encounter_schedule: Array[Dictionary] = []


func to_dict() -> Dictionary:
	return {
		"origin_id": String(origin_id),
		"destination_id": String(destination_id),
		"progress_step": progress_step,
		"total_steps": total_steps,
		"elapsed_phases": elapsed_phases,
		"rng_seed": rng_seed,
		"encounter_schedule": encounter_schedule.duplicate(true),
		"state": int(state),
	}


static func from_dict(data: Variant) -> TravelPlan:
	var plan := TravelPlan.new()
	if not data is Dictionary:
		return plan

	plan.origin_id = StringName(data.get("origin_id", ""))
	plan.destination_id = StringName(data.get("destination_id", ""))
	plan.progress_step = maxi(int(data.get("progress_step", 0)), 0)
	plan.total_steps = maxi(int(data.get("total_steps", 0)), 0)
	plan.progress_step = mini(plan.progress_step, plan.total_steps)
	plan.elapsed_phases = maxi(int(data.get("elapsed_phases", 0)), 0)
	plan.rng_seed = int(data.get("rng_seed", 0))
	plan.state = clampi(
		int(data.get("state", State.EN_ROUTE)), State.EN_ROUTE, State.CANCELLED
	) as State

	var raw_schedule: Variant = data.get("encounter_schedule", [])
	if raw_schedule is Array:
		for raw_slot: Variant in raw_schedule:
			if not raw_slot is Dictionary:
				continue
			plan.encounter_schedule.append({
				"at_step": maxi(int(raw_slot.get("at_step", 0)), 0),
				"encounter_id": StringName(raw_slot.get("encounter_id", "")),
				"resolved": bool(raw_slot.get("resolved", false)),
				"spoils_granted": bool(raw_slot.get("spoils_granted", false)),
			})
	return plan


## Repair invariants a permissive from_dict may admit, and runtime states that
## cannot survive the save envelope. Called by GameFlow on every restore.
func reconcile() -> void:
	for slot: Dictionary in encounter_schedule:
		# An unresolved slot past the destination could otherwise be skipped by
		# arrival; clamping keeps it reachable at the final step.
		slot["at_step"] = clampi(int(slot.get("at_step", 0)), 0, maxi(total_steps, 0))
	if state == State.IN_BATTLE:
		# Battle runtime never rides the envelope. The reached slot is still
		# unresolved, so demoting re-offers the prompt; the avoidance roll is
		# per-slot deterministic, so this is not a reroll exploit.
		state = State.AVOID_PROMPT
	if state == State.AVOID_PROMPT and next_unresolved_reached_index() < 0:
		# Nothing left to prompt about — a prompt state here would deadlock.
		state = State.EN_ROUTE


## Index of the first unresolved slot at or before progress_step, or -1.
func next_unresolved_reached_index() -> int:
	for index: int in encounter_schedule.size():
		var slot: Dictionary = encounter_schedule[index]
		if not bool(slot.get("resolved", false)):
			return index if int(slot.get("at_step", 0)) <= progress_step else -1
	return -1
