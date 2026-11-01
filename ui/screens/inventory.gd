class_name InventoryScreen
extends Screen
## Three-column GLoot inventory presentation over GameState.inventory.

const ITEM_SLOT_SCENE := preload("res://ui/components/item_slot.tscn")
const BAG_SLOT_SCENE := preload("res://ui/components/item_slot_small.tscn")
const EQUIPMENT_SLOTS: Array[StringName] = [&"main", &"off", &"head", &"body", &"trinket"]
const WEIGHT_CAPACITY := 60.0

var _bag_grid: CtrlInventoryGrid
var _equipment: Dictionary = {}
var _weight_constraint: WeightConstraint
var _weight_label: Label
var _name_label: Label
var _type_label: Label
var _stats: VBoxContainer
var _flavour_label: Label
var _requirement_label: Label
var _value_label: Label
var _selected_item: InventoryItem
var _detail_column: Control
var _equip_button: Button
var _drop_button: Button
var _closing := false
var _selected_member: PartyMember
var _member_picker: OptionButton
var _bag_drop_target: Control


func _uses_ledger_style() -> bool:
	return true


func _build() -> void:
	_add_opaque_backdrop()
	_build_shell()
	_ensure_bag_constraints()
	_build_columns()
	_configure_equipment_drops()
	_refresh_members()
	_refresh_detail()
	_refresh_weight()
	GameState.inventory_changed.connect(_refresh_weight)
	GameState.party_changed.connect(_refresh_members)


func _exit_tree() -> void:
	_closing = true
	# Rail inventories contain display references only. GameState owns all edits
	# immediately, so closing/saving/switching members never transfers physical items.


func _refresh_members() -> void:
	if _closing:
		return
	var selected_id := _selected_member.id if _selected_member != null else ""
	_member_picker.clear()
	var selected_index := 0
	for index: int in GameState.party.size():
		var member: PartyMember = GameState.party[index]
		_member_picker.add_item(member.display_name)
		if member.id == selected_id:
			selected_index = index
	_member_picker.disabled = GameState.party.is_empty()
	_selected_member = null
	if not GameState.party.is_empty():
		_member_picker.select(selected_index)
		_selected_member = GameState.party[selected_index]
	_restore_equipment()
	_refresh_detail()


func _on_member_selected(index: int) -> void:
	if index < 0 or index >= GameState.party.size():
		return
	_selected_member = GameState.party[index]
	_restore_equipment()
	_refresh_detail()


func _restore_equipment() -> void:
	for slot_name: StringName in EQUIPMENT_SLOTS:
		var slot_inventory: Inventory = _equipment[slot_name]
		slot_inventory.clear()
		if _selected_member == null:
			continue
		var proto_id := str(_selected_member.equipped_slots.get(String(slot_name), ""))
		if proto_id.is_empty():
			continue
		if GameState.equipped_item(_selected_member, slot_name) != null:
			var display_item := InventoryItem.new(GameState.inventory.protoset, proto_id)
			transfer_to_equipment(display_item, slot_inventory, slot_name)


func _configure_equipment_drops() -> void:
	# GLoot normally transfers items after emitting item_dropped. Forward each
	# rail control's drop to the system-owned equip request; the rail is a view.
	for slot_name: StringName in EQUIPMENT_SLOTS:
		var grid := find_child("Equipment_%s" % slot_name, true, false) as CtrlInventoryGrid
		var target := grid.get_node("_CtrlInventoryGridBasic") as Control
		target.set_drag_forwarding(
			Callable(), _can_drop_equipment.bind(slot_name),
			func(at: Vector2, data: Variant) -> void: grid.item_dropped.emit(data, at)
		)
	_bag_drop_target = _bag_grid.get_node("_CtrlInventoryGridBasic") as Control
	_bag_drop_target.set_drag_forwarding(Callable(), _can_drop_bag, _drop_on_bag)


