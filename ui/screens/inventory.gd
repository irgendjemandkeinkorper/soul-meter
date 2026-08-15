class_name InventoryScreen
extends Screen
## Three-column GLoot inventory presentation over GameState.inventory.

const ITEM_SLOT_SCENE := preload("res://ui/components/item_slot.tscn")
const EQUIPMENT_SLOTS: Array[StringName] = [&"main", &"off", &"head", &"body", &"trinket"]
## Pandora items carry `equip_slot` values like "main_hand"; the rail's slot names are
## the short forms above. Both spellings are accepted wherever a slot is matched.
const EQUIP_SLOT_ALIASES := {
	"main_hand": &"main",
	"off_hand": &"off",
	"head": &"head",
	"body": &"body",
	"trinket": &"trinket",
}
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


func _build() -> void:
	_build_shell()
	_ensure_bag_constraints()
	_build_columns()
	_restore_equipment()
	_refresh_weight()
	GameState.inventory_changed.connect(_refresh_weight)


func _exit_tree() -> void:
	# The per-slot inventories are children of this screen and die with it, so the
	# equipped state is snapshotted into GameState.equipped_slots here (the single
	# write point — every in-screen drag/equip path is captured by this final pass)
	# and the items themselves return to the persistent bag.
	GameState.equipped_slots.clear()
	for slot_name: StringName in _equipment:
		var inventory: Inventory = _equipment[slot_name]
		for item: InventoryItem in inventory.get_items().duplicate():
			GameState.equipped_slots[String(slot_name)] = item.get_prototype().get_prototype_id()
			if not transfer_from_equipment(item, GameState.inventory):
				push_error("InventoryScreen: could not return %s to the bag on close." % item.get_title())


func _restore_equipment() -> void:
	for slot_name: StringName in EQUIPMENT_SLOTS:
		var proto_id := str(GameState.equipped_slots.get(String(slot_name), ""))
		if proto_id.is_empty():
			continue
		for item: InventoryItem in GameState.inventory.get_items_with_prototype_id(proto_id):
			if transfer_to_equipment(item, _equipment[slot_name], slot_name):
				break


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


func _ensure_bag_constraints() -> void:
	var grid := GameState.inventory.get_constraint(GridConstraint) as GridConstraint
	if grid == null:
		grid = GridConstraint.new()
		grid.size = Vector2i(8, 8)
		GameState.inventory.add_child(grid)
	_weight_constraint = GameState.inventory.get_constraint(WeightConstraint) as WeightConstraint
	if _weight_constraint == null:
		_weight_constraint = WeightConstraint.new()
		_weight_constraint.capacity = WEIGHT_CAPACITY
		GameState.inventory.add_child(_weight_constraint)
	_weight_constraint.changed.connect(_refresh_weight)


func _build_columns() -> void:
	var columns := HBoxContainer.new()
	columns.name = "InventoryColumns"
	columns.theme_type_variation = "InventoryColumns"
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	shell_body.add_child(columns)
	columns.add_child(_build_equipment_column())
	columns.add_child(_build_bag_column())
	columns.add_child(_build_detail_column())


func _build_equipment_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "EquipmentColumn"
	column.custom_minimum_size.x = 360.0
	column.theme_type_variation = "ScreenContentColumn"
	var party_tabs := HBoxContainer.new()
	party_tabs.name = "PartyTabs"
	for index: int in 3:
		var tab := Button.new()
		tab.text = str(index + 1)
		tab.theme_type_variation = "ItemSlot"
		tab.custom_minimum_size = Vector2.ONE * DS.SLOT_SIZE_SM
		party_tabs.add_child(tab)
	column.add_child(party_tabs)
	column.add_child(_section("EQUIPMENT"))
	for slot_name: StringName in EQUIPMENT_SLOTS:
		column.add_child(_build_equipment_row(slot_name))
	column.add_child(_section("STATS"))
	for stat_text: String in ["VITALITY", "DEFENCE", "CARRY"]:
		var stat := Label.new()
		stat.name = "StatRow_%s" % stat_text.capitalize()
		stat.text = "%s  —" % stat_text
		stat.theme_type_variation = "StatLabel"
		column.add_child(stat)
	return column


