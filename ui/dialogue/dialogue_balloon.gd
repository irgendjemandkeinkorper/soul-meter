extends CanvasLayer
## The Soul Meter dialogue balloon (DS: ui_kits/dialogue — "the Echo Gate").
## Registered as Dialogue Manager's runtime balloon. U1 (owner 2026-11-01,
## docs/design/ui-rework-plan-2026-11-01.md) lays it out as one block anchored to the
## bottom of the screen, over a soft scrim, with the field HUD and world labels cleared:
##   Left:   speaker Portrait (element-ringed).
##   Right:  the SoulGauge (the only one on screen: the player must always see what a line
##           costs), the spoken line in a bronze-trimmed panel, the ledger strip (what the
##           last choice just wrote), the choice stack (max width 860), and the promise line
##           (the focused choice's [#consequence]).
##
## Choice metadata: [#tag=REGISTRY] [#consequence=The Ledger will hold your name.]
## [#lock=show|hide]. Effects and check odds are NOT authored: DialogueChoiceInfo reads the
## branch's own leading `do` mutations (Reputation.record, Renown.gain_*,
## GameState.set_soul_meter, SkillCheck.resolve), so the row and the ledger always agree.
## A legacy [#cost=...] tag is shown only when no Soul mutation can be read.

const DialogueChoiceScript := preload("res://ui/dialogue/dialogue_choice.gd")
const PortraitScript := preload("res://ui/dialogue/portrait.gd")
const NpcRosterScript := preload("res://globals/npc_roster.gd")
const SOUL_GAUGE := preload("res://ui/hud/soul_gauge.tscn")
const GROUP := &"dialogue_balloon"
## Choices beyond this share of the screen scroll instead of pushing the block off the top.
const MAX_CHOICES_HEIGHT_RATIO := 0.42
const CONTENT_MAX_WIDTH := 860.0

## Speaker registry: dialogue `character` name -> portrait config.
## The element is the character's ATTUNEMENT (rings the portrait). Grows with the cast;
## later this generates from Pandora NPCs.
const SPEAKERS := {
	"Iris Illepah": {
		"subtitle": "Ssae-Seeder of the Groves",
		"element": "mozh",
		"portrait_id": "iris-illepah",
		"portrait_path":
		"res://assets/generated/portraits/iris_illepah_portrait_neutral.png",
	},
	"Marshal Coiljaw": {"subtitle": "the Road-Bench", "element": ""},
	"Sella Varn": {"subtitle": "Bell Warden of the Lower Ward", "element": "zhur"},
	"Hadrik Vale": {"subtitle": "Registry Archive Clerk", "element": "zhem"},
	"Toma Reedhand": {"subtitle": "Dockhand and Shrine-Keeper", "element": "luth"},
}

var dialogue_resource: DialogueResource
var dialogue_line: DialogueLine
var _root: Control
var _block: HBoxContainer
var _portrait: SMPortrait
var _line_label: RichTextLabel
var _ledger_label: Label
var _choices_box: VBoxContainer
var _choices_scroll: ScrollContainer
var _promise_label: Label
var _content: VBoxContainer
var _continue_hint: Label
var _is_waiting_for_input := false
## Bumped per line so an older line's awaited choice checks cannot paint over a newer one.
var _line_serial := 0
## Ledger writes since the last choice, shown on the next line. Each entry is
## {"kind", "delta", "faction"?, "event"?}.
var _ledger_entries: Array[Dictionary] = []
var _soul_seen := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8  # under UIManager (10) so pause still stacks above dialogue
	add_to_group(GROUP)
	_build_ui()
	_soul_seen = GameState.soul_meter
	Reputation.reputation_changed.connect(_on_reputation_changed)
	Renown.renown_changed.connect(_on_renown_changed)
	GameState.soul_meter_changed.connect(_on_soul_meter_changed)
	get_tree().call_group(&"field_hud", &"set_conversation_open", true)
	get_tree().call_group(&"field_map", &"set_world_labels_muted", true)
	get_tree().paused = true


