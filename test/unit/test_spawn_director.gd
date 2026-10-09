extends GdUnitTestSuite
## E4.1 (#345): SpawnDirector slot state, the deterministic roll, rehydrate-then-roll, the
## per-scene cap, partial clears, and the `spawn_state` save surface.

const FIXTURE_SCENE := "res://test/fixtures/spawn_field.tscn"
const TABLE_ID := "test-ambient"
const WILDERNESS := {
	"world_seed": 1234,
	"day_index": 3,
	"respawn_policy": "wilderness",
	"thinning_tier": 0,
	"zhavar_rung_index": 0,
}

var _clock_backup: Dictionary


func before_test() -> void:
	_clock_backup = WorldClock.to_dict()
	SpawnDirector.set_tables_for_testing({FIXTURE_SCENE: [_table()]})


func after_test() -> void:
	WorldClock.from_dict(_clock_backup)
	SpawnDirector.set_tables_for_testing({}, true)


func _table(entries: Array = [], pack: Dictionary = {}, caps: Dictionary = {}) -> Dictionary:
	return {
		"schema": SpawnDirector.TABLE_SCHEMA,
		"id": TABLE_ID,
		"scene_path": FIXTURE_SCENE,
		"slots": [{
			"id": "hollow-east",
			"anchor": "SpawnSlotHollowEast",
			"respawn_days": 2,
			"entries": entries if not entries.is_empty() else [{"archetype_id": "bog-wight", "weight": 1}],
			"pack_size": pack if not pack.is_empty() else {"min": 3, "max": 3},
		}],
		"caps": caps,
	}


func _root() -> Node2D:
	var root: Node2D = auto_free(Node2D.new())
	root.name = "SpawnFixture"
	root.scene_file_path = FIXTURE_SCENE
	var anchor := Marker2D.new()
	anchor.name = "SpawnSlotHollowEast"
	anchor.position = Vector2(400, 300)
	root.add_child(anchor)
	add_child(root)
	return root


func _context(day: int) -> Dictionary:
	var context := WILDERNESS.duplicate()
	context["day_index"] = day
	return context


func test_valid_table_has_no_problems_and_each_invariant_is_reported() -> void:
	assert_array(Array(SpawnDirector.table_problems(_table()))).is_empty()
	var broken := _table([{"empty": true, "weight": 3}, {"archetype_id": "loam-boar", "weight": 0}])
	broken["slots"][0]["respawn_days"] = 0
	broken["slots"][0]["pack_size"] = {"min": 2, "max": 1}
	var problems := " | ".join(SpawnDirector.table_problems(broken))
	assert_str(problems).contains("respawn_days must be at least 1")
	assert_str(problems).contains("pack_size needs 1 <= min <= max")
	assert_str(problems).contains("weights must be positive integers")
	assert_str(problems).contains("needs a non-empty entry")


func test_same_save_and_day_rolls_the_same_slot() -> void:
	var entries := [
		{"archetype_id": "bog-wight", "weight": 40},
		{"archetype_id": "loam-boar", "weight": 40},
		{"empty": true, "weight": 20},
	]
	var pack := {"min": 1, "max": 3}
	var outcomes: Dictionary = {}
	for day: int in 20:
		var first := SpawnDirector.roll(99, TABLE_ID, "hollow-east", day, entries, pack)
		var again := SpawnDirector.roll(99, TABLE_ID, "hollow-east", day, entries, pack)
		assert_dict(again).is_equal(first)
		outcomes[str(first)] = true
	assert_int(outcomes.size()).override_failure_message(
		"twenty days of one slot all rolled the same thing; the day is not reaching the seed"
	).is_greater(1)


func test_populate_instantiates_a_day_stamped_pack_at_the_anchor() -> void:
	var director := SpawnDirector.new()
	var root := _root()
	var spawned := director.populate(root, _context(3))
	assert_int(spawned.size()).is_equal(3)
	var combat_ids: Dictionary = {}
	for hostile: Hostile in spawned:
		assert_str(String(hostile.unit_id)).is_equal("bog-wight")
		assert_str(String(hostile.group_id)).is_equal("test-ambient:hollow-east:3")
		assert_bool(hostile.is_queued_for_deletion()).is_false()
		var actor := hostile.battle_actor()
		assert_object(actor).is_not_null()
		assert_str(String(actor.combat_id)).is_equal(String(hostile.combat_id))
		combat_ids[hostile.combat_id] = true
	assert_int(combat_ids.size()).is_equal(3)
	var state := director.slot_state(TABLE_ID, "hollow-east")
	assert_int(int(state["spawned_day"])).is_equal(3)
	assert_int((state["members"] as Array).size()).is_equal(3)