func _build_equipment_row(slot_name: StringName) -> Control:
	var row := HBoxContainer.new()
	row.name = "EquipRow_%s" % slot_name
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
	var eyebrow := Label.new()
	eyebrow.text = str(slot_name).to_upper()
	eyebrow.theme_type_variation = "EyebrowLabel"
	labels.add_child(eyebrow)
	var item_name := Label.new()
	item_name.name = "EquipmentLabel_%s" % slot_name
	item_name.text = "EMPTY"
	item_name.theme_type_variation = "MutedLabel"
	labels.add_child(item_name)
	row.add_child(labels)
	return row


func _build_bag_column() -> Control:
	var panel := PanelContainer.new()
	panel.name = "BagColumn"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var scroll := ScrollContainer.new()
	scroll.name = "BagScroll"
	panel.add_child(scroll)
	_bag_grid = CtrlInventoryGrid.new()
	_bag_grid.name = "BagGrid"
	_bag_grid.inventory = GameState.inventory
	_bag_grid.field_dimensions = Vector2.ONE * DS.SLOT_SIZE
	_bag_grid.item_spacing = DS.ITEM_GRID_GAP
	_bag_grid.custom_item_control_scene = ITEM_SLOT_SCENE
	_bag_grid.inventory_item_selected.connect(_on_item_selected)
	scroll.add_child(_bag_grid)
	return panel


func _build_detail_column() -> Control:
	var column := VBoxContainer.new()
	column.name = "DetailColumn"
	column.custom_minimum_size.x = 430.0
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
	equip.name = "EquipButton"
	equip.text = "EQUIP"
	equip.theme_type_variation = "BronzeButton"
	equip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	equip.pressed.connect(_equip_selected)
	actions.add_child(equip)
	var drop := Button.new()
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
	return label


func _on_item_selected(item: InventoryItem) -> void:
	_selected_item = item
	_refresh_detail()


func _refresh_detail() -> void:
	if not is_instance_valid(_selected_item):
		return
	var proto_id := _selected_item.get_prototype().get_prototype_id()
	_name_label.text = _selected_item.get_title()
	_type_label.text = proto_id.split("/")[0].capitalize()
	for child: Node in _stats.get_children():
		child.queue_free()
	# "ap_cost" is display-only item metadata (AP compatibility: gate T-10, not the AP round economy).
	for property: String in ["damage", "dr", "ap_cost", "soul_cost", "weight", "element"]:
		if _selected_item.has_property(property):
			var row := Label.new()
			row.text = "%s  %s" % [property.to_upper(), _selected_item.get_property(property)]
			row.theme_type_variation = "StatLabel"
			_stats.add_child(row)
	_flavour_label.text = str(_selected_item.get_property("flavour", ""))
	_requirement_label.text = str(_selected_item.get_property("requirement", ""))
	_value_label.text = "%s SILVER" % _selected_item.get_property("value", _selected_item.get_property("base_price", 0))
	modulate.a = 0.0
	position.x += DS.SPACE_3
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "modulate:a", 1.0, DS.DUR_FAST)
	tween.tween_property(self, "position:x", position.x - DS.SPACE_3, DS.DUR_FAST)


func _on_equipment_drop(item: InventoryItem, _offset: Vector2, slot_name: StringName) -> void:
	var target: Inventory = _equipment[slot_name]
	if slot_of(item) != slot_name:
		transfer_from_equipment(item, GameState.inventory)
		return
	_flash(find_child("Equipment_%s" % slot_name, true, false) as Control)


func _equip_selected() -> void:
	if not is_instance_valid(_selected_item):
		return
	var slot_name := slot_of(_selected_item)
	if not _equipment.has(slot_name):
		_requirement_label.text = "THIS ITEM HAS NO COMPATIBLE SLOT"
		return
	if transfer_to_equipment(_selected_item, _equipment[slot_name], slot_name):
		_flash(find_child("Equipment_%s" % slot_name, true, false) as Control)


func _drop_selected() -> void:
	if is_instance_valid(_selected_item) and _selected_item.get_inventory() == GameState.inventory:
		GameState.inventory.remove_item(_selected_item)
		_selected_item = null


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
	var raw := str(item.get_property("slot", item.get_property("equip_slot", "")))
	return EQUIP_SLOT_ALIASES.get(raw, StringName(raw))


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
