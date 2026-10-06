extends GdUnitTestSuite
## #412: enemy combat numbers off DRAMGID attributes, and wild per-instance variation.

const PACKET := "res://docs/enemy-curve-packet.md"
const FIXTURE_SCENE := "res://test/fixtures/variation_field.tscn"
const HOSTILE_SCENE := "res://actors/hostile/hostile.tscn"


func after_test() -> void:
	SpawnDirector.set_tables_for_testing({}, true)


## The packet's §2 table, read literally: `| id | grit | mus | hp → **hp'** | drift | atk → atk' |
## def → def' |`. Returns id -> {hp, attack, defense} (the derived side of each arrow).
func _packet_rows() -> Dictionary:
	var rows: Dictionary = {}
	var text := FileAccess.get_file_as_string(PACKET)
	for line: String in text.split("\n"):
		var cells := line.split("|", false)
		if cells.size() != 7 or not cells[3].contains("→") or not cells[1].strip_edges().is_valid_int():
			continue
		var derived := func(cell: String) -> int:
			return int(cell.split("→")[1].replace("*", "").strip_edges())
		rows[cells[0].strip_edges()] = {
			"grit": int(cells[1].strip_edges()),
			"muster": int(cells[2].strip_edges()),
			"hp": derived.call(cells[3]),
			"attack": derived.call(cells[5]),
			"defense": derived.call(cells[6]),
		}
	return rows


func test_the_packet_table_and_the_live_curve_cannot_drift() -> void:
	var rows := _packet_rows()
	assert_int(rows.size()).override_failure_message(
		"the packet's §2 table did not parse; the pin is not checking anything"
	).is_equal(6)
	for archetype_id: String in rows:
		var row: Dictionary = rows[archetype_id]
		assert_int(EnemyDerived.max_hp(row["grit"], row["muster"])).is_equal(row["hp"])
		assert_int(EnemyDerived.attack(row["muster"])).is_equal(row["attack"])
		assert_int(EnemyDerived.defense(row["grit"])).is_equal(row["defense"])


func test_every_archetype_and_set_piece_reaches_combat_on_the_curve() -> void:
	var rows := _packet_rows()
	for archetype_id: String in rows:
		var actor := EncounterCatalog.make_actor(StringName(archetype_id))
		assert_object(actor).is_not_null()
		var row: Dictionary = rows[archetype_id]
		assert_int(actor.max_hp).override_failure_message(archetype_id).is_equal(row["hp"])
		assert_int(actor.hp).is_equal(actor.max_hp)
		assert_int(actor.attack).override_failure_message(archetype_id).is_equal(row["attack"])
		assert_int(actor.defense).override_failure_message(archetype_id).is_equal(row["defense"])
	# Set-pieces are pinned to the curve too: no roll, whichever encounter builds them.
	var wight := EncounterCatalog.make_actor(&"bog-wight", &"bog-wight")
	assert_int(wight.max_hp).is_equal(rows["bog-wight"]["hp"])


func test_a_roll_is_a_pure_function_of_its_seed_and_stays_inside_the_band() -> void:
	for rng_seed: int in 300:
		var first := EnemyDerived.roll(rng_seed)
		assert_dict(EnemyDerived.roll(rng_seed)).is_equal(first)
		for stat: String in ["hp", "attack", "defense"]:
			assert_float(absf(float(first[stat]))).is_less_equal(EnemyDerived.VARIATION_BAND)


func test_the_tell_marks_both_tails_and_leaves_most_spawns_unremarked() -> void:
	var counts := {EnemyDerived.Tier.WEAK: 0, EnemyDerived.Tier.TYPICAL: 0, EnemyDerived.Tier.STRONG: 0}
	var samples := 4000
	for rng_seed: int in samples:
		counts[EnemyDerived.roll(rng_seed)["tier"]] += 1
	for tail: int in [EnemyDerived.Tier.WEAK, EnemyDerived.Tier.STRONG]:
		var share := float(counts[tail]) / samples
		assert_float(share).override_failure_message("tail %d share %.3f" % [tail, share]).is_between(0.14, 0.24)
	assert_float(float(counts[EnemyDerived.Tier.TYPICAL]) / samples).is_greater(0.5)


