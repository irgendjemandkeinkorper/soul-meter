class_name OfshutjeAttribution
extends ClassResource
## Stormbearer — Ofshütje: Attribution. The storm chooses the effect.
##
## The table is deliberately a small PROVISIONAL placeholder until B11 supplies the authored
## floor/variance table. The B0 seam has no Resolution term for a seeded effect draw, so this
## resource exposes the deterministic draw without pretending it changes damage yet.

const EFFECT_TABLE := [
	{"id": "surge", "floor": 1},
	{"id": "fork", "floor": 2},
	{"id": "thunder", "floor": 3},
]

var last_effect_id: StringName = &""
var last_effect_floor: int = 0


func attribution_for(seed: int) -> Dictionary:
	var index := absi(seed) % EFFECT_TABLE.size()
	return (EFFECT_TABLE[index] as Dictionary).duplicate(true)


func on_action(event: CombatEvent) -> void:
	var resolution: Dictionary = event.data.get("resolution", {})
	if resolution.is_empty():
		return
	var chosen := attribution_for(int(resolution.get("seed", 0)))
	last_effect_id = StringName(str(chosen.get("id", "")))
	last_effect_floor = int(chosen.get("floor", 0))


func snapshot() -> Dictionary:
	return {
		"patron_id": String(patron_id),
		"label": "Attribution",
		"value": String(last_effect_id),
		"floor": last_effect_floor,
		"hidden": true,
	}


func to_dict() -> Dictionary:
	var data: Dictionary = super.to_dict()
	data["last_effect_id"] = String(last_effect_id)
	data["last_effect_floor"] = last_effect_floor
	return data


func from_dict(data: Dictionary) -> void:
	super.from_dict(data)
	last_effect_id = StringName(str(data.get("last_effect_id", "")))
	last_effect_floor = int(data.get("last_effect_floor", 0))
