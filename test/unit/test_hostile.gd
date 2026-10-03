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


## D4 lock: a hostile with a `required_flag` stands dimmed and deaf until the flag is set, then
## opens with no prompt and no press — the next alert is simply accepted.
func test_locked_hostile_stays_deaf_and_dimmed_until_its_flag_is_set() -> void:
	var root := _root()
	root.add_child(CombatField.new())
	var had_flag: bool = GameState.flag_is_true("test_hostile_gate")
	GameState.set_flag("test_hostile_gate", false)
	var packed := load(HOSTILE_SCENE) as PackedScene
	var hostile := packed.instantiate() as Node2D
	hostile.name = "Wight"
	hostile.set("unit_id", &"bog-wight")
	hostile.set("required_flag", "test_hostile_gate")
	root.add_child(hostile)

	assert_bool(hostile.call("is_unlocked")).is_false()
	assert_that(hostile.modulate).is_equal(Hostile.LOCKED_MODULATE)
	assert_bool(hostile.call("request_alert")).is_false()
	assert_int(hostile.get("state")).is_equal(0)

	GameState.set_flag("test_hostile_gate", true)
	assert_bool(hostile.call("is_unlocked")).is_true()
	assert_that(hostile.modulate).override_failure_message(
		"an opened gate hands the tint back"
	).is_equal(Color.WHITE)
	assert_bool(hostile.call("request_alert")).is_true()
	GameState.set_flag("test_hostile_gate", had_flag)


## Two writers of `modulate`: the lock tints a standing hostile, `mark_downed()` tints a corpse.
## A gate that flips after the kill must never un-dim the body.
func test_a_flag_change_never_undims_a_downed_hostile() -> void:
	var root := _root()
	root.add_child(CombatField.new())
	var had_flag: bool = GameState.flag_is_true("test_hostile_gate")
	GameState.set_flag("test_hostile_gate", true)
	var packed := load(HOSTILE_SCENE) as PackedScene
	var hostile := packed.instantiate() as Node2D
	hostile.name = "Wight"
	hostile.set("unit_id", &"bog-wight")
	hostile.set("required_flag", "test_hostile_gate")
	root.add_child(hostile)
	hostile.call("mark_downed")
	var corpse_tint: Color = hostile.modulate
	assert_that(corpse_tint).is_not_equal(Color.WHITE)

	GameState.set_flag("test_hostile_gate", false)
	assert_that(hostile.modulate).is_equal(corpse_tint)
	GameState.set_flag("test_hostile_gate", true)
	assert_that(hostile.modulate).is_equal(corpse_tint)
	assert_bool(hostile.call("request_alert")).is_false()
	GameState.set_flag("test_hostile_gate", had_flag)


## D7 ruling 3: a group the party already put down stays down across scene loads.
func test_hostile_whose_group_is_already_defeated_frees_itself() -> void:
	var root := _root()
	root.add_child(CombatField.new())
	var had_flag: bool = GameState.flag_is_true("defeated_bog_wight")
	GameState.set_flag("defeated_bog_wight", true)
	var packed := load(HOSTILE_SCENE) as PackedScene
	var hostile := packed.instantiate() as Node2D
	hostile.name = "Wight"
	hostile.set("unit_id", &"bog-wight")
	hostile.set("group_id", &"bog-wight")
	root.add_child(hostile)
	# Retirement hides and disarms the mob on the spot and frees it on a later idle frame.
	assert_bool(hostile.visible).is_false()
	assert_bool(hostile.is_in_group(&"hostile")).is_false()
	await get_tree().process_frame
	await get_tree().process_frame
	GameState.set_flag("defeated_bog_wight", had_flag)
	assert_object(root.get_node_or_null("Wight")) \
		.override_failure_message("A hostile whose group is already defeated must despawn.") \
		.is_null()


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