func test_survivors_rehydrate_under_their_group_on_a_later_visit() -> void:
	var director := SpawnDirector.new()
	var first_visit := director.populate(_root(), _context(3))
	first_visit[0].mark_downed()
	# Leave and come back days later through a save round trip.
	var reloaded := SpawnDirector.new()
	reloaded.from_dict(JSON.parse_string(JSON.stringify(director.to_dict())))
	var second_visit := reloaded.populate(_root(), _context(9))
	assert_int(second_visit.size()).override_failure_message(
		"a partly cleared pack must come back without its downed member, and must not re-roll"
	).is_equal(2)
	for hostile: Hostile in second_visit:
		assert_str(String(hostile.group_id)).is_equal("test-ambient:hollow-east:3")


func test_slot_clears_when_every_member_is_downed_and_waits_out_its_cadence() -> void:
	var director := SpawnDirector.new()
	WorldClock.phase_count = 3 * WorldClock.PHASES.size()
	for hostile: Hostile in director.populate(_root(), _context(3)):
		hostile.mark_downed()
	var state := director.slot_state(TABLE_ID, "hollow-east")
	assert_array(state["members"]).is_empty()
	assert_int(int(state["cleared_day"])).is_equal(3)
	assert_int(director.populate(_root(), _context(4)).size()).override_failure_message(
		"respawn_days is 2: the slot must stay empty on day 4"
	).is_equal(0)
	var refilled := director.populate(_root(), _context(5))
	assert_int(refilled.size()).is_equal(3)
	assert_str(String(refilled[0].group_id)).is_equal("test-ambient:hollow-east:5")


func test_a_body_from_an_old_group_cannot_clear_the_next_one() -> void:
	var director := SpawnDirector.new()
	WorldClock.phase_count = 3 * WorldClock.PHASES.size()
	var old_pack := director.populate(_root(), _context(3))
	for index: int in old_pack.size() - 1:
		old_pack[index].mark_downed()
	var straggler := old_pack[old_pack.size() - 1]
	straggler.mark_downed()
	var new_pack := director.populate(_root(), _context(5))
	assert_int(new_pack.size()).is_equal(3)
	# A second downed emit from a body of the cleared group must be ignored.
	straggler.downed.emit(straggler)
	assert_int((director.slot_state(TABLE_ID, "hollow-east")["members"] as Array).size()).is_equal(3)


func test_a_pack_over_the_scene_cap_is_blocked_and_stays_eligible() -> void:
	SpawnDirector.set_tables_for_testing({FIXTURE_SCENE: [_table([], {}, {"max_alive": 2})]})
	var director := SpawnDirector.new()
	assert_int(director.populate(_root(), _context(3)).size()).is_equal(0)
	var state := director.slot_state(TABLE_ID, "hollow-east")
	assert_bool(state["blocked_by_cap"]).is_true()
	assert_int(int(state["cleared_day"])).is_equal(SpawnDirector.NEVER_CLEARED)


func test_the_empty_sentinel_clears_the_slot_without_spawning() -> void:
	var entries := [{"archetype_id": "bog-wight", "weight": 1}, {"empty": true, "weight": 50}]
	SpawnDirector.set_tables_for_testing({FIXTURE_SCENE: [_table(entries)]})
	var empty_day := -1
	for day: int in 50:
		if bool(SpawnDirector.roll(1234, TABLE_ID, "hollow-east", day, entries, {"min": 3, "max": 3})["empty"]):
			empty_day = day
			break
	assert_int(empty_day).is_greater_equal(0)
	var director := SpawnDirector.new()
	assert_int(director.populate(_root(), _context(empty_day)).size()).is_equal(0)
	assert_int(int(director.slot_state(TABLE_ID, "hollow-east")["cleared_day"])).is_equal(empty_day)


