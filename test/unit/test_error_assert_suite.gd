extends "res://test/helpers/error_assert_suite.gd"
## The helper base must take `assert_error()`'s engine logger out of the engine once a test is
## done. A logger left in place broke CI on PR #589 (see test/helpers/error_assert_suite.gd).


func test_a_released_assert_error_logger_stops_receiving_engine_messages() -> void:
	var error_assert: GdUnitGodotErrorAssert = await assert_error(
		func() -> void: push_error("captured by the assert")
	).is_push_error("captured by the assert")
	var logger: Variant = error_assert.get("_logger")
	assert_bool(logger is GodotGdErrorMonitor.GdUnitLogger).override_failure_message(
		"gdUnit's assert_error() no longer keeps its logger in `_logger`;"
		+ " update test/helpers/error_assert_suite.gd"
	).is_true()
	if not logger is GodotGdErrorMonitor.GdUnitLogger:
		return
	var gd_logger := logger as GodotGdErrorMonitor.GdUnitLogger
	# Still registered: the engine hands it a later warning.
	var registered := gd_logger.entries().size()
	push_warning("seen while registered")
	assert_int(gd_logger.entries().size()).is_equal(registered + 1)

	release_error_loggers()
	var released := gd_logger.entries().size()
	push_warning("not seen after release")
	assert_int(gd_logger.entries().size()).is_equal(released)
