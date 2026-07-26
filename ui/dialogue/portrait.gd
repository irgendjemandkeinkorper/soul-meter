class_name SMPortrait
extends PanelContainer
## Portrait (DS: components/narrative/Portrait) — how every named character appears.
## The ring colour is the character's ATTUNEMENT ELEMENT, not their faction.
## Epithets go in `subtitle` — Dramgid characters are known by titles more than names.
## Until the DS art PNGs come over, an initial-monogram stands in for `image`.

@export var character_name: String = "":
	set(v):
		character_name = v
		_refresh()
@export var subtitle: String = "":
	set(v):
		subtitle = v
		_refresh()
## Wheel-of-Ten element id ("scor", "molm", …) — colours the ring.
@export var element: String = "":
	set(v):
		element = v
		_refresh()
@export var portrait_size: int = 96

var _frame: PanelContainer
var _monogram: Label
var _name_label: Label
var _subtitle_label: Label


func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", DS.SPACE_2)
	add_child(vbox)

	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(portrait_size, portrait_size)
	vbox.add_child(_frame)

	_monogram = Label.new()
	_monogram.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monogram.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_monogram.theme_type_variation = "TitleLabel"
	_frame.add_child(_monogram)

	_name_label = Label.new()
	_name_label.theme_type_variation = "HeadingLabel"
	vbox.add_child(_name_label)

	_subtitle_label = Label.new()
	_subtitle_label.theme_type_variation = "QuoteLabel"
	vbox.add_child(_subtitle_label)
	_refresh()


func _element_color() -> Color:
	for e in DS.WHEEL:
		if e["id"] == element:
			return e["color"]
	return DS.IRON_2


func _refresh() -> void:
	if _frame == null:
		return
	var ring := StyleBoxFlat.new()
	ring.bg_color = DS.VOID_1                     # inset well behind the (future) image
	ring.border_color = _element_color()          # the attunement ring
	ring.set_border_width_all(DS.BORDER_TRIM_W)
	ring.set_corner_radius_all(DS.RADIUS)
	_frame.add_theme_stylebox_override("panel", ring)
	_monogram.text = character_name.left(1)
	_monogram.modulate = _element_color()
	_name_label.text = character_name
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()