func _build_shell() -> void:
	var shell := _make_shell()
	shell_header = shell[0] as HBoxContainer
	shell_body = shell[1] as MarginContainer
	shell_hud_bar = shell[2] as HBoxContainer
	var title := Label.new()
	title.name = "ScreenTitle"
	title.text = "INVENTORY"
	title.theme_type_variation = "TitleLabel"
	shell_header.add_child(title)
	var eyebrow := Label.new()
	eyebrow.text = "FIELD LEDGER"
	eyebrow.theme_type_variation = "EyebrowLabel"
	shell_header.add_child(eyebrow)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_header.add_child(spacer)
	_weight_label = Label.new()
	_weight_label.name = "WeightReadout"
	_weight_label.theme_type_variation = "StatLabel"
	shell_header.add_child(_weight_label)
	var silver := Label.new()
	silver.name = "SilverReadout"
	silver.text = "%d SILVER" % GameState.gp
	silver.theme_type_variation = "StatLabel"
	shell_header.add_child(silver)
	var hints := Label.new()
	hints.text = "SELECT  ·  DRAG TO EQUIP  ·  ESC BACK"
	hints.theme_type_variation = "EyebrowLabel"
	shell_hud_bar.add_child(hints)
	var hud_spacer := Control.new()
	hud_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell_hud_bar.add_child(hud_spacer)
	var gauge := SOUL_GAUGE_SCENE.instantiate()
	gauge.custom_minimum_size.x = 300.0
	shell_hud_bar.add_child(gauge)
	_add_back_button(shell_hud_bar)


func _ensure_bag_constraints() -> void:
	var grid := GameState.inventory.get_constraint(GridConstraint) as GridConstraint
	if grid == null:
		grid = GridConstraint.new()
		grid.size = Vector2i(8, 8)
		GameState.inventory.add_child(grid)
	if not repair_bag_layout(grid):
		push_warning("Bag layout exceeds available space; all items and their positions were preserved.")
	_weight_constraint = GameState.inventory.get_constraint(WeightConstraint) as WeightConstraint
	if _weight_constraint == null:
		_weight_constraint = WeightConstraint.new()
		_weight_constraint.capacity = WEIGHT_CAPACITY
		GameState.inventory.add_child(_weight_constraint)
	_weight_constraint.changed.connect(_refresh_weight)


## Attaching GLoot's grid to a populated bag leaves existing items at (0, 0).
## Plan positions first, preserving valid player placements. Never remove/re-add
## items: that can trigger quest events, merge stacks, or lose an overfull save.
static func repair_bag_layout(grid: GridConstraint) -> bool:
	var occupied: Array[Rect2i] = []
	var pending: Array[InventoryItem] = []
	var placements: Dictionary = {}
	var bounds := Rect2i(Vector2i.ZERO, grid.size)
	for item: InventoryItem in grid.inventory.get_items():
		var rect := grid.get_item_rect(item)
		if bounds.encloses(rect) and _bag_rect_is_free(rect, occupied):
			occupied.append(rect)
		else:
			pending.append(item)
	for item: InventoryItem in pending:
		var item_size := grid.get_item_size(item)
		var found := false
		for x: int in range(grid.size.x - item_size.x + 1):
			for y: int in range(grid.size.y - item_size.y + 1):
				var rect := Rect2i(Vector2i(x, y), item_size)
				if _bag_rect_is_free(rect, occupied):
					occupied.append(rect)
					placements[item] = rect.position
					found = true
					break
			if found:
				break
		if not found:
			return false
	for item: InventoryItem in placements:
		grid.set_item_position_unsafe(item, placements[item])
	return true


static func _bag_rect_is_free(rect: Rect2i, occupied: Array[Rect2i]) -> bool:
	for prior: Rect2i in occupied:
		if prior.intersects(rect):
			return false
	return true


func _build_columns() -> void:
	var columns := HBoxContainer.new()
	columns.name = "InventoryColumns"
	columns.theme_type_variation = "InventoryColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_body.add_child(columns)
	columns.add_child(_ledger_panel(_build_equipment_column(), "EquipmentLedger"))
	columns.add_child(_build_bag_column())
	_detail_column = _build_detail_column()
	columns.add_child(_ledger_panel(_detail_column, "ItemLedger"))


