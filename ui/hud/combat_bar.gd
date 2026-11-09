class_name CombatBar
extends HBoxContainer
## The bar's combat parts (owner 2026-11-01, "one bar, both modes"): the active member's
## plate, the message window, the command grid, the party readout and the turn controls.
## Authored inside battle_interface.tscn and hosted in the field HUD's bottom bar while a
## fight is on. The logic is the former command dock's (ui/screens/battle.gd): every button
## routes to the same Battle / controller commands, and nothing here resolves combat.

const LOG_LINE_LIMIT := 40

@onready var active_unit_plate: UnitPlateRegion = %ActiveUnitPlate

var cursor_readout: Label
var log_scroll: ScrollContainer
var log_list: VBoxContainer
var _enemy_lbl: Label
var _balance_lbl: Label
var _balance_bar: ProgressBar
var _party_box: VBoxContainer
## The hotbar: the active member's eight slotted commands, in slot order.
var _actions_box: HFlowContainer
var _action_scroll: ScrollContainer
## Behind MORE: usable commands that are not slotted, in catalog order.
var _spare_box: HFlowContainer
## Behind MORE, after the usable ones: locked commands as dimmed tiles. Owner 2026-11-02 (item
## 33 follow-up): the lock reason moved from a row of text onto the tile's hover card.
var _locked_box: HFlowContainer
## Each command tile's key label ("1"–"8"), shown while the command holds a slot.
var _slot_keys: Array[Label] = []
## Each command tile's AP badge (top right).
var _tile_costs: Array[Label] = []
## Each command tile's hover-card content for this refresh: {title, stats, reach, effect,
## lock, hint}. The card is the bar's one `_command_card`, filled from here on hover.
var _cards: Array[Dictionary] = []
var _command_card: PanelContainer
var _card_title: Label
var _card_stats: Label
var _card_reach: Label
var _card_effect: Label
var _card_lock: Label
var _card_hint: Label
var _card_source: Control
## Slotted action ids per member for this battle (combat id -> Array of ids, slot order).
## The bar is built per battle, so this lives and dies with the fight; nothing is saved.
var _slots: Dictionary = {}
## Commands each member chose this battle (combat id -> {action id: count}).
var _uses: Dictionary = {}
## The member whose hotbar is showing (the last ally to act during an enemy phase).
var _hotbar_owner: StringName = &""
var _more_button: Button
var _show_all := false
var _locked_count := 0
var _command_column: VBoxContainer
var _command_footer: HBoxContainer
var _aim_host: HBoxContainer
var _target_button: Button
var _end_turn_button: Button
var _withdraw_button: Button
var _breakdown_button: Button
var _outcome_box: VBoxContainer
var _action_buttons: Array[Button] = []
var _interface: BattleInterface
var _weakness_dialog: Window
var _weakness_picker: OptionButton
var _weakness_forecast: Label
var _selected_weakness_id: StringName = &""
var _refresh_queued := false
## #473: the result waits here until the field has presented the beats that led to it.
var _pending_result: BattleResult
var _built := false


## Column minimums (px) on the 1920 x 1080 logical viewport: 240 plate, 240 log (grows),
## 720 command, 250 party (a member's name and HP on one line), 124 controls, plus the four
## rules, inside the bar's 1626 px.
## The project scales the whole canvas (canvas_items stretch), so 1366 x 768 renders this
## same layout at 0.71 and nothing reflows or clips.
const LOG_WIDTH := 240
const COMMAND_WIDTH := 720
const PARTY_WIDTH := 250
const CONTROLS_WIDTH := 124
## Command buttons: 22 px rows so six rows of ready actions fit the column without scrolling.
const ACTION_ROW := 22
## Hotbar slots stand taller than the footer's MORE and TARGET (owner playtest 2026-11-02:
## the commands were too small to read).
const SLOT_ROW := 30
## A command tile (owner 2026-11-02, item 33 follow-up: "abilities behind icons with a hover
## tooltip"): eight across fit the 720 px command column with their gaps; a two-line name.
const TILE_SIZE := Vector2(84, 64)
## The hover card's width: one short paragraph of effect text per line set.
const CARD_WIDTH := 300.0
## Owner 2026-11-01: an eight-slot hotbar, auto-filled; keys 1–8 fire the slots and every
## other command waits behind MORE.
const HOTBAR_SIZE := 8
## Refusals that mean "not this member's command": another class's action, an unowned perk.
## Any other lock is momentary, so a slotted command keeps its slot, dimmed, with the reason.
const NOT_IN_KIT: Array[StringName] = [&"class_resource", &"perk_missing"]
## Fill order: one command per role, then the two cheapest usable weapon arts and spells.
enum SlotRole { STRIKE, GUARD, SIGNATURE, DEFINING, WEAPON_ART, SPELL, OTHER }
const ROLE_QUOTA := {
	SlotRole.STRIKE: 1, SlotRole.GUARD: 1, SlotRole.SIGNATURE: 1, SlotRole.DEFINING: 1,
	SlotRole.WEAPON_ART: 2, SlotRole.SPELL: 2,
}


func _ready() -> void:
	_build()
	_refresh()


## The field HUD reparents the bar out of the interface and into its own bar, which leaves
## and re-enters the tree; the Battle wiring follows the tree membership, not `_ready`.
func _enter_tree() -> void:
	if not Battle.turn_resolved.is_connected(_queue_refresh):
		Battle.turn_resolved.connect(_queue_refresh)
	if not Battle.balance_changed.is_connected(_on_balance_changed):
		Battle.balance_changed.connect(_on_balance_changed)
	if not Battle.battle_ended.is_connected(_on_battle_ended):
		Battle.battle_ended.connect(_on_battle_ended)
	if _built:
		_queue_refresh()


func _exit_tree() -> void:
	if _card_source != null:
		_hide_card(_card_source)
	if Battle.turn_resolved.is_connected(_queue_refresh):
		Battle.turn_resolved.disconnect(_queue_refresh)
	if Battle.balance_changed.is_connected(_on_balance_changed):
		Battle.balance_changed.disconnect(_on_balance_changed)
	if Battle.battle_ended.is_connected(_on_battle_ended):
		Battle.battle_ended.disconnect(_on_battle_ended)


