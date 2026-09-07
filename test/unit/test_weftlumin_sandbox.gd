extends GdUnitTestSuite
## E2.4 (#335): the single sandbox owner from architecture §4.5.6.
##
## The properties tested here are exactly the ones the two debug labs each had to discover
## separately, which is the reason this class exists: restore/capture as an unconditional pair,
## restore exactly once, LIFO ownership, RNG seed before state, and surfaces the owner never
## enumerates for itself.

const SandboxScript := preload("res://addons/weftlumin/core/sandbox.gd")


## Stands in for SaveGame: an authoritative runtime snapshot plus the suppression bracket.
class FakeRuntimeOwner extends RefCounted:
	var state: Dictionary = {"soul": 10, "zhavar": 0}
	var sessions: int = 0
	var max_sessions: int = 0
	var refuse_restore: bool = false
	var restores: int = 0

	func capture_runtime_state() -> Dictionary:
		return state.duplicate(true)

	func restore_runtime_state(snapshot: Variant) -> bool:
		restores += 1
		if refuse_restore:
			return false
		state = (snapshot as Dictionary).duplicate(true)
		return true

	func begin_runtime_sandbox() -> void:
		sessions += 1
		max_sessions = maxi(max_sessions, sessions)

	func end_runtime_sandbox() -> void:
		sessions = maxi(0, sessions - 1)


class FakeRngOwner extends RefCounted:
	var random_number_generator := RandomNumberGenerator.new()


var _runtime: FakeRuntimeOwner
var _rng: FakeRngOwner
var _sandbox: WeftluminSandbox


func before_test() -> void:
	_runtime = FakeRuntimeOwner.new()
	_rng = FakeRngOwner.new()
	_rng.random_number_generator.seed = 1234
	_sandbox = SandboxScript.new()
	_sandbox.add_default_surfaces(_runtime, _rng)


func test_arm_captures_and_disarm_puts_everything_back() -> void:
	assert_bool(_sandbox.arm(&"combat_lab")["allowed"]).is_true()
	assert_bool(_sandbox.is_armed()).is_true()
	assert_str(String(_sandbox.owner())).is_equal("combat_lab")

	_runtime.state = {"soul": 0, "zhavar": 7}
	assert_bool(_sandbox.disarm()["allowed"]).is_true()
	assert_int(int(_runtime.state["soul"])).is_equal(10)
	assert_int(int(_runtime.state["zhavar"])).is_equal(0)
	assert_bool(_sandbox.is_armed()).is_false()


func test_the_rng_position_is_restored_and_the_seed_is_restored_first() -> void:
	# The host serializes reroll usage, not the generator's position, so a session that drew
	# random numbers would permanently shift the randomness later campaign checks draw from.
	var generator: RandomNumberGenerator = _rng.random_number_generator
	var before_seed: int = generator.seed
	var before_state: int = generator.state
	var expected: int = generator.randi()
	generator.state = before_state

	_sandbox.arm(&"dialogue_lab")
	for _draw in 25:
		generator.randi()
	generator.seed = 999
	_sandbox.disarm()

	assert_int(generator.seed).override_failure_message(
		"restoring state alone leaves the observable seed reading as the session's, "
		+ "misreporting where the campaign's randomness came from"
	).is_equal(before_seed)
	assert_int(generator.randi()).override_failure_message(
		"assigning seed RESETS state, so a seed-after-state restore discards the position"
	).is_equal(expected)


func test_a_restart_by_the_same_owner_restores_before_capturing_again() -> void:
	# The unconditional pair. A plain `if not armed` guard gets this exact case wrong: the
	# second arm must not snapshot the first session's dirty state as if it were clean.
	_sandbox.arm(&"combat_lab")
	_runtime.state = {"soul": 0, "zhavar": 7}
	assert_bool(_sandbox.arm(&"combat_lab")["restarted"]).is_true()
	assert_int(int(_runtime.state["soul"])).override_failure_message(
		"a restart must restore first, or the fresh capture records the dirty state"
	).is_equal(10)

	_runtime.state = {"soul": 3, "zhavar": 1}
	_sandbox.disarm()
	assert_int(int(_runtime.state["soul"])).is_equal(10)


