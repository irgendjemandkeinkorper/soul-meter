extends GdUnitTestSuite
## Rendered evidence for hex slice H3a (owner item 34; docs/design/hex-grid-plan-2026-11-03.md),
## with `soul_meter/grid/hex` on: Kesselford and the Lower Trial Hall while exploring (grid off by
## default, then the faint "Show hex grid while exploring" grid), a fight starting (the party
## mid-walk onto its seats, the grid fading in), the fight on the player's turn (hex cursor, move
## range, reach ring, a walk-in path), and two bodies on touching hexes at full size (the overlap
## the owner ruled for). Run explicitly under Xvfb:
##   CAPTURE_OUT=<dir> scripts/test.sh -a test/manual/hex_seam_capture.gd
## Frames land in $CAPTURE_OUT (default user://qa/hex-seam).

const HOSTILE_SCENE := "res://actors/hostile/hostile.tscn"

var _saved_state: Dictionary
var _setting_before: Variant
var _exploring_before: Variant
var _out_dir := ""


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	_setting_before = ProjectSettings.get_setting(IsoGrid.HEX_SETTING, false)
	_exploring_before = GameState.get_setting(
		FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, false
	)
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, true)
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, false)
	get_tree().root.size = Vector2i(1920, 1080)
	_out_dir = OS.get_environment("CAPTURE_OUT")
	if _out_dir.is_empty():
		_out_dir = ProjectSettings.globalize_path("user://qa/hex-seam")
	DirAccess.make_dir_recursive_absolute(_out_dir)


func after_test() -> void:
	if Battle.session_active:
		Battle._end_session(null)
	Battle.controller = null
	Battle.ended = true
	UIManager.close_all()
	ProjectSettings.set_setting(IsoGrid.HEX_SETTING, _setting_before)
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, _exploring_before)
	GameState.from_dict(_saved_state)


func test_kesselford_on_hexes() -> void:
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	_ensure_companions(2)
	var runner := scene_runner(GameFlow.KESSELFORD_WALK_SCENE)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	_hide_other_root_canvas_items(root)
	SaveGame.pending_spawn_id = GameFlow.KESSELFORD_WALK_SPAWN
	SaveGame.has_pending_player_position = false
	SaveGame.apply_pending_location(root)
	await runner.simulate_frames(30, 16)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	_current_camera(field)
	await runner.simulate_frames(20, 16)
	await _capture("kesselford-01-exploring")
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, true)
	await runner.simulate_frames(40, 16)
	await _capture("kesselford-02-exploring-grid-on")
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, false)
	await runner.simulate_frames(40, 16)
	# A hostile three cells east of the lead; the companions stand stacked on the lead, as they do
	# on arrival, so the fight has to spread them over hexes.
	var grid := field.iso_grid()
	var lead := field.player()
	for follower: PartyFollower in field.party_followers().followers():
		follower.global_position = lead.global_position + Vector2(-6, 3)
	var hostile := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
	hostile.name = "CaptureWight"
	hostile.unit_id = &"bog-wight"
	hostile.realert_cooldown = 0.0
	root.add_child(hostile)
	var lead_square := grid.square_cell_of(grid.world_to_cell(lead.global_position))
	hostile.global_position = grid.cell_to_world(grid.cell_at_square(lead_square + Vector2i(3, 0)))
	hostile.sync_cell()
	assert_bool(Battle.start_session(field, hostile).get("allowed", false)).is_true()
	UIManager.close_all()
	GameFlow._on_battle_entered()
	_hide_other_root_canvas_items(root)
	await runner.simulate_frames(4, 16)
	await _capture("kesselford-03-fight-starts-walking")
	var stage := field.field_hud().battle_interface.stage
	await _settle(runner, stage)
	await _to_ally_turn(runner, stage)
	await runner.simulate_frames(30, 16)
	await _capture("kesselford-04-fight-player-turn")
	await _hover_far_enemy(runner, field)
	await _capture("kesselford-05-walk-in-path")
	await _arm_reaching_command(runner, field)
	await _capture("kesselford-06-reach-ring")
	await _capture_overlap("kesselford-07-overlap-x2", field)
	field.field_hud().exit_combat()
	field.set_combat_mode(false)
	await runner.simulate_frames(40, 16)
	await _capture("kesselford-08-after-the-fight")


func test_trial_hall_on_hexes() -> void:
	GameState.flags.clear()
	if GameState.party.is_empty():
		GameState._seed_demo_data()
	var runner := scene_runner(GameFlow.TRIAL_SCENE)
	var root := runner.scene() as Node2D
	await runner.simulate_frames(3)
	_hide_other_root_canvas_items(root)
	var field := root.find_child("FieldMap", true, false) as FieldMap
	_current_camera(field)
	await runner.simulate_frames(20, 16)
	await _capture("trial-01-exploring")
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, true)
	await runner.simulate_frames(40, 16)
	await _capture("trial-02-exploring-grid-on")
	GameState.set_setting(FieldGridLayer.SETTING_SECTION, FieldGridLayer.SETTING_KEY, false)
	await runner.simulate_frames(40, 16)
	root.call("request_warden_encounter")
	UIManager.close_all()
	GameFlow._on_battle_entered()
	_hide_other_root_canvas_items(root)
	await runner.simulate_frames(4, 16)
	await _capture("trial-03-fight-starts")
	var stage := field.field_hud().battle_interface.stage
	await _settle(runner, stage)
	await _to_ally_turn(runner, stage)
	await runner.simulate_frames(30, 16)
	await _capture("trial-04-fight-player-turn")
	await _hover_far_enemy(runner, field)
	await _capture("trial-05-walk-in-path")
	await _capture_overlap("trial-06-overlap-x2", field)


