extends GdUnitTestSuite

const OCCLUDER_PATH := "res://world/facade_occluder.gd"
const TAVERN_TEXTURE := preload(
	"res://assets/generated/sprites/world/dom-four-arms-tavern--building-facade.png"
)

var _town: Node2D
var _building: Node2D
var _facade: Sprite2D


func before_test() -> void:
	_town = auto_free(Node2D.new()) as Node2D
	add_child(_town)
	_building = Node2D.new()
	_building.position = Vector2(1700, 1800)
	_town.add_child(_building)
	_facade = Sprite2D.new()
	_facade.texture = TAVERN_TEXTURE
	_facade.offset = Vector2(0, -384)
	_building.add_child(_facade)
	assert_bool(ResourceLoader.exists(OCCLUDER_PATH)).is_true()
	if ResourceLoader.exists(OCCLUDER_PATH):
		_building.add_child(load(OCCLUDER_PATH).new(_facade))


func test_player_on_opaque_texel_fades_facade_without_changing_actor() -> void:
	var player := _actor(&"player", Vector2(0, -136))
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal_approx(0.35, 0.001)
	assert_bool(player.visible).is_true()
	assert_float(player.modulate.a).is_equal(1.0)
	assert_int(player.z_index).is_equal(0)
	assert_int(_facade.z_index).is_equal(0)


func test_player_south_of_origin_does_not_fade() -> void:
	_actor(&"player", Vector2(0, 40))
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal(1.0)


func test_player_on_transparent_texel_does_not_fade() -> void:
	_actor(&"player", Vector2(0, -36))
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal(1.0)


func test_facade_restores_after_player_leaves() -> void:
	var player := _actor(&"player", Vector2(0, -136))
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal_approx(0.35, 0.001)
	player.position = _building.position + Vector2(0, 40)
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal_approx(1.0, 0.001)


func test_follower_alone_fades_facade() -> void:
	_actor(&"party_follower", Vector2(0, -136))
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal_approx(0.35, 0.001)


func test_generated_townsfolk_alone_fades_facade() -> void:
	_actor(&"generated_townsfolk", Vector2(0, -136))
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal_approx(0.35, 0.001)


func test_ungrouped_prop_does_not_fade() -> void:
	_actor(&"props", Vector2(0, -136))
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal(1.0)


func test_named_npc_without_actor_group_fades_facade() -> void:
	var npc := load("res://actors/npc/npc.tscn").instantiate() as NPC
	_town.add_child(npc)
	npc.global_position = _building.global_position + Vector2(0, -136)
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal_approx(0.35, 0.001)
	assert_bool(npc.visible).is_true()
	assert_float(npc.modulate.a).is_equal(1.0)


func test_actor_in_another_scene_does_not_fade() -> void:
	var actor := auto_free(Node2D.new()) as Node2D
	actor.add_to_group(&"player")
	actor.position = _building.global_position + Vector2(0, -136)
	add_child(actor)
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal(1.0)


func test_fade_does_not_change_serialized_game_state() -> void:
	var state_before := GameState.to_dict().duplicate(true)
	_actor(&"party_followers", Vector2(0, -136))
	await _settle_fade()
	assert_float(_facade.modulate.a).is_equal_approx(0.35, 0.001)
	assert_dict(GameState.to_dict()).is_equal(state_before)


func _settle_fade() -> void:
	# Physics starts the tween. Wait across frames so a long startup frame
	# cannot expire a SceneTreeTimer before the occluder has even run.
	for frame: int in 20:
		await get_tree().physics_frame


func _actor(group: StringName, offset: Vector2) -> Node2D:
	var actor := Node2D.new()
	actor.position = _building.position + offset
	actor.add_to_group(group)
	_town.add_child(actor)
	return actor
