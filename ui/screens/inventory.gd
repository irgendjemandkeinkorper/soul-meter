extends Screen
## A view of GameState.inventory: item list on the left, details on the right.

var _list: ItemList
var _name_lbl: Label
var _cat_lbl: Label
var _desc_lbl: Label


func _build() -> void:
	var vbox := _make_window("Inventory", Vector2(720, 480))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	_list = ItemList.new()
	_list.custom_minimum_size = Vector2(280, 0)
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(_list)

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

	_list.item_selected.connect(_on_selected)
	GameState.inventory_changed.connect(_rebuild_list)

	_rebuild_list()

	_add_back_button(vbox)


func _rebuild_list() -> void:
	var selected_idx := -1
	if _list.get_selected_items().size() > 0:
		selected_idx = _list.get_selected_items()[0]

	_list.clear()
	var items := GameState.inventory.get_items()
	for item in items:
		var label := item.get_title()
		var stack_size := item.get_stack_size()
		if stack_size > 1:
			label += "  ×%d" % stack_size
		var icon := item.get_texture()
		if icon != null:
			_list.add_item(label, icon)
		else:
			_list.add_item(label)

	if items.size() > 0:
		if selected_idx >= 0 and selected_idx < items.size():
			_list.select(selected_idx)
			_on_selected(selected_idx)
		else:
			_list.select(0)
			_on_selected(0)
	else:
		_name_lbl.text = "(empty)"
		_cat_lbl.text = ""
		_desc_lbl.text = ""


func _on_selected(idx: int) -> void:
	var items := GameState.inventory.get_items()
	if idx < 0 or idx >= items.size():
		return
	var item: InventoryItem = items[idx]
	var proto_id := item.get_prototype().get_prototype_id()
	var name_key := ItemLocalization.key_for(proto_id, "name")
	_name_lbl.text = ItemLocalization.with_fallback(tr(name_key), name_key, item.get_title())
	var category := proto_id.split("/")[0]
	_cat_lbl.text = category.capitalize()
	var desc_key := ItemLocalization.key_for(proto_id, "description")
	var fallback_description := str(item.get_property("description", ""))
	_desc_lbl.text = ItemLocalization.with_fallback(
		tr(desc_key), desc_key, fallback_description
	)
