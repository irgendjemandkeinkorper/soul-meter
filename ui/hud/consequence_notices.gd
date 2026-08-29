class_name ConsequenceNotices
extends Control

signal notice_shown(text: String)

const MAX_VISIBLE_NOTICES: int = 3
const SLIDE_DISTANCE: float = 32.0

@export_range(0.0, 2.0, 0.01) var slide_seconds: float = 0.2
@export_range(0.0, 10.0, 0.1) var hold_seconds: float = 3.0
@export_range(0.0, 2.0, 0.01) var fade_seconds: float = 0.35

@onready var _notice_stack: VBoxContainer = %NoticeStack

var _pending_texts: Array[String] = []
var _seen_events: Dictionary = {}
var _notice_sequence: int = 0


func _ready() -> void:
	var reputation_handler := Callable(self, "_on_reputation_changed")
	if not Reputation.reputation_changed.is_connected(reputation_handler):
		Reputation.reputation_changed.connect(reputation_handler)
	var renown_handler := Callable(self, "_on_renown_changed")
	if not Renown.renown_changed.is_connected(renown_handler):
		Renown.renown_changed.connect(renown_handler)
	_flush_pending()


func _exit_tree() -> void:
	var reputation_handler := Callable(self, "_on_reputation_changed")
	if Reputation.reputation_changed.is_connected(reputation_handler):
		Reputation.reputation_changed.disconnect(reputation_handler)
	var renown_handler := Callable(self, "_on_renown_changed")
	if Renown.renown_changed.is_connected(renown_handler):
		Renown.renown_changed.disconnect(renown_handler)


func _notification(what: int) -> void:
	if what == NOTIFICATION_UNPAUSED and is_node_ready():
		_flush_pending()


func visible_notice_texts() -> Array[String]:
	var texts: Array[String] = []
	if not is_instance_valid(_notice_stack):
		return texts
	for child: Node in _notice_stack.get_children():
		var label: Label = child.get_node_or_null("Label") as Label
		if label != null:
			texts.append(label.text)
	return texts


func pending_notice_count() -> int:
	return _pending_texts.size()


func _on_reputation_changed(
	faction: String, _standing: float, event: ReputationEvent
) -> void:
	if not _remember_event(event):
		return
	_enqueue("%s WILL REMEMBER — %s" % [
		_faction_display_name(faction).to_upper(), event.cause.strip_edges()
	])


func _on_renown_changed(
	_kind: StringName, _total: float, event: RenownEvent
) -> void:
	if not _remember_event(event):
		return
	_enqueue("WORD OF YOU SPREADS — %s" % event.cause.strip_edges())


func _remember_event(event: RefCounted) -> bool:
	if event == null or _seen_events.has(event):
		return false
	_seen_events[event] = true
	return true


func _enqueue(text: String) -> void:
	_pending_texts.append(text)
	_flush_pending()


func _flush_pending() -> void:
	if not is_node_ready() or get_tree().paused:
		return
	while (
		_notice_stack.get_child_count() < MAX_VISIBLE_NOTICES
		and not _pending_texts.is_empty()
	):
		var text: String = _pending_texts.pop_front()
		_show_notice(text)


func _show_notice(text: String) -> void:
	var panel := PanelContainer.new()
	panel.name = "Notice_%d" % _notice_sequence
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.theme_type_variation = &"ConsequenceNoticePanel"
	_notice_sequence += 1

	var label := Label.new()
	label.name = "Label"
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.theme_type_variation = &"ConsequenceNoticeLabel"
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.text = text
	panel.add_child(label)
	_notice_stack.add_child(panel)

	panel.modulate.a = 0.0
	panel.position.x += SLIDE_DISTANCE
	var tween := panel.create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_STOP)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_parallel(true)
	tween.tween_property(panel, "position:x", panel.position.x - SLIDE_DISTANCE, slide_seconds)
	tween.tween_property(panel, "modulate:a", 1.0, slide_seconds)
	tween.set_parallel(false)
	tween.tween_interval(hold_seconds)
	tween.tween_property(panel, "modulate:a", 0.0, fade_seconds)
	tween.tween_callback(_finish_notice.bind(panel))
	notice_shown.emit(text)


func _finish_notice(panel: PanelContainer) -> void:
	if is_instance_valid(panel):
		panel.queue_free()
		await panel.tree_exited
	_flush_pending()


static func _faction_display_name(faction: String) -> String:
	return faction.replace("-", " ").replace("_", " ").capitalize()
