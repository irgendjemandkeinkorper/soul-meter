class_name SMPortrait
extends PanelContainer
## Portrait (DS: components/narrative/Portrait) — how every named character appears.
## The ring colour is the character's ATTUNEMENT ELEMENT, not their faction.
## Epithets go in `subtitle` — Dramgid characters are known by titles more than names.
## Until real source images are assigned in Pandora, the generated NPC id drives
## a stable monogram card and one of the design system's portrait variations.

const NpcRosterScript := preload("res://globals/npc_roster.gd")

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
@export var portrait_id: String = "":
	set(v):
		portrait_id = v
		_refresh()
@export var portrait_path: String = "":
	set(v):
		portrait_path = v
		_refresh()
@export var portrait_size: int = 96

var _frame: PanelContainer
var _image: TextureRect
var _placeholder: VBoxContainer
var _monogram: Label
var _mark: Label
var _name_label: Label
var _subtitle_label: Label


func _ready() -> void:
	var vbox := VBoxContainer.new()
	vbox.theme_type_variation = "NpcPortraitColumn"
	add_child(vbox)

	_frame = PanelContainer.new()
	_frame.custom_minimum_size = Vector2(portrait_size, portrait_size)
	vbox.add_child(_frame)

	_image = TextureRect.new()
	_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_image.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_image)

	_placeholder = VBoxContainer.new()
	_placeholder.alignment = BoxContainer.ALIGNMENT_CENTER
	_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_placeholder)

	_monogram = Label.new()
	_monogram.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_monogram.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_monogram.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_placeholder.add_child(_monogram)

	_mark = Label.new()
	_mark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mark.theme_type_variation = "NpcPortraitMark"
	_placeholder.add_child(_mark)

	_name_label = Label.new()
	_name_label.theme_type_variation = "HeadingLabel"
	vbox.add_child(_name_label)

	_subtitle_label = Label.new()
	_subtitle_label.theme_type_variation = "QuoteLabel"
	vbox.add_child(_subtitle_label)
	_refresh()

func _refresh() -> void:
	if _frame == null:
		return
	var descriptor := NpcRosterScript.portrait_descriptor(portrait_id)
	var palette_index := _palette_index(descriptor)
	_frame.theme_type_variation = "NpcPortraitFrame%d" % palette_index
	_monogram.theme_type_variation = "NpcPortraitMonogram%d" % palette_index
	_monogram.text = str(descriptor.get("monogram", _initials(character_name)))
	_mark.text = str(descriptor.get("mark", _fallback_mark()))
	_mark.visible = not _mark.text.is_empty()

	var asset_path := portrait_path
	if asset_path.is_empty():
		asset_path = str(descriptor.get("asset_path", ""))
	if asset_path.is_empty():
		asset_path = NpcRosterScript.unit_portrait_path(portrait_id)
	var texture := NpcRosterScript.load_portrait_texture(asset_path)
	_image.texture = texture
	_image.visible = texture != null
	_placeholder.visible = texture == null
	_name_label.text = character_name
	_subtitle_label.text = subtitle
	_subtitle_label.visible = not subtitle.is_empty()


func _palette_index(descriptor: Dictionary) -> int:
	if descriptor.has("palette_index"):
		return clampi(int(descriptor["palette_index"]), 0, DS.WHEEL.size() - 1)
	for index: int in DS.WHEEL.size():
		if DS.WHEEL[index]["id"] == element:
			return index
	if not portrait_id.is_empty():
		return (portrait_id.hash() & 0x7fffffff) % DS.WHEEL.size()
	return 8  # Nul: the neutral placeholder treatment.


func _initials(value: String) -> String:
	var parts := value.split(" ", false)
	if parts.is_empty():
		return "?"
	if parts.size() == 1:
		return parts[0].left(2).to_upper()
	return (parts[0].left(1) + parts[-1].left(1)).to_upper()


func _fallback_mark() -> String:
	return portrait_id.sha256_text().left(4).to_upper() if not portrait_id.is_empty() else ""
