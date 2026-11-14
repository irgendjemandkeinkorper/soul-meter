extends RefCounted
## #603 scripted evidence, after timing. Only runtime fixture state is changed.
## The existing HUD renders an actual locked strike, followed by an actual Guard submit.
## No annotation is added to the game; named facts and rectangles go into the report.


func capture(
	tree: SceneTree, battle: Node, field: Node, hud: Control, planner: RefCounted,
	directory: String, variant: String
) -> Dictionary:
	var controller := battle.get("controller") as CombatController
	if hud == null or controller == null or bool(battle.get("ended")):
		return {"automated_facts": 0, "error": "No live HUD/session for capture."}
	var interface := hud as BattleInterface
	# Flush the measured round's queued presentation through the existing replay seam.
	# Static readability captures must not be overwritten by old animated beats.
	interface.stage.set_replaying(true)
	var board := controller.battlefield as GridBattlefieldModel
	var ally := controller.allies[0]
	var enemy := controller.enemies[0]
	enemy.display_name = "Benchmark Wight 001"
	# PROVISIONAL capture-only values make Guard's reduction observable above the damage floor.
	enemy.attack = 20
	for member: BattleActor in controller.allies:
		member.guarding = false
		member.max_hp = 100
		member.hp = 100
	# A declared capture fixture: place one existing wight adjacent to its real target.
	# Other 99 hostiles retain their CT seats; no performance samples use this arrangement.
	var cell: Vector2i = board.cell_of(ally)
	var placed := false
	for offset: Vector2i in GridMetric.neighbor_offsets():
		var neighbor := cell + offset
		if bool(board.displace(enemy, neighbor).get("allowed", false)):
			placed = true
			var bodies: Dictionary = battle.get("_session_hostiles")
			var body := bodies.get(enemy.combat_id) as Hostile
			if body != null:
				body.global_position = (field as FieldMap).iso_grid().cell_to_world(neighbor)
				body.sync_cell()
			break
	if not placed:
		return {"automated_facts": 0, "error": "No adjacent capture cell is free."}
	# Deterministic readiness fixture through the scheduler's serialization seam.
	# Membership is unchanged. The real scheduler projects and executes this order.
	var state := controller.scheduler.to_dict()
	var charges: Dictionary = state["charge"]
	for id: Variant in charges:
		charges[id] = 0
	charges[String(ally.combat_id)] = 110
	charges[String(enemy.combat_id)] = 100
	state["charge"] = charges
	controller.scheduler.from_dict(state)
	controller.active_ally_index = 0
	controller.state = CombatController.State.ALLY_TURN
	battle.set("active_ally_index", 0)
	controller.lock_enemy_intent(enemy.combat_id, ally.combat_id)
	var shown := controller.shown_intent(enemy)
	var planned: Dictionary = planner.call("plan_for_decision", enemy)
	var agrees := str(planned.get("kind", "")) == str(shown.get("kind", "")) \
		and str(planned.get("target_id", "")) == str(shown.get("target_id", "")) \
		and str(planned.get("aim_location", "")) == str(shown.get("aim_location", ""))
	controller._emit_event(&"battle_snapshot", ally, null, {})
	for _frame: int in 8:
		await tree.process_frame
	var marker_index := -1
	for index: int in interface.turn_timeline.markers.get_child_count():
		if interface.turn_timeline.marker_name_label(index).text == enemy.display_name:
			marker_index = index
			break
	var facts: Array[Dictionary] = []
	var next_matches := marker_index == 1
	facts.append({"name": "next_actor", "answer": enemy.display_name,
		"verified": next_matches, "marker_index": marker_index})
	var readable_intent := false
	if marker_index >= 0:
		var label := interface.turn_timeline.marker_status_label(marker_index)
		readable_intent = label.text.contains(ally.display_name) and str(shown.get("kind", "")) == "strike" and agrees
		facts.append({"name": "revealed_intent", "answer": label.text,
			"verified": readable_intent, "rect": _rect(label.get_global_rect()), "plan": shown})
	else:
		facts.append({"name": "revealed_intent", "verified": false, "plan": shown})
	var guard_slot := interface.combat_bar.hotbar_ids().find(&"guard")
	var guard_visible := guard_slot >= 0
	var guard_rect: Dictionary = {}
	if guard_visible:
		var button := interface.combat_bar.hotbar_buttons()[guard_slot]
		guard_visible = button.is_visible_in_tree() and not button.disabled
		guard_rect = _rect(button.get_global_rect())
		# Present the real hover card, including the existing Guard effect text.
		button.mouse_entered.emit()
	for _frame: int in 8:
		await tree.process_frame
	DirAccess.make_dir_recursive_absolute(directory)
	var before_path := directory.path_join("%s-legibility-before.png" % variant)
	var after_path := directory.path_join("%s-legibility-response.png" % variant)
	var before_saved := await _save(tree, before_path)
	var strike := controller.action_by_id(&"enemy-strike")
	var before_damage := controller.forecast_damage_on_hit(controller.forecast_context(enemy, ally, strike), ally)
	var trace: Dictionary = {}
	var observer := func(outcome: CombatEvent) -> void:
		if outcome.type != &"action_resolved":
			return
		if outcome.actor_id == ally.combat_id and str(outcome.data.get("action_id", "")) == "guard":
			trace["guarding"] = ally.guarding
			trace["guarded_damage"] = controller.forecast_damage_on_hit(controller.forecast_context(enemy, ally, strike), ally)
		if outcome.actor_id == enemy.combat_id:
			trace["enemy_target_id"] = String(outcome.target_id)
			trace["enemy_action_id"] = str(outcome.data.get("action_id", ""))
	controller.event_emitted.connect(observer)
	var guard_result := bool(battle.call("use_action", &"guard"))
	controller.event_emitted.disconnect(observer)
	var response_ok := guard_result and guard_visible and bool(trace.get("guarding", false)) \
		and int(trace.get("guarded_damage", before_damage)) < before_damage \
		and str(trace.get("enemy_target_id", "")) == String(ally.combat_id)
	facts.append({"name": "right_response", "answer": "%s uses Guard against the revealed strike" % ally.display_name,
		"verified": response_ok, "rect": guard_rect, "submit": guard_result,
		"unguarded_damage_on_hit": before_damage, "trace": trace})
	for _frame: int in 90:
		await tree.process_frame
	var after_saved := await _save(tree, after_path)
	interface.stage.set_replaying(false)
	var count := 0
	for fact: Dictionary in facts:
		if bool(fact.get("verified", false)):
			count += 1
	return {"automated_facts": count if before_saved and after_saved else 0,
		"visual_inspection_required": true, "facts": facts,
		"before": before_path, "response": after_path,
		"fixture": "After timing only: adjacent existing wight, attack 20; allies HP 100 and unguarded; ally CT 110, wight CT 100, other seats CT 0; lock via existing controller seam; presentation replay flush. All numbers PROVISIONAL."}


func _save(tree: SceneTree, path: String) -> bool:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	return tree.root.get_texture().get_image().save_png(path) == OK


func _rect(value: Rect2) -> Dictionary:
	return {"x": value.position.x, "y": value.position.y, "width": value.size.x, "height": value.size.y}
