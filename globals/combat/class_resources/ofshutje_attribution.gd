class_name OfshutjeAttribution
extends ClassResource
## Stormbearer — Ofshütje: Attribution. The storm chooses the effect.
##
## B11 (ratified 2026-10-25, owner item 6): the tailed table. Same floor of 1, mean 2.5, and a
## 1-in-6 result worth waiting for. Row weights are repeated rows because the hidden draw is
## uniform over `rows`. Resolution consumes this same table through the hidden-draw channel.

const EFFECT_TABLE := [
	{"id": "surge", "bonus_damage": 1},
	{"id": "surge", "bonus_damage": 1},
	{"id": "fork", "bonus_damage": 2},
	{"id": "fork", "bonus_damage": 2},
	{"id": "thunder", "bonus_damage": 3},
	{"id": "tempest", "bonus_damage": 6},
]

var last_effect_id: StringName = &""
var last_effect_floor: int = 0
var last_effect_revealed: bool = false
## Steadier Hand (#285 slice 2, ruled 2026-10-26): spent once a draw has been redrawn this battle.
var redraw_spent: bool = false


func on_cast_forecast(context: Dictionary) -> Dictionary:
	var ability: Dictionary = context.get("ability", {})
	if not bool(ability.get("is_spell", false)):
		return {}
	return {"hidden_draw": {
		"table_id": "ofshutje_attribution",
		"seed_key": "ofshutje",
		"rows": EFFECT_TABLE.duplicate(true),
		# Resolution redraws a lowest-row result once; the forecast carries the same flag, so
		# the forecast and the commit still draw the same row.
		"redraw_lowest": not redraw_spent and perk_total("redraw_lowest_once") > 0,
		# Named Storm (#285 slice 3): draw twice, keep the higher row.
		"draw_twice_keep_higher": perk_total("draw_twice_keep_higher") > 0,
		# Grounded (#285 slice 3): the lowest row reads as the next one up.
		"floor_lowest": perk_total("floor_lowest_draw") > 0,
		# Tuned Thunder (#285 slice 4): the top row chains a second draw.
		"chain_top": perk_total("chain_on_top_row") > 0,
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
	if bool(draw.get("redrawn", false)):
		redraw_spent = true
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
	data["redraw_spent"] = redraw_spent
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	last_effect_id = StringName(str(data.get("last_effect_id", "")))
	last_effect_floor = int(data.get("last_effect_floor", 0))
	last_effect_revealed = bool(data.get("last_effect_revealed", false))
	redraw_spent = bool(data.get("redraw_spent", false))
