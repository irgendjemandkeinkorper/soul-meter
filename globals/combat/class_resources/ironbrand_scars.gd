class_name IronbrandScars
extends ClassResource
## Kero — Ironbrand: **Scars**. The worked example for the B-wave (#223 → #226 completes it).
##
## Vault `systems/magic-system.md` §Per-class resources: "Taking (or self-inflicting) damage
## banks Scars; spend them for guaranteed-hit / guaranteed-crit windows."
##
## Mechanics here: every HP loss banks one Scar (cap `MAX_SCARS`, PROVISIONAL — B11 owns the
## number). `spend_scar()` arms a guaranteed-hit window; `on_cast_forecast()` expresses it as
## `{"to_hit_enabled": false}` — Resolution's existing "no to-hit roll" channel — so the forecast
## and the commit both see a certain hit. The window is consumed by the owner's next resolved
## action (`on_action`), never by a forecast. Guaranteed-crit is #226's job (no crit channel
## exists in Resolution yet; do not invent one here).

const MAX_SCARS := 5  # PROVISIONAL — B11 numeric pass

var scars: int = 0
var guaranteed_hit_armed: bool = false


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
	return [&"spend_scars"]


func query_command(action_id: StringName, target_id: StringName, payload: Dictionary = {}) -> Dictionary:
	var gate := super.query_command(action_id, target_id, payload)
	if not bool(gate.allowed):
		return gate
	if guaranteed_hit_armed:
		return command_refusal(&"class_resource_armed", "Your guaranteed hit is already armed. Resolve an attack first.")
	if scars <= 0:
		return command_refusal(&"class_resource_empty", "No Scars banked. Taking damage banks a Scar.")
	return gate


func on_command(action_id: StringName, _target_id: StringName) -> void:
	if action_id != &"spend_scars":
		return
	spend_scar()


func on_cast_forecast(_context: Dictionary) -> Dictionary:
	if guaranteed_hit_armed:
		return {"to_hit_enabled": false}
	return {}


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
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	scars = clampi(int(data.get("scars", 0)), 0, max_scars())
	guaranteed_hit_armed = bool(data.get("guaranteed_hit_armed", false))
