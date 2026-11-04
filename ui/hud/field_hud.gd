class_name FieldHUD
extends CanvasLayer
## Field HUD — the one bottom bar, in both modes (owner 2026-11-01). Per the DS layout rules:
## pinned to the bottom edge with a 2px bronze top rule; the SoulGauge is always the
## rightmost element in it. In exploration the bar carries the objective and the party
## readout. On combat start the same bar grows its combat parts (BattleInterface's CombatBar:
## active member, message window, commands, party, turn controls) and the thin turn strip
## appears at the top; on combat end they retract. The map underneath stays full-screen.

const BATTLE_INTERFACE_SCENE := preload("res://ui/hud/battle_interface.tscn")
const COMBAT_AUDIO := preload("res://audio/combat_audio.gd")
const EXPLORE_BAR_HEIGHT := 84.0
const COMBAT_BAR_HEIGHT := 196.0
const EXPLORE_HINTS := (
	"WASD  MOVE    SHIFT  SPRINT    E  INTERACT    I  INVENTORY    P  PARTY    "
	+ "Q  JOURNAL    R  STANDINGS    ESC  PAUSE"
)
const COMBAT_HINTS := "WASD  SCROLL    SPACE  END TURN    B  BREAKDOWN    ESC  PAUSE"
## The AI-vs-AI demo takes no orders, so its hints leave END TURN out (item 33).
const COMBAT_WATCH_HINTS := "WASD  SCROLL    B  BREAKDOWN    ESC  PAUSE"
## The key hints' home, top left.
const HINTS_AT := Vector2(24, 20)

var battle_interface: BattleInterface
var combat_bar: CombatBar
var _combat_audio: CombatAudio
var _bar: Control
var _bar_column: VBoxContainer
var _tutorial: Label
var _bar_tween: Tween
var _combat_active := false


func _ready() -> void:
	var bar: Control = $Bar
	_bar = bar
	bar.theme = UIManager.ui_theme  # CanvasLayer children don't inherit the root Window theme
	bar.draw.connect(
		func() -> void:
			# the 2px bronze top rule
			bar.draw_rect(Rect2(0, 0, bar.size.x, DS.BORDER_TRIM_W), DS.BRONZE_1)
			# stone fill under the bar, slightly scrimmed so the field reads through
			bar.draw_rect(
				Rect2(0, DS.BORDER_TRIM_W, bar.size.x, bar.size.y), Color(DS.STONE_0, 0.82)
			)
	)
	bar.queue_redraw()
	bar.resized.connect(_apply_insets)
	# The objective is two lines when a destination is set — lay the bar out as a
	# column (right edge reserved for the SoulGauge) instead of absolute positions,
	# so the second objective line can never sit on top of the party readout.
	var column := VBoxContainer.new()
	column.name = "BarColumn"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = 24.0
	column.offset_top = float(DS.BORDER_TRIM_W) + 6.0
	column.offset_right = -270.0
	column.offset_bottom = -4.0
	column.add_theme_constant_override("separation", 2)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(column)
	_bar_column = column
	var objective := Label.new()
	objective.name = "Objective"
	objective.theme_type_variation = "HUDLabel"
	objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(objective)
	var party_status := Label.new()
	party_status.name = "PartyStatus"
	party_status.theme_type_variation = "StatLabel"
	party_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	column.add_child(party_status)

	var tutorial := Label.new()
	tutorial.name = "Tutorial"
	tutorial.position = HINTS_AT
	tutorial.size = Vector2(760, 72)
	tutorial.theme_type_variation = "EyebrowLabel"
	tutorial.text = EXPLORE_HINTS
	add_child(tutorial)
	_tutorial = tutorial

	var autosave := Label.new()
	autosave.name = "AutosaveStatus"
	autosave.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	autosave.position = Vector2(-310, 20)
	autosave.size = Vector2(280, 30)
	autosave.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	autosave.theme_type_variation = "EyebrowLabel"
	autosave.focus_mode = Control.FOCUS_NONE
	autosave.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(autosave)
	QuestSystem.quest_accepted.connect(
		func(quest: Quest) -> void:
			_bind_quest(quest, objective)
			_refresh_objective(objective)
	)
	QuestSystem.quest_completed.connect(func(_quest: Quest) -> void: _refresh_objective(objective))
	GameState.flag_changed.connect(
		func(_flag: String, _value: Variant) -> void: _refresh_objective(objective)
	)
	GameState.party_changed.connect(
		func() -> void:
			_refresh_objective(objective)
			_refresh_party(party_status)
	)
	SaveGame.autosave_finished.connect(
		func(_reason: String, succeeded: bool) -> void:
			autosave.text = "AUTOSAVED" if succeeded else "AUTOSAVE FAILED"
			_fade_status(autosave)
	)
	for quest in QuestSystem.get_active_quests():
		_bind_quest(quest, objective)
	_refresh_objective(objective)
	_refresh_party(party_status)


