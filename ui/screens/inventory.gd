extends Screen
## A view of GameState.inventory: a compact item grid on the left, details on the right.

var _grid: GridContainer
var _name_lbl: Label
var _cat_lbl: Label
var _desc_lbl: Label
var _selected_idx := -1


func _build() -> void:
	var vbox := _make_window("Inventory", Vector2(720, 480))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(280, 0)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(scroll)

	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.add_theme_constant_override("h_separation", DS.ITEM_GRID_GAP)
	_grid.add_theme_constant_override("v_separation", DS.ITEM_GRID_GAP)
	scroll.add_child(_grid)

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

	GameState.inventory_changed.connect(_rebuild_list)

	_rebuild_list()

	_add_back_button(vbox)


func _rebuild_list() -> void:
	for child in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()

	var items := GameState.inventory.get_items()
	if items.is_empty():
		_selected_idx = -1
		_name_lbl.text = "(empty)"
		_cat_lbl.text = ""
		_desc_lbl.text = ""
		return

	_selected_idx = clampi(_selected_idx, 0, items.size() - 1)
	for index in items.size():
		var item: InventoryItem = items[index]
		var slot := Button.new()
		slot.custom_minimum_size = Vector2(DS.SLOT_SIZE, DS.SLOT_SIZE)
		slot.theme_type_variation = "ItemSlot"
		slot.toggle_mode = true
		slot.focus_mode = Control.FOCUS_ALL
		slot.text = _slot_text(item)
		slot.tooltip_text = _tooltip_text(item)
		var icon := item.get_texture()
		if icon != null:
			slot.icon = icon
		slot.pressed.connect(_on_slot_pressed.bind(index))
		_grid.add_child(slot)

	_select_item(_selected_idx)


func _on_slot_pressed(index: int) -> void:
	_select_item(index)


func _select_item(index: int) -> void:
	_selected_idx = index
	for child_idx in _grid.get_child_count():
		var slot := _grid.get_child(child_idx) as Button
		if slot != null:
			slot.button_pressed = child_idx == index
	_on_selected(index)


func _slot_text(item: InventoryItem) -> String:
	var title := _localized_name(item)
	if title.length() > 9:
		title = title.substr(0, 8) + "…"
	var stack_size := item.get_stack_size()
	if stack_size > 1:
		title += "\n×%d" % stack_size
	return title


func _tooltip_text(item: InventoryItem) -> String:
	var title := _localized_name(item)
	var stack_size := item.get_stack_size()
	return "%s  ×%d" % [title, stack_size] if stack_size > 1 else title


func _localized_name(item: InventoryItem) -> String:
	var proto_id := item.get_prototype().get_prototype_id()
	var key := ItemLocalization.key_for(proto_id, "name")
	return ItemLocalization.with_fallback(tr(key), key, item.get_title())


func _on_selected(idx: int) -> void:
	var items := GameState.inventory.get_items()
	if idx < 0 or idx >= items.size():
		return
	var item: InventoryItem = items[idx]
	var proto_id := item.get_prototype().get_prototype_id()
	_name_lbl.text = _localized_name(item)
	var category := proto_id.split("/")[0]
	_cat_lbl.text = category.capitalize()
	var desc_key := ItemLocalization.key_for(proto_id, "description")
	var fallback_description := str(item.get_property("description", ""))
	_desc_lbl.text = ItemLocalization.with_fallback(
		tr(desc_key), desc_key, fallback_description
	)
