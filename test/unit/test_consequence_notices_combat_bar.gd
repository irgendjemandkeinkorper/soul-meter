extends GdUnitTestSuite
## #628: consequence notices clear the one-bar HUD throughout entry and exit.

const HUD_SCENE := preload("res://ui/hud/field_hud.tscn")
const EXPLORE_OFFSETS := Vector2(-420.0, -104.0)
const NOTICE_GAP := 20.0
## The bar's height tween can settle a few ten-thousandths of a pixel off its target.
const OFFSET_TOLERANCE := 0.01

var _hud: FieldHUD
var _notices: ConsequenceNotices
var _window_size_before: Vector2i
var _reduced_motion_before: bool
var _time_scale_before: float


func before_test() -> void:
	_window_size_before = get_tree().root.size
	_reduced_motion_before = bool(GameState.get_setting("accessibility", "reduced_motion", false))
	_time_scale_before = Engine.time_scale


func after_test() -> void:
	if is_instance_valid(_hud):
		_hud.exit_combat()
		_hud.free()
	Engine.time_scale = _time_scale_before
	GameState.set_setting("accessibility", "reduced_motion", _reduced_motion_before)
	get_tree().root.size = _window_size_before


func test_notices_clear_the_bar_and_return_to_their_exploration_position(
	resolution: Vector2i,
	reduced_motion: bool,
	test_parameters := [
		[Vector2i(1920, 1080), false], [Vector2i(1366, 768), false],
		[Vector2i(1920, 1080), true], [Vector2i(1366, 768), true],
	]
) -> void:
	get_tree().root.size = resolution
	GameState.set_setting("accessibility", "reduced_motion", reduced_motion)
	_hud = HUD_SCENE.instantiate() as FieldHUD
	get_tree().root.add_child(_hud)
	_notices = _hud.get_node("ConsequenceNotices") as ConsequenceNotices
	_notices.hold_seconds = 10.0
	await get_tree().process_frame
	assert_vector(get_tree().root.size).is_equal(resolution)
	assert_vector(Vector2(_notices.offset_top, _notices.offset_bottom)).is_equal_approx(
		EXPLORE_OFFSETS, Vector2(OFFSET_TOLERANCE, OFFSET_TOLERANCE)
	)
	var exploration_rect := _notices.get_global_rect()
	assert_float(_hud.bar_height()).is_equal(FieldHUD.EXPLORE_BAR_HEIGHT)

	# Slow the fixture clock to sample intermediate heights, even on software rendering.
	Engine.time_scale = 0.2
	_hud.enter_combat(null)
	_notices._enqueue("WILL REMEMBER — Cleared the Bog Wight from the grove margins")
	_notices._enqueue("WORD OF YOU SPREADS — Cleared the Bog Wight from the grove margins")
	assert_bool(_hud.combat_active()).is_true()
	assert_int(_notices.visible_notice_texts().size()).is_equal(2)
	assert_int(_notices.pending_notice_count()).is_equal(0)
	await _assert_clear_through_transition(FieldHUD.COMBAT_BAR_HEIGHT, reduced_motion)
	_assert_clear_rects()

	_hud.exit_combat()
	await _assert_clear_through_transition(FieldHUD.EXPLORE_BAR_HEIGHT, reduced_motion)
	_assert_clear_rects()
	assert_vector(Vector2(_notices.offset_top, _notices.offset_bottom)).is_equal_approx(
		EXPLORE_OFFSETS, Vector2(OFFSET_TOLERANCE, OFFSET_TOLERANCE)
	)
	assert_bool(_rects_close(_notices.get_global_rect(), exploration_rect)).override_failure_message(
		"Notices at %s, expected %s" % [_notices.get_global_rect(), exploration_rect]
	).is_true()


func _assert_clear_through_transition(target_height: float, reduced_motion: bool) -> void:
	var min_gap := INF
	var max_gap := -INF
	var sampled_intermediate_height := false
	var overlap := ""
	var deadline := Time.get_ticks_msec() + 5000
	while Time.get_ticks_msec() < deadline:
		# A process frame, not RenderingServer.frame_post_draw: the headless renderer never emits
		# that signal, so CI waited on it until the 25-minute test timeout. Layout and the bar's
		# height tween both advance per process frame.
		await get_tree().process_frame
		var bar_rect := _hud.bar().get_global_rect()
		var notice_rect := _notices.get_global_rect()
		var gap := bar_rect.position.y - notice_rect.end.y
		min_gap = minf(min_gap, gap)
		max_gap = maxf(max_gap, gap)
		if notice_rect.intersects(bar_rect):
			overlap = "Notice stack %s intersects bar %s" % [notice_rect, bar_rect]
		for panel: Control in _notices.get_node("NoticeStack").get_children():
			if panel.get_global_rect().intersects(bar_rect):
				overlap = "Notice panel %s intersects bar %s" % [panel.get_global_rect(), bar_rect]
		var height := _hud.bar_height()
		if height > FieldHUD.EXPLORE_BAR_HEIGHT and height < FieldHUD.COMBAT_BAR_HEIGHT:
			sampled_intermediate_height = true
		if absf(height - target_height) < OFFSET_TOLERANCE:
			break
	# Let the height tween finish before the final checks.
	var settle_deadline := Time.get_ticks_msec() + 3000
	var last_height := -1.0
	while Time.get_ticks_msec() < settle_deadline and last_height != _hud.bar_height():
		last_height = _hud.bar_height()
		await get_tree().process_frame
	assert_float(_hud.bar_height()).is_equal_approx(target_height, 0.01)
	assert_bool(sampled_intermediate_height).is_equal(not reduced_motion)
	assert_str(overlap).is_empty()
	assert_float(min_gap).is_equal_approx(NOTICE_GAP, 0.01)
	assert_float(max_gap).is_equal_approx(NOTICE_GAP, 0.01)


func _assert_clear_rects() -> void:
	var bar_rect := _hud.bar().get_global_rect()
	assert_bool(_notices.get_global_rect().intersects(bar_rect)).is_false()
	assert_int(_notices.get_node("NoticeStack").get_child_count()).is_equal(2)
	for panel: Control in _notices.get_node("NoticeStack").get_children():
		assert_bool(panel.get_global_rect().intersects(bar_rect)).is_false()


func _rects_close(a: Rect2, b: Rect2) -> bool:
	return (
		a.position.distance_to(b.position) < OFFSET_TOLERANCE
		and a.size.distance_to(b.size) < OFFSET_TOLERANCE
	)