func _exit_tree() -> void:
	if Reputation.reputation_changed.is_connected(_on_reputation_changed):
		Reputation.reputation_changed.disconnect(_on_reputation_changed)
	if Renown.renown_changed.is_connected(_on_renown_changed):
		Renown.renown_changed.disconnect(_on_renown_changed)
	if GameState.soul_meter_changed.is_connected(_on_soul_meter_changed):
		GameState.soul_meter_changed.disconnect(_on_soul_meter_changed)
	# A conversation that opens before this one leaves keeps the stage clear.
	if not _another_balloon_open():
		get_tree().call_group(&"field_hud", &"set_conversation_open", false)
		get_tree().call_group(&"field_map", &"set_world_labels_muted", false)
	get_tree().paused = false
	GameFlow.notify_dialogue_closed()


func _another_balloon_open() -> bool:
	for node: Node in get_tree().get_nodes_in_group(GROUP):
		if node != self and not node.is_queued_for_deletion():
			return true
	return false


## Dialogue Manager entry point.
func start(
	with_resource: DialogueResource, cue: String = "", extra_game_states: Array = []
) -> void:
	dialogue_resource = with_resource
	_next(cue if not cue.is_empty() else "start", extra_game_states)


func _next(id: String, extra_states: Array = []) -> void:
	dialogue_line = await dialogue_resource.get_next_dialogue_line(id, extra_states)
	if dialogue_line == null:
		queue_free()
		return
	await _apply_line()


func _apply_line() -> void:
	_line_serial += 1
	var serial := _line_serial
	var line := dialogue_line
	# speaker
	var who := line.character
	var roster_row := NpcRosterScript.by_display_name(who)
	var cfg: Dictionary = SPEAKERS.get(who, {})
	if not roster_row.is_empty():
		var portrait: Dictionary = roster_row.get("portrait", {})
		cfg = {
			"subtitle": roster_row.get("role", ""),
			"portrait_id": portrait.get("id", roster_row.get("id", "")),
			"portrait_path": portrait.get("asset_path", ""),
		}
	_portrait.character_name = who
	_portrait.subtitle = cfg.get("subtitle", "")
	_portrait.element = cfg.get("element", "")
	_portrait.portrait_id = cfg.get("portrait_id", "")
	_portrait.portrait_path = cfg.get("portrait_path", "")

	# the spoken line (Cormorant body at fs-500)
	_line_label.text = line.text
	_show_ledger()

	# choices
	for child in _choices_box.get_children():
		child.queue_free()
	_promise_label.text = ""
	_is_waiting_for_input = line.responses.is_empty()
	_continue_hint.visible = true
	_continue_hint.text = (
		"CONTINUE  ·  ESC CLOSE" if _is_waiting_for_input else "SELECT  ·  ESC CLOSE"
	)
	var rows: Array[SMDialogueChoice] = []
	for response in line.responses:
		var shown: Dictionary = await DialogueChoiceInfo.visibility(dialogue_resource, response)
		if serial != _line_serial or not is_inside_tree():
			return
		if not bool(shown["visible"]):
			continue
		rows.append(_choice_for(response, bool(shown["locked"]), shown["reasons"]))
	for choice: SMDialogueChoice in rows:
		_choices_box.add_child(choice)
	_choices_scroll.visible = not rows.is_empty()
	_promise_label.visible = not rows.is_empty()
	_fit_choices.call_deferred()
	# focus the first selectable choice (gamepad rule: grab_focus on entry)
	for choice: SMDialogueChoice in rows:
		if not choice.disabled:
			choice.grab_focus.call_deferred()
			break


