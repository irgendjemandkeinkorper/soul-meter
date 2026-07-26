extends Screen
## A view of GameState.inventory: item list on the left, details on the right.

var _name_lbl: Label
var _cat_lbl: Label
var _desc_lbl: Label


func _build() -> void:
	var vbox := _make_window("Inventory", Vector2(720, 480))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(280, 0)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(list)

	var details := VBoxContainer.new()
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_theme_constant_override("separation", 8)
	row.add_child(details)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 24)
	details.add_child(_name_lbl)

	_cat_lbl = Label.new()
	_cat_lbl.modulate = Color(1, 1, 1, 0.6)
	details.add_child(_cat_lbl)

	_desc_lbl = Label.new()
	_desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	details.add_child(_desc_lbl)

	for stack in GameState.inventory:
		var label := stack.item.display_name
		if stack.item.stackable and stack.count > 1:
			label += "  ×%d" % stack.count
		list.add_item(label)

	list.item_selected.connect(_on_selected)
	if GameState.inventory.size() > 0:
		list.select(0)
		_on_selected(0)
	else:
		_name_lbl.text = "(empty)"

	_add_back_button(vbox)


func _on_selected(idx: int) -> void:
	var stack: ItemStack = GameState.inventory[idx]
	_name_lbl.text = stack.item.display_name
	_cat_lbl.text = stack.item.category.capitalize()
	_desc_lbl.text = stack.item.description
