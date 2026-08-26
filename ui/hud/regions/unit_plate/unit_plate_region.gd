class_name UnitPlateRegion
extends PanelContainer

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %UnitName
@onready var hp_label: Label = %HP
@onready var element_label: Label = %Element
@onready var ct_label: Label = %CT


func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", event.data)
	var unit: Dictionary = snapshot.get("active_unit", snapshot.get("actor", {}))
	if unit.is_empty():
		unit = _active_from_rosters(snapshot)
	if unit.is_empty():
		return
	name_label.text = str(unit.get("name", unit.get("display_name", unit.get("id", "ACTIVE UNIT"))))
	hp_label.text = "HP %d / %d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", unit.get("hp", 0)))]
	var element := str(unit.get("element_id", ""))
	element_label.text = "UNATTUNED" if element.is_empty() else element.to_upper()
	ct_label.text = _ct_line(unit)
	portrait.texture = unit.get("portrait", null) as Texture2D


## CombatController snapshots carry the active unit as `active_actor_id` plus
## `allies`/`enemies` roster arrays (CT banked under "charge"), not as a prebuilt
## `active_unit` dictionary — resolve it from the rosters when needed.
func _active_from_rosters(snapshot: Dictionary) -> Dictionary:
	var active_id := StringName(str(snapshot.get("active_actor_id", "")))
	if active_id == &"":
		return {}
	for group_key in ["allies", "enemies"]:
		var group: Variant = snapshot.get(group_key, [])
		if group is not Array:
			continue
		for value: Variant in group as Array:
			if value is Dictionary and StringName(str((value as Dictionary).get("id", ""))) == active_id:
				return value as Dictionary
	return {}


## Only render the segments the payload actually carries — the production snapshot has
## no speed/height yet, and "SPD 0 · H0" would be fabricated data on the HUD.
func _ct_line(unit: Dictionary) -> String:
	var parts: Array[String] = ["CT %d" % int(unit.get("ct", unit.get("charge", 0)))]
	if unit.has("speed"):
		parts.append("SPD %d" % int(unit.get("speed", 0)))
	if unit.has("height") or unit.has("height_delta"):
		parts.append("H%d" % int(unit.get("height", unit.get("height_delta", 0))))
	var facing := str(unit.get("facing", ""))
	if not facing.is_empty():
		parts.append("FACING %s" % facing.to_upper())
	return " · ".join(parts)