func _build_equipment_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "EquipmentColumn"
	column.custom_minimum_size.x = 260.0
	column.theme_type_variation = "ScreenContentColumn"
	column.add_child(_section("EQUIPMENT"))
	_member_picker = OptionButton.new()
	_member_picker.name = "EquipmentMemberPicker"
	_member_picker.tooltip_text = tr("PARTY MEMBER") # DRAFT: owner review.
	_member_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_member_picker.item_selected.connect(_on_member_selected)
	column.add_child(_member_picker)
	for slot_name: StringName in EQUIPMENT_SLOTS:
		column.add_child(_build_equipment_row(slot_name))
	return column


func _build_equipment_row(slot_name: StringName) -> Control:
	var row := HBoxContainer.new()
	row.name = "EquipRow_%s" % slot_name
	row.theme_type_variation = "LedgerRow"
	var inventory := make_equipment_inventory(GameState.inventory.protoset)
	inventory.name = "EquipmentInventory_%s" % slot_name
	add_child(inventory)
	_equipment[slot_name] = inventory
	var grid := CtrlInventoryGrid.new()
	grid.name = "Equipment_%s" % slot_name
	grid.inventory = inventory
	grid.field_dimensions = Vector2.ONE * DS.SLOT_SIZE_SM
	grid.item_spacing = DS.ITEM_GRID_GAP
	grid.custom_item_control_scene = ITEM_SLOT_SCENE
	grid.custom_minimum_size = Vector2.ONE * DS.SLOT_SIZE_SM
	grid.item_dropped.connect(_on_equipment_drop.bind(slot_name))
	grid.inventory_item_selected.connect(_on_item_selected)
	row.add_child(grid)
	var labels := VBoxContainer.new()
	labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var eyebrow := Label.new()
	eyebrow.text = str(slot_name).to_upper()
	eyebrow.theme_type_variation = "EyebrowLabel"
	labels.add_child(eyebrow)
	var item_name := Label.new()
	item_name.name = "EquipmentLabel_%s" % slot_name
	item_name.text = "EMPTY"
	item_name.theme_type_variation = "MutedLabel"
	item_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	labels.add_child(item_name)
	row.add_child(labels)
	inventory.item_added.connect(_refresh_equipment_label.bind(inventory, item_name))
	inventory.item_removed.connect(_refresh_equipment_label.bind(inventory, item_name))
	return row


func _refresh_equipment_label(_item: InventoryItem, inventory: Inventory, label: Label) -> void:
	if _closing:
		return
	var items := inventory.get_items()
	label.text = items[0].get_title() if not items.is_empty() else tr("EMPTY")
	_refresh_detail()


func _build_bag_column() -> Control:
	var panel := PanelContainer.new()
	panel.name = "BagColumn"
	panel.theme_type_variation = "LedgerInset"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content := VBoxContainer.new()
	content.theme_type_variation = "LedgerColumn"
	panel.add_child(content)
	content.add_child(_section(tr("CARRIED ITEMS")))
	var scroll := ScrollContainer.new()
	scroll.name = "BagScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(scroll)
	_bag_grid = CtrlInventoryGrid.new()
	_bag_grid.name = "BagGrid"
	_bag_grid.inventory = GameState.inventory
	_bag_grid.field_dimensions = Vector2.ONE * DS.SLOT_SIZE
	_bag_grid.item_spacing = DS.ITEM_GRID_GAP
	_bag_grid.custom_item_control_scene = BAG_SLOT_SCENE
	_bag_grid.inventory_item_selected.connect(_on_item_selected)
	scroll.add_child(_bag_grid)
	scroll.resized.connect(func() -> void:
		var cell := clampf(floorf((scroll.size.x - DS.SPACE_6) / 8.0) - DS.ITEM_GRID_GAP, DS.SLOT_SIZE_SM, DS.SLOT_SIZE)
		_bag_grid.field_dimensions = Vector2.ONE * cell)
	return panel


