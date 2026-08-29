extends GdUnitTestSuite

const NOTICE_SCENE := preload("res://ui/hud/consequence_notices.tscn")
const ConsequenceNoticesScript := preload("res://ui/hud/consequence_notices.gd")

var _reputation_before: Dictionary = {}
var _renown_before: Dictionary = {}
var _paused_before: bool = false


func before_test() -> void:
	_reputation_before = Reputation.to_dict()
	_renown_before = Renown.to_dict()
	_paused_before = get_tree().paused
	get_tree().paused = false
	Reputation.from_dict({})
	Renown.from_dict({})


func after_test() -> void:
	get_tree().paused = false
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	get_tree().paused = _paused_before


func test_ledger_signals_show_each_event_once_without_numeric_values() -> void:
	var notices: ConsequenceNoticesScript = _notices()
	var reputation_event: ReputationEvent = Reputation.record(
		"vex", "the-iron-companies", 47.5, "Sheltered the strikers", "test"
	)
	Renown.gain_reputation("vex", 91.25, "Carried the warning", "test")
	Reputation.reputation_changed.emit("the-iron-companies", 999.0, reputation_event)

	var texts: Array[String] = notices.visible_notice_texts()
	assert_array(texts).contains_exactly([
		"THE IRON COMPANIES WILL REMEMBER — Sheltered the strikers",
		"WORD OF YOU SPREADS — Carried the warning",
	])
	assert_int(notices.pending_notice_count()).is_equal(0)
	for notice_text: String in texts:
		assert_bool(_contains_digit(notice_text)).is_false()
		assert_bool(notice_text.contains("47.5")).is_false()
		assert_bool(notice_text.contains("91.25")).is_false()
		assert_bool(notice_text.contains("999")).is_false()


func test_queue_preserves_fifo_order_and_caps_visible_notices_at_three() -> void:
	var notices: ConsequenceNoticesScript = _notices(0.08)
	for cause: String in ["First oath", "Second oath", "Third oath", "Fourth oath"]:
		Reputation.record("vex", "iron-companies", 12.0, cause, "test")

	assert_array(notices.visible_notice_texts()).contains_exactly([
		"IRON COMPANIES WILL REMEMBER — First oath",
		"IRON COMPANIES WILL REMEMBER — Second oath",
		"IRON COMPANIES WILL REMEMBER — Third oath",
	])
	assert_int(notices.pending_notice_count()).is_equal(1)

	await await_millis(140)
	var after_first_exit: Array[String] = notices.visible_notice_texts()
	assert_int(after_first_exit.size()).is_less_equal(3)
	assert_array(after_first_exit).contains(["IRON COMPANIES WILL REMEMBER — Fourth oath"])


func test_paused_tree_defers_events_until_gameplay_resumes() -> void:
	var notices: ConsequenceNoticesScript = _notices()
	get_tree().paused = true
	Renown.gain_infamy("vex", 35.0, "Defied the tribunal", "test")

	assert_array(notices.visible_notice_texts()).is_empty()
	assert_int(notices.pending_notice_count()).is_equal(1)

	get_tree().paused = false
	await get_tree().process_frame
	assert_array(notices.visible_notice_texts()).contains_exactly([
		"WORD OF YOU SPREADS — Defied the tribunal",
	])
	assert_int(notices.pending_notice_count()).is_equal(0)


func _notices(hold_seconds: float = 10.0) -> ConsequenceNoticesScript:
	var notices: ConsequenceNoticesScript = (
		auto_free(NOTICE_SCENE.instantiate()) as ConsequenceNoticesScript
	)
	notices.hold_seconds = hold_seconds
	notices.slide_seconds = 0.01
	notices.fade_seconds = 0.01
	get_tree().root.add_child(notices)
	return notices


func _contains_digit(value: String) -> bool:
	for character: String in value:
		if character >= "0" and character <= "9":
			return true
	return false
