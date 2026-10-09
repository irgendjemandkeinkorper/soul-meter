extends GdUnitTestSuite
## #412 rendered evidence: a Wilds spawn pack with one STRONG and one WEAK roll side by side.
## Run explicitly with scripts/test.sh -a test/manual/capture_spawn_variation.gd under Xvfb;
## the PNG lands in user://qa/spawn_variation.png.

const TABLE_ID := "wilds-glade-ambient"
const SLOT_ID := "glade-south"
const DAY := 0

var _saved_state: Dictionary
var _saved_clock: Dictionary
var _saved_spawns: Dictionary
var _boot_visible := true


func before_test() -> void:
	_saved_state = GameState.to_dict().duplicate(true)
	_saved_clock = WorldClock.to_dict()
	_saved_spawns = SaveGame.spawn_director.to_dict()
	get_tree().root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		_boot_visible = boot.visible
		boot.hide()


func after_test() -> void:
	GameState.from_dict(_saved_state)
	WorldClock.from_dict(_saved_clock)
	SaveGame.spawn_director.from_dict(_saved_spawns)
	var boot := get_tree().current_scene as CanvasItem
	if boot != null:
		boot.visible = _boot_visible


func test_capture_a_strong_and_a_weak_wild_spawn() -> void:
	var table: Dictionary = SpawnDirector.tables_for_scene("res://world/test_room.tscn")[0]
	var slot: Dictionary = table["slots"][0]
	var world_seed := _find_seed(slot)
	assert_int(world_seed).is_greater(0)
	GameState.world_seed = world_seed
	WorldClock.phase_count = DAY * WorldClock.PHASES.size()
	SaveGame.spawn_director.from_dict({})
	var scene: Node = auto_free((load("res://world/test_room.tscn") as PackedScene).instantiate())
	add_child(scene)
	await get_tree().process_frame
	var player := scene.find_child("Player", true, false) as Node2D
	player.global_position = Vector2(1300, 470)
	var spawned := SaveGame.spawn_director.populate(scene)
	assert_int(spawned.size()).is_equal(2)
	for hostile: Hostile in spawned:
		var actor := hostile.battle_actor()
		print("%s tier=%d hp=%d atk=%d def=%d scale=%.3f" % [
			hostile.name, hostile.variation_tier, actor.max_hp, actor.attack, actor.defense,
			(hostile.get_node("Sprite2D") as Sprite2D).scale.y])
	# Evidence of the field only: hide every UI layer, frame the pack with the player's camera.
	for layer: Node in get_tree().root.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).hide()
	for control: Node in get_tree().root.find_children("*", "Control", true, false):
		if not scene.is_ancestor_of(control):
			(control as Control).hide()
	var camera := player.get_node("Camera2D") as Camera2D
	camera.enabled = true
	camera.make_current()
	camera.zoom = Vector2(2.0, 2.0)
	camera.limit_enabled = false
	camera.global_position = spawned[0].global_position.lerp(spawned[1].global_position, 0.5) + Vector2(0, -60)
	camera.reset_smoothing()
	for _frame: int in 30:
		await get_tree().process_frame
	var image := get_tree().root.get_viewport().get_texture().get_image()
	var out := "user://qa/spawn_variation.png"
	assert_int(image.save_png(out)).is_equal(OK)
	print("saved ", ProjectSettings.globalize_path(out), " seed=", world_seed)


func _find_seed(slot: Dictionary) -> int:
	var location := LocationRegistry.by_scene("res://world/test_room.tscn")
	for candidate: int in range(1, 5000):
		var rolled := SpawnDirector.roll(
			candidate, TABLE_ID, SLOT_ID, DAY,
			SpawnMath.scaled_weights(slot["entries"], location.thinning_tier), slot["pack_size"]
		)
		if bool(rolled["empty"]) or int(rolled["count"]) != 2:
			continue
		var group := SpawnDirector.group_id_for(TABLE_ID, SLOT_ID, DAY)
		var tiers := [
			int(EnemyDerived.roll(EnemyDerived.spawn_seed(candidate, group, 0))["tier"]),
			int(EnemyDerived.roll(EnemyDerived.spawn_seed(candidate, group, 1))["tier"]),
		]
		if EnemyDerived.Tier.STRONG in tiers and EnemyDerived.Tier.WEAK in tiers:
			return candidate
	return -1