func _choice_for(response: DialogueResponse, locked: bool, reasons: PackedStringArray) -> SMDialogueChoice:
	var found := DialogueChoiceInfo.effects(dialogue_resource, response)
	var effects_text := DialogueChoiceInfo.chips_text(found)
	var legacy_cost := _tag_value(response.tags, "cost")
	if not legacy_cost.is_empty() and not _has_kind(found, &"soul"):
		effects_text = legacy_cost.to_upper() if effects_text.is_empty() else (
			"%s  ·  %s" % [legacy_cost.to_upper(), effects_text]
		)
	var skill := DialogueChoiceInfo.check_skill(dialogue_resource, response)
	var tag := _tag_value(response.tags, "tag")
	if tag.is_empty() and not skill.is_empty():
		tag = DialogueChoiceInfo.skill_label(skill)
	var chance := -1 if (locked or skill.is_empty()) else DialogueChoiceInfo.odds(skill)
	var choice: SMDialogueChoice = DialogueChoiceScript.new()
	choice.setup(
		response.text,
		tag,
		effects_text,
		_tag_value(response.tags, "consequence"),
		locked,
		chance,
		"  ".join(reasons),
	)
	choice.pressed.connect(_on_choice.bind(response))
	choice.hot_changed.connect(_on_choice_hot.bind(choice))
	return choice


func _on_choice(response: DialogueResponse) -> void:
	_ledger_entries.clear()
	_next(response.next_id)


func _on_choice_hot(hot: bool, choice: SMDialogueChoice) -> void:
	if hot:
		_promise_label.text = choice.consequence
	elif _promise_label.text == choice.consequence:
		_promise_label.text = ""


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		queue_free()
	elif (
		_is_waiting_for_input
		and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"))
	):
		get_viewport().set_input_as_handled()
		_ledger_entries.clear()
		_next(dialogue_line.next_id)


static func _tag_value(tags: PackedStringArray, key: String) -> String:
	return DialogueChoiceInfo.tag_value(tags, key)


static func _has_kind(found: Array[Dictionary], kind: StringName) -> bool:
	for effect: Dictionary in found:
		if effect["kind"] == kind:
			return true
	return false


# --- the ledger strip -------------------------------------------------------------------------

func _on_reputation_changed(faction: String, _standing: float, event: ReputationEvent) -> void:
	_ledger_entries.append({
		"kind": &"faction", "faction": faction, "delta": event.delta if event != null else 0.0,
		"event": event,
	})


func _on_renown_changed(kind: StringName, _total: float, event: RenownEvent) -> void:
	var shown_kind: StringName = {&"reputation": &"renown", &"infamy": &"infamy"}.get(kind, &"")
	if shown_kind == &"":
		# Karma has no number on screen anywhere: the strip leaves it alone, so the field
		# notice still tells it after the conversation, exactly as before U1.
		return
	_ledger_entries.append({
		"kind": shown_kind, "delta": event.delta if event != null else 0.0, "event": event,
	})


func _on_soul_meter_changed(value: float) -> void:
	var delta := value - _soul_seen
	_soul_seen = value
	if not is_zero_approx(delta):
		_ledger_entries.append({"kind": &"soul", "delta": delta})


## Shows what the last choice wrote, on the reply it led to; marks those ledger events so
## the field notices do not repeat them when the conversation closes.
func _show_ledger() -> void:
	var shown: Array[Dictionary] = []
	for entry: Dictionary in _ledger_entries:
		if entry.has("event"):
			DialogueLedgerEcho.mark(entry["event"])
		if entry["kind"] != &"":
			shown.append(entry)
	var chips := DialogueChoiceInfo.chips_text(shown)
	_ledger_label.text = "" if chips.is_empty() else "%s  ·  %s" % [tr("RECORDED"), chips]
	_ledger_label.visible = not chips.is_empty()
	_ledger_entries.clear()


func ledger_text() -> String:
	return _ledger_label.text if _ledger_label.visible else ""


# --- layout (the Echo Gate) ---------------------------------------------------

