extends GdUnitTestSuite
## Base for suites that call `assert_error()`.
##
## gdUnit4 6.1.3's `assert_error()` builds a `GdUnitLogger` that registers itself with
## `OS.add_logger()`, and nothing ever removes it. A leaked logger keeps reporting every later
## engine error for the rest of the run. For an error with no GDScript frame, such as a deferred
## call on a freed object, its stack trace reads frame 0 of an empty backtrace. That read fails
## inside error printing. In the full CI run of PR #589 (2026-11-13) the nested errors stalled
## the engine until the 60-minute job limit. Whether it happens depends on suite order: only runs
## that reach these suites before the deferred errors stall.
##
## This base removes each such logger when the test that made it ends. A suite that defines
## `after_test()` calls `super()` in it. `after()` is a safety net for the end of the suite.

var _error_asserts: Array[GdUnitGodotErrorAssert] = []


func assert_error(current: Callable) -> GdUnitGodotErrorAssert:
	var error_assert := super(current)
	_error_asserts.append(error_assert)
	return error_assert


func after_test() -> void:
	release_error_loggers()


func after() -> void:
	release_error_loggers()


## Removes the engine loggers of every `assert_error()` made since the last release. Reads the
## assert's private `_logger` (gdUnit4 6.1.3); if a gdUnit update renames it, this does nothing,
## and the test of this helper fails.
func release_error_loggers() -> void:
	for error_assert: GdUnitGodotErrorAssert in _error_asserts:
		var logger: Variant = error_assert.get("_logger")
		if logger is Logger:
			OS.remove_logger(logger as Logger)
	_error_asserts.clear()
