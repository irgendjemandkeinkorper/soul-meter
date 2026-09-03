class_name VhorrHunger
extends ClassResource
## Vhorr — Husk-bearer: Hunger. Active DoT ticks stack Hunger; a kill from the owner's DoT
## refunds Soul Gauge.

const MAX_HUNGER := 5 # PROVISIONAL — B11 owns tuning.
const SOUL_REFUND := 1.0 # PROVISIONAL — B11 owns tuning.

var hunger: int = 0
var pending_soul_refunds: float = 0.0


func on_action(event: CombatEvent) -> void:
	var resolution: Dictionary = event.data.get("resolution", {}) as Dictionary
	for write_value: Variant in resolution.get("writes", []):
		if write_value is Dictionary and StringName(str((write_value as Dictionary).get("kind", ""))) == &"dot":
			hunger = mini(hunger + 1, MAX_HUNGER)
	if resolution.is_empty() or bool(resolution.get("fizzled", false)):
		return
	var action_id := StringName(str(event.data.get("action_id", "")))
	if action_id.is_empty() or event.target_id.is_empty() or hunger >= MAX_HUNGER:
		if hunger >= MAX_HUNGER:
			_queue_hunger_dot(event.target_id)
		return
	if action_id in [&"strike", &"cast", &"enemy-strike"]:
		hunger = mini(hunger + 1, MAX_HUNGER)
		_queue_hunger_dot(event.target_id)


func _queue_hunger_dot(target_id: StringName) -> void:
	if target_id.is_empty() or hunger <= 0:
		return
	enqueue_deferred(
		{"writes": [{"kind": "dot", "target_id": String(target_id), "amount": hunger}]},
		{"delay_rounds": 1},
		&"hunger_dot",
	)


func on_deferred_fired(entry: Dictionary) -> void:
	var label := StringName(str(entry.get("label", "")))
	if label == &"hunger_refund":
		pending_soul_refunds = maxf(pending_soul_refunds - SOUL_REFUND, 0.0)
		return
	if label != &"hunger_dot":
		return
	var applied: Array = entry.get("applied", []) as Array
	if applied.is_empty() or not (applied[0] is Dictionary):
		return
	var write: Dictionary = applied[0] as Dictionary
	if int(write.get("after", 0)) > 0:
		_queue_hunger_dot(StringName(str(write.get("target_id", ""))))


func on_kill(_target_id: StringName, cause: StringName) -> void:
	if cause == &"dot":
		pending_soul_refunds += SOUL_REFUND
		enqueue_deferred(
		{"writes": [{
			"kind": "soul_refund",
			"target_id": String(owner_id),
			"amount": SOUL_REFUND,
		}]},
		{"delay_rounds": 0},
		&"hunger_refund",
	)


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Hunger",
		"value": hunger,
		"max": MAX_HUNGER,
		"hidden_on_plate": true,
		"pending_soul_refunds": pending_soul_refunds,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["hunger"] = hunger
	data["pending_soul_refunds"] = pending_soul_refunds
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	hunger = clampi(int(data.get("hunger", 0)), 0, MAX_HUNGER)
	pending_soul_refunds = maxf(float(data.get("pending_soul_refunds", 0.0)), 0.0)
