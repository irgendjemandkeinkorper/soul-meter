extends GdUnitTestSuite
## Issue #201 item 1: design/ui-shell-conventions.md rule 3 requires every Screen to
## play its enter animation when opened and its exit animation when closed, driven
## from the sanctioned seam (UIManager.open()/back()/close_all(), which is itself
## called from the state chart's state_entered/state_exited handlers in
## ui/flow/game_flow.gd — see e.g. _on_paused_entered()/_on_paused_exited()).
##
## This was found to already be wired (ui/ui_manager.gd calls Screen.play_enter()
## in open() and awaits Screen.play_exit() in _finish_screen_close(), landed in
## commit b028f7a3 "ui: await screen exit transitions (#159)", predating the #150
## assessment that reported it missing). This suite proves the wiring on
## observable Control state (modulate/position), not private internals, so a
## future regression is caught.


func before_test() -> void:
	UIManager.close_all()
	get_tree().paused = false


func after_test() -> void:
	UIManager.close_all()
	get_tree().paused = false


func test_opening_a_screen_plays_the_enter_transition() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(5)

	var screen: Control = UIManager.open(UIManager.INVENTORY, true)
	assert_object(screen).is_not_null()

	# play_enter() sets the pre-tween start state synchronously: invisible and
	# settled 8px above rest, per design/ui-shell-conventions.md rule 3.
	assert_float(screen.modulate.a).is_equal_approx(0.0, 0.001)
	assert_float(screen.position.y).is_equal_approx(-8.0, 0.001)

	await (screen as Screen).transition_finished
	await runner.simulate_frames(1)

	assert_float(screen.modulate.a).is_equal_approx(1.0, 0.01)
	assert_float(screen.position.y).is_equal_approx(0.0, 0.01)


func test_closing_a_screen_plays_the_exit_transition_before_freeing_it() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(5)

	var screen: Control = UIManager.open(UIManager.INVENTORY, true)
	await runner.simulate_frames(60)  # let the enter transition finish and settle
	assert_float(screen.modulate.a).is_equal_approx(1.0, 0.01)

	UIManager.back()
	# Immediately after back(), the exit tween has only just started (DS.DUR_FAST
	# = 0.14s) — the screen must still be alive and mid-fade, not instantly freed,
	# proving the close path actually awaits play_exit()/transition_finished.
	await runner.simulate_frames(1)
	assert_bool(is_instance_valid(screen)).is_true()
	assert_float(screen.modulate.a).is_less(1.0)

	await runner.simulate_frames(60)
	assert_bool(is_instance_valid(screen)).is_false()
	assert_bool(UIManager.is_open()).is_false()


func test_pause_menu_flow_owned_screen_also_plays_enter_and_exit() -> void:
	# Flow-owned screens are opened from the state chart's state_entered handlers
	# (e.g. GameFlow._on_paused_entered() -> UIManager.open(PAUSE_MENU, false, true))
	# through the exact same UIManager.open()/close_all() seam as overlay screens,
	# so they get the same transitions. Called directly here (rather than via
	# GameFlow.send_event("pause")) so the assertion doesn't depend on the chart
	# already being in the Playing/Active state — see test/integration/
	# test_field_room.gd's test_pause_menu_* suites for the same pattern.
	var runner := scene_runner("res://world/test_room.tscn")
	await runner.simulate_frames(5)

	var screen: Control = UIManager.open(GameFlow.PAUSE_MENU, false, true)
	assert_object(screen).is_not_null()
	assert_float(screen.modulate.a).is_less(1.0)

	await runner.simulate_frames(60)
	assert_float(screen.modulate.a).is_equal_approx(1.0, 0.01)

	UIManager.close_all()
	await runner.simulate_frames(1)
	assert_bool(is_instance_valid(screen)).is_true()
	assert_float(screen.modulate.a).is_less(1.0)

	await runner.simulate_frames(60)
	assert_bool(is_instance_valid(screen)).is_false()
	assert_bool(UIManager.is_open()).is_false()
