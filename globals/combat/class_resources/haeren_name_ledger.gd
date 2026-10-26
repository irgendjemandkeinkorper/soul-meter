class_name HaerenNameLedger
extends ClassResource
## Haeren — River-Mother: Name-Ledger. Recording a fallen or saved ally's name returns Breath;
## each name is recorded once per battle.
##
## It used to return Soul Gauge. Owner ruling (docs/game-identity.md ruling 3, reaffirmed
## 2026-09-08 on #286): the Gauge rises ONLY through an act of Agreement, and an act of
## Agreement is a tagged quest outcome — not something a combat resource can mint. Naming the
## fallen is arguably the closest a class comes to one, so if the owner wants this specific
## refund to credit Soul, the change is to route it through the quest system's tagged path,
## not to reopen a second income channel here. Magnitude unchanged; B11 owns the number.

const BREATH_REFUND := 1 # PROVISIONAL — B11 owns tuning.

var recorded_names: Array[String] = []
var recorded_actor_ids: Array[String] = []
var refunded_actor_ids: Array[String] = []
var pending_breath_refunds: float = 0.0


func record_name(name: String, _saved: bool) -> bool:
	var normalized := name.strip_edges()
	if normalized.is_empty() or recorded_names.has(normalized):
		return false
	recorded_names.append(normalized)
	return true


func commands() -> Array[StringName]:
	return [&"record_name"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	var target := host.actor_by_id(target_id) if host != null else null
	if target == null or not target.is_alive() or not host.allies.has(target):
		return command_refusal(&"no_target", "Record Name requires a living ally.")
	if recorded_actor_ids.count(String(target_id)) >= _record_limit(target_id) or (
		target_id != owner_id and recorded_names.has(target.display_name.strip_edges())
	):
		return command_refusal(&"class_resource_duplicate", "That name is already recorded in this battle.")
	return gate


## Own Name Twice (#285 slice 3): the River-Mother's own name may be recorded twice per battle.
func _record_limit(target_id: StringName) -> int:
	if target_id == owner_id and perk_total("own_name_twice") > 0:
		return perk_total("own_name_twice")
	return 1


func on_command(action_id: StringName, target_id: StringName) -> void:
	if action_id != &"record_name" or target_id.is_empty():
		return
	var target := host.actor_by_id(target_id) if host != null else null
	if target == null or not target.is_alive() or not host.allies.has(target):
		return
	var name: String = target.display_name
	if recorded_actor_ids.count(String(target_id)) >= _record_limit(target_id):
		return
	if not record_name(name, true) and not recorded_actor_ids.has(String(target_id)):
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
			_refund_actor(StringName(target_id), true)
	if host != null and not host.has_living_enemies():
		for actor_id: String in recorded_actor_ids:
			var actor := host.actor_by_id(StringName(actor_id))
			if actor != null and actor.is_alive():
				_refund_actor(actor.combat_id)


## Longer Ledger (#285 slice 2, ruled 2026-10-25 flag B): the first name to pay each battle
## pays `first_payer_multiplier` times. "First" is the first refund this battle, whichever path
## paid it; `refunded_actor_ids` is per battle, so it is empty exactly once.
## A name recorded twice (Own Name Twice) pays once per recording. Names Carried (#285 slice 3):
## when a recorded ally FALLS, every other living recorded ally gets the base refund too.
func _refund_actor(actor_id: StringName, fell: bool = false) -> void:
	if actor_id.is_empty() or actor_id in refunded_actor_ids:
		return
	var amount := BREATH_REFUND * maxi(recorded_actor_ids.count(String(actor_id)), 1)
	var multiplier := perk_total("first_payer_multiplier")
	if refunded_actor_ids.is_empty() and multiplier > 1:
		amount *= multiplier
	refunded_actor_ids.append(String(actor_id))
	pending_breath_refunds += float(amount)
	var carried: Array[String] = []
	if fell and perk_total("refund_reaches_all_recorded") > 0 and host != null:
		for recorded_id: String in recorded_actor_ids:
			var ally := host.actor_by_id(StringName(recorded_id))
			if recorded_id != String(actor_id) and recorded_id != String(owner_id) \
					and recorded_id not in carried and ally != null and ally.is_alive():
				carried.append(recorded_id)
	_queue_refund(amount, carried)


func _queue_refund(amount: int = BREATH_REFUND, carried: Array[String] = []) -> void:
	var writes: Array = [{"kind": "breath", "target_id": String(owner_id), "amount": amount}]
	for ally_id: String in carried:
		writes.append({"kind": "breath", "target_id": ally_id, "amount": BREATH_REFUND})
	enqueue_deferred({"writes": writes}, {"delay_rounds": 0}, &"name_ledger_refund")


func on_combatant_fell(target_id: StringName) -> void:
	if String(target_id) in recorded_actor_ids:
		_refund_actor(target_id, true)


func on_battle_end(victory: bool) -> void:
	if not victory or host == null:
		return
	for actor_id: String in recorded_actor_ids:
		var actor := host.actor_by_id(StringName(actor_id))
		if actor != null and actor.is_alive():
			_refund_actor(actor.combat_id)


func on_deferred_fired(entry: Dictionary) -> void:
	if StringName(str(entry.get("label", ""))) == &"name_ledger_refund":
		pending_breath_refunds = maxf(pending_breath_refunds - _entry_amount(entry), 0.0)


## The Breath an entry carries to the River-Mother herself (the first write); Names Carried's
## writes to other allies are not hers to settle. BREATH_REFUND for an older entry.
func _entry_amount(entry: Dictionary) -> float:
	var effect: Variant = entry.get("effect", {})
	if effect is Dictionary:
		for raw: Variant in (effect as Dictionary).get("writes", []):
			if raw is Dictionary and str((raw as Dictionary).get("kind", "")) == "breath":
				return float((raw as Dictionary).get("amount", BREATH_REFUND))
	return float(BREATH_REFUND)


func on_deferred_cancelled(entry: Dictionary, _by_id: StringName) -> void:
	on_deferred_fired(entry)


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Names Remembered",
		"value": recorded_names.size(),
		"pending_breath_refunds": pending_breath_refunds,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["recorded_names"] = recorded_names.duplicate()
	data["recorded_actor_ids"] = recorded_actor_ids.duplicate()
	data["refunded_actor_ids"] = refunded_actor_ids.duplicate()
	data["pending_breath_refunds"] = pending_breath_refunds
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
	# A save written before the Soul->Breath swap carries the old key; read either.
	pending_breath_refunds = maxf(
		float(data.get("pending_breath_refunds", data.get("pending_soul_refunds", 0.0))), 0.0
	)
