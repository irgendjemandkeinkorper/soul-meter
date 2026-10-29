class_name StuidClarity
extends ClassResource
## Lensbearer — Stuid: Clarity. A depleting reserve burned to expose one forecast.
##
## Vault `systems/magic-system.md` §Per-class resources: "A depleting stat burned for
## guaranteed information (true fizzle %, hidden resistances, traps)."
##
## The armed reveal is returned through the shared forecast context and consumed only after
## the owner's cast outcome is committed.

const MAX_CLARITY := 3  # PROVISIONAL — B11 owns the cap

var clarity: int = MAX_CLARITY
var reveal_armed: bool = false
## Read Aloud (#285 slice 5): the round the reveal was armed in; allies read it only then.
var armed_round: int = -1
## Kept Focus (#285 slice 4): Clarity carried in from the last battle, held above the cap.
var carried_in: int = 0


## The live cap: MAX_CLARITY plus any picked `cap_delta` perk (Wider Lens, #285 slice 2).
func max_clarity() -> int:
	return MAX_CLARITY + perk_total("cap_delta")


## Kept Focus: one unspent Clarity carries into the next battle, on top of a full start.
func carry_out() -> Dictionary:
	var kept := mini(clarity, perk_total("carry_one_clarity"))
	return {"clarity": kept} if kept > 0 else {}


func receive_carry(carried: Dictionary) -> void:
	carried_in = maxi(int(carried.get("clarity", 0)), 0)
	clarity += carried_in


## Wider Lens raises the start with the cap: start and cap are both 3, so a higher cap alone
## would leave the extra point empty on turn one (docs/perks-draft-285.md §6).
func _on_perks_applied() -> void:
	clarity = max_clarity()


func spend_clarity() -> bool:
	if clarity <= 0 or reveal_armed:
		return false
	clarity -= 1
	reveal_armed = true
	armed_round = host.round_number if host != null else -1
	return true


## `data/combat/actions/21_spend_clarity.tres` is the button. The armed reveal
## is still consumed by the owner's next committed cast, not by the command.
func commands() -> Array[StringName]:
	return [&"spend_clarity", &"sacred_clarity"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	if action_id == &"sacred_clarity":
		return _query_read(target_id, gate)
	if reveal_armed:
		return command_refusal(&"class_resource_armed", "Clarity is already armed for your next cast.")
	if clarity <= 0:
		return command_refusal(&"class_resource_empty", "No Clarity remains in this battle.")
	return gate


func on_command(action_id: StringName, target_id: StringName) -> void:
	if action_id == &"sacred_clarity":
		_read_enemy(target_id)
		return
	if action_id != &"spend_clarity":
		return
	spend_clarity()


## Sacred Clarity (#285 slice 5, ruled 2026-10-29): one Clarity locks an enemy's next action and
## shows it. It never touches the armed cast reveal; the two compete for the same Clarity.
func _query_read(target_id: StringName, gate: Dictionary) -> Dictionary:
	var missing := perk_refusal("sacred_clarity", "Sacred Clarity")
	if not missing.is_empty():
		return missing
	if clarity < perk_total("sacred_clarity"):
		return command_refusal(&"class_resource_empty", "No Clarity remains in this battle.")
	if host != null and host.is_intent_locked(target_id):
		return command_refusal(&"intent_read", "That enemy is already read.")
	return gate


func _read_enemy(target_id: StringName) -> void:
	var cost := perk_total("sacred_clarity")
	if cost <= 0 or clarity < cost or host == null:
		return
	if bool(host.lock_enemy_intent(target_id, owner_id).get("allowed", false)):
		clarity -= cost


## Read Aloud (#285 slice 5): an armed reveal also shows on an ally's spell forecast, in the
## round it was armed. Allies read it; only the owner's committed cast spends it.
func on_ally_cast_forecast(_actor_id: StringName, context: Dictionary) -> Dictionary:
	if perk_total("read_aloud") <= 0 or not reveal_armed or host == null or host.round_number != armed_round:
		return {}
	var ability: Dictionary = context.get("ability", {})
	return {"reveal": true} if bool(ability.get("is_spell", false)) else {}


func on_cast_forecast(_context: Dictionary) -> Dictionary:
	var ability: Dictionary = _context.get("ability", {})
	if not reveal_armed or not bool(ability.get("is_spell", false)):
		return {}
	return {"reveal": true}


func on_action(event: CombatEvent) -> void:
	if not reveal_armed or event.actor_id != owner_id:
		return
	var data: Dictionary = event.data
	var action_verb: Variant = data.get("verb", null)
	var action_kind: Variant = data.get("kind", null)
	if action_verb != CombatAction.Verb.CAST and action_kind != CombatAction.Kind.CAST:
		return
	if data.has("resolution") and not (data.get("resolution", {}) as Dictionary).is_empty():
		reveal_armed = false


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Clarity",
		"value": clarity,
		"max": max_clarity(),
		"armed": reveal_armed,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["clarity"] = clarity
	data["reveal_armed"] = reveal_armed
	data["armed_round"] = armed_round
	data["carried_in"] = carried_in
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	carried_in = maxi(int(data.get("carried_in", 0)), 0)
	clarity = clampi(int(data.get("clarity", max_clarity())), 0, max_clarity() + carried_in)
	reveal_armed = bool(data.get("reveal_armed", false))
	armed_round = int(data.get("armed_round", -1))
