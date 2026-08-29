class_name LootPanel
extends Screen
## Shared inspectable transfer screen for persistent containers and transient spoils.

## PROVISIONAL — aligned with the project's small quest-scale reputation deltas.
const THEFT_REPUTATION_DELTA: float = -5.0

signal dismissed(remaining: Array[Dictionary])

var _source_name := "LOOT"
var _items: Array[Dictionary] = []
var _container_id := ""
var _owned_by_faction := ""
var _theft_recorded := false
var _rows: VBoxContainer
var _status: Label
var _dismissed_emitted := false


func _build() -> void:
	var content := _make_shell_window(_source_name)
	_status = Label.new()
	_status.name = "LootStatus"
	_status.theme_type_variation = "MutedLabel"
	content.add_child(_status)
	_rows = VBoxContainer.new()
	_rows.name = "LootRows"
	_rows.theme_type_variation = "ScreenContentColumn"
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(_rows)
	var actions := HBoxContainer.new()
	actions.name = "LootActions"
	content.add_child(actions)
	var take_all_button := _menu_button(actions, "TAKE ALL", take_all)
	take_all_button.name = "TakeAllButton"
	take_all_button.theme_type_variation = "BronzeButton"
	var leave := _menu_button(actions, "CLOSE", close)
	leave.name = "CloseButton"
	_render()


func configure(
	source_name: String,
	items: Array[Dictionary],
	container_id: String = "",
	owned_by_faction: String = "",
) -> void:
	_source_name = source_name
	_items = items.duplicate(true)
	_container_id = container_id
	_owned_by_faction = owned_by_faction.strip_edges()
	_theft_recorded = (
		GameState.loot_container_theft_recorded(_container_id)
		if not _container_id.is_empty()
		else false
	)
	if not _container_id.is_empty():
		GameState.set_loot_container_contents(_container_id, _items)
	var title := find_child("ScreenTitle", true, false) as Label
	if title != null:
		title.text = "OWNED — %s" % _source_name if _is_owned() else _source_name
		title.theme_type_variation = "DangerLabel" if _is_owned() else "TitleLabel"
	var take_all_button := find_child("TakeAllButton", true, false) as Button
	if take_all_button != null:
		take_all_button.theme_type_variation = "DangerButton" if _is_owned() else "BronzeButton"
	_status.theme_type_variation = "DangerLabel" if _is_owned() else "MutedLabel"
	_status.text = "OWNED PROPERTY — TAKING IS THEFT." if _is_owned() else ""
	_render()


func remaining_items() -> Array[Dictionary]:
	return _items.duplicate(true)


func take_item(index: int) -> bool:
	if not take_from(_items, index, GameState.inventory):
		_status.text = "NO ROOM — THE ITEM REMAINS HERE."
		return false
	_persist_remaining()
	_record_theft_if_needed()
	_status.text = "ITEM TAKEN."
	_render()
	return true


func take_all() -> int:
	var taken := 0
	for index: int in range(_items.size() - 1, -1, -1):
		if take_from(_items, index, GameState.inventory):
			taken += 1
	_persist_remaining()
	if taken > 0:
		_record_theft_if_needed()
	_status.text = (
		"EVERYTHING TAKEN." if _items.is_empty()
		else "NO ROOM FOR %d ITEM ROW(S); THEY REMAIN HERE." % _items.size()
	)
	_render()
	return taken


static func take_from(contents: Array[Dictionary], index: int, inventory: Inventory) -> bool:
	if inventory == null or index < 0 or index >= contents.size():
		return false
	var row: Dictionary = contents[index]
	var item_id := str(row.get("item_id", row.get("id", "")))
	var quantity := maxi(int(row.get("quantity", 1)), 1)
	if item_id.is_empty():
		return false
	var item: InventoryItem = inventory.create_item(item_id)
	if item == null or item.get_prototype().get_prototype_id() != item_id:
		return false
	if not item.set_stack_size(quantity) or not inventory.add_item(item):
		return false
	contents.remove_at(index)
	return true


func _persist_remaining() -> void:
	if not _container_id.is_empty():
		GameState.set_loot_container_contents(_container_id, _items)


func _record_theft_if_needed() -> void:
	if not _is_owned() or _theft_recorded:
		return
	if (
		not _container_id.is_empty()
		and not GameState.mark_loot_container_theft_recorded(_container_id)
	):
		_theft_recorded = true
		return
	_theft_recorded = true
	Reputation.record(
		"player",
		_owned_by_faction,
		THEFT_REPUTATION_DELTA,
		"Took goods from %s" % _source_name,
		_current_scene_path(),
	)


func _is_owned() -> bool:
	return not _owned_by_faction.is_empty()


func _current_scene_path() -> String:
	var current_scene: Node = get_tree().current_scene
	return current_scene.scene_file_path if current_scene != null else ""


func _render() -> void:
	if _rows == null or _status == null:
		return
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	if _items.is_empty():
		var empty := Label.new()
		empty.name = "EmptyLabel"
		empty.text = "EMPTY"
		empty.theme_type_variation = "MutedLabel"
		_rows.add_child(empty)
		return
	for index: int in _items.size():
		var row_data: Dictionary = _items[index]
		var row := HBoxContainer.new()
		row.name = "LootRow_%d" % index
		var label := Label.new()
		label.name = "ItemLabel_%d" % index
		label.text = _item_label(row_data)
		label.theme_type_variation = "DangerLabel" if _is_owned() else "HeadingLabel"
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		var take := Button.new()
		take.name = "TakeButton_%d" % index
		take.text = "TAKE"
		take.theme_type_variation = "DangerButton" if _is_owned() else "BronzeButton"
		take.pressed.connect(take_item.bind(index))
		row.add_child(take)
		_rows.add_child(row)


func _item_label(row: Dictionary) -> String:
	var item_id := str(row.get("item_id", row.get("id", "")))
	var item: InventoryItem = GameState.inventory.create_item(item_id)
	var title := item_id.replace("/", " · ").replace("_", " ").capitalize()
	if item != null and item.get_prototype().get_prototype_id() == item_id:
		title = item.get_title()
	return "%s  ×%d" % [title, maxi(int(row.get("quantity", 1)), 1)]


func _exit_tree() -> void:
	if not _dismissed_emitted:
		_dismissed_emitted = true
		dismissed.emit(remaining_items())
