extends GdUnitTestSuite
## #603: tool-only comparison contracts. No production controller replacement.

var _benchmark: Script = preload("res://tools/populated_field_benchmark.gd")
const PROTOTYPE := "res://tools/planner_spike/planner.gd"


func test_variant_selection_accepts_control_and_rejects_unknown_names() -> void:
	assert_bool(_benchmark.has_method("is_planner_variant")).is_true()
	if not _benchmark.has_method("is_planner_variant"):
		return
	for variant: String in ["none", "full", "cached", "fallback24"]:
		assert_bool(_benchmark.call("is_planner_variant", variant)).is_true()
	assert_bool(_benchmark.call("is_planner_variant", "unknown")).is_false()
	assert_bool(_benchmark.call("is_planner_variant", "")).is_false()


func test_budget_requires_complete_hundred_hostile_samples_and_both_limits() -> void:
	assert_bool(_benchmark.has_method("planner_budget_verdict")).is_true()
	if not _benchmark.has_method("planner_budget_verdict"):
		return
	assert_bool(_benchmark.call("planner_budget_verdict", [16.67], 1999.0, 100, 100)).is_true()
	assert_bool(_benchmark.call("planner_budget_verdict", [16.68], 10.0, 100, 100)).is_false()
	assert_bool(_benchmark.call("planner_budget_verdict", [1.0], 2000.0, 100, 100)).is_false()
	assert_bool(_benchmark.call("planner_budget_verdict", [], 10.0, 100, 100)).is_false()
	assert_bool(_benchmark.call("planner_budget_verdict", [1.0], -1.0, 100, 100)).is_false()
	assert_bool(_benchmark.call("planner_budget_verdict", [1.0], 10.0, 99, 100)).is_false()
	assert_bool(_benchmark.call("planner_budget_verdict", [1.0], 10.0, 100, 99)).is_false()
	assert_bool(_benchmark.call("planner_budget_verdict", [-1.0], 10.0, 100, 100)).is_false()


func test_fallback_cannot_pass_the_gate_and_missing_comparators_fail() -> void:
	assert_bool(_benchmark.has_method("planner_comparison_verdict")).is_true()
	if not _benchmark.has_method("planner_comparison_verdict"):
		return
	var full := {"variant": "full", "budget_pass": false, "legibility_facts": 3}
	var cached := {"variant": "cached", "budget_pass": false, "legibility_facts": 3}
	var fallback := {"variant": "fallback24", "budget_pass": true, "legibility_facts": 3}
	assert_bool(_benchmark.call("planner_comparison_verdict", [full, cached, fallback])).is_false()
	var control := {"variant": "none", "budget_pass": true, "legibility_facts": 3}
	assert_bool(_benchmark.call("planner_comparison_verdict", [control, full, cached, fallback])).is_false()
	cached["budget_pass"] = true
	assert_bool(_benchmark.call("planner_comparison_verdict", [full, cached])).is_false()
	assert_bool(_benchmark.call("planner_comparison_verdict", [full, cached, fallback])).is_true()
	cached["legibility_facts"] = 2
	assert_bool(_benchmark.call("planner_comparison_verdict", [full, cached, fallback])).is_false()


func test_all_variants_leave_every_hostile_in_ct_without_mutating_combat() -> void:
	assert_bool(FileAccess.file_exists(PROTOTYPE)).is_true()
	if not FileAccess.file_exists(PROTOTYPE):
		return
	var controller := _controller()
	var before := controller.scheduler.to_dict().duplicate(true)
	for variant: String in ["none", "full", "cached", "fallback24"]:
		var planner: RefCounted = load(PROTOTYPE).new()
		planner.call("configure", controller, variant)
		var result: Dictionary = planner.call("refresh")
		assert_int(result["ct_hostiles"]).is_equal(100)
		var expected := 0 if variant == "none" else (24 if variant == "fallback24" else 100)
		assert_int(result["planned_hostiles"]).is_equal(expected)
		assert_that(controller.scheduler.to_dict()).is_equal(before)
		planner.call("dispose")


func test_control_does_no_speculative_work_and_uses_default_decision_plan() -> void:
	var controller := _controller()
	var listeners_before := controller.event_emitted.get_connections().size()
	var planner: RefCounted = load(PROTOTYPE).new()
	planner.call("configure", controller, "none")
	var result: Dictionary = planner.call("refresh")
	assert_int(controller.event_emitted.get_connections().size()).is_equal(listeners_before)
	assert_that(result["plans"]).is_equal({})
	assert_int(result["detailed_hostiles"]).is_equal(0)
	assert_int(result["cheap_hostiles"]).is_equal(0)
	assert_int(result["cache_hits"]).is_equal(0)
	assert_that(planner.get("decision_ms")).is_equal([])
	assert_that(planner.call("plan_for_decision", controller.enemies[0])).is_equal(
		controller.plan_enemy_turn(controller.enemies[0]))
	planner.call("dispose")


func test_cached_plans_reuse_work_but_target_death_invalidates_before_decision() -> void:
	assert_bool(FileAccess.file_exists(PROTOTYPE)).is_true()
	if not FileAccess.file_exists(PROTOTYPE):
		return
	var controller := _controller()
	var planner: RefCounted = load(PROTOTYPE).new()
	planner.call("configure", controller, "cached")
	planner.call("refresh")
	var warm: Dictionary = planner.call("refresh")
	assert_int(warm["cache_hits"]).is_equal(100)
	var enemy := controller.enemies[0]
	var original: Dictionary = planner.call("plan_for_decision", enemy)
	assert_str(original["target_id"]).is_equal(String(controller.allies[0].combat_id))
	controller.allies[0].hp = 0
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	controller.event_emitted.emit(event)
	planner.call("refresh")
	var changed: Dictionary = planner.call("plan_for_decision", enemy)
	assert_str(changed["target_id"]).is_equal(String(controller.allies[1].combat_id))
	assert_that(changed).is_equal(controller.plan_enemy_turn(enemy))
	# Even an unannounced fixture mutation cannot make a decision consume stale work.
	controller.allies[0].hp = 1000
	var fresh: Dictionary = planner.call("plan_for_decision", enemy)
	assert_str(fresh["target_id"]).is_equal(String(controller.allies[0].combat_id))
	planner.call("dispose")


func _controller() -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = true
	var controller := CombatController.new()
	var board: BattlefieldModel = load("res://globals/combat/zone_battlefield_model.gd").new()
	controller.configure(CombatActionCatalog.all(), board, rules)
	var first := _actor("First", 100)
	var second := _actor("Second", 100)
	var enemies: Array[BattleActor] = []
	for index: int in 100:
		enemies.append(_actor("Hostile %03d" % index, 10))
	controller.start([first, second], enemies, &"planner-spike-fixture")
	return controller


func _actor(label: String, speed: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = label
	actor.hp = 1000
	actor.max_hp = 1000
	actor.attributes = {"reason": speed}
	actor.attack = 5
	return actor
