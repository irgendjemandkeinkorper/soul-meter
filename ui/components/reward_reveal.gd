class_name RewardReveal
extends Control
## A modal, queued-by-UIManager ledger reveal shown after a quest transaction has
## finished. QuestRegistry supplies facts; this component only formats and presents them.

signal dismissed

@onready var _scrim: ColorRect = $Scrim
@onready var _panel: PanelContainer = $SafeArea/Center/RewardPanel
@onready var _trim: ColorRect = $SafeArea/Center/RewardPanel/Content/Column/Trim
@onready var _quest_title: Label = $SafeArea/Center/RewardPanel/Content/Column/QuestTitle
@onready var _resolution: Label = $SafeArea/Center/RewardPanel/Content/Column/Resolution
@onready var _entries: VBoxContainer = $SafeArea/Center/RewardPanel/Content/Column/Entries
@onready var _continue: Button = $SafeArea/Center/RewardPanel/Content/Column/Continue

var _animation_tween: Tween
var _reduced_motion := false
var _is_dismissing := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_STOP
	_scrim.color = Color(DS.VOID_0, 0.82)
	_trim.color = DS.BRONZE_3
	_continue.pressed.connect(dismiss)
	visible = false


func present(summary: Dictionary, reduced_motion: bool = false) -> void:
	_stop_animation()
	_reduced_motion = reduced_motion
	_is_dismissing = false
	_quest_title.text = str(summary.get("quest_name", "Quest completed"))
	var resolution_label := str(summary.get("resolution_label", "")).strip_edges()
	_resolution.visible = not resolution_label.is_empty()
	_resolution.text = "OUTCOME  ·  %s" % resolution_label
	_clear_entries()
	var reward_entries: Array = summary.get("entries", [])
	for entry_value: Variant in reward_entries:
		if entry_value is Dictionary:
			_entries.add_child(_build_entry(entry_value as Dictionary))
	if _entries.get_child_count() == 0:
		_entries.add_child(_build_empty_entry())

	visible = true
	_scrim.modulate.a = 1.0
	_panel.modulate.a = 1.0
	_panel.scale = Vector2.ONE
	for row: Control in _entry_controls():
		row.modulate.a = 1.0
	if not _reduced_motion:
		_scrim.modulate.a = 0.0
		_panel.modulate.a = 0.0
		_panel.scale = Vector2(0.94, 0.94)
		for row: Control in _entry_controls():
			row.modulate.a = 0.0
		call_deferred("_play_intro")
	call_deferred("_focus_continue")


func dismiss() -> void:
	if not visible or _is_dismissing:
		return
	_is_dismissing = true
	_stop_animation()
	if _reduced_motion:
		_finish_dismiss()
		return
	_animation_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animation_tween.set_parallel(true)
	_animation_tween.tween_property(_panel, "modulate:a", 0.0, DS.DUR_FAST)
	_animation_tween.tween_property(_scrim, "modulate:a", 0.0, DS.DUR_FAST)
	await _animation_tween.finished
	_finish_dismiss()


func is_animation_active() -> bool:
	return _animation_tween != null and _animation_tween.is_running()


func reset() -> void:
	_stop_animation()
	visible = false
	_is_dismissing = false


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		dismiss()
		get_viewport().set_input_as_handled()


func _play_intro() -> void:
	if not visible or _reduced_motion or _is_dismissing:
		return
	_panel.pivot_offset = _panel.size * 0.5
	_animation_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_animation_tween.set_parallel(true)
	_animation_tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_animation_tween.tween_property(_scrim, "modulate:a", 1.0, DS.DUR_BASE)
	_animation_tween.tween_property(_panel, "modulate:a", 1.0, DS.DUR_BASE)
	_animation_tween.tween_property(_panel, "scale", Vector2.ONE, DS.DUR_SLOW)
	var index := 0
	for row: Control in _entry_controls():
		_animation_tween.tween_property(row, "modulate:a", 1.0, DS.DUR_FAST).set_delay(
			DS.DUR_FAST + float(index) * DS.DUR_INSTANT
		)
		index += 1