func test_apply_moves_all_three_numbers_and_respects_the_floors() -> void:
	var actor := EncounterCatalog.make_actor(&"cleaned-jawbrace-guard")
	EnemyDerived.apply(actor, {"hp": 0.15, "attack": 0.15, "defense": 0.15})
	assert_int(actor.max_hp).is_equal(44)
	assert_int(actor.hp).is_equal(44)
	assert_int(actor.attack).is_equal(7)
	assert_int(actor.defense).is_equal(5)
	var floor_actor := BattleActor.new()
	floor_actor.max_hp = 1
	floor_actor.attack = 1
	floor_actor.defense = 0
	EnemyDerived.apply(floor_actor, {"hp": -0.15, "attack": -0.15, "defense": -0.15})
	assert_int(floor_actor.max_hp).is_equal(1)
	assert_int(floor_actor.attack).is_equal(1)
	assert_int(floor_actor.defense).is_equal(0)


func _wild_table() -> Dictionary:
	return {
		"schema": SpawnDirector.TABLE_SCHEMA,
		"id": "variation-test",
		"scene_path": FIXTURE_SCENE,
		"slots": [{
			"id": "pack",
			"anchor": "SpawnSlotPack",
			"respawn_days": 1,
			"entries": [{"archetype_id": "cleaned-jawbrace-guard", "weight": 1}],
			"pack_size": {"min": 6, "max": 6},
		}],
	}


func _root() -> Node2D:
	var root: Node2D = auto_free(Node2D.new())
	root.scene_file_path = FIXTURE_SCENE
	var anchor := Marker2D.new()
	anchor.name = "SpawnSlotPack"
	root.add_child(anchor)
	add_child(root)
	return root


func _stats(hostiles: Array[Hostile]) -> Array:
	var result: Array = []
	for hostile: Hostile in hostiles:
		var actor := hostile.battle_actor()
		result.append([actor.max_hp, actor.attack, actor.defense, hostile.variation_tier])
	return result


func test_a_wild_pack_varies_and_a_reloaded_survivor_is_the_same_creature() -> void:
	SpawnDirector.set_tables_for_testing({FIXTURE_SCENE: [_wild_table()]})
	var context := {
		"world_seed": 42, "day_index": 2, "respawn_policy": "wilderness",
		"thinning_tier": 0, "zhavar_rung_index": 0,
	}
	var director := SpawnDirector.new()
	var first := _stats(director.populate(_root(), context))
	assert_int(first.size()).is_equal(6)
	var distinct: Dictionary = {}
	for row: Array in first:
		distinct[str(row)] = true
	assert_int(distinct.size()).override_failure_message(
		"six guards from one pack all rolled identical numbers: %s" % str(first)
	).is_greater(1)
	var reloaded := SpawnDirector.new()
	reloaded.from_dict(JSON.parse_string(JSON.stringify(director.to_dict())))
	context["day_index"] = 5
	assert_array(_stats(reloaded.populate(_root(), context))).is_equal(first)


func test_a_stronger_roll_stands_larger_than_a_weaker_one() -> void:
	var sizes: Dictionary = {}
	for tier: int in [EnemyDerived.Tier.WEAK, EnemyDerived.Tier.TYPICAL, EnemyDerived.Tier.STRONG]:
		var hostile := (load(HOSTILE_SCENE) as PackedScene).instantiate() as Hostile
		hostile.spawn_into_slot(
			EncounterCatalog.make_actor(&"bog-wight"), &"t:s:0", StringName("tell:%d" % tier), tier
		)
		_root().add_child(hostile)
		sizes[tier] = (hostile.get_node("Sprite2D") as Sprite2D).scale.y
	assert_float(sizes[EnemyDerived.Tier.STRONG]).is_greater(sizes[EnemyDerived.Tier.TYPICAL])
	assert_float(sizes[EnemyDerived.Tier.WEAK]).is_less(sizes[EnemyDerived.Tier.TYPICAL])
