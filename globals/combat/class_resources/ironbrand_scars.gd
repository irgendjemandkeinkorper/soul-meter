class_name IronbrandScars
extends ClassResource
## Kero — Ironbrand: **Scars**. The worked example for the B-wave (#223 → #226 completes it).
##
## Vault `systems/magic-system.md` §Per-class resources: "Taking (or self-inflicting) damage
## banks Scars; spend them for guaranteed-hit / guaranteed-crit windows."
##
## Mechanics here: every HP loss banks one Scar (cap `MAX_SCARS`, B11, ratified
## 2026-10-25). `spend_scar()` arms a guaranteed-hit window; `on_cast_forecast()` expresses it as
## `{"to_hit_enabled": false}` — Resolution's existing "no to-hit roll" channel — so the forecast
## and the commit both see a certain hit. The window is consumed by the owner's next resolved
## action (`on_action`), never by a forecast. Guaranteed-crit is #226's job (no crit channel
## exists in Resolution yet; do not invent one here).

const MAX_SCARS := 3  # B11, ratified 2026-10-25 (owner item 6): reached under pressure, so banking is a choice.

var scars: int = 0
var guaranteed_hit_armed: bool = false
## Debt of Arms (#285 slice 4, ruled 2026-10-26): whose next attack carries the paid bonus.
var debt_target_id: StringName = &""
const DEBT_HP := 6


## The live cap: MAX_SCARS plus any picked `cap_delta` perk (Thick Hide, #285 slice 2).
func max_scars() -> int:
	return MAX_SCARS + perk_total("cap_delta")


## First Blood (#285 slice 3): the first Scar each battle is banked when combat starts.
func _on_perks_applied() -> void:
	if perk_total("bank_scar_at_start") > 0:
		scars = mini(maxi(scars, perk_total("bank_scar_at_start")), max_scars())


func on_damage_taken(amount: int, _source_id: StringName) -> void:
	if amount <= 0:
		return
	scars = mini(scars + 1, max_scars())


## Arms a guaranteed hit for the owner's next resolved action. Returns false when no Scar is
## banked or a window is already armed (spending twice would waste a Scar).
func spend_scar() -> bool:
	if scars <= 0 or guaranteed_hit_armed:
		return false
	scars -= 1
	guaranteed_hit_armed = true
	return true


## `data/combat/actions/20_spend_scars.tres` is the button; the window it arms
## is consumed by the owner's next resolved action, exactly as `spend_scar()`
## describes. The command adds no second path — it only exposes the existing one.
func commands() -> Array[StringName]:
	return [&"spend_scars", &"debt_of_arms"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	if action_id == &"debt_of_arms":
		return _query_debt(target_id, gate)
	if guaranteed_hit_armed:
		return command_refusal(&"class_resource_armed", "Your guaranteed hit is already armed. Resolve an attack first.")
	if scars <= 0:
		return command_refusal(&"class_resource_empty", "No Scars banked. Taking damage banks a Scar.")
	return gate


func on_command(action_id: StringName, target_id: StringName) -> void:
	if action_id == &"debt_of_arms":
		_pay_debt(target_id)
		return
	if action_id != &"spend_scars":
		return
	spend_scar()


func _query_debt(target_id: StringName, gate: Dictionary) -> Dictionary:
	var missing := perk_refusal("debt_of_arms", "Debt of Arms")
	if not missing.is_empty():
		return missing
	if not debt_target_id.is_empty():
		return command_refusal(&"class_resource_armed", "A debt is already owed. Resolve that attack first.")
	var owner := host.actor_by_id(owner_id) if host != null else null
	var target := host.actor_by_id(target_id) if host != null else null
	if target == null or not target.is_alive() or not host.allies.has(target):
		return command_refusal(&"no_target", "Debt of Arms needs a living ally, or yourself.")
	if owner == null or owner.hp <= 1:
		return command_refusal(&"class_resource_empty", "Not enough HP left to pay the debt.")
	return gate


## Pays up to DEBT_HP (never below 1 HP) through the controller's write path, so the loss banks
## a Scar like any other; the target's next landed attack carries `debt_of_arms` bonus damage.
func _pay_debt(target_id: StringName) -> void:
	var owner := host.actor_by_id(owner_id) if host != null else null
	if owner == null or owner.hp <= 1 or not debt_target_id.is_empty() or perk_total("debt_of_arms") <= 0:
		return
	debt_target_id = target_id
	enqueue_deferred(
		{"writes": [{"kind": "hp", "target_id": String(owner_id), "amount": mini(DEBT_HP, owner.hp - 1)}]},
		{"delay_rounds": 0},
		&"debt_of_arms",
	)


func on_ally_cast_forecast(actor_id: StringName, _context: Dictionary) -> Dictionary:
	if debt_target_id.is_empty() or actor_id != debt_target_id:
		return {}
	return {"bonus_damage": perk_total("debt_of_arms")}


## The debt is settled by the target's next resolved attack or cast, hit or miss.
func on_any_action(
	actor_id: StringName, _action_id: StringName, _target_id: StringName, outcome: Dictionary
) -> void:
	if debt_target_id.is_empty() or actor_id != debt_target_id:
		return
	if not (outcome.get("resolution", {}) as Dictionary).is_empty():
		debt_target_id = &""


func on_cast_forecast(_context: Dictionary) -> Dictionary:
	var overrides := {}
	if guaranteed_hit_armed:
		overrides["to_hit_enabled"] = false
	if not debt_target_id.is_empty() and debt_target_id == owner_id:
		overrides["bonus_damage"] = perk_total("debt_of_arms")
	return overrides


func on_action(event: CombatEvent) -> void:
	# Only an action that actually resolved an attack/cast consumes the window; a move or a
	# guard leaves it armed for the strike that follows.
	if not guaranteed_hit_armed:
		return
	var data: Dictionary = event.data
	var resolution: Dictionary = data.get("resolution", {}) as Dictionary
	if not resolution.is_empty():
		guaranteed_hit_armed = false
		# Debt Collected (#285 slice 3): the Scar comes back when the guaranteed hit downs its target.
		if perk_total("refund_scar_on_down") > 0 and _downed(resolution, String(event.target_id)):
			scars = mini(scars + perk_total("refund_scar_on_down"), max_scars())


static func _downed(resolution: Dictionary, target_id: String) -> bool:
	if target_id.is_empty():
		return false
	for raw: Variant in resolution.get("writes", []):
		if raw is Dictionary and str((raw as Dictionary).get("kind", "")) == "hp" \
				and str((raw as Dictionary).get("target_id", "")) == target_id \
				and int((raw as Dictionary).get("after", 1)) <= 0:
			return true
	return false


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Scars",
		"value": scars,
		"max": max_scars(),
		"armed": guaranteed_hit_armed,
	}


func to_dict() -> Dictionary:
	var data := super.to_dict()
	data["scars"] = scars
	data["guaranteed_hit_armed"] = guaranteed_hit_armed
	data["debt_target_id"] = String(debt_target_id)
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	scars = clampi(int(data.get("scars", 0)), 0, max_scars())
	guaranteed_hit_armed = bool(data.get("guaranteed_hit_armed", false))
	debt_target_id = StringName(str(data.get("debt_target_id", "")))
