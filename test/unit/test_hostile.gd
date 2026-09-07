extends GdUnitTestSuite

const HOSTILE_SCENE := "res://actors/hostile/hostile.tscn"


class SafeField extends FieldMap:
	func no_combat_zone() -> bool:
		return true


class CombatField extends FieldMap:
	func no_combat_zone() -> bool:
		return false


func test_alert_is_accepted_once_on_a_combat_field() -> void:
	var root := _root()
	root.add_child(CombatField.new())
	var hostile := _spawn(root, "Wight")
	if hostile == null:
		return
	assert_bool(hostile.call("request_alert")).is_true()
	assert_int(hostile.get("state")).is_equal(1)
	assert_bool(hostile.call("request_alert")).is_false()


func test_chain_alert_advances_one_hop_even_when_admission_is_immediate() -> void:
	var root := _root()
	var field := CombatField.new()
	root.add_child(field)
	var first := _spawn(root, "First")
	var second := _spawn(root, "Second")
	var third := _spawn(root, "Third")
	if first == null or second == null or third == null:
		return
	first.position = Vector2.ZERO
	second.position = Vector2(100, 0)
	third.position = Vector2(200, 0)
	for hostile: Node2D in [first, second, third]:
		hostile.set("chain_radius", 120.0)
		hostile.connect("alerted", func(actor: Node2D) -> void: actor.set("state", 2))
	first.set("state", 2)
	field.propagate_alerts()
	assert_int(second.get("state")).is_equal(2)
	assert_int(third.get("state")).is_equal(0)
	field.propagate_alerts()
	assert_int(third.get("state")).is_equal(2)


func test_idle_hostile_caches_its_actor_and_does_not_tick() -> void:
	var root := _root()
	var hostile := _spawn(root, "Wight")
	if hostile == null:
		return
	var actor: BattleActor = hostile.call("battle_actor")
	assert_object(actor).is_not_null()
	assert_object(hostile.call("battle_actor")).is_same(actor)
	assert_str(String(actor.archetype_id)).is_equal("bog-wight")
	assert_str(String(actor.combat_id)).is_not_empty()
	assert_str(String(hostile.get("combat_id"))).is_equal(String(actor.combat_id))
	assert_bool(hostile.is_processing()).is_false()
	assert_bool(hostile.is_physics_processing()).is_false()


func test_actor_built_before_ready_receives_the_authored_combat_id() -> void:
	var root := _root()
	var packed := load(HOSTILE_SCENE) as PackedScene
	var hostile := packed.instantiate() as Node2D
	hostile.name = "EarlyActor"
	hostile.set("unit_id", &"bog-wight")
	var actor: BattleActor = hostile.call("battle_actor")
	root.add_child(hostile)
	assert_object(hostile.call("battle_actor")).is_same(actor)
	assert_str(String(actor.combat_id)).is_not_empty()
	assert_str(String(actor.combat_id)).is_equal(String(hostile.get("combat_id")))


func test_authored_node_paths_produce_distinct_repeatable_ids() -> void:
	var root := _root()
	var first := _spawn(root, "First")
	var second := _spawn(root, "Second")
	if first == null or second == null:
		return
	var first_id := String(first.get("combat_id"))
	assert_str(first_id).is_not_equal(String(second.get("combat_id")))
	first.free()
	var replacement := _spawn(root, "First")
	assert_str(String(replacement.get("combat_id"))).is_equal(first_id)


func test_safe_field_refuses_alerts() -> void:
	var root := _root()
	root.add_child(SafeField.new())
	var hostile := _spawn(root, "Wight")
	if hostile == null:
		return
	assert_bool(hostile.call("request_alert")).is_false()
	assert_int(hostile.get("state")).is_equal(0)


func test_downed_hostile_retains_its_actor_and_cannot_alert() -> void:
	var root := _root()
	var hostile := _spawn(root, "Wight")
	if hostile == null:
		return
	var actor: BattleActor = hostile.call("battle_actor")
	hostile.call("mark_downed")
	assert_int(actor.hp).is_equal(0)
	assert_object(hostile.call("battle_actor")).is_same(actor)
	assert_bool(hostile.call("request_alert")).is_false()


func _root() -> Node2D:
	var root: Node2D = auto_free(Node2D.new())
	root.name = "HostileFixture"
	root.scene_file_path = "res://test/fixtures/hostile_field.tscn"
	add_child(root)
	return root


func _spawn(root: Node, node_name: String) -> Node2D:
	var packed := load(HOSTILE_SCENE) as PackedScene
	assert_object(packed).is_not_null()
	if packed == null:
		return null
	var hostile := packed.instantiate() as Node2D
	hostile.name = node_name
	hostile.set("unit_id", &"bog-wight")
	root.add_child(hostile)
	return hostile
