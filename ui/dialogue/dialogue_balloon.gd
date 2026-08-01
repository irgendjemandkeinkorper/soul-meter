extends CanvasLayer
## The Soul Meter dialogue balloon (DS: ui_kits/dialogue — "the Echo Gate").
## Registered as Dialogue Manager's runtime balloon. Three stacked rows:
##   Top:    speaker Portrait (element-ringed) left · SoulGauge right — the player must
##           always be able to see what a line of dialogue costs.
##   Middle: the spoken line in a bronze-trimmed panel, fs-500/1.6.
##   Bottom: DialogueChoice stack, max width 860, gap space-3. Locked choices visible+dim.
##
## Choice metadata rides on Dialogue Manager response tags:
##   [#tag=REGISTRY] [#cost=-4 soul] [#consequence=The Ledger will hold your name.]
## Consequences are enacted by `do ...` mutations in the .dialogue file (Reputation.record,
## GameState.set_soul_meter) — the balloon renders promises; the dialogue file keeps them.

const DialogueChoiceScript := preload("res://ui/dialogue/dialogue_choice.gd")
const PortraitScript := preload("res://ui/dialogue/portrait.gd")
const SOUL_GAUGE := preload("res://ui/hud/soul_gauge.tscn")

## Speaker registry: dialogue `character` name -> portrait config.
## The element is the character's ATTUNEMENT (rings the portrait). Grows with the cast;
## later this generates from Pandora NPCs.
const SPEAKERS := {
	"Iris Illepah": {"subtitle": "Ssae-Seeder of the Groves", "element": "molm"},
	"Marshal Coiljaw": {"subtitle": "the Road-Bench", "element": ""},
}

var dialogue_resource: DialogueResource
var dialogue_line: DialogueLine
var _root: Control
var _portrait: SMPortrait
var _line_label: RichTextLabel
var _choices_box: VBoxContainer
var _continue_hint: Label
var _is_waiting_for_input := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 8  # under UIManager (10) so pause still stacks above dialogue
	_build_ui()
	get_tree().paused = true


func _exit_tree() -> void:
	get_tree().paused = false
	GameFlow.notify_dialogue_closed()


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
	_apply_line()


func _apply_line() -> void:
	# speaker
	var who := dialogue_line.character
	var cfg: Dictionary = SPEAKERS.get(who, {})
	_portrait.character_name = who
	_portrait.subtitle = cfg.get("subtitle", "")
	_portrait.element = cfg.get("element", "")

	# the spoken line (Cormorant body at fs-500)
	_line_label.text = dialogue_line.text

	# choices
	for child in _choices_box.get_children():
		child.queue_free()
	_is_waiting_for_input = dialogue_line.responses.is_empty()
	_continue_hint.visible = _is_waiting_for_input
	for response in dialogue_line.responses:
		var choice: SMDialogueChoice = DialogueChoiceScript.new()
		(
			choice
			. setup(
				response.text,
				_tag_value(response.tags, "tag"),
				_tag_value(response.tags, "cost"),
				_tag_value(response.tags, "consequence"),
				not response.is_allowed,
			)
		)
		choice.pressed.connect(_on_choice.bind(response))
		_choices_box.add_child(choice)
	# focus the first selectable choice (gamepad rule: grab_focus on entry)
	for child in _choices_box.get_children():
		if child is Button and not child.disabled:
			child.grab_focus.call_deferred()
			break


func _on_choice(response: DialogueResponse) -> void:
	_next(response.next_id)


func _unhandled_input(event: InputEvent) -> void:
	if (
		_is_waiting_for_input
		and (event.is_action_pressed("ui_accept") or event.is_action_pressed("interact"))
	):
		get_viewport().set_input_as_handled()
		_next(dialogue_line.next_id)


static func _tag_value(tags: PackedStringArray, key: String) -> String:
	for t in tags:
		if t.begins_with(key + "="):
			return t.substr(key.length() + 1)
	return ""


# --- layout (the Echo Gate) ---------------------------------------------------


func _build_ui() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIManager.ui_theme
	add_child(_root)

	# bottom scrim so parchment text holds over the field
	var scrim := ColorRect.new()
	scrim.color = Color(DS.VOID_0, 0.78)
	scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrim.anchor_top = 0.42
	_root.add_child(scrim)

	var column := VBoxContainer.new()
	column.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	column.anchor_top = 0.44
	column.offset_left = 0
	column.offset_right = 0
	column.alignment = BoxContainer.ALIGNMENT_END
	column.add_theme_constant_override("separation", DS.SPACE_5)
	_root.add_child(column)

	var center := CenterContainer.new()
	column.add_child(center)
	var content := VBoxContainer.new()
	content.custom_minimum_size = Vector2(860, 0)  # content column cap
	content.add_theme_constant_override("separation", DS.SPACE_5)
	center.add_child(content)

	# --- top row: portrait left, soul gauge right ---
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", DS.SPACE_7)
	content.add_child(top)
	_portrait = PortraitScript.new()
	top.add_child(_portrait)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var gauge := SOUL_GAUGE.instantiate()
	gauge.custom_minimum_size = Vector2(220, 42)
	top.add_child(gauge)

	# --- middle row: the spoken line, bronze-trimmed panel ---
	var line_panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = DS.STONE_1
	sb.border_color = DS.BRONZE_1  # the one bronze-trimmed panel on this screen
	sb.set_border_width_all(DS.BORDER_TRIM_W)
	sb.set_corner_radius_all(DS.RADIUS)
	sb.set_content_margin_all(DS.PANEL_PAD)
	line_panel.add_theme_stylebox_override("panel", sb)
	content.add_child(line_panel)
	_line_label = RichTextLabel.new()
	_line_label.bbcode_enabled = false
	_line_label.fit_content = true
	_line_label.add_theme_font_size_override("normal_font_size", DS.FS_500)
	_line_label.custom_minimum_size = Vector2(0, 56)
	line_panel.add_child(_line_label)

	_continue_hint = Label.new()
	_continue_hint.text = "CONTINUE"
	_continue_hint.theme_type_variation = "EyebrowLabel"
	_continue_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	content.add_child(_continue_hint)

	# --- bottom row: the choice stack ---
	_choices_box = VBoxContainer.new()
	_choices_box.add_theme_constant_override("separation", DS.SPACE_3)
	content.add_child(_choices_box)

	# breathing room from the screen edge
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, DS.SPACE_8)
	column.add_child(pad)