func _build_detail_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "DetailColumn"
	column.custom_minimum_size.x = 320.0
	column.theme_type_variation = "ScreenContentColumn"
	_name_label = _detail_label("ItemName", "SELECT AN ITEM", "TitleLabel")
	_type_label = _detail_label("ItemType", "", "MutedLabel")
	_stats = VBoxContainer.new()
	_stats.name = "ItemStats"
	_flavour_label = _detail_label("ItemFlavour", "", "QuoteLabel")
	_flavour_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_requirement_label = _detail_label("ItemRequirement", "", "DangerLabel")
	_value_label = _detail_label("ItemValue", "", "StatLabel")
	for child: Control in [_name_label, _type_label, _stats, _flavour_label, _requirement_label, _value_label]:
		column.add_child(child)
	var actions := HBoxContainer.new()
	var equip := Button.new()
	_equip_button = equip
	equip.name = "EquipButton"
	equip.theme_type_variation = "BronzeButton"
	equip.text = "EQUIP"
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip.pressed.connect(_equip_selected)
	actions.add_child(equip)
	var drop := Button.new()
	_drop_button = drop
	drop.name = "DropButton"
	drop.text = "DROP"
	drop.pressed.connect(_drop_selected)
	actions.add_child(drop)
	column.add_child(actions)
	return column