func _focus_continue() -> void:
	if visible:
		_continue.grab_focus()


func _finish_dismiss() -> void:
	visible = false
	_is_dismissing = false
	_animation_tween = null
	dismissed.emit()


func _stop_animation() -> void:
	if _animation_tween != null and _animation_tween.is_valid():
		_animation_tween.kill()
	_animation_tween = null


func _clear_entries() -> void:
	for child: Node in _entries.get_children():
		child.free()


func _entry_controls() -> Array[Control]:
	var controls: Array[Control] = []
	for child: Node in _entries.get_children():
		if child is Control:
			controls.append(child as Control)
	return controls


func _build_entry(entry: Dictionary) -> Control:
	var row := PanelContainer.new()
	row.name = "RewardEntry%d" % _entries.get_child_count()
	row.theme_type_variation = "BattleHudPanel"
	row.custom_minimum_size.y = float(DS.CONTROL_H_LG)

	var layout := HBoxContainer.new()
	layout.theme_type_variation = "BattleHudRow"
	row.add_child(layout)

	var category := Label.new()
	category.custom_minimum_size.x = 150.0
	category.theme_type_variation = "EyebrowLabel"
	category.add_theme_font_size_override("font_size", DS.FS_200)
	category.text = _kind_label(str(entry.get("kind", "reward")))
	layout.add_child(category)

	var description := VBoxContainer.new()
	description.theme_type_variation = "BattleHudColumn"
	description.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	layout.add_child(description)
	var name_label := Label.new()
	name_label.text = _entry_name(entry)
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_child(name_label)
	var detail := str(entry.get("detail", "")).strip_edges()
	if not detail.is_empty():
		var detail_label := Label.new()
		detail_label.theme_type_variation = "MutedLabel"
		detail_label.text = detail
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_child(detail_label)

	var amount := Label.new()
	amount.custom_minimum_size.x = 92.0
	amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	amount.theme_type_variation = _delta_theme(entry)
	amount.add_theme_font_size_override("font_size", DS.FS_600)
	amount.text = _entry_amount(entry)
	layout.add_child(amount)
	return row


func _build_empty_entry() -> Control:
	var label := Label.new()
	label.name = "QuestCompleteEntry"
	label.theme_type_variation = "MutedLabel"
	label.text = "QUEST COMPLETE  ·  No material reward was recorded."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return label


static func _kind_label(kind: String) -> String:
	match kind:
		"item":
			return "LOOT"
		"currency":
			return "CURRENCY"
		"faction":
			return "FACTION INFLUENCE"
		"renown":
			return "RENOWN"
		"level":
			return "MILESTONE"
		_:
			return "REWARD"


static func _entry_name(entry: Dictionary) -> String:
	var authored_label := str(entry.get("label", "")).strip_edges()
	if not authored_label.is_empty():
		return authored_label
	return str(entry.get("id", "reward")).replace("/", " ").replace("-", " ").replace("_", " ").capitalize()


static func _entry_amount(entry: Dictionary) -> String:
	var kind := str(entry.get("kind", "reward"))
	if kind == "item":
		return "×%d" % maxi(1, int(entry.get("amount", 1)))
	var delta := float(entry.get("delta", 0.0))
	var magnitude := str(int(absf(delta))) if is_equal_approx(delta, roundf(delta)) else "%.1f" % absf(delta)
	var signed := "%s%s" % ["+" if delta >= 0.0 else "-", magnitude]
	return "LEVEL %s" % signed if kind == "level" else signed


static func _delta_theme(entry: Dictionary) -> String:
	if str(entry.get("kind", "")) == "item":
		return "StatLabel"
	return "PositiveLabel" if float(entry.get("delta", 0.0)) >= 0.0 else "NegativeLabel"
