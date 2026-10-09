extends GdUnitTestSuite
## #412 rendered evidence: a Wilds spawn pack with one STRONG and one WEAK roll side by side.
## Run explicitly with scripts/test.sh -a test/manual/capture_spawn_variation.gd under Xvfb;
## the PNG lands in user://qa/spawn_variation.png.

const TABLE_ID := "wilds-glade-ambient"
const SLOT_ID := "glade-south"
const DAY := 0
const TELL_ARCHETYPES := [
	"bog-wight", "loam-maddened-boar", "gnaal-breach-hound",
	"gnaal-rift-scavenger", "mustered-bloodbellow", "cleaned-jawbrace-guard",
]

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
		var sprite := hostile.get_node("Sprite2D") as Sprite2D
		var material := sprite.material as ShaderMaterial
		assert_object(material).override_failure_message("wild wight must load its tell mask").is_not_null()
		if material != null:
			assert_object(material.get_shader_parameter(&"tell_mask")).is_not_null()
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


## #445: actual shader renders at source resolution, plus a typical reference.
## Save per-archetype pairs as well as the labeled sheet for close inspection.
func test_capture_all_six_tell_masks() -> void:
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(256, 256)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.world_2d = World2D.new()
	add_child(viewport)
	var sprite := Sprite2D.new()
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport.add_child(sprite)
	var renders: Array[Image] = []
	for archetype: String in TELL_ARCHETYPES:
		var source_path := UnitArt.texture_path(archetype)
		var mask_path := source_path.trim_suffix(".png") + Hostile.TELL_MASK_SUFFIX
		sprite.texture = load(source_path) as Texture2D
		var mask := load(mask_path) as Texture2D
		assert_object(mask).override_failure_message(mask_path).is_not_null()
		var baseline: Image
		for tier: int in [EnemyDerived.Tier.TYPICAL, EnemyDerived.Tier.STRONG, EnemyDerived.Tier.WEAK]:
			sprite.material = null
			if tier != EnemyDerived.Tier.TYPICAL:
				var material := ShaderMaterial.new()
				material.shader = Hostile.TELL_SHADER
				material.set_shader_parameter(&"tell_mask", mask)
				material.set_shader_parameter(&"tell_color", Hostile.TELL_COLORS[tier])
				sprite.material = material
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			var rendered := viewport.get_texture().get_image()
			if tier == EnemyDerived.Tier.TYPICAL:
				baseline = rendered
			else:
				_assert_tint_is_local(archetype, baseline, rendered, mask.get_image())
			renders.append(rendered)
			var tier_name := "typical" if tier == EnemyDerived.Tier.TYPICAL else ("strong" if tier == EnemyDerived.Tier.STRONG else "weak")
			assert_int(rendered.save_png("user://qa/%s--%s.png" % [archetype, tier_name])).is_equal(OK)
	# A separate viewport keeps the sheet independent of the field camera/UI.
	var sheet_viewport := auto_free(SubViewport.new()) as SubViewport
	sheet_viewport.size = Vector2i(1600, 1040)
	sheet_viewport.world_2d = World2D.new()
	sheet_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(sheet_viewport)
	var background := ColorRect.new()
	background.size = Vector2(sheet_viewport.size)
	background.color = DS.STONE_1
	sheet_viewport.add_child(background)
	_sheet_label(sheet_viewport, "#445  |  TELL MASKS  |  idle / SE / frame 0", Vector2(24, 8))
	_sheet_label(sheet_viewport, "Live variation_tell shader; existing colors and strength. Source size (256px); equal scale for tint comparison.", Vector2(24, 34))
	for index: int in TELL_ARCHETYPES.size():
		var origin := Vector2(24 + (index % 2) * 792, 76 + (index / 2) * 316)
		_sheet_label(sheet_viewport, TELL_ARCHETYPES[index], origin)
		for column: int in 3:
			_sheet_label(sheet_viewport, ["TYPICAL / reference", "STRONG / ember", "WEAK / pale"][column], origin + Vector2(column * 256, 24))
			var tile := Sprite2D.new()
			tile.centered = false
			tile.position = origin + Vector2(column * 256, 48)
			tile.texture = ImageTexture.create_from_image(renders[index * 3 + column])
			sheet_viewport.add_child(tile)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var out := "user://qa/tell-masks-contact-sheet.png"
	assert_int(sheet_viewport.get_texture().get_image().save_png(out)).is_equal(OK)
	print("saved ", ProjectSettings.globalize_path(out))


func _sheet_label(viewport: SubViewport, text: String, position: Vector2) -> void:
	var label := Label.new()
	label.theme = ThemeBuilder.build()
	label.text = text
	label.position = position
	viewport.add_child(label)


func _assert_tint_is_local(archetype: String, baseline: Image, tinted: Image, mask: Image) -> void:
	if mask.is_compressed():
		mask.decompress()
	var changed := 0
	var outside_mask := 0
	var alpha_changed := 0
	for y: int in baseline.get_height():
		for x: int in baseline.get_width():
			var before := baseline.get_pixel(x, y)
			var after := tinted.get_pixel(x, y)
			if not is_equal_approx(before.a, after.a):
				alpha_changed += 1
			if before != after:
				changed += 1
				if mask.get_pixel(x, y).r == 0.0:
					outside_mask += 1
	assert_int(changed).override_failure_message(archetype + ": shader did not tint any pixels").is_greater(0)
	assert_int(outside_mask).override_failure_message(archetype + ": tint escaped mask").is_equal(0)
	assert_int(alpha_changed).override_failure_message(archetype + ": tint changed silhouette alpha").is_equal(0)


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
