class_name OfshutjeAttribution
extends ClassResource
## Stormbearer — Ofshütje: Attribution. The storm chooses the effect.
##
## The table is deliberately a small PROVISIONAL placeholder until B11 supplies the authored
## floor/variance table. Resolution consumes this same table through the hidden-draw channel.

const EFFECT_TABLE := [
	{"id": "surge", "bonus_damage": 1},
	{"id": "fork", "bonus_damage": 2},
	{"id": "thunder", "bonus_damage": 3},
]

var last_effect_id: StringName = &""
var last_effect_floor: int = 0
var last_effect_revealed: bool = false


func attribution_for(seed: int) -> Dictionary:
	var index := absi(seed) % EFFECT_TABLE.size()
	return (EFFECT_TABLE[index] as Dictionary).duplicate(true)


func on_cast_forecast(context: Dictionary) -> Dictionary:
	var ability: Dictionary = context.get("ability", {})
	if not bool(ability.get("is_spell", false)):
		return {}
	return {"hidden_draw": {
		"table_id": "ofshutje_attribution",
		"seed_key": "ofshutje",
		"rows": EFFECT_TABLE.duplicate(true),
	}}


func on_action(event: CombatEvent) -> void:
	if event.actor_id != owner_id:
		return
	var resolution: Dictionary = event.data.get("resolution", {})
	if resolution.is_empty():
		return
	var draw: Dictionary = resolution.get("hidden_draw", {})
	if draw.is_empty():
		return
	var chosen: Dictionary = draw.get("row", {})
	last_effect_id = StringName(str(draw.get("row_id", chosen.get("id", ""))))
	last_effect_floor = int(chosen.get("bonus_damage", 0))
	last_effect_revealed = resolution.has("revealed")


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Attribution",
		"value": String(last_effect_id) if last_effect_revealed else "??",
		"floor": last_effect_floor,
		"hidden": not last_effect_revealed,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["last_effect_id"] = String(last_effect_id)
	data["last_effect_floor"] = last_effect_floor
	data["last_effect_revealed"] = last_effect_revealed
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	last_effect_id = StringName(str(data.get("last_effect_id", "")))
	last_effect_floor = int(data.get("last_effect_floor", 0))
	last_effect_revealed = bool(data.get("last_effect_revealed", false))
