class_name Badge
extends PanelContainer
## Element/zone/weak/resist chip using the DS text-presentation sigils.

enum Kind { ELEMENT, ZONE, WEAK, RESIST }

@export var text := "":
	set(next_text):
		text = next_text
		_refresh()
@export var element_id := &"":
	set(next_id):
		element_id = next_id
		_refresh()
@export var kind := Kind.ELEMENT:
	set(next_kind):
		kind = next_kind
		_refresh()

var _label: Label


func _ready() -> void:
	_label = Label.new()
	_label.theme_type_variation = "BadgeLabel"
	add_child(_label)
	_refresh()


func _refresh() -> void:
	theme_type_variation = ["Badge", "BadgeZone", "BadgeWeak", "BadgeResist"][kind]
	if not is_instance_valid(_label):
		return
	var prefix := ""
	for element: Dictionary in DS.WHEEL:
		if StringName(element["id"]) == element_id:
			prefix = "%s " % element["sigil"]
			break
	_label.text = prefix + text