func _ensure_companions(count: int) -> void:
	var members: Array[PartyMember] = []
	members.assign(GameState.party)
	while members.size() < count + 1:
		var extra := members[0].duplicate(true) as PartyMember
		extra.id = StringName("capture-companion-%d" % members.size())
		extra.display_name = "Companion %d" % members.size()
		members.append(extra)
	GameState.set_party(members)


func _current_camera(field: FieldMap) -> void:
	var camera := field.player().get_node_or_null("Camera2D") as Camera2D
	if camera != null:
		camera.enabled = true
		camera.make_current()
		camera.reset_smoothing()


## Hovers the farthest living enemy with the armed command: out of reach, the overlay draws the
## walk-in path over hexes.
func _hover_far_enemy(runner: GdUnitSceneRunner, field: FieldMap) -> void:
	var interface := field.field_hud().battle_interface
	var model := Battle.controller.battlefield as GridBattlefieldModel
	var active := Battle.controller.active_actor()
	var best: BattleActor = null
	var best_distance := -1
	for enemy: BattleActor in Battle.controller.enemies:
		if enemy.hp <= 0 or model.cell_of(enemy) == null or model.cell_of(active) == null:
			continue
		var distance := GridMetric.distance(model.cell_of(enemy) as Vector2i, model.cell_of(active) as Vector2i)
		if distance > best_distance:
			best = enemy
			best_distance = distance
	if best == null:
		return
	var cell := model.cell_of(best) as Vector2i
	interface.call("_on_tile_hovered", {"x": cell.x, "y": cell.y})
	var overlay := field.combat_overlay() as CombatOverlay
	overlay.set_pointer(null, cell)
	await runner.simulate_frames(10, 16)


## Arms the party's longest-reaching command so the reach ring shows (strike's touching ring when
## nothing reaches farther).
func _arm_reaching_command(runner: GdUnitSceneRunner, field: FieldMap) -> void:
	var interface := field.field_hud().battle_interface
	var best: StringName = &"strike"
	var best_steps := 0
	for action_id: Variant in Battle.controller.get("_actions"):
		var action := Battle.controller.action_by_id(StringName(str(action_id)))
		if action != null and action.player_available and action.reach_steps() > best_steps:
			best = action.id
			best_steps = action.reach_steps()
	interface.select_pointer_action(best)
	print("REACH armed %s (%d hexes)" % [best, best_steps])
	await runner.simulate_frames(10, 16)


## The party at twice full size: bodies on touching hexes overlap (owner ruling H-a3).
func _capture_overlap(name: String, field: FieldMap) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var canvas := get_viewport().get_canvas_transform()
	var lead := canvas * field.player().global_position
	var region := Rect2i(Vector2i(lead) - Vector2i(160, 140), Vector2i(320, 200))
	region = region.intersection(Rect2i(Vector2i.ZERO, image.get_size()))
	var crop := image.get_region(region)
	crop.resize(crop.get_width() * 2, crop.get_height() * 2, Image.INTERPOLATE_NEAREST)
	var path := "%s/%s.png" % [_out_dir, name]
	assert_int(crop.save_png(path)).is_equal(OK)
	print("SHOT ", path)


func _settle(runner: GdUnitSceneRunner, stage: Node) -> void:
	for _guard: int in 600:
		if not stage.is_presenting_beats():
			return
		await runner.simulate_frames(1, 16)


func _to_ally_turn(runner: GdUnitSceneRunner, stage: Node) -> void:
	for _step: int in 30:
		if Battle.ended or Battle.controller.state == CombatController.State.ALLY_TURN:
			return
		await runner.simulate_frames(10, 16)
		await _settle(runner, stage)


func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [_out_dir, name]
	assert_int(image.save_png(path)).is_equal(OK)
	print("SHOT ", path)


## The harness leaves the boot menu (and whatever else it mounted) in the tree; production
## frees it on travel. Hide every root canvas item that is not the field scene.
func _hide_other_root_canvas_items(field_root: Node) -> void:
	for child: Node in get_tree().root.get_children():
		if child == field_root or child.is_ancestor_of(field_root):
			continue
		if child is CanvasItem:
			(child as CanvasItem).hide()
	var current := get_tree().current_scene
	if current is CanvasItem and current != field_root and not current.is_ancestor_of(field_root):
		(current as CanvasItem).hide()