func test_a_none_policy_scene_refuses_every_table() -> void:
	var context := _context(3)
	context["respawn_policy"] = "none"
	assert_int(SpawnDirector.new().populate(_root(), context).size()).is_equal(0)


func test_spawn_state_rides_the_runtime_capture_and_restores() -> void:
	var saves: Node = SaveGame
	var backup: Dictionary = saves.capture_runtime_state()
	saves.spawn_director.populate(_root(), _context(3))
	var captured: Dictionary = saves.capture_runtime_state()
	assert_bool(captured.has("spawn_state")).is_true()
	assert_bool(SpawnDirector.validate_save_data(captured["spawn_state"])).is_true()
	saves.spawn_director.from_dict({})
	assert_bool(saves.restore_runtime_state(captured)).is_true()
	assert_int((saves.spawn_director.slot_state(TABLE_ID, "hollow-east")["members"] as Array).size()).is_equal(3)
	saves.restore_runtime_state(backup)


func test_corrupt_spawn_state_is_refused_and_an_absent_one_is_empty() -> void:
	assert_bool(SpawnDirector.validate_save_data({})).is_true()
	assert_bool(SpawnDirector.validate_save_data("nope")).is_false()
	assert_bool(SpawnDirector.validate_save_data({"slots": {"a:b": {"group_id": 3}}})).is_false()
	var director := SpawnDirector.new()
	director.from_dict({"slots": {"a:b": {"members": "bad"}}})
	assert_dict(director.to_dict()["slots"]).is_empty()


func test_canon_tables_all_pass_validation() -> void:
	# Whatever ships under canon/*/spawn_tables must load clean; a rejected table is logged and
	# silently missing from the game, so catch it here instead.
	var loaded := SpawnDirector.load_tables()
	var count := 0
	for scene_path: String in loaded:
		count += (loaded[scene_path] as Array).size()
		assert_bool(ResourceLoader.exists(scene_path)).is_true()
	var on_disk := 0
	for hub: String in DirAccess.get_directories_at(SpawnDirector.CANON_ROOT):
		var directory := "%s/%s/%s" % [SpawnDirector.CANON_ROOT, hub, SpawnDirector.TABLE_DIR]
		if DirAccess.dir_exists_absolute(directory):
			for file_name: String in DirAccess.get_files_at(directory):
				if file_name.ends_with(".json"):
					on_disk += 1
	assert_int(count).is_equal(on_disk)


## A pack placed inside alert range of where the party stands opens a fight on arrival (it broke
## the #282 populated-field benchmark). Every canon slot's nearest member must sit outside the
## alert radius of the scene's Player and of every arrival marker.
func test_no_canon_slot_alerts_the_party_on_arrival() -> void:
	var probe := (load("res://actors/hostile/hostile.tscn") as PackedScene).instantiate() as Hostile
	var alert_radius := probe.alert_radius
	probe.free()
	var loaded := SpawnDirector.load_tables()
	for scene_path: String in loaded:
		var scene := (load(scene_path) as PackedScene).instantiate() as Node2D
		var anchors: Array[String] = []
		for table: Dictionary in loaded[scene_path]:
			for slot: Dictionary in table.get("slots", []):
				anchors.append(str(slot.get("anchor", "")))
		var arrivals: Array[Node2D] = []
		var player := scene.find_child("Player", true, false) as Node2D
		if player != null:
			arrivals.append(player)
		for marker: Node in scene.find_children("Spawn*", "Marker2D", true, false):
			if not anchors.has(String(marker.name)):
				arrivals.append(marker as Node2D)
		for anchor_name: String in anchors:
			var anchor := scene.find_child(anchor_name, true, false) as Node2D
			assert_object(anchor).override_failure_message("%s: no anchor %s" % [scene_path, anchor_name]).is_not_null()
			if anchor == null:
				continue
			for arrival: Node2D in arrivals:
				var nearest := anchor.position.distance_to(arrival.position) - SpawnDirector.PACK_SPACING
				assert_float(nearest).override_failure_message(
					"%s: %s's pack would stand %.0f px from %s, inside the %.0f px alert radius"
					% [scene_path, anchor_name, nearest, arrival.name, alert_radius]
				).is_greater(alert_radius)
		scene.free()
