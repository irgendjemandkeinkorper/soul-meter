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
		return
	name_label.text = str(unit.get("name", unit.get("id", "ACTIVE UNIT")))
	hp_label.text = "HP %d / %d" % [int(unit.get("hp", 0)), int(unit.get("max_hp", unit.get("hp", 0)))]
	element_label.text = str(unit.get("element_id", "UNATTUNED")).to_upper()
	ct_label.text = "CT %d · SPD %d · H%d · FACING %s" % [int(unit.get("ct", 0)), int(unit.get("speed", 0)), int(unit.get("height", unit.get("height_delta", 0))), str(unit.get("facing", "E")).to_upper()]
	portrait.texture = unit.get("portrait", null) as Texture2D