## The interface owns pointer aiming and the breakdown popover; the bar only routes to it.
func bind(interface: BattleInterface) -> void:
	_interface = interface
	if not interface.refusal_pulsed.is_connected(_on_refusal):
		interface.refusal_pulsed.connect(_on_refusal)
	if not interface.breakdown_visibility_changed.is_connected(_on_breakdown_visibility_changed):
		interface.breakdown_visibility_changed.connect(_on_breakdown_visibility_changed)
	if not interface.stage.beat_presented.is_connected(_on_beat_presented):
		interface.stage.beat_presented.connect(_on_beat_presented)
	if not interface.pointer_action_selected.is_connected(_on_pointer_action_selected):
		interface.pointer_action_selected.connect(_on_pointer_action_selected)
	_refresh()


## The armed tile follows the interface's armed command (bronze), however it was armed.
func _on_pointer_action_selected(_action_id: StringName) -> void:
	_queue_refresh()


## The aim row (called shots) is a command, so it lives on the bar under the action grid
## even though the forecast panel that builds it sits in the breakdown popover.
func host_aim_row(row: Control) -> void:
	if row.get_parent() == _aim_host:
		return
	row.reparent(_aim_host, false)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_set_aiming(row.visible)
	row.visibility_changed.connect(func() -> void: _set_aiming(row.visible))


## While the AIM row is up it takes the FOE readout's place on the footer line (the tooltip
## at the body names the foe); MORE and TARGET stay reachable beside it.
func _set_aiming(aiming: bool) -> void:
	_aim_host.visible = aiming
	_enemy_lbl.visible = not aiming


## Left to right, Fallout 2's reading order: who acts, what happened, what you can do, who
## is with you, and the turn controls. The SoulGauge stays the bar's rightmost element and
## belongs to the field HUD itself.
func _build() -> void:
	add_child(_rule())

	var log_column := VBoxContainer.new()
	log_column.name = "LogColumn"
	log_column.theme_type_variation = "HudBarColumn"
	log_column.custom_minimum_size = Vector2(LOG_WIDTH, 0)
	log_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(log_column)
	cursor_readout = Label.new()
	cursor_readout.name = "CursorReadout"
	# Empty until the pointer is over a cell: an idle "CURSOR —" told the player nothing.
	cursor_readout.theme_type_variation = "HeadingLabel"
	cursor_readout.text = ""
	cursor_readout.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	log_column.add_child(cursor_readout)
	var balance_row := HBoxContainer.new()
	balance_row.name = "BalanceRow"
	balance_row.theme_type_variation = "HudBarRow"
	log_column.add_child(balance_row)
	_balance_bar = ProgressBar.new()
	_balance_bar.name = "BalanceBar"
	_balance_bar.min_value = Battle.BALANCE_MIN
	_balance_bar.max_value = Battle.BALANCE_MAX
	_balance_bar.show_percentage = false
	_balance_bar.custom_minimum_size = Vector2(0, 6)
	_balance_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_balance_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	balance_row.add_child(_balance_bar)
	_balance_lbl = Label.new()
	_balance_lbl.name = "BalanceLabel"
	_balance_lbl.theme_type_variation = "EyebrowLabel"
	_balance_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	balance_row.add_child(_balance_lbl)
	log_scroll = ScrollContainer.new()
	log_scroll.name = "MessageLog"
	log_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	log_column.add_child(log_scroll)
	log_list = VBoxContainer.new()
	log_list.name = "Lines"
	log_list.theme_type_variation = "HudBarColumn"
	log_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_scroll.add_child(log_list)

	add_child(_rule())

	var command_column := VBoxContainer.new()
	command_column.name = "CommandColumn"
	command_column.theme_type_variation = "HudBarColumn"
	command_column.custom_minimum_size = Vector2(COMMAND_WIDTH, 0)
	add_child(command_column)
	_command_column = command_column
	# Fallout's bar labels nothing: the hotbar is the command area, eight slots at full label
	# width (never clipped) that fit without scrolling. Everything else waits behind MORE:
	# the usable rest first, then the locked ones with their lock reasons. Every command
	# stays reachable from the same buttons with the same enabled/lock logic.
	_action_scroll = ScrollContainer.new()
	_action_scroll.name = "ActionScroll"
	_action_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_action_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	command_column.add_child(_action_scroll)
	var stack := VBoxContainer.new()
	stack.name = "ActionStack"
	stack.theme_type_variation = "HudBarColumn"
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_scroll.add_child(stack)
	_actions_box = HFlowContainer.new()
	_actions_box.name = "Actions"
	_actions_box.theme_type_variation = "HudActionFlow"
	_actions_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack.add_child(_actions_box)
	_spare_box = HFlowContainer.new()
	_spare_box.name = "Spare"
	_spare_box.theme_type_variation = "HudActionFlow"
	_spare_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_spare_box.visible = false
	stack.add_child(_spare_box)
	_locked_box = HFlowContainer.new()
	_locked_box.name = "Locked"
	_locked_box.theme_type_variation = "HudActionFlow"
	_locked_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_locked_box.visible = false
	stack.add_child(_locked_box)
	for action in Battle.available_actions():
		var tile := _command_tile(action)
		_actions_box.add_child(tile)
		_action_buttons.append(tile)
		_cards.append({})
	_outcome_box = VBoxContainer.new()
	_outcome_box.name = "Outcome"
	_outcome_box.theme_type_variation = "HudBarColumn"
	_outcome_box.visible = false
	command_column.add_child(_outcome_box)
	# One footer line under the ready actions: the FOE readout, MORE and the target cycler;
	# while an aimed action quotes a hovered enemy, the AIM row takes the readout's place on
	# that same line (the tooltip at the body already names the foe).
	var command_footer := HBoxContainer.new()
	command_footer.name = "CommandFooter"
	command_footer.theme_type_variation = "HudBarRow"
	command_column.add_child(command_footer)
	_command_footer = command_footer
	_aim_host = HBoxContainer.new()
	_aim_host.name = "AimRow"
	_aim_host.theme_type_variation = "HudBarRow"
	_aim_host.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aim_host.visible = false
	command_footer.add_child(_aim_host)
	var aim_title := Label.new()
	aim_title.text = tr("AIM")
	aim_title.theme_type_variation = "EyebrowLabel"
	_aim_host.add_child(aim_title)
	_enemy_lbl = Label.new()
	_enemy_lbl.name = "FoeReadout"
	_enemy_lbl.theme_type_variation = "StatLabel"
	_enemy_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_enemy_lbl.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	command_footer.add_child(_enemy_lbl)
	_more_button = Button.new()
	_more_button.name = "MoreButton"
	_more_button.theme_type_variation = "HudActionButton"
	_more_button.custom_minimum_size = Vector2(0, ACTION_ROW)
	_more_button.toggle_mode = true
	_more_button.focus_mode = Control.FOCUS_NONE
	_more_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	_more_button.tooltip_text = tr("Show every command, with why the locked ones cannot be used now.")
	_more_button.toggled.connect(set_show_all)
	command_footer.add_child(_more_button)
	_target_button = _button(command_footer, tr("TARGET  〉"), Battle.select_next_enemy)
	_target_button.name = "TargetButton"
	_target_button.theme_type_variation = "HudActionButton"
	_target_button.custom_minimum_size = Vector2(0, ACTION_ROW)
	_target_button.tooltip_text = tr("Cycle to the next enemy.")

	add_child(_rule())

	var party_column := VBoxContainer.new()
	party_column.name = "PartyColumn"
	party_column.theme_type_variation = "HudBarColumn"
	party_column.custom_minimum_size = Vector2(PARTY_WIDTH, 0)
	add_child(party_column)
	var party_title := Label.new()
	party_title.text = "PARTY"
	party_title.theme_type_variation = "EyebrowLabel"
	party_column.add_child(party_title)
	_party_box = VBoxContainer.new()
	_party_box.name = "PartyRows"
	_party_box.theme_type_variation = "BattleTightColumn"
	_party_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	party_column.add_child(_party_box)

	add_child(_rule())

	var controls := VBoxContainer.new()
	controls.name = "TurnControls"
	controls.theme_type_variation = "HudBarColumn"
	controls.custom_minimum_size = Vector2(CONTROLS_WIDTH, 0)
	add_child(controls)
	_end_turn_button = _button(controls, "END TURN", Battle.end_turn)
	_end_turn_button.name = "EndTurnButton"
	_end_turn_button.custom_minimum_size = Vector2(CONTROLS_WIDTH, 40)
	_end_turn_button.theme_type_variation = "BronzeButton"
	_end_turn_button.tooltip_text = tr("End your turn (Space).")
	_withdraw_button = _button(controls, "WITHDRAW", Battle.flee)
	_withdraw_button.name = "WithdrawButton"
	_withdraw_button.custom_minimum_size = Vector2(CONTROLS_WIDTH, 28)
	_withdraw_button.theme_type_variation = "DangerButton"
	_breakdown_button = _button(controls, tr("BREAKDOWN"), _toggle_breakdown)
	_breakdown_button.name = "BreakdownButton"
	_breakdown_button.custom_minimum_size = Vector2(CONTROLS_WIDTH, 28)
	_breakdown_button.toggle_mode = true
	_breakdown_button.tooltip_text = tr("Accuracy and power breakdown, attunement and tactical data (B).")
	_build_command_card()
	_built = true


