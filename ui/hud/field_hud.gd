extends CanvasLayer
## Field HUD — the bottom bar. Per the DS layout rules: pinned to the bottom edge with a
## 2px bronze top rule; the SoulGauge is always the rightmost element in it.
##
## U2 (owner 2026-11-02, docs/design/ui-rework-plan-2026-11-01.md):
##  - Key hints leave once learned: each hint hides after its key is first used, saved in
##    the settings file; Settings → Interface → "Control hints" brings the strip back.
##  - The party is a strip of portraits with HP and Breath meters, sized for six; a card's
##    numbers show while the pointer is over it.
##  - The objective is one line. "GO TO" appears only when the target is in another area.

## U1 (owner 2026-11-01): a conversation clears the stage. The balloon calls this through
## the group so the HUD bar, its second Soul gauge, the key hints and the notices step
## aside while it is open. It toggles the children, not the layer: combat hides the layer
## itself (world/field_map.gd), and a parley opened mid-fight must not bring it back.
const GROUP := &"field_hud"

const PartyMemberVisualsScript := preload("res://actors/party_followers/party_member_visuals.gd")

const SETTINGS_SECTION := "interface"
const SETTING_HINTS := "control_hints"
const SETTING_HINTS_USED := "control_hints_used"
## One hint per verb. A hint leaves the first time any of its actions is pressed.
const KEY_HINTS: Array[Dictionary] = [
	{"id": "move", "text": "WASD  MOVE", "actions": [&"move_left", &"move_right", &"move_up", &"move_down"]},
	{"id": "sprint", "text": "SHIFT  SPRINT", "actions": [&"sprint"]},
	{"id": "interact", "text": "E  INTERACT", "actions": [&"interact"]},
	{"id": "inventory", "text": "I  INVENTORY", "actions": [&"open_inventory"]},
	{"id": "party", "text": "P  PARTY", "actions": [&"open_party"]},
	{"id": "journal", "text": "Q  JOURNAL", "actions": [&"open_journal"]},
	{"id": "standing", "text": "R  STANDINGS", "actions": [&"open_standing"]},
	{"id": "pause", "text": "ESC  PAUSE", "actions": [&"ui_cancel"]},
]
## Six members fit beside the gauge at the 1920 design width.
const PARTY_CARD_WIDTH := 196.0
const PARTY_PORTRAIT_SIZE := 40.0

var _conversation_restore: Dictionary = {}
var _key_hints: HBoxContainer
var _objective: Label
var _party_strip: HBoxContainer
## The party as last drawn: ids, then HP/Breath per member. Rebuilt or refreshed on change.
var _party_ids: PackedStringArray = []
var _party_stats: PackedInt32Array = []


func set_conversation_open(open: bool) -> void:
	if open:
		if not _conversation_restore.is_empty():
			return
		for child: Node in get_children():
			if child is CanvasItem:
				_conversation_restore[child] = (child as CanvasItem).visible
				(child as CanvasItem).visible = false
		return
	for child: Variant in _conversation_restore.keys():
		if is_instance_valid(child):
			(child as CanvasItem).visible = bool(_conversation_restore[child])
	_conversation_restore.clear()


func _ready() -> void:
	add_to_group(GROUP)
	var bar: Control = $Bar
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
	# Objective over party strip; the right edge stays reserved for the SoulGauge.
	var column := VBoxContainer.new()
	column.name = "BarColumn"
	column.theme_type_variation = "HUDBarColumn"
	column.set_anchors_preset(Control.PRESET_FULL_RECT)
	column.offset_left = DS.SPACE_8
	column.offset_top = DS.BORDER_TRIM_W + DS.SPACE_3
	column.offset_right = -270.0
	column.offset_bottom = -DS.SPACE_2
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(column)
	_objective = Label.new()
	_objective.name = "Objective"
	_objective.theme_type_variation = "HUDObjectiveLabel"
	_objective.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_objective.clip_text = true
	_objective.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_objective)
	_party_strip = HBoxContainer.new()
	_party_strip.name = "PartyStrip"
	_party_strip.theme_type_variation = "HUDPartyStrip"
	_party_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_party_strip)

	_key_hints = HBoxContainer.new()
	_key_hints.name = "KeyHints"
	_key_hints.theme = UIManager.ui_theme
	_key_hints.theme_type_variation = "HUDKeyHints"
	_key_hints.position = Vector2(DS.SPACE_8, DS.SPACE_7)
	_key_hints.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for hint: Dictionary in KEY_HINTS:
		var label := Label.new()
		label.name = "Hint_%s" % hint["id"]
		label.text = str(hint["text"])
		label.theme_type_variation = "HUDKeyHint"
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_key_hints.add_child(label)
	add_child(_key_hints)
	refresh_key_hints()

	var autosave := Label.new()
	autosave.name = "AutosaveStatus"
	autosave.theme = UIManager.ui_theme
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
			_bind_quest(quest)
			_refresh_objective()
	)
	QuestSystem.quest_completed.connect(func(_quest: Quest) -> void: _refresh_objective())
	GameState.flag_changed.connect(func(_flag: String, _value: Variant) -> void: _refresh_objective())
	GameState.party_changed.connect(
		func() -> void:
			_refresh_objective()
			_refresh_party()
	)
	SaveGame.autosave_finished.connect(
		func(_reason: String, succeeded: bool) -> void:
			autosave.text = "AUTOSAVED" if succeeded else "AUTOSAVE FAILED"
			_fade_status(autosave)
	)
	for quest in QuestSystem.get_active_quests():
		_bind_quest(quest)
	_refresh_objective()
	_refresh_party()