# --- combat: the bar grows, the strip appears ----------------------------------------------


func combat_active() -> bool:
	return _combat_active


func bar() -> Control:
	return _bar


func bar_height() -> float:
	return _bar.size.y


## Grows the bar's combat parts over the live field (owner 2026-11-01). `field` is the map
## the fight runs on; null hosts the stage's own battlefield drawing (standalone tools and
## tests). Idempotent: resuming from the pause menu keeps the parts that are already up.
func enter_combat(field: FieldMap) -> BattleInterface:
	if _combat_active:
		return battle_interface
	_combat_active = true
	var reduced_motion := bool(GameState.get_setting("accessibility", "reduced_motion", false))
	battle_interface = BATTLE_INTERFACE_SCENE.instantiate() as BattleInterface
	battle_interface.name = "BattleInterface"
	battle_interface.theme = UIManager.ui_theme
	add_child(battle_interface)
	# Under the bar in draw order: the bar hosts the combat parts and must stay on top.
	move_child(battle_interface, _bar.get_index())
	if field != null:
		battle_interface.stage.bind_field(field)
	# The open window is the bar's full combat height from the first beat, so the opening
	# pan already keeps the actor clear of where the bar will be.
	_apply_insets()
	# The one log line of the cue goes in before the replayed narration, so the window reads
	# in order: the cue, then what has happened so far.
	battle_interface.combat_bar.append_cue(tr("COMBAT BEGINS"))
	Battle.combat_event.connect(battle_interface.consume_event)
	battle_interface.stage.set_replaying(true)
	Battle.replay_combat_events(battle_interface.consume_event)
	battle_interface.stage.set_replaying(false)
	if Battle.controller != null and Battle.controller.scheduler != null:
		battle_interface.bind_controller(Battle.controller)
	_combat_audio = COMBAT_AUDIO.new() as CombatAudio
	_combat_audio.name = "CombatAudio"
	add_child(_combat_audio)
	Battle.combat_event.connect(_combat_audio.consume_event)

	combat_bar = battle_interface.combat_bar
	combat_bar.reparent(_bar, false)
	combat_bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	combat_bar.offset_left = 24.0
	combat_bar.offset_top = float(DS.BORDER_TRIM_W) + 6.0
	combat_bar.offset_right = -270.0
	combat_bar.offset_bottom = -6.0
	_bar_column.visible = false
	_tutorial.text = tr(COMBAT_WATCH_HINTS if battle_interface.autoplaying() else COMBAT_HINTS)
	# The bar takes pointer input in combat (buttons); in exploration it lets clicks through.
	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	battle_interface.turn_strip.resized.connect(_apply_insets)
	_apply_insets()

	# The cue: the combat parts slide in with the bar, a brief edge vignette, one sound and one
	# log line — under 0.5 s in all, and no motion at all under reduced motion.
	_set_bar_height(COMBAT_BAR_HEIGHT, reduced_motion)
	if not reduced_motion:
		combat_bar.modulate = Color(1, 1, 1, 0)
		var fade := create_tween()
		fade.tween_property(combat_bar, "modulate:a", 1.0, DS.DUR_BASE)
	battle_interface.play_entry_cue(reduced_motion)
	_combat_audio.play_cue(CombatAudio.CUE_COMBAT_START)
	return battle_interface


