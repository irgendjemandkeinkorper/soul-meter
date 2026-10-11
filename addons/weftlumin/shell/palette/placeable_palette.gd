class_name WeftluminPlaceablePalette
extends VBoxContainer
## Registry-driven placeable palette (architecture §4.6.4, E3.1b): lists `adapter.placeables()`
## by the group each entry carries, with a search box. It knows no actor type; choosing an entry
## only emits `placeable_chosen`, and the host's scene tool arms placement.

signal placeable_chosen(entry: WeftluminPlaceable)

const ALL_GROUPS := "All groups"
const RESULT_LIMIT := 240

## `(query: String, text: String) -> int`: lower is a better match, negative is no match. The
## host supplies its fuzzy scorer; unset falls back to a case-insensitive substring match.
var scorer: Callable = Callable()
var group_option: OptionButton
var search: LineEdit
var list: Tree
var _entries: Array[WeftluminPlaceable] = []
var _groups: PackedStringArray = PackedStringArray()


func _init() -> void:
	name = "PlaceablePalette"
	theme_type_variation = &"EditorColumn"
	group_option = OptionButton.new()
	group_option.name = "Group"
	group_option.theme_type_variation = &"EditorOptionButton"
	group_option.item_selected.connect(func(_index: int) -> void: populate())
	add_child(group_option)
	search = LineEdit.new()
	search.name = "Search"
	search.theme_type_variation = &"EditorLineEdit"
	search.clear_button_enabled = true
	search.text_changed.connect(func(_text: String) -> void: populate())
	add_child(search)
	list = Tree.new()
	list.name = "Placeables"
	list.theme_type_variation = &"EditorTree"
	list.hide_root = true
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.item_selected.connect(_on_item_selected)
	add_child(list)


## Replace the registry. Groups appear in the order the host first lists them.
func set_placeables(entries: Array[WeftluminPlaceable]) -> void:
	_entries = entries.duplicate()
	_groups = PackedStringArray()
	for entry: WeftluminPlaceable in _entries:
		if not _groups.has(entry.group):
			_groups.append(entry.group)
	group_option.clear()
	group_option.add_item(ALL_GROUPS)
	for group: String in _groups:
		group_option.add_item(group)
	group_option.select(0)
	populate()


func set_group(group: String) -> void:
	group_option.select(maxi(0, _groups.find(group) + 1))
	populate()


## Entries in the selected group matching the search, best match first, then registry order.
func visible_entries() -> Array[WeftluminPlaceable]:
	var group: String = "" if group_option.selected <= 0 else _groups[group_option.selected - 1]
	var query: String = search.text.strip_edges()
	var scored: Array[Dictionary] = []
	for index: int in _entries.size():
		var entry: WeftluminPlaceable = _entries[index]
		if not group.is_empty() and entry.group != group:
			continue
		var score: int = _score(query, "%s %s" % [entry.display, entry.group])
		if score >= 0:
			scored.append({"entry": entry, "score": score, "index": index})
	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["score"]) < int(b["score"]) if a["score"] != b["score"] else int(a["index"]) < int(b["index"])
	)
	var result: Array[WeftluminPlaceable] = []
	for row: Dictionary in scored.slice(0, RESULT_LIMIT):
		result.append(row["entry"] as WeftluminPlaceable)
	return result


func populate() -> void:
	list.clear()
	var root: TreeItem = list.create_item()
	var shown: Array[WeftluminPlaceable] = visible_entries()
	for entry: WeftluminPlaceable in shown:
		var item: TreeItem = list.create_item(root)
		item.set_text(0, entry.display)
		item.set_tooltip_text(0, "%s · %s" % [entry.group, entry.scene_path() if entry.scene != null else String(entry.node_type)])
		item.set_metadata(0, entry)
	search.placeholder_text = "Search %d placeables (%d shown)" % [_entries.size(), shown.size()]


## Select the listed entry with `id`, as a click on its row would; false when it is not shown.
func choose(id: StringName) -> bool:
	var root: TreeItem = list.get_root()
	for item: TreeItem in root.get_children() if root != null else []:
		if (item.get_metadata(0) as WeftluminPlaceable).id == id:
			item.select(0)
			return true
	return false


func clear_choice() -> void:
	list.deselect_all()


func _on_item_selected() -> void:
	var item: TreeItem = list.get_selected()
	if item != null:
		placeable_chosen.emit(item.get_metadata(0) as WeftluminPlaceable)


func _score(query: String, text: String) -> int:
	if query.is_empty():
		return 0
	if scorer.is_valid():
		return int(scorer.call(query, text))
	return text.findn(query)