## One command tile: the glyph, the name under it, the slot key top left and the AP top right.
## Everything else about the command is on its hover card.
func _command_tile(action: CombatAction) -> Button:
	var tile := Button.new()
	tile.text = action.display_name.to_upper()
	tile.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tile.focus_mode = Control.FOCUS_NONE
	tile.pressed.connect(_use_action.bind(action.id))
	tile.name = "Command_%s" % String(action.id).replace("-", "_")
	tile.theme_type_variation = "HudCommandTile"
	tile.custom_minimum_size = TILE_SIZE
	tile.icon = CommandIcons.for_action(action)
	tile.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tile.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	tile.expand_icon = false
	tile.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tile.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	tile.set_meta("index", _action_buttons.size())
	tile.set_meta("action_id", action.id)
	var key := Label.new()
	key.name = "SlotKey"
	key.theme_type_variation = "HudTileKey"
	key.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, DS.SPACE_3)
	key.visible = false
	tile.add_child(key)
	_slot_keys.append(key)
	# AP round economy: the tile's badge is the same `ap_cost` the controller charges.
	var cost := Label.new()
	cost.name = "TileCost"
	cost.theme_type_variation = "HudTileCost"
	cost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cost.text = "%d AP" % action.ap_cost
	cost.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE, DS.SPACE_3)
	tile.add_child(cost)
	_tile_costs.append(cost)
	tile.mouse_entered.connect(_show_card.bind(tile))
	tile.mouse_exited.connect(_hide_card.bind(tile))
	return tile


func _rule() -> VSeparator:
	var rule := VSeparator.new()
	rule.theme_type_variation = "HudBarRule"
	return rule


