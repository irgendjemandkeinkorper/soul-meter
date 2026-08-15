class_name SoulItemSlot
extends CtrlInventoryItemBase
## Reusable GLoot item presentation with closed-set rarity styling and captions.

@export var small := false
@export var hotkey := ""

var _frame: PanelContainer
var _icon: TextureRect
var _stack: Label
var _hotkey: Label
var _cost: Label
var _old_item: InventoryItem


func _ready() -> void:
	item_changed.connect(_on_item_changed)
	_frame = PanelContainer.new()
	_frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_frame)
	_icon = TextureRect.new()
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_frame.add_child(_icon)
	_stack = _caption(HORIZONTAL_ALIGNMENT_RIGHT, VERTICAL_ALIGNMENT_BOTTOM)
	_hotkey = _caption(HORIZONTAL_ALIGNMENT_LEFT, VERTICAL_ALIGNMENT_TOP)
	_cost = _caption(HORIZONTAL_ALIGNMENT_CENTER, VERTICAL_ALIGNMENT_BOTTOM)
	add_child(_stack)
	add_child(_hotkey)
	add_child(_cost)
	custom_minimum_size = Vector2.ONE * (DS.SLOT_SIZE_SM if small else DS.SLOT_SIZE)
	_refresh()


func _caption(horizontal: HorizontalAlignment, vertical: VerticalAlignment) -> Label:
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.theme_type_variation = "ItemSlotCaption"
	label.horizontal_alignment = horizontal
	label.vertical_alignment = vertical
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _on_item_changed() -> void:
	if is_instance_valid(_old_item) and _old_item.property_changed.is_connected(_on_property_changed):
		_old_item.property_changed.disconnect(_on_property_changed)
	_old_item = item
	if is_instance_valid(item):
		item.property_changed.connect(_on_property_changed)
	_refresh()


func _on_property_changed(_property: String) -> void:
	_refresh()


func _refresh() -> void:
	if not is_instance_valid(_frame):
		return
	var rarity := "common"
	if is_instance_valid(item):
		rarity = str(item.get_property("rarity", "common")).to_lower()
	if rarity not in ["common", "rare", "mythic"]:
		rarity = "common"
	_frame.theme_type_variation = "ItemSlot%s" % rarity.capitalize()
	_icon.texture = item.get_texture() if is_instance_valid(item) else null
	_stack.text = str(item.get_stack_size()) if is_instance_valid(item) and item.get_stack_size() > 1 else ""
	_hotkey.text = hotkey
	_cost.text = str(item.get_property("cost", "")) if is_instance_valid(item) else ""
