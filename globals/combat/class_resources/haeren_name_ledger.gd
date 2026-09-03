class_name HaerenNameLedger
extends ClassResource
## Haeren — River-Mother: Name-Ledger. Recording a fallen or saved ally's name refunds Gauge;
## each name is recorded once per battle.

const SOUL_REFUND := 1.0 # PROVISIONAL — B11 owns tuning.

var recorded_names: Array[String] = []
var recorded_actor_ids: Array[String] = []
var refunded_actor_ids: Array[String] = []
var pending_soul_refunds: float = 0.0


func record_name(name: String, _saved: bool) -> bool:
	var normalized := name.strip_edges()
	if normalized.is_empty() or recorded_names.has(normalized):
		return false
	recorded_names.append(normalized)
	return true


func on_command(action_id: StringName, target_id: StringName) -> void:
	if action_id != &"record_name" or target_id.is_empty():
		return
	var target := host.actor_by_id(target_id) if host != null else null
	if target == null or not target.is_alive() or not host.allies.has(target):
		return
	var name: String = target.display_name
	if not record_name(name, true):
		return
	recorded_actor_ids.append(String(target_id))


func on_any_action(
	_actor_id: StringName, _action_id: StringName, _target_id: StringName, outcome: Dictionary
) -> void:
	var resolution: Dictionary = outcome.get("resolution", {}) as Dictionary
	for raw: Variant in resolution.get("writes", []):
		if not (raw is Dictionary):
			continue
		var write: Dictionary = raw as Dictionary
		var kind := StringName(str(write.get("kind", "")))
		var target_id := String(write.get("target_id", ""))
		if int(write.get("after", 1)) <= 0 and kind in [&"hp", &"dot"] and target_id in recorded_actor_ids:
			_refund_actor(StringName(target_id))
	if host != null and not host.has_living_enemies():
		for actor_id: String in recorded_actor_ids:
			var actor := host.actor_by_id(StringName(actor_id))
			if actor != null and actor.is_alive():
				_refund_actor(actor.combat_id)


func _refund_actor(actor_id: StringName) -> void:
	if actor_id.is_empty() or actor_id in refunded_actor_ids:
		return
	refunded_actor_ids.append(String(actor_id))
	pending_soul_refunds += SOUL_REFUND
	_queue_refund()


func _queue_refund() -> void:
	enqueue_deferred(
		{"writes": [{"kind": "soul_refund", "target_id": String(owner_id), "amount": SOUL_REFUND}]},
		{"delay_rounds": 0},
		&"name_ledger_refund",
	)


func on_deferred_fired(entry: Dictionary) -> void:
	if StringName(str(entry.get("label", ""))) == &"name_ledger_refund":
		pending_soul_refunds = maxf(pending_soul_refunds - SOUL_REFUND, 0.0)


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Names Remembered",
		"value": recorded_names.size(),
		"pending_soul_refunds": pending_soul_refunds,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["recorded_names"] = recorded_names.duplicate()
	data["recorded_actor_ids"] = recorded_actor_ids.duplicate()
	data["refunded_actor_ids"] = refunded_actor_ids.duplicate()
	data["pending_soul_refunds"] = pending_soul_refunds
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	recorded_names.clear()
	recorded_actor_ids.clear()
	refunded_actor_ids.clear()
	for value: Variant in data.get("recorded_names", []):
		var name := str(value).strip_edges()
		if not name.is_empty() and not recorded_names.has(name):
			recorded_names.append(name)
	for value: Variant in data.get("recorded_actor_ids", []):
		var actor_id := str(value)
		if not actor_id.is_empty() and actor_id not in recorded_actor_ids:
			recorded_actor_ids.append(actor_id)
	for value: Variant in data.get("refunded_actor_ids", []):
		var refunded_id := str(value)
		if not refunded_id.is_empty() and refunded_id not in refunded_actor_ids:
			refunded_actor_ids.append(refunded_id)
	pending_soul_refunds = maxf(float(data.get("pending_soul_refunds", 0.0)), 0.0)