## Bar buttons are mouse targets and never hold focus: Space stays END TURN (owner
## 2026-11-01) instead of re-pressing whatever was clicked last.
func _button(box: Container, text: String, cb: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(cb)
	box.add_child(button)
	return button


## The command footer's rect (the AIM row, FOE readout, MORE and TARGET share it).
func command_footer() -> HBoxContainer:
	return _command_footer


## The usable command buttons on the hotbar, in slot order.
func ready_buttons() -> Array[Button]:
	var ready: Array[Button] = []
	for button: Button in hotbar_buttons():
		if not button.disabled:
			ready.append(button)
	return ready


## Every hotbar button, usable or dimmed, in slot order (key 1 first).
func hotbar_buttons() -> Array[Button]:
	var slotted: Array[Button] = []
	for child: Node in _actions_box.get_children():
		if child is Button and (child as Button).visible:
			slotted.append(child as Button)
	return slotted


## The showing member's slotted action ids, in slot order.
func hotbar_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for id: Variant in _slots.get(_hotbar_owner, []):
		ids.append(StringName(id))
	return ids


## Key 1–8: fires the slot's command exactly as a click would. A dimmed or empty slot is
## a no-op; the interface guards the turn and the focus.
func press_slot(slot: int) -> void:
	var slotted := hotbar_buttons()
	if slot < 0 or slot >= slotted.size() or slotted[slot].disabled:
		return
	slotted[slot].pressed.emit()


## Every visible command button, ready or locked (the MORE list included when shown).
func visible_action_buttons() -> Array[Button]:
	var shown: Array[Button] = []
	for button: Button in _action_buttons:
		if button.is_visible_in_tree():
			shown.append(button)
	return shown


func showing_all() -> bool:
	return _show_all


func set_show_all(show_all: bool) -> void:
	_show_all = show_all
	_more_button.set_pressed_no_signal(show_all)
	_refresh()


## END TURN from the key (Space): the interface guards the turn and the focus.
func press_end_turn() -> void:
	if _end_turn_button.disabled or not _end_turn_button.visible:
		return
	_end_turn_button.pressed.emit()


func _make_meter() -> ProgressBar:
	var meter := ProgressBar.new()
	meter.show_percentage = false
	meter.theme_type_variation = "HealthProgressBar"
	return meter


# --- the message window ------------------------------------------------------------------


## Appends one narration line. Lines come from the event stream (`message`), turn cues and
## refusals; the bar never writes prose of its own.
func append_log(text: String, variation: String = "HudLogLine") -> void:
	if text.strip_edges().is_empty():
		return
	var line := Label.new()
	line.text = text
	line.theme_type_variation = variation
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_list.add_child(line)
	while log_list.get_child_count() > LOG_LINE_LIMIT:
		var oldest := log_list.get_child(0)
		log_list.remove_child(oldest)
		oldest.queue_free()
	_scroll_log_to_end.call_deferred()


func append_cue(text: String) -> void:
	append_log(text, "HudLogCue")


func log_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for child: Node in log_list.get_children():
		lines.append((child as Label).text)
	return lines


func _scroll_log_to_end() -> void:
	if is_instance_valid(log_scroll):
		log_scroll.scroll_vertical = int(log_scroll.get_v_scroll_bar().max_value)


func _on_refusal(message: String) -> void:
	append_log(message, "HudLogRefusal")


## #473: the log follows the field's presented beats, so a sequenced enemy phase narrates
## in the order the player sees it. Turn cues come from the event type; narration from the
## event's own `message`.
func _on_beat_presented(event: CombatEvent) -> void:
	if event.type in [&"turn_started", &"enemy_turn_started"]:
		var actor_name := _actor_name(event)
		if not actor_name.is_empty():
			append_cue(tr("TURN  ·  %s") % actor_name.to_upper())
	if event.data.has("message"):
		append_log(str(event.data["message"]))
	_queue_refresh()


func _actor_name(event: CombatEvent) -> String:
	if event.actor_id.is_empty():
		return ""
	var row: Dictionary = _presented_rows().get(event.actor_id, {})
	if not row.is_empty():
		return str(row.get("display_name", row.get("name", "")))
	if Battle.controller != null:
		var actor := Battle.controller.actor_by_id(event.actor_id)
		if actor != null:
			return actor.display_name
	return ""


# --- commands ----------------------------------------------------------------------------


func _use_action(action_id: StringName) -> void:
	if _watching():
		return
	_note_use(action_id)
	var action: CombatAction = null
	for candidate: CombatAction in Battle.available_actions():
		if candidate.id == action_id:
			action = candidate
			break
	if action != null and action.kind == CombatAction.Kind.DEFINING_STRIKE:
		_open_weakness_dialog()
		return
	if action != null and is_instance_valid(_interface):
		if action.targets_cells() or action.targets_any_side() or (
			action.class_resource_action.is_empty() and action.target_side == "ally"
		):
			# Cell workings and creature-side cards are aimed on the stage; the button only arms.
			_interface.select_pointer_action(action_id)
			return
		if action.requires_enemy_target():
			_interface.select_pointer_action(action_id)
			if Battle.is_positional_refusal(Battle.action_lock(action)):
				# Out of reach of the selected foe: the tile only arms. A click on the field
				# picks a foe in reach, or walks in to a far one (item 33 follow-up).
				return
	Battle.use_action(action_id)


func _watching() -> bool:
	return is_instance_valid(_interface) and _interface.autoplaying()


func _open_weakness_dialog() -> void:
	var weaknesses := Battle.available_weaknesses()
	if weaknesses.is_empty():
		return
	_ensure_weakness_dialog()
	_weakness_picker.clear()
	for weakness: Dictionary in weaknesses:
		_weakness_picker.add_item(str(weakness.get("display_name", weakness.get("id", "Weakness"))))
		_weakness_picker.set_item_metadata(
			_weakness_picker.item_count - 1, StringName(weakness.get("id", ""))
		)
	_selected_weakness_id = StringName(_weakness_picker.get_item_metadata(0))
	_update_weakness_forecast(0)
	_weakness_dialog.popup_centered(Vector2i(520, 280))


func _ensure_weakness_dialog() -> void:
	if is_instance_valid(_weakness_dialog):
		return
	_weakness_dialog = Window.new()
	_weakness_dialog.name = "DefiningStrikeDialog"
	_weakness_dialog.title = "Defining Strike"
	_weakness_dialog.transient = true
	_weakness_dialog.exclusive = true
	_weakness_dialog.unresizable = true
	_weakness_dialog.close_requested.connect(_weakness_dialog.hide)
	add_child(_weakness_dialog)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.theme_type_variation = "BattlePanelMargin"
	_weakness_dialog.add_child(margin)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var instruction := Label.new()
	instruction.text = "Choose a discovered weakness to name."
	column.add_child(instruction)
	_weakness_picker = OptionButton.new()
	_weakness_picker.name = "WeaknessPicker"
	_weakness_picker.item_selected.connect(_update_weakness_forecast)
	column.add_child(_weakness_picker)
	_weakness_forecast = Label.new()
	_weakness_forecast.name = "WeaknessForecast"
	_weakness_forecast.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_weakness_forecast.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(_weakness_forecast)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(buttons)
	var cancel := _button(buttons, "CANCEL", _weakness_dialog.hide)
	cancel.custom_minimum_size = Vector2(96, 30)
	var confirm := _button(buttons, "CONFIRM STRIKE", _confirm_weakness)
	confirm.name = "ConfirmDefiningStrike"
	confirm.custom_minimum_size = Vector2(156, 34)
	confirm.theme_type_variation = "BronzeButton"


func _update_weakness_forecast(index: int) -> void:
	if not is_instance_valid(_weakness_picker) or index < 0 or index >= _weakness_picker.item_count:
		return
	_selected_weakness_id = StringName(_weakness_picker.get_item_metadata(index))
	var forecast := Battle.defining_strike_forecast(_selected_weakness_id)
	if not bool(forecast.get("allowed", false)):
		_weakness_forecast.text = str(forecast.get("message", "Strike unavailable."))
		return
	var effect_name := str(forecast.get("effect_id", "")).replace("_", " ").capitalize()
	var resolution: Dictionary = forecast.get("resolution", {})
	var accuracy: Dictionary = resolution.get("accuracy_breakdown", {})
	_weakness_forecast.text = (
		"COST %d AP  ·  KNOWLEDGE %.0f%%  ·  HIT %d%%\nFORECAST %d DAMAGE ON HIT\n%s requires a successful knowledge check and a hit."
		% [
			int(forecast.get("ap_cost", 0)),
			float(forecast.get("chance", 0.0)),
			int(accuracy.get("effective_hit_chance", resolution.get("hit_chance", 100))),
			int(forecast.get("damage_on_hit", forecast.get("damage", 0))),
			effect_name if not effect_name.is_empty() else "No additional effect",
		]
	)


func _confirm_weakness() -> void:
	if _selected_weakness_id.is_empty():
		return
	_weakness_dialog.hide()
	Battle.use_defining_strike(_selected_weakness_id)


func _toggle_breakdown() -> void:
	if not is_instance_valid(_interface):
		return
	_interface.toggle_breakdown()


func _on_breakdown_visibility_changed(visible_now: bool) -> void:
	if is_instance_valid(_breakdown_button):
		_breakdown_button.set_pressed_no_signal(visible_now)


func _on_balance_changed(_value: int) -> void:
	_queue_refresh()


# --- refresh -----------------------------------------------------------------------------


## The controller resolves a whole enemy phase inside one frame, and nothing is drawn between
## its events, so the bar refreshes once per frame instead of once per event (#282: with 100
## hostiles that was 6 ms a turn, every turn). The deferred call still lands before the frame
## draws. Battle end and setup refresh directly.
func _queue_refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_flush_refresh.call_deferred()


func _flush_refresh() -> void:
	_refresh_queued = false
	_refresh()


func _refresh() -> void:
	if not _built:
		return
	_balance_bar.value = Battle.balance
	_balance_lbl.text = _balance_text()
	_update_enemy_status()
	_update_party_status()

	var actions := Battle.available_actions()
	var cell_battlefield := _battlefield_has_cells()
	var offered: Array[bool] = []
	var ready: Array[bool] = []
	var in_kit: Array[bool] = []
	var reasons := PackedStringArray()
	var hints := PackedStringArray()
	for i in _action_buttons.size():
		if i >= actions.size():
			offered.append(false)
			ready.append(false)
			in_kit.append(false)
			reasons.append("")
			hints.append("")
			continue
		# #473: on a cell battlefield a move is a click on a cell; the zone MOVE cards
		# (FRONT/BACK/FLANK, and the destination-less MOVE) have nothing to aim at there.
		var is_offered := not (cell_battlefield and actions[i].kind == CombatAction.Kind.MOVE)
		var refusal := Battle.action_lock(actions[i])
		var allowed := bool(refusal.get("allowed", false))
		var blocked_by := StringName(str(refusal.get("blocked_by", "")))
		# Where the selected foe stands never locks a command: the tile arms, and a click on
		# the field picks a foe in reach or walks in to a far one (item 33 follow-up).
		var positional := Battle.is_positional_refusal(refusal)
		offered.append(is_offered)
		ready.append(is_offered and (allowed or positional))
		in_kit.append(is_offered and (allowed or not NOT_IN_KIT.has(blocked_by)))
		var message := str(refusal.get("message", "Action unavailable."))
		reasons.append("" if allowed or positional else message)
		hints.append(message if positional else "")
	var slotted := _update_hotbar(actions, ready, in_kit)
	var spare: Array[int] = []
	var locked: Array[int] = []
	# Nobody arms a command while the demo plays itself (item 33: AI vs AI).
	var armed := &"" if _watching() else _armed_action_id()
	for i in _action_buttons.size():
		var button := _action_buttons[i]
		if not offered[i]:
			button.disabled = true
			button.visible = false
			_slot_keys[i].visible = false
			_cards[i] = {}
			continue
		var reason := reasons[i]
		var forecast := (
			Battle.action_forecast(actions[i])
			if actions[i].kind == CombatAction.Kind.CAST and reason.is_empty() and hints[i].is_empty()
			else {}
		)
		button.disabled = not ready[i]
		button.tooltip_text = ""
		button.text = _tile_caption(actions[i], reason)
		var slot := slotted.find(i)
		_slot_keys[i].visible = slot >= 0
		_slot_keys[i].text = str(slot + 1)
		_slot_keys[i].theme_type_variation = "HudTileKey" if ready[i] else "HudTileKeyDim"
		_tile_costs[i].text = "%d AP" % actions[i].ap_cost
		_cards[i] = _card_for(actions[i], reason, hints[i], forecast, slot)
		button.theme_type_variation = (
			"HudCommandTileArmed" if actions[i].id == armed and ready[i] else "HudCommandTile"
		)
		if slot >= 0:
			_place_action(i, _actions_box)
		elif ready[i]:
			_place_action(i, _spare_box)
			spare.append(i)
		else:
			_place_action(i, _locked_box)
			locked.append(i)
		button.visible = slot >= 0 or _show_all
	for slot: int in slotted.size():
		_actions_box.move_child(_action_buttons[slotted[slot]], slot)
	for place: int in spare.size():
		_spare_box.move_child(_action_buttons[spare[place]], place)
	for place: int in locked.size():
		_locked_box.move_child(_action_buttons[locked[place]], place)
	if _card_source != null and (not _card_source.is_visible_in_tree()):
		_hide_card(_card_source)
	elif _card_source != null:
		_show_card(_card_source)
	var off_bar := spare.size() + locked.size()
	_locked_count = off_bar
	_spare_box.visible = _show_all and not spare.is_empty()
	_locked_box.visible = _show_all and not locked.is_empty()
	_more_button.visible = (off_bar > 0 or _show_all) and not outcome_shown()
	# The count is what MORE adds that can be used now; locked commands wait inside it with
	# their reasons but are not a promise ("MORE · 50" counted every locked one).
	if _show_all:
		_more_button.text = tr("LESS")
	elif spare.is_empty():
		_more_button.text = tr("MORE")
	else:
		_more_button.text = tr("MORE · %d") % spare.size()

	# Autoplay (owner 2026-11-02, AI vs AI): the bar shows the acting unit's kit, but the
	# player has no orders to give, so nothing on it can be pressed.
	var watching := _watching()
	if watching:
		for button: Button in _action_buttons:
			button.disabled = true
		_more_button.visible = false
		_end_turn_button.disabled = true
		_withdraw_button.disabled = true
	var target := Battle.current_target()
	_target_button.visible = Battle.living_enemies().size() > 1 and not outcome_shown() and not watching
	_target_button.disabled = Battle.living_enemies().size() <= 1

	if is_instance_valid(_interface):
		var forecast_ctx := Battle.forecast_context()
		if not forecast_ctx.is_empty():
			_interface.set_forecast_context(forecast_ctx)
		_breakdown_button.set_pressed_no_signal(_interface.breakdown_visible())


## A slotted command sits on the hotbar; a usable unslotted one in MORE's flow; a locked one
## in MORE's locked flow, dimmed, its reason on the hover card. The tile is the same node
## everywhere, so its wiring never changes. `_refresh` orders the flows afterwards.
func _place_action(index: int, home: Container) -> void:
	var button := _action_buttons[index]
	if button.get_parent() == home:
		return
	button.get_parent().remove_child(button)
	home.add_child(button)


# --- hotbar (owner 2026-11-01: eight slots, auto-filled, keys 1–8) ---------------------------


## The showing member's slots for this refresh, as catalog indices in slot order. Slots stick
## for the battle, so a key always fires the same command: a slotted command keeps its slot
## while it is in the member's kit, dimmed when momentarily locked. Empty slots fill by role
## (`_default_fill`); a resolution, Defining Strike or parley that opens up joins on its own.
func _update_hotbar(
	actions: Array[CombatAction], ready: Array[bool], in_kit: Array[bool]
) -> Array[int]:
	var ally := Battle.current_ally()
	if ally != null:
		_hotbar_owner = ally.combat_id
	var count := mini(actions.size(), ready.size())
	var index_of: Dictionary = {}
	for i: int in count:
		index_of[actions[i].id] = i
	var slots: Array[StringName] = []
	for id: StringName in hotbar_ids():
		var i := int(index_of.get(id, -1))
		if i >= 0 and in_kit[i]:
			slots.append(id)
	if ally != null:
		slots.append_array(_default_fill(actions.slice(0, count), ready, in_kit, slots))
	_slots[_hotbar_owner] = slots
	if ally != null:
		# Commands surfacing together protect each other, so two openers never trade one slot
		# back and forth between refreshes.
		var surfacing: Array[StringName] = []
		for i: int in count:
			if ready[i] and _always_surfaces(actions[i]):
				surfacing.append(actions[i].id)
		for id: StringName in surfacing:
			_promote(_hotbar_owner, id, surfacing)
		slots = hotbar_ids()
	var indices: Array[int] = []
	for id: StringName in slots:
		indices.append(int(index_of[id]))
	return indices


## Fills the open slots: Strike, Guard, the class signature and Defining Strike, then the two
## cheapest usable weapon arts and the two cheapest usable spells; any slot still open takes
## the cheapest usable command left. Strike and the signature hold their slot while locked
## (out of reach, nothing banked yet); every other role needs a command usable now.
func _default_fill(
	actions: Array[CombatAction], ready: Array[bool], in_kit: Array[bool], taken: Array[StringName]
) -> Array[StringName]:
	var picked: Array[StringName] = []
	var room := HOTBAR_SIZE - taken.size()
	if room <= 0:
		return picked
	var filled: Dictionary = {}
	var candidates: Array[int] = []
	for i: int in actions.size():
		if taken.has(actions[i].id):
			var role := _slot_role(actions[i])
			filled[role] = int(filled.get(role, 0)) + 1
		elif in_kit[i]:
			candidates.append(i)
	candidates.sort_custom(func(a: int, b: int) -> bool:
		var role_a := _slot_role(actions[a])
		var role_b := _slot_role(actions[b])
		if role_a != role_b:
			return role_a < role_b
		if actions[a].ap_cost != actions[b].ap_cost:
			return actions[a].ap_cost < actions[b].ap_cost
		return a < b
	)
	for i: int in candidates:
		if picked.size() >= room:
			return picked
		var role := _slot_role(actions[i])
		if int(filled.get(role, 0)) >= int(ROLE_QUOTA.get(role, 0)):
			continue
		if not ready[i] and role != SlotRole.STRIKE and role != SlotRole.SIGNATURE:
			continue
		picked.append(actions[i].id)
		filled[role] = int(filled.get(role, 0)) + 1
	candidates.sort_custom(func(a: int, b: int) -> bool:
		if actions[a].ap_cost != actions[b].ap_cost:
			return actions[a].ap_cost < actions[b].ap_cost
		return a < b
	)
	for i: int in candidates:
		if picked.size() >= room:
			break
		if ready[i] and not picked.has(actions[i].id):
			picked.append(actions[i].id)
	return picked


static func _slot_role(action: CombatAction) -> SlotRole:
	if action.id == Battle.ACTION_STRIKE:
		return SlotRole.STRIKE
	if action.kind == CombatAction.Kind.GUARD:
		return SlotRole.GUARD
	if not action.class_resource_action.is_empty():
		return SlotRole.SIGNATURE
	if action.kind == CombatAction.Kind.DEFINING_STRIKE:
		return SlotRole.DEFINING
	if action.spell:
		return SlotRole.SPELL
	if action.kind == CombatAction.Kind.ATTACK:
		return SlotRole.WEAPON_ART
	return SlotRole.OTHER


## Commands that open up mid-fight and must never hide behind MORE.
static func _always_surfaces(action: CombatAction) -> bool:
	return (
		action.kind == CombatAction.Kind.RESOLUTION
		or action.kind == CombatAction.Kind.DEFINING_STRIKE
		or action.id == Battle.ACTION_SPEECH
	)


## A command chosen from MORE joins the bar: an open slot if there is one, else the slot its
## member used least this battle (ties: the later slot). Slot 1 is never given up, nor is a
## `protected` command.
func _promote(
	owner: StringName, action_id: StringName, protected: Array[StringName] = []
) -> void:
	var slots: Array[StringName] = []
	for id: Variant in _slots.get(owner, []):
		slots.append(StringName(id))
	if slots.has(action_id):
		return
	if slots.size() < HOTBAR_SIZE:
		slots.append(action_id)
	else:
		var tally: Dictionary = _uses.get(owner, {})
		var evict := -1
		for slot: int in range(slots.size() - 1, 0, -1):
			if protected.has(slots[slot]):
				continue
			if evict < 0 or int(tally.get(slots[slot], 0)) < int(tally.get(slots[evict], 0)):
				evict = slot
		if evict < 0:
			return
		slots[evict] = action_id
	_slots[owner] = slots


func _note_use(action_id: StringName) -> void:
	var ally := Battle.current_ally()
	if ally == null:
		return
	var tally: Dictionary = _uses.get(ally.combat_id, {})
	tally[action_id] = int(tally.get(action_id, 0)) + 1
	_uses[ally.combat_id] = tally
	_hotbar_owner = ally.combat_id
	if not hotbar_ids().has(action_id):
		_promote(ally.combat_id, action_id)
		_queue_refresh()


func _battlefield_has_cells() -> bool:
	if Battle.controller == null or Battle.controller.battlefield == null:
		return false
	return bool(Battle.controller.battlefield.capabilities().get("cells", false))


## #473: the actor rows of the snapshot the field currently presents, by combat id. Empty
## before the first presented event; callers then fall back to the live actor.
func _presented_rows() -> Dictionary:
	var rows: Dictionary = {}
	if not is_instance_valid(_interface):
		return rows
	var event := _interface.stage.presented_event()
	if event == null:
		return rows
	var snapshot: Dictionary = event.data.get("snapshot", {})
	for side: String in ["allies", "enemies"]:
		for row: Variant in snapshot.get(side, []):
			if row is Dictionary:
				rows[StringName(str((row as Dictionary).get("id", "")))] = row
	return rows


## HP as the field presents it: the presented snapshot's row, else the live actor.
func _presented_hp(actor: BattleActor, rows: Dictionary) -> Vector2i:
	var row: Dictionary = rows.get(actor.combat_id, {})
	if row.is_empty():
		return Vector2i(actor.hp, actor.max_hp)
	return Vector2i(int(row.get("hp", actor.hp)), int(row.get("max_hp", actor.max_hp)))


func _update_enemy_status() -> void:
	var target := Battle.current_target()
	if target == null:
		_enemy_lbl.text = "FOE  —"
		return
	var hp := _presented_hp(target, _presented_rows())
	_enemy_lbl.text = "FOE  %s  ·  HP %d / %d" % [target.display_name.to_upper(), hp.x, hp.y]


## One slim entry per ally — marker, name and HP on one line, a thin meter under it; the bar
## is a readout, not a card stack, and the unit plate carries the active member's detail.
## Owner 2026-11-02 (item 33 follow-up, "the screen is very busy"): a full party of five on
## two lines each overflowed the bar upward over the map, so each member is one line now.
## Entry children: [0] the HP row (marker, name, HP label), [1] the meter.
func _update_party_status() -> void:
	for child in _party_box.get_children():
		child.free()
	# Alone, the column would repeat the unit plate; it shows once there is company.
	var party_column := _party_box.get_parent() as Control
	party_column.visible = Battle.allies.size() > 1
	var rule := party_column.get_parent().get_child(party_column.get_index() - 1) as Control
	if rule is VSeparator:
		rule.visible = party_column.visible
	var rows := _presented_rows()
	for actor in Battle.allies:
		var hp_now := _presented_hp(actor, rows)
		var entry := VBoxContainer.new()
		entry.theme_type_variation = "BattleTightColumn"
		_party_box.add_child(entry)
		var hp_row := HBoxContainer.new()
		hp_row.name = "HPRow"
		hp_row.theme_type_variation = "BattlePartyRow"
		entry.add_child(hp_row)
		var marker := Label.new()
		marker.text = "▶" if actor == Battle.current_ally() and hp_now.x > 0 else "·"
		marker.custom_minimum_size = Vector2(12, 0)
		marker.theme_type_variation = "EyebrowLabel"
		hp_row.add_child(marker)
		var name_label := Label.new()
		name_label.name = "Name"
		name_label.text = actor.display_name.to_upper()
		if hp_now.x <= 0:
			name_label.text += "  ·  FALLEN"
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_label.tooltip_text = name_label.text
		name_label.mouse_filter = Control.MOUSE_FILTER_PASS
		name_label.theme_type_variation = "StatLabel"
		hp_row.add_child(name_label)
		var hp := Label.new()
		hp.name = "HP"
		hp.text = "HP %d / %d" % [hp_now.x, hp_now.y]
		hp.theme_type_variation = "StatLabel"
		hp_row.add_child(hp)
		var bar := _make_meter()
		bar.name = "Meter"
		bar.max_value = hp_now.y
		bar.value = hp_now.x
		bar.custom_minimum_size = Vector2(0, 3)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		entry.add_child(bar)


## AP round economy: every command tile surfaces its AP cost (ratified
## `docs/fallout2-adoption-spec.md` Wave 1) on its badge and its card — this is the shipped
## scheduler's live cost display, not a Gate T-10 compatibility remnant.
func _tile_caption(action: CombatAction, reason: String = "") -> String:
	var caption := action.display_name.to_upper()
	if not reason.is_empty() and action.kind == CombatAction.Kind.RESOLUTION:
		caption += " · LOCKED"
	return caption


## The hover card's content for one command: name; costs; target, reach, tone and key; the
## effect; and why it is locked, or how to use it when the selected foe is out of reach.
func _card_for(
	action: CombatAction, reason: String, hint: String, forecast: Dictionary, slot: int
) -> Dictionary:
	var stats := PackedStringArray(["%d AP" % action.ap_cost])
	if action.kind == CombatAction.Kind.CAST and not forecast.is_empty():
		stats.append(tr("Breath %d") % int(forecast.get("breath_cost", 0)))
		stats.append(tr("Soul %d") % int(forecast.get("soul_cost", 0.0)))
		var tone_relief := float(forecast.get("fizzle_tone_relief", 0.0))
		if tone_relief > 0.0:
			# SR9: a held Tone's share of the chance, shown as its own step.
			stats.append(
				tr("Fizzle %.0f%% (Resonance %.0f%% → −%.0f)") % [
					float(forecast.get("fizzle_percent", 0.0)),
					float(forecast.get("fizzle_resonance", 0.0)),
					tone_relief,
				]
			)
		else:
			stats.append(tr("Fizzle %.0f%%") % float(forecast.get("fizzle_percent", 0.0)))
	else:
		if action.breath_cost > 0:
			stats.append(tr("Breath %d") % action.breath_cost)
		if action.soul_cost > 0.0:
			stats.append(tr("Soul %d") % int(action.soul_cost))
	var reach := PackedStringArray([action.target_text()])
	if not action.reach_text().is_empty():
		reach.append(action.reach_text())
	var tone := _tone_name(action.element_id)
	if not tone.is_empty():
		reach.append(tr("tone %s") % tone)
	if slot >= 0:
		reach.append(tr("key %d") % (slot + 1))
	return {
		"title": action.display_name,
		"stats": "  ·  ".join(stats),
		"reach": "  ·  ".join(reach),
		"effect": action.effect_text(),
		"lock": reason,
		"hint": "" if hint.is_empty() else tr("%s Click a foe on the field: out of reach, the unit walks in first.") % hint,
	}


static func _tone_name(element_id: StringName) -> String:
	for tone: Dictionary in DS.WHEEL:
		if tone["id"] == String(element_id):
			return str(tone["name"])
	return ""


## The command a click on the field will use (the interface's armed pointer action).
func _armed_action_id() -> StringName:
	return _interface.selected_pointer_action() if is_instance_valid(_interface) else &""


# --- the hover card (owner 2026-11-02, item 33 follow-up) -----------------------------------


func _build_command_card() -> void:
	_command_card = PanelContainer.new()
	_command_card.name = "CommandCard"
	_command_card.theme_type_variation = "HudCommandCard"
	_command_card.top_level = true
	_command_card.visible = false
	_command_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_command_card.custom_minimum_size = Vector2(CARD_WIDTH, 0)
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_command_card.add_child(column)
	_card_title = _card_label(column, "HudCardTitle")
	_card_stats = _card_label(column, "HudCardStats")
	_card_reach = _card_label(column, "HudCardReach")
	_card_effect = _card_label(column, "HudCardEffect")
	_card_lock = _card_label(column, "HudCardLock")
	_card_hint = _card_label(column, "HudCardHint")
	add_child(_command_card)


func _card_label(parent: Container, type_variation: String) -> Label:
	var label := Label.new()
	label.theme_type_variation = type_variation
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(CARD_WIDTH - DS.SPACE_5 * 2, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label


func _show_card(tile: Control) -> void:
	var index := int(tile.get_meta("index", -1))
	if index < 0 or index >= _cards.size() or _cards[index].is_empty():
		return
	var card: Dictionary = _cards[index]
	_card_source = tile
	_card_title.text = str(card["title"])
	_card_stats.text = str(card["stats"])
	_card_reach.text = str(card["reach"])
	_card_effect.text = str(card["effect"])
	_card_lock.text = str(card["lock"])
	_card_lock.visible = not _card_lock.text.is_empty()
	_card_hint.text = str(card["hint"])
	_card_hint.visible = not _card_hint.text.is_empty()
	_command_card.visible = true
	_command_card.reset_size()
	# The bar sits at the bottom of the screen, so the card opens above it, clear of the
	# bar's top edge (the field HUD's bar hosts this one).
	var rect := tile.get_global_rect()
	var card_size := _command_card.get_combined_minimum_size()
	var view := get_viewport_rect().size
	var ceiling := rect.position.y
	var host := get_parent_control()
	if host != null:
		ceiling = minf(ceiling, host.get_global_rect().position.y)
	var at := Vector2(rect.position.x, ceiling - card_size.y - DS.SPACE_4)
	if at.y < 0.0:
		at.y = rect.end.y + DS.SPACE_2
	at.x = clampf(at.x, 0.0, maxf(view.x - card_size.x, 0.0))
	_command_card.global_position = at


func _hide_card(tile: Control) -> void:
	if _command_card != null and tile == _card_source:
		_command_card.visible = false
		_card_source = null


## The card on screen, for tests and captures: {} when hidden.
func command_card_text() -> Dictionary:
	if _command_card == null or not _command_card.visible:
		return {}
	return {
		"title": _card_title.text, "stats": _card_stats.text, "reach": _card_reach.text,
		"effect": _card_effect.text, "lock": _card_lock.text if _card_lock.visible else "",
		"hint": _card_hint.text if _card_hint.visible else "",
	}


## A tile's card content for this refresh without hovering it (tests): {} when not offered.
func card_for_button(button: Button) -> Dictionary:
	var index := int(button.get_meta("index", -1))
	return _cards[index] if index >= 0 and index < _cards.size() else {}


func _balance_text() -> String:
	if Battle.balance <= -Battle.EXTREME_THRESHOLD:
		return "CHAOS  %d" % Battle.balance
	if Battle.balance >= Battle.EXTREME_THRESHOLD:
		return "ORDER  +%d" % Battle.balance
	return "CHAOS  ◀  %s  ▶  ORDER" % ("+%d" % Battle.balance if Battle.balance > 0 else str(Battle.balance))


# --- outcome -----------------------------------------------------------------------------


## The model resolves the finishing blow in the frame of the command; the field presents it
## over the next beats. The result is shown once the field has presented them (#473).
func _on_battle_ended(result: BattleResult) -> void:
	_refresh()
	_pending_result = result
	if is_instance_valid(_interface) and _interface.stage.is_presenting_beats():
		set_process(true)
		return
	_show_outcome()


func _process(_delta: float) -> void:
	if _pending_result == null:
		set_process(false)
		return
	if is_instance_valid(_interface) and _interface.stage.is_presenting_beats():
		return
	set_process(false)
	_refresh()
	_show_outcome()


func outcome_shown() -> bool:
	return is_instance_valid(_outcome_box) and _outcome_box.visible


func _show_outcome() -> void:
	var result := _pending_result
	_pending_result = null
	if result == null or outcome_shown():
		return
	_action_scroll.visible = false
	_aim_host.visible = false
	_target_button.visible = false
	_more_button.visible = false
	_end_turn_button.disabled = true
	_withdraw_button.disabled = true
	append_log(result.message)
	if not result.cause.is_empty():
		append_log(result.cause)
	_outcome_box.visible = true
	var outcome := Label.new()
	outcome.text = "ENCOUNTER RESOLVED"
	outcome.theme_type_variation = "EyebrowLabel"
	_outcome_box.add_child(outcome)
	var continue_button := _button(_outcome_box, "CONTINUE", _continue_after_battle.bind(result))
	continue_button.name = "ContinueButton"
	continue_button.custom_minimum_size = Vector2(220, 36)
	continue_button.theme_type_variation = "BronzeButton"


func _continue_after_battle(result: BattleResult) -> void:
	if not result.succeeded() or result.spoils.is_empty():
		GameFlow.send_event("battle_end")
		return
	var panel := UIManager.open(UIManager.LOOT_PANEL) as LootPanel
	panel.configure("BATTLE SPOILS", result.spoils)
	panel.dismissed.connect(
		func(_remaining: Array[Dictionary]) -> void: GameFlow.send_event("battle_end"),
		CONNECT_ONE_SHOT,
	)
