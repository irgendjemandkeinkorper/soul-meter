class_name WeftluminTimelinePanel
extends SoulMeterToolPanel
## Consequence timeline bottom tab (§4.12): the read-only ledger observer behind the panel
## contract. Rows, ordering, retention, debug classification and restored-history backfill are
## the model's; this panel only lays them out.

const MODEL_SCRIPT := preload("res://weftlumin/panels/models/consequence_timeline.gd")
const COLUMNS: Array[String] = ["Time", "Ledger", "Change", "Provenance", "Cause", "Actor · scene"]

var summary_label: Label = null
var tree: Tree = null


func _init() -> void:
	title = "Consequence timeline"
	needs_sandbox = false
	hotkey_hint = ""


func _model_script() -> Script:
	return MODEL_SCRIPT


func _build(content: VBoxContainer) -> void:
	summary_label = _label("", &"EditorLabel", true)
	summary_label.name = "Summary"
	content.add_child(summary_label)
	content.add_child(_label(
		"RESTORED HISTORY is approximate across ledgers; live rows follow signal arrival.",
		&"EditorLabel", true
	))
	tree = Tree.new()
	tree.name = "Rows"
	tree.theme_type_variation = &"EditorTree"
	tree.columns = COLUMNS.size()
	tree.column_titles_visible = true
	tree.hide_root = true
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.custom_minimum_size.y = get_theme_constant(&"dock_height", &"EditorTabContainer")
	for index: int in COLUMNS.size():
		tree.set_column_title(index, COLUMNS[index])
		tree.set_column_expand(index, index == 4)
	content.add_child(tree)
	(model as ConsequenceTimelineController).timeline_changed.connect(_refresh_rows)


func refresh(_payload: Dictionary) -> void:
	_refresh_rows()


## Timeline rows, newest-first exactly as the model retains them.
func rows() -> Array[Dictionary]:
	return (model as ConsequenceTimelineController).rows()


func _refresh_rows() -> void:
	if tree == null:
		return
	var controller := model as ConsequenceTimelineController
	summary_label.text = _format_summary(controller.summary())
	tree.clear()
	var root := tree.create_item()
	var timeline_rows: Array[Dictionary] = controller.rows()
	if timeline_rows.is_empty():
		root.create_child().set_text(0, "No consequences recorded this session.")
		return
	for row: Dictionary in timeline_rows:
		var item := root.create_child()
		var provenance: Array[String] = []
		if bool(row.get("debug_injected", false)):
			provenance.append("DEBUG-INJECTED")
		if bool(row.get("restored", false)):
			provenance.append("RESTORED HISTORY")
		item.set_text(0, _format_time(int(row.get("at", 0))))
		item.set_text(1, "%s / %s" % [str(row.get("ledger", "")), str(row.get("subject", ""))])
		item.set_text(2, "%s → %s" % [
			_signed(float(row.get("delta", 0.0))), _number(float(row.get("resulting", 0.0))),
		])
		item.set_text(3, " · ".join(provenance))
		item.set_text(4, str(row.get("cause", "")))
		item.set_text(5, "%s · %s" % [str(row.get("actor", "")), str(row.get("scene", ""))])
		item.set_metadata(0, row)


static func _format_summary(summary: Dictionary) -> String:
	var standings: Dictionary = summary.get("standings", {})
	var faction_ids: Array[String] = []
	for faction_value: Variant in standings.keys():
		faction_ids.append(str(faction_value))
	faction_ids.sort()
	var parts: Array[String] = []
	for faction: String in faction_ids:
		parts.append("%s %s" % [faction, _signed(float(standings[faction]))])
	return "FACTIONS: %s  ·  REPUTATION %s  ·  INFAMY %s" % [
		"none touched" if parts.is_empty() else ", ".join(parts),
		_number(float(summary.get("reputation", 0.0))),
		_number(float(summary.get("infamy", 0.0))),
	]


static func _format_time(timestamp: int) -> String:
	var value: Dictionary = Time.get_datetime_dict_from_unix_time(timestamp)
	return "%02d:%02d:%02d" % [
		int(value.get("hour", 0)), int(value.get("minute", 0)), int(value.get("second", 0))
	]


static func _signed(value: float) -> String:
	return "+%.1f" % value if value >= 0.0 else "%.1f" % value


static func _number(value: float) -> String:
	return "%.1f" % value