## Retracts the combat parts and frees the interface (and with it the field's CombatOverlay,
## which releases the camera). The bar returns to its exploration height.
func exit_combat() -> void:
	if not _combat_active:
		return
	_combat_active = false
	if is_instance_valid(battle_interface):
		if Battle.combat_event.is_connected(battle_interface.consume_event):
			Battle.combat_event.disconnect(battle_interface.consume_event)
		if is_instance_valid(combat_bar) and combat_bar.get_parent() == _bar:
			combat_bar.reparent(battle_interface, false)
		remove_child(battle_interface)
		battle_interface.queue_free()
	if is_instance_valid(_combat_audio):
		if Battle.combat_event.is_connected(_combat_audio.consume_event):
			Battle.combat_event.disconnect(_combat_audio.consume_event)
		remove_child(_combat_audio)
		_combat_audio.queue_free()
	battle_interface = null
	combat_bar = null
	_combat_audio = null
	_bar_column.visible = true
	_tutorial.text = EXPLORE_HINTS
	_tutorial.position = HINTS_AT
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var reduced_motion := bool(GameState.get_setting("accessibility", "reduced_motion", false))
	_set_bar_height(EXPLORE_BAR_HEIGHT, reduced_motion)


func _set_bar_height(height: float, immediate: bool) -> void:
	if _bar_tween != null and _bar_tween.is_valid():
		_bar_tween.kill()
	if immediate:
		_bar.offset_top = -height
		return
	_bar_tween = create_tween()
	_bar_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_bar_tween.tween_property(_bar, "offset_top", -height, DS.DUR_BASE)


## The interface keeps its visibility checks, tooltip and notices inside the viewport minus
## the strip and the bar.
func _apply_insets() -> void:
	if not is_instance_valid(battle_interface):
		return
	battle_interface.set_hud_insets(
		battle_interface.turn_strip.size.y, maxf(_bar.size.y, COMBAT_BAR_HEIGHT)
	)
	_place_hints()


## Owner 2026-11-02 (item 33 follow-up): a full turn strip (the 5v5 demo's ten units) runs
## under the top-left key hints, which printed over the first names. The hints drop below the
## strip whenever the two would meet, and go home when the strip is short again.
func _place_hints() -> void:
	_tutorial.position = HINTS_AT
	if not is_instance_valid(battle_interface):
		return
	var strip := battle_interface.turn_strip.get_global_rect()
	var hints := Rect2(_tutorial.global_position, _tutorial.get_minimum_size())
	if strip.intersects(hints):
		_tutorial.global_position.y = strip.end.y + DS.SPACE_3


# --- exploration readouts -------------------------------------------------------------------


func _bind_quest(quest: Quest, label: Label) -> void:
	if not quest.updated.is_connected(_refresh_objective.bind(label)):
		quest.updated.connect(_refresh_objective.bind(label))


func _refresh_objective(label: Label) -> void:
	var text := "NEXT OBJECTIVE  ·  %s  —  %s" % [
		ChapterOneProgress.title(), ChapterOneProgress.objective()
	]
	var destination := ChapterOneProgress.destination()
	if not destination.is_empty():
		text += "\nGO TO  ·  " + destination
	var action_hint := ChapterOneProgress.action_hint()
	if not action_hint.is_empty():
		text += "  ·  " + action_hint
	label.text = text


func _refresh_party(label: Label) -> void:
	var rows: PackedStringArray = []
	for member in GameState.party:
		rows.append(
			"%s  HP %d/%d  BREATH %d/%d"
			% [member.display_name, member.hp, member.max_hp, member.breath, member.breath_max]
		)
	label.text = "   •   ".join(rows)


func _fade_status(label: Label) -> void:
	label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