func _process(_delta: float) -> void:
	# HP and Breath are plain fields with no signal; six members are cheap to compare.
	if _party_changed_since_draw():
		_refresh_party()


func _input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var used := _hints_used()
	var learned := false
	for hint: Dictionary in KEY_HINTS:
		if used.has(hint["id"]):
			continue
		for action: StringName in hint["actions"]:
			if InputMap.has_action(action) and event.is_action_pressed(action):
				used.append(hint["id"])
				learned = true
				break
	if learned:
		GameState.set_setting(SETTINGS_SECTION, SETTING_HINTS_USED, used)
		refresh_key_hints()


# --- key hints ---------------------------------------------------------------------------

## Re-reads the settings; Settings calls this through the group after its toggle.
func refresh_key_hints() -> void:
	if _key_hints == null:
		return
	var enabled := bool(GameState.get_setting(SETTINGS_SECTION, SETTING_HINTS, true))
	var used := _hints_used()
	for hint: Dictionary in KEY_HINTS:
		var label := _key_hints.get_node_or_null("Hint_%s" % hint["id"]) as Label
		if label != null:
			label.visible = enabled and not used.has(hint["id"])


## Settings → Interface → "Control hints": on brings every hint back, off hides them all.
static func set_control_hints(enabled: bool) -> void:
	GameState.set_setting(SETTINGS_SECTION, SETTING_HINTS, enabled)
	if enabled:
		GameState.set_setting(SETTINGS_SECTION, SETTING_HINTS_USED, [])


## The Settings toggle reads as on while any hint is still showing.
static func control_hints_showing() -> bool:
	if not bool(GameState.get_setting(SETTINGS_SECTION, SETTING_HINTS, true)):
		return false
	return _hints_used().size() < KEY_HINTS.size()


static func _hints_used() -> Array:
	var stored: Variant = GameState.get_setting(SETTINGS_SECTION, SETTING_HINTS_USED, [])
	var used: Array = []
	if stored is Array:
		for id: Variant in stored:
			used.append(str(id))
	return used


# --- objective -------------------------------------------------------------------------------

func _bind_quest(quest: Quest) -> void:
	if not quest.updated.is_connected(_refresh_objective):
		quest.updated.connect(_refresh_objective)


func _refresh_objective() -> void:
	if _objective == null:
		return
	var text := "%s  ·  %s" % [ChapterOneProgress.title(), ChapterOneProgress.objective()]
	var destination := ChapterOneProgress.destination()
	if not destination.is_empty() and not destination_is_here(destination, _area_here()):
		text += "  ·  GO TO  %s" % destination
	_objective.text = text
	_objective.tooltip_text = text


## "Trial Council Hall in Dom" is here when standing in Dom; "North Road → Dorthkor" is
## here on the Dorthkor Road. The place is the hint's last segment (after "→" or " in ").
static func destination_is_here(destination: String, area: String) -> bool:
	if area.is_empty():
		return false
	var place := destination.get_slice("→", destination.get_slice_count("→") - 1).strip_edges()
	var at := place.rfind(" in ")
	if at >= 0:
		place = place.substr(at + 4).strip_edges()
	place = place.to_lower()
	var here := area.to_lower()
	return not place.is_empty() and (place == here or here.contains(place) or place.contains(here))


