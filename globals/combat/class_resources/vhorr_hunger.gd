class_name VhorrHunger
extends ClassResource
## Vhorr — Husk-bearer: Hunger. Active DoT ticks stack Hunger; a kill from the owner's DoT
## returns Breath.
##
## It used to return Soul Gauge. Owner ruling (docs/game-identity.md ruling 3, reaffirmed
## 2026-09-08 on #286): the Gauge rises ONLY through an act of Agreement — a tagged quest
## outcome — and a kill is the opposite of one. The refund keeps its magnitude and moves to
## Breath, the adjacent per-battle casting pool, so the class economy is a currency swap
## rather than a deletion. B11 still owns the number.

const MAX_HUNGER := 5 # PROVISIONAL — B11 owns tuning.
const BREATH_REFUND := 1 # PROVISIONAL — B11 owns tuning.

var hunger: int = 0
var pending_breath_refunds: float = 0.0
var pending_dot_targets: Array[String] = []


func on_action(event: CombatEvent) -> void:
	var resolution: Dictionary = event.data.get("resolution", {}) as Dictionary
	for write_value: Variant in resolution.get("writes", []):
		if write_value is Dictionary and StringName(str((write_value as Dictionary).get("kind", ""))) == &"dot":
			hunger = mini(hunger + 1, MAX_HUNGER)
	if resolution.is_empty() or bool(resolution.get("fizzled", false)):
		return
	var action_id := StringName(str(event.data.get("action_id", "")))
	if action_id.is_empty() or event.target_id.is_empty() or action_id not in [&"strike", &"cast"]:
		return
	if not bool(resolution.get("hit", true)):
		return
	var target_id := String(event.target_id)
	hunger = mini(hunger + 1, MAX_HUNGER)
	if target_id in pending_dot_targets:
		return
	_queue_hunger_dot(event.target_id)


func _queue_hunger_dot(target_id: StringName) -> void:
	var target_key := String(target_id)
	if target_id.is_empty() or hunger <= 0 or target_key in pending_dot_targets:
		return
	pending_dot_targets.append(target_key)
	enqueue_deferred(
		{"writes": [{"kind": "dot", "target_id": String(target_id), "amount": hunger}]},
		{"delay_rounds": 1},
		&"hunger_dot",
	)


func on_deferred_fired(entry: Dictionary) -> void:
	var label := StringName(str(entry.get("label", "")))
	if label == &"hunger_refund":
		pending_breath_refunds = maxf(pending_breath_refunds - float(BREATH_REFUND), 0.0)
		return
	if label != &"hunger_dot":
		return
	var applied: Array = entry.get("applied", []) as Array
	if applied.is_empty() or not (applied[0] is Dictionary):
		return
	var write: Dictionary = applied[0] as Dictionary
	var target_key := String(write.get("target_id", ""))
	pending_dot_targets.erase(target_key)
	if int(write.get("after", 0)) > 0:
		_queue_hunger_dot(StringName(str(write.get("target_id", ""))))


func on_kill(_target_id: StringName, cause: StringName) -> void:
	if cause == &"dot":
		pending_breath_refunds += float(BREATH_REFUND)
		enqueue_deferred(
			{"writes": [{
				"kind": "breath",
				"target_id": String(owner_id),
				"amount": BREATH_REFUND,
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
		"pending_breath_refunds": pending_breath_refunds,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["hunger"] = hunger
	data["pending_breath_refunds"] = pending_breath_refunds
	data["pending_dot_targets"] = pending_dot_targets.duplicate()
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	hunger = clampi(int(data.get("hunger", 0)), 0, MAX_HUNGER)
	# A save written before the Soul->Breath swap carries the old key; read either, so an
	# in-flight refund is not silently dropped by loading an older battle.
	pending_breath_refunds = maxf(
		float(data.get("pending_breath_refunds", data.get("pending_soul_refunds", 0.0))), 0.0
	)
	pending_dot_targets.clear()
	for value: Variant in data.get("pending_dot_targets", []):
		var target_id := str(value)
		if not target_id.is_empty() and target_id not in pending_dot_targets:
			pending_dot_targets.append(target_id)