func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIManager.ui_theme
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	# A soft scrim: clear where the block's top usually sits, settling to near-black at
	# the bottom edge, so the world reads above the conversation and the text holds below.
	var gradient := Gradient.new()
	gradient.set_offset(0, 0.0)
	gradient.set_color(0, Color(DS.VOID_0, 0.0))
	gradient.set_offset(1, 1.0)
	gradient.set_color(1, Color(DS.VOID_0, 0.9))
	gradient.add_point(0.4, Color(DS.VOID_0, 0.7))
	var scrim_texture := GradientTexture2D.new()
	scrim_texture.gradient = gradient
	scrim_texture.fill_from = Vector2(0.0, 0.0)
	scrim_texture.fill_to = Vector2(0.0, 1.0)
	scrim_texture.width = 4
	scrim_texture.height = 256
	var scrim := TextureRect.new()
	scrim.name = "Scrim"
	scrim.texture = scrim_texture
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrim.anchor_top = 0.3
	_root.add_child(scrim)

	_block = HBoxContainer.new()
	_block.name = "ConversationBlock"
	_block.theme_type_variation = "DialogueBlock"
	_block.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_block.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_block.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_block.offset_bottom = -DS.SPACE_9
	_root.add_child(_block)

	_portrait = PortraitScript.new()
	_portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_block.add_child(_portrait)

	_content = VBoxContainer.new()
	_content.name = "Column"
	_content.theme_type_variation = "DialogueColumn"
	_block.add_child(_content)

	var gauge_row := HBoxContainer.new()
	_content.add_child(gauge_row)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gauge_row.add_child(spacer)
	var gauge := SOUL_GAUGE.instantiate()
	gauge.custom_minimum_size = Vector2(220, 42)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_END
	gauge_row.add_child(gauge)

	# the spoken line, bronze-trimmed panel
	var line_panel := PanelContainer.new()
	line_panel.theme_type_variation = "DialogueLinePanel"
	line_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(line_panel)
	_line_label = RichTextLabel.new()
	_line_label.bbcode_enabled = false
	_line_label.fit_content = true
	_line_label.scroll_active = false
	_line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_line_label.add_theme_font_size_override("normal_font_size", DS.FS_500)
	line_panel.add_child(_line_label)

	# what the last choice wrote · the continue/select hint
	var status_row := HBoxContainer.new()
	_content.add_child(status_row)
	_ledger_label = Label.new()
	_ledger_label.name = "Ledger"
	_ledger_label.theme_type_variation = "DialogueLedgerLabel"
	_ledger_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ledger_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_ledger_label.visible = false
	status_row.add_child(_ledger_label)
	var status_spacer := Control.new()
	status_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(status_spacer)
	_continue_hint = Label.new()
	_continue_hint.text = "CONTINUE"
	_continue_hint.theme_type_variation = "EyebrowLabel"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status_row.add_child(_continue_hint)

	# the choice stack
	_choices_scroll = ScrollContainer.new()
	_choices_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_choices_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_child(_choices_scroll)
	_choices_box = VBoxContainer.new()
	_choices_box.theme_type_variation = "DialogueChoiceList"
	_choices_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_choices_scroll.add_child(_choices_box)
	# Rows settle their wrapped height a frame after they enter; refit when they do.
	_choices_box.minimum_size_changed.connect(_fit_choices)

	# the focused choice's promise ([#consequence]) — one line, never one per row
	_promise_label = Label.new()
	_promise_label.name = "Promise"
	_promise_label.theme_type_variation = "DialoguePromiseLabel"
	_promise_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_promise_label.custom_minimum_size.y = DS.FS_500 * 1.4
	_content.add_child(_promise_label)

	# Keep the content capped on a wide monitor while allowing it to shrink with
	# the window. This is also reapplied when the player resizes the window.
	_update_content_width()
	_root.resized.connect(_update_content_width)


func _update_content_width() -> void:
	if _content == null or _root == null:
		return
	var portrait_width := _portrait.get_combined_minimum_size().x if _portrait != null else 0.0
	var available_width := maxf(320.0, _root.size.x - 48.0 - portrait_width - DS.SPACE_8)
	_content.custom_minimum_size.x = minf(CONTENT_MAX_WIDTH, available_width)
	_fit_choices()


## Choices take their natural height up to a share of the screen, then scroll; the block
## grows upward from the bottom edge, so it never runs under the bottom or off the top.
func _fit_choices() -> void:
	if _choices_scroll == null or _root == null or not is_inside_tree():
		return
	var wanted := _choices_box.get_combined_minimum_size().y
	var cap := _root.size.y * MAX_CHOICES_HEIGHT_RATIO
	_choices_scroll.custom_minimum_size.y = minf(wanted, cap)
