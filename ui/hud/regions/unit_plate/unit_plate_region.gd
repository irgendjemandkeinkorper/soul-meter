class_name UnitPlateRegion
extends PanelContainer

const UnitArtScript := preload("res://globals/unit_art.gd")

@onready var portrait: TextureRect = %Portrait
@onready var name_label: Label = %UnitName
@onready var hp_label: Label = %HP
@onready var breath_label: Label = %Breath
@onready var aftertones_label: Label = %Aftertones
@onready var tempo_label: Label = %Tempo
@onready var element_label: Label = %Element
@onready var ct_label: Label = %CT
@onready var resource_label: Label = %Resource


func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", event.data)
	var unit: Dictionary = snapshot.get("active_unit", snapshot.get("actor", {}))
	if unit.is_empty():
		unit = _active_from_rosters(snapshot)
	if unit.is_empty():
		return
	name_label.text = str(unit.get("name", unit.get("display_name", unit.get("id", "ACTIVE UNIT"))))
	hp_label.text = "HP %d / %d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", unit.get("hp", 0)))]
	breath_label.text = "BREATH %d" % int(unit.get("breath", 0))
	aftertones_label.text = "AFTERTONES %s" % _aftertone_pips(unit.get("aftertones", []))
	tempo_label.text = "TEMPO %d" % int(unit.get("tempo", 0))
	var element := str(unit.get("element_id", ""))
	element_label.text = "UNATTUNED" if element.is_empty() else element.to_upper()
	ct_label.text = _ct_line(unit)
	resource_label.text = _resource_line(unit.get("class_resource", {}))
	portrait.texture = _portrait_for(unit)


## Snapshots carry no portrait textures — fall back to the same painterly unit
## art the stage renders, resolved from the roster keys the payload does carry.
func _portrait_for(unit: Dictionary) -> Texture2D:
	var provided := unit.get("portrait", null) as Texture2D
	if provided != null:
		return provided
	var unit_id := UnitArtScript.combat_unit_id(
		StringName(str(unit.get("side", "ally"))),
		str(unit.get("archetype_id", "")),
		str(unit.get("display_name", unit.get("name", "")))
	)
	return load(UnitArtScript.texture_path(UnitArtScript.resolve(unit_id))) as Texture2D


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


func _resource_line(resource: Variant) -> String:
	if not resource is Dictionary or (resource as Dictionary).is_empty():
		return ""
	var data: Dictionary = resource as Dictionary
	if bool(data.get("hidden_on_plate", false)):
		return ""
	var label := str(data.get("label", ""))
	if label.is_empty():
		return ""
	var value := str(data.get("value", ""))
	var maximum := str(data.get("max", ""))
	return "%s %s / %s" % [label.to_upper(), value, maximum] if not maximum.is_empty() else "%s %s" % [label.to_upper(), value]


func _aftertone_pips(value: Variant) -> String:
	if not value is Array or (value as Array).is_empty():
		return "—"
	var pips: Array[String] = []
	for entry: Variant in value as Array:
		if entry is Dictionary:
			var element := str((entry as Dictionary).get("element", "?")).to_upper()
			var rounds := int((entry as Dictionary).get("remaining_rounds", 0))
			pips.append("%s:%d" % [element, rounds])
	return " ".join(pips)
