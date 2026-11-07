extends GdUnitTestSuite
## U1 (owner 2026-11-01): the conversation balloon offers only what can matter now, shows
## what each choice changes and its odds, lands the effects on the reply, and clears the
## stage while it is open.

const BALLOON := "res://ui/dialogue/dialogue_balloon.tscn"
const NOTICE_SCENE := preload("res://ui/hud/consequence_notices.tscn")
const ConsequenceNoticesScript := preload("res://ui/hud/consequence_notices.gd")

const DIALOGUE := """~ start
Nemo: Pick one.
- "Pay." [#tag=COMMUNION] [#consequence=It costs.]
	do GameState.set_soul_meter(GameState.soul_meter - 6.0)
	do Reputation.record("player", "ssae-seeders", 3.0, "Paid the grove", "test")
	do Renown.gain_karma("player", 5.0, "Asked nothing back", "test")
	Nemo: Paid.
	=> END
- "Roll." [if check("undertone", 0) /]
	do SkillCheck.resolve("undertone")
	Nemo: Rolled.
	=> END
- "Earn it." [if Reputation.standing("ssae-seeders") >= 15.0 /]
	Nemo: Earned.
	=> END
- "Bookkeeping." [if GameState.get_flag("u1_never_set") /]
	Nemo: Never.
	=> END
"""

var _reputation_before: Dictionary = {}
var _renown_before: Dictionary = {}
var _game_state_before: Dictionary = {}


func before_test() -> void:
	_reputation_before = Reputation.to_dict()
	_renown_before = Renown.to_dict()
	_game_state_before = GameState.to_dict()
	Reputation.from_dict({})
	Renown.from_dict({})
	GameState.set_soul_meter(50.0)
	GameState.set_flag("u1_never_set", false)
	DialogueLedgerEcho.clear()


func after_test() -> void:
	get_tree().paused = false
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	GameState.from_dict(_game_state_before)
	DialogueLedgerEcho.clear()


func test_rows_show_effects_odds_and_only_earnable_locks() -> void:
	var balloon := await _open(DIALOGUE)
	var rows := _rows(balloon)

	assert_array(rows.map(func(row: SMDialogueChoice) -> String: return row.choice_text)) \
		.contains_exactly(["\"Pay.\"", "\"Roll.\"", "\"Earn it.\""])
	var pay: SMDialogueChoice = rows[0]
	var roll: SMDialogueChoice = rows[1]
	var earn: SMDialogueChoice = rows[2]

	assert_str(_label(pay, "Effects")).is_equal("SOUL −6  ·  SSAE SEEDERS +3")
	assert_str(_label(pay, "Tag")).is_equal("[COMMUNION]")
	assert_str(_label(pay, "Line")).is_equal("\"Pay.\"")
	# A row never prints its promise; the balloon shows the focused one's.
	assert_bool(_all_text(pay).contains("It costs.")).is_false()

	assert_str(_label(roll, "Tag")).is_equal("[UNDERTONE]")
	assert_str(_label(roll, "Odds")).is_equal("%d%%" % roundi(SkillCheck.preview("undertone")))

	assert_bool(earn.locked).is_true()
	assert_bool(earn.disabled).is_true()
	assert_str(_label(earn, "LockReason")).is_equal(
		"Ssae Seeders standing 15 needed — you have 0."
	)
	assert_str(_label(earn, "Odds")).is_empty()
	balloon.free()


func test_the_promise_follows_focus() -> void:
	var balloon := await _open(DIALOGUE)
	var rows := _rows(balloon)
	var promise := balloon.get("_promise_label") as Label

	(rows[0] as SMDialogueChoice).grab_focus()
	await get_tree().process_frame
	assert_str(promise.text).is_equal("It costs.")
	(rows[1] as SMDialogueChoice).grab_focus()
	await get_tree().process_frame
	assert_str(promise.text).is_empty()
	balloon.free()


func test_a_choice_lands_on_the_reply_and_is_not_announced_twice() -> void:
	var notices: ConsequenceNoticesScript = auto_free(NOTICE_SCENE.instantiate())
	notices.hold_seconds = 10.0
	notices.slide_seconds = 0.01
	notices.fade_seconds = 0.01
	get_tree().root.add_child(notices)

	var balloon := await _open(DIALOGUE)
	(_rows(balloon)[0] as SMDialogueChoice).pressed.emit()
	await _until(func() -> bool: return (balloon.get("_line_label") as RichTextLabel).text == "Paid.")

	assert_str(balloon.call("ledger_text")).is_equal("RECORDED  ·  SOUL −6  ·  SSAE SEEDERS +3")
	# The tree is paused under the conversation, so the field notices are still queued.
	assert_int(notices.pending_notice_count()).is_greater(0)

	balloon.free()
	await _until(func() -> bool: return notices.pending_notice_count() == 0)

	var texts: Array[String] = notices.visible_notice_texts()
	assert_array(texts).not_contains(["SSAE SEEDERS WILL REMEMBER — Paid the grove"])
	# Karma has no readout on the strip, so the field still tells it, as before U1.
	assert_array(texts).contains(["WORD OF YOU SPREADS — Asked nothing back"])


func test_the_stage_clears_and_comes_back() -> void:
	var runner := scene_runner("res://world/starting_town.tscn")
	await runner.simulate_frames(3)
	var town := runner.scene() as Node2D
	var hud := town.get_node("FieldHUD") as CanvasLayer
	var town_hall := town.get_node("TownHall/LocationLabel") as Label
	var before := {}
	for child: Node in hud.get_children():
		if child is CanvasItem:
			before[child] = (child as CanvasItem).visible
	assert_float(town_hall.self_modulate.a).is_greater(0.0)

	var balloon := await _open(DIALOGUE)
	for child: Variant in before.keys():
		assert_bool((child as CanvasItem).visible) \
			.override_failure_message(str((child as Node).name)).is_false()
	assert_float(town_hall.self_modulate.a).is_equal(0.0)

	balloon.free()
	for child: Variant in before.keys():
		assert_bool((child as CanvasItem).visible).is_equal(bool(before[child]))
	assert_float(town_hall.self_modulate.a).is_greater(0.0)
	assert_bool(get_tree().paused).is_false()


# --- helpers ------------------------------------------------------------------------------------

func _open(text: String) -> Node:
	var balloon: Node = load(BALLOON).instantiate()
	add_child(balloon)
	balloon.call("start", DialogueManager.create_resource_from_text(text), "start")
	await _until(func() -> bool: return not _rows(balloon).is_empty())
	await get_tree().process_frame
	return balloon


func _rows(balloon: Node) -> Array:
	var box := balloon.get("_choices_box") as VBoxContainer
	if box == null:
		return []
	return box.get_children().filter(
		func(child: Node) -> bool: return child is SMDialogueChoice and not child.is_queued_for_deletion()
	)


func _label(row: Node, label_name: String) -> String:
	var label := row.find_child(label_name, true, false) as Label
	return "" if label == null else label.text


func _all_text(row: Node) -> String:
	var parts := PackedStringArray()
	for node: Node in row.find_children("*", "Label", true, false):
		parts.append((node as Label).text)
	return " | ".join(parts)


func _until(condition: Callable, frames: int = 240) -> void:
	for _frame: int in frames:
		if condition.call():
			return
		await get_tree().process_frame
