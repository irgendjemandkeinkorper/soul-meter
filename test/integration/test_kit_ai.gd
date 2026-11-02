extends GdUnitTestSuite
## The class-kit enemy AI (combat polish, owner ruling 2026-11-02: "you lead 5, AI runs 5").
## Enemies built from roster members fight with their own class kit through the player's
## gates; the 5v5 class demo (one member per class) runs to an end.

var _saved_soul := 0.0
var _controllers: Array[CombatController] = []


func before_test() -> void:
	_saved_soul = GameState.soul_meter


func after_test() -> void:
	GameState.soul_meter = _saved_soul
	for controller: CombatController in _controllers:
		for actor: BattleActor in controller.allies + controller.enemies:
			if actor.class_resource != null:
				actor.class_resource.host = null
	_controllers.clear()


func test_every_demo_member_is_a_legal_character_of_their_class() -> void:
	for class_id: String in ClassDemo.PLAYER_SIDE + ClassDemo.AI_SIDE:
		var member := ClassDemo.member(class_id)
		assert_str(member.class_id).is_equal(class_id)
		assert_str(member.display_name).is_equal(str(ClassCatalog.by_id(class_id)["name"]))
		assert_str(member.major_element).override_failure_message(class_id).is_not_empty()
		assert_int(member.max_hp).is_greater(0)
	var all := ClassDemo.PLAYER_SIDE + ClassDemo.AI_SIDE
	all.sort()
	var catalog: Array[String] = []
	for row: Dictionary in ClassCatalog.ALL:
		catalog.append(str(row["id"]))
	catalog.sort()
	assert_array(all).is_equal(catalog)


## Allies stand still; the AI side closes in and fights with its own kits. Nothing an enemy
## does spends the player's Soul Gauge, and every enemy action is one its class could take.
func test_the_ai_side_fights_with_its_own_kit_and_never_spends_the_gauge() -> void:
	var controller := _demo_battle()
	var kits := {}
	for enemy: BattleActor in controller.enemies:
		var ids: Array[StringName] = [&"move"]
		for action: CombatAction in KitAI.kit_actions(enemy):
			ids.append(action.id)
		kits[enemy.combat_id] = ids
	var used := {}
	var strays: Array[String] = []
	controller.event_emitted.connect(func(event: CombatEvent) -> void:
		if event.type != &"action_resolved" or not kits.has(event.actor_id):
			return
		var action_id := StringName(str(event.data.get("action_id", "")))
		used[action_id] = true
		if not (kits[event.actor_id] as Array).has(action_id):
			strays.append("%s used %s" % [event.actor_id, action_id])
	)
	GameState.soul_meter = 40.0
	for _turn: int in 60:
		if controller.state == CombatController.State.FINISHED:
			break
		if controller.state == CombatController.State.ALLY_TURN:
			controller.end_turn()
	assert_array(strays).is_empty()
	assert_float(GameState.soul_meter).is_equal(40.0)
	used.erase(&"move")
	assert_int(used.size()).override_failure_message("used: %s" % str(used.keys())).is_greater_equal(3)


## The demo with both sides run by KitAI (the player's side through the player's own submit
## path) ends in a victory or a defeat, never a stall.
func test_the_ten_class_demo_plays_to_an_end() -> void:
	var controller := _demo_battle()
	var steps := 0
	while controller.state != CombatController.State.FINISHED and steps < 600:
		steps += 1
		if controller.state != CombatController.State.ALLY_TURN:
			break
		var actor := controller.active_actor()
		var plan := KitAI.plan_step(controller, actor, [])
		var result := {}
		match str(plan.get("kind", "pass")):
			"act":
				var action := plan["action"] as CombatAction
				result = controller.submit_action(action.id, plan.get("target") as BattleActor, plan.get("options", {}))
			"move":
				result = controller.submit_action(&"move", null, {"destination": plan["destination"]})
		if not bool(result.get("allowed", false)):
			controller.end_turn()
	assert_int(controller.state).override_failure_message("stalled after %d steps" % steps).is_equal(CombatController.State.FINISHED)


func _demo_battle() -> CombatController:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), _grid_model(12, 6), rules)
	var allies: Array[BattleActor] = []
	var index := 0
	for member: PartyMember in ClassDemo.party(ClassDemo.PLAYER_SIDE):
		allies.append(BattleActor.from_party_member(member, index))
		index += 1
	var enemies: Array[BattleActor] = []
	for member: PartyMember in ClassDemo.party(ClassDemo.AI_SIDE):
		enemies.append(BattleActor.from_party_member(member, -1))
	controller.start(allies, enemies, ClassDemo.ENCOUNTER_ID)
	_controllers.append(controller)
	return controller


func _grid_model(width: int, height: int) -> GridBattlefieldModel:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var ground := auto_free(TileMapLayer.new()) as TileMapLayer
	ground.tile_set = tile_set
	for y: int in height:
		for x: int in width:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var model := GridBattlefieldModel.new()
	model.configure(load("res://data/combat/combat_rules.tres") as CombatRules)
	model.build_grid(ground)
	return model