func _detail_label(node_name: String, text: String, variation: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.theme_type_variation = variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _on_item_selected(item: InventoryItem) -> void:
	# Selecting a rail reference selects its real bag item for all actions.
	if is_instance_valid(item) and item.get_inventory() != GameState.inventory:
		for slot: StringName in _equipment:
			if item.get_inventory() == _equipment[slot]:
				item = GameState.equipped_item(_selected_member, slot)
				break
	_selected_item = item
	_refresh_detail()


func _refresh_detail() -> void:
	for child: Node in _stats.get_children():
		_stats.remove_child(child)
		child.queue_free()
	var selected := is_instance_valid(_selected_item)
	var owner: PartyMember = null
	if selected:
		owner = GameState.equipment_owner(_selected_item)
	var worn_here := owner != null and owner == _selected_member
	_equip_button.text = tr("UNEQUIP") if worn_here else tr("EQUIP") # DRAFT: UNEQUIP.
	_equip_button.disabled = not selected or not (worn_here or GameState.can_equip_item(_selected_member, _selected_item, slot_of(_selected_item)))
	_drop_button.disabled = not selected or owner != null or _selected_item.get_inventory() != GameState.inventory
	if not selected:
		_name_label.text = tr("SELECT AN ITEM")
		for label: Label in [_type_label, _flavour_label, _requirement_label, _value_label]:
			label.text = ""
		return
	var proto_id := _selected_item.get_prototype().get_prototype_id()
	_name_label.text = _selected_item.get_title()
	_type_label.text = proto_id.split("/")[0].capitalize()
	# "ap_cost" is display-only item metadata (AP compatibility: gate T-10, not the AP round economy).
	for property: String in ["damage", "dr", "ap_cost", "soul_cost", "weight", "element"]:
		if _selected_item.has_property(property):
			var row := Label.new()
			row.text = "%s  %s" % [property.to_upper(), _selected_item.get_property(property)]
			row.theme_type_variation = "StatLabel"
			_stats.add_child(row)
	_flavour_label.text = str(_selected_item.get_property("flavour", ""))
	_requirement_label.text = str(_selected_item.get_property("requirement", ""))
	if owner != null and owner != _selected_member:
		# DRAFT: owner review.
		_requirement_label.text = tr("EQUIPPED BY %s — UNEQUIP THERE FIRST") % owner.display_name
	for property: String in ["attack_bonus", "defense_bonus"]:
		if _selected_item.has_property(property):
			var row := Label.new()
			# DRAFT: owner review. Equipment stats do not imply any other weapon effect.
			var format := tr("ATTACK BONUS  %+d") if property == "attack_bonus" else tr("DEFENSE BONUS  %+d")
			row.text = format % int(_selected_item.get_property(property))
			row.theme_type_variation = "StatLabel"
			_stats.add_child(row)
	_value_label.text = "%s SILVER" % _selected_item.get_property("value", _selected_item.get_property("base_price", 0))
	_settle_content(_detail_column)


func _on_equipment_drop(item: InventoryItem, _offset: Vector2, slot_name: StringName) -> void:
	if GameState.equip_item(_selected_member, item, slot_name):
		_flash(find_child("Equipment_%s" % slot_name, true, false) as Control)


func _can_drop_equipment(_at: Vector2, data: Variant, slot: StringName) -> bool:
	return data is InventoryItem and GameState.can_equip_item(_selected_member, data, slot)


func _can_drop_bag(_at: Vector2, data: Variant) -> bool:
	return data is InventoryItem


func _drop_on_bag(at: Vector2, data: Variant) -> void:
	if not data is InventoryItem:
		return
	var item: InventoryItem = data
	for slot: StringName in _equipment:
		if item.get_inventory() == _equipment[slot]:
			GameState.unequip_item(_selected_member, slot)
			return
	# Ordinary bag movement keeps GLoot's existing grid/stack behavior.
	_bag_drop_target.call("_drop_data", at, data)


func _equip_selected() -> void:
	if not is_instance_valid(_selected_item):
		return
	var slot_name := slot_of(_selected_item)
	if _selected_member != null and GameState.equipment_owner(_selected_item) == _selected_member:
		GameState.unequip_item(_selected_member, slot_name)
		return
	if not _equipment.has(slot_name):
		_requirement_label.text = "THIS ITEM HAS NO COMPATIBLE SLOT"
		return
	if GameState.equip_item(_selected_member, _selected_item, slot_name):
		_flash(find_child("Equipment_%s" % slot_name, true, false) as Control)


func _drop_selected() -> void:
	if is_instance_valid(_selected_item) and _selected_item.get_inventory() == GameState.inventory and GameState.equipment_owner(_selected_item) == null:
		GameState.inventory.remove_item(_selected_item)
		_selected_item = null
		_refresh_detail()


func _flash(control: Control) -> void:
	if control == null:
		return
	control.modulate = DS.VIOLET_3
	create_tween().tween_property(control, "modulate", Color.WHITE, DS.DUR_BASE)


func _refresh_weight() -> void:
	if not is_instance_valid(_weight_label) or not is_instance_valid(_weight_constraint):
		return
	var occupied := _weight_constraint.get_occupied_space()
	_weight_label.text = "%.1f / %.1f WEIGHT" % [occupied, _weight_constraint.capacity]
	_weight_label.theme_type_variation = "DangerLabel" if occupied > _weight_constraint.capacity else "StatLabel"


static func make_equipment_inventory(protoset: JSON) -> Inventory:
	var inventory := Inventory.new()
	inventory.protoset = protoset
	var grid := GridConstraint.new()
	grid.size = Vector2i.ONE
	inventory.add_child(grid)
	var count := ItemCountConstraint.new()
	count.capacity = 1
	inventory.add_child(count)
	return inventory


static func slot_of(item: InventoryItem) -> StringName:
	return GameState.equipment_slot_of(item)


static func transfer_to_equipment(
	item: InventoryItem, equipment: Inventory, slot_name: StringName
) -> bool:
	if not is_instance_valid(item) or slot_of(item) != slot_name:
		return false
	var grid := equipment.get_constraint(GridConstraint) as GridConstraint
	if grid != null:
		# The slot holds exactly one item (ItemCountConstraint); the grid exists only to
		# satisfy GLoot's fit check, so it must match the incoming item's footprint.
		grid.size = grid.get_item_size(item)
	return equipment.add_item(item)


static func transfer_from_equipment(item: InventoryItem, bag: Inventory) -> bool:
	if not is_instance_valid(item):
		return false
	var source := item.get_inventory()
	if not bag.add_item(item):
		return false
	if source != null and source.get_item_count() == 0:
		var grid := source.get_constraint(GridConstraint) as GridConstraint
		if grid != null:
			grid.size = Vector2i.ONE
	return true