func _area_here() -> String:
	var field := owner if owner != null else get_parent()
	return "" if field == null else LocationRegistry.area_name(field.scene_file_path)


# --- party strip -----------------------------------------------------------------------------

func _party_changed_since_draw() -> bool:
	var party := GameState.party
	if party.size() != _party_ids.size():
		return true
	for index: int in party.size():
		var member := party[index]
		if member == null or member.id != _party_ids[index]:
			return true
		var base := index * 4
		if (
			_party_stats[base] != member.hp or _party_stats[base + 1] != member.max_hp
			or _party_stats[base + 2] != member.breath or _party_stats[base + 3] != member.breath_max
		):
			return true
	return false


func _refresh_party() -> void:
	if _party_strip == null:
		return
	var ids := PackedStringArray()
	var stats := PackedInt32Array()
	for member: PartyMember in GameState.party:
		if member == null:
			continue
		ids.append(member.id)
		stats.append_array([member.hp, member.max_hp, member.breath, member.breath_max])
	if ids != _party_ids:
		# Freed now, not queued: a detached card waiting for the frame end is an orphan,
		# and nothing but the strip holds one.
		for child: Node in _party_strip.get_children():
			child.free()
		for member: PartyMember in GameState.party:
			if member != null:
				_party_strip.add_child(_party_card(member))
	var cards := _party_strip.get_children()
	var index := 0
	for member: PartyMember in GameState.party:
		if member == null or index >= cards.size():
			continue
		_update_card(cards[index], member)
		index += 1
	_party_ids = ids
	_party_stats = stats


func _party_card(member: PartyMember) -> Control:
	var card := HBoxContainer.new()
	card.name = "Member_%s" % member.id.validate_node_name()
	card.theme_type_variation = "HUDPartyCard"
	card.custom_minimum_size = Vector2(PARTY_CARD_WIDTH, 0)
	card.mouse_filter = Control.MOUSE_FILTER_PASS
	var frame := PanelContainer.new()
	frame.theme_type_variation = "HUDPortraitFrame"
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(frame)
	var portrait := TextureRect.new()
	portrait.name = "Portrait"
	portrait.custom_minimum_size = Vector2(PARTY_PORTRAIT_SIZE, PARTY_PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.texture = PartyMemberVisualsScript.bust_texture(member)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(portrait)
	var meters := VBoxContainer.new()
	meters.theme_type_variation = "HUDPartyMeters"
	meters.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meters.alignment = BoxContainer.ALIGNMENT_CENTER
	meters.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(meters)
	var name_label := Label.new()
	name_label.name = "Name"
	name_label.theme_type_variation = "HUDPartyName"
	name_label.text = member.display_name.to_upper()
	name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meters.add_child(name_label)
	var numbers := Label.new()
	numbers.name = "Numbers"
	numbers.theme_type_variation = "HUDPartyNumbers"
	numbers.visible = false
	numbers.clip_text = true
	numbers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meters.add_child(numbers)
	var hp := MeterBar.new()
	hp.name = "HP"
	hp.meter_size = MeterBar.MeterSize.SMALL
	meters.add_child(hp)
	var breath := MeterBar.new()
	breath.name = "Breath"
	breath.meter_size = MeterBar.MeterSize.SMALL
	breath.fill_start = DS.METER_BREATH_A
	breath.fill_end = DS.METER_BREATH_B
	meters.add_child(breath)
	card.mouse_entered.connect(_show_numbers.bind(card, true))
	card.mouse_exited.connect(_show_numbers.bind(card, false))
	return card


func _update_card(card: Node, member: PartyMember) -> void:
	(card.find_child("HP", true, false) as MeterBar).value = (
		float(member.hp) / float(maxi(1, member.max_hp))
	)
	(card.find_child("Breath", true, false) as MeterBar).value = (
		float(member.breath) / float(maxi(1, member.breath_max))
	)
	(card.find_child("Numbers", true, false) as Label).text = "HP %d/%d  ·  BR %d/%d" % [
		member.hp, member.max_hp, member.breath, member.breath_max
	]


## Hover swaps the name for the exact numbers on the same line, so nothing shifts.
func _show_numbers(card: Control, show: bool) -> void:
	if not is_instance_valid(card):
		return
	(card.find_child("Name", true, false) as Label).visible = not show
	(card.find_child("Numbers", true, false) as Label).visible = show


func _fade_status(label: Label) -> void:
	label.modulate.a = 1.0
	var tween := create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.5)