func test_a_restart_does_not_nest_the_suppression_bracket() -> void:
	_sandbox.arm(&"combat_lab")
	_sandbox.arm(&"combat_lab")
	_sandbox.arm(&"combat_lab")
	assert_int(_runtime.max_sessions).override_failure_message(
		"three restarts of one session must not stack three suppression brackets"
	).is_equal(1)
	_sandbox.disarm()
	assert_int(_runtime.sessions).override_failure_message(
		"one disarm must fully clear the bracket, or autosaves stay suppressed for good"
	).is_equal(0)


func test_a_second_owner_is_refused_while_the_first_holds_it() -> void:
	_sandbox.arm(&"combat_lab")
	var result: Dictionary = _sandbox.arm(&"dialogue_lab")
	assert_bool(result["allowed"]).override_failure_message(
		"two holders restore in whatever order they end, and the second reinstates the "
		+ "first's dirty state after it already cleaned up"
	).is_false()
	assert_str(str(result["message"])).contains("combat_lab")
	assert_str(String(_sandbox.owner())).is_equal("combat_lab")
	assert_bool(_sandbox.held_by_other(&"dialogue_lab")).is_true()
	assert_bool(_sandbox.held_by_other(&"combat_lab")).override_failure_message(
		"a tool must still recognise its OWN armed session, which a restart may replace"
	).is_false()


func test_disarm_restores_exactly_once() -> void:
	_sandbox.arm(&"combat_lab")
	_sandbox.disarm()
	var restores_after_first: int = _runtime.restores
	_runtime.state = {"soul": 99, "zhavar": 99}

	var second: Dictionary = _sandbox.disarm()
	assert_bool(second["allowed"]).is_false()
	assert_int(_runtime.restores).override_failure_message(
		"an armed snapshot that outlives its session would roll back progress the player "
		+ "legitimately earned after returning to normal play"
	).is_equal(restores_after_first)
	assert_int(int(_runtime.state["soul"])).is_equal(99)


func test_a_refusing_surface_is_reported_and_the_session_still_ends() -> void:
	_sandbox.arm(&"combat_lab")
	_runtime.refuse_restore = true
	var result: Dictionary = _sandbox.disarm()
	assert_bool(result["allowed"]).is_false()
	assert_str(str(result["message"])).contains("runtime")
	assert_bool(_sandbox.is_armed()).override_failure_message(
		"a failed restore must still end the session; staying armed strands the suppression "
		+ "bracket and blocks every later tool"
	).is_false()
	assert_int(_runtime.sessions).is_equal(0)


func test_surfaces_added_later_are_covered_without_touching_the_owner() -> void:
	# The rule that matters most: the labs' hand-enumerated snapshots missed four surfaces.
	var extra := {"value": 1}
	_sandbox.add_surface(
		&"spawn_slots",
		func() -> Variant: return extra.duplicate(true),
		func(snapshot: Variant) -> bool:
			extra.clear()
			extra.merge(snapshot as Dictionary, true)
			return true,
	)
	_sandbox.arm(&"spawn_panel")
	extra["value"] = 42
	_sandbox.disarm()
	assert_int(int(extra["value"])).is_equal(1)


func test_arming_without_an_owner_id_is_refused() -> void:
	var result: Dictionary = _sandbox.arm(&"")
	assert_bool(result["allowed"]).is_false()
	assert_bool(_sandbox.is_armed()).is_false()
	for key: String in ["blocked_by", "nearest_unblock", "message"]:
		assert_bool(result.has(key)).is_true()


func test_signals_report_the_owner_on_both_edges() -> void:
	var seen: Array[String] = []
	_sandbox.armed.connect(func(owner_id: StringName) -> void: seen.append("armed:%s" % owner_id))
	_sandbox.disarmed.connect(
		func(owner_id: StringName) -> void: seen.append("disarmed:%s" % owner_id)
	)
	_sandbox.arm(&"combat_lab")
	_sandbox.disarm()
	assert_array(seen).is_equal(["armed:combat_lab", "disarmed:combat_lab"])
