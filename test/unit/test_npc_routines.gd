extends GdUnitTestSuite
## FR-504a §2/§5 routine-table invariants: the cap is a number (criterion 7),
## absence is declared rather than accidental (criterion 4), and quest-critical
## NPCs stay reachable in at least two phases (criterion 5 / FR-905 §3.4).
##
## Since #385 the rows live in `canon/<hub>/characters/*.json`, so this suite
## also pins the read itself: the table has to come off disk, and it has to
## arrive with the coordinates the GDScript table used to hold.

const CANON_CHARACTERS := "res://canon/dom/characters"


func test_routine_count_is_within_the_cap() -> void:
	assert_int(NpcRoutines.routine_count()).is_between(1, NpcRoutines.ROUTINE_CAP)


func test_every_routine_declares_every_phase() -> void:
	# Criterion 4: an NPC is findable in every phase or explicitly declared
	# absent — a missing phase key would be an ACCIDENTAL nowhere.
	for npc_id: String in NpcRoutines.ROUTINES:
		var routine: Dictionary = NpcRoutines.ROUTINES[npc_id]
		assert_int(routine.size()).override_failure_message(
			"Routine '%s' must declare exactly the four phases." % npc_id
		).is_equal(WorldClock.PHASES.size())
		for phase: StringName in WorldClock.PHASES:
			assert_bool(routine.has(phase)).override_failure_message(
				"Routine '%s' is missing phase '%s'." % [npc_id, phase]
			).is_true()


func test_present_rows_carry_position_and_state() -> void:
	for npc_id: String in NpcRoutines.ROUTINES:
		for phase: StringName in WorldClock.PHASES:
			var row := NpcRoutines.placement(npc_id, phase)
			assert_bool(row.is_empty()).is_false()
			if bool(row["present"]):
				assert_bool(row["position"] is Vector2).is_true()
				assert_bool(row["state"] is StringName).is_true()
				assert_bool(row["state"] != NpcRoutines.ABSENT).is_true()


func test_quest_giver_routines_stay_reachable_in_two_phases() -> void:
	# FR-905 §3.4: a quest-critical interaction must be reachable in ≥ 2
	# phases. Collect every Dom side-quest actor plus authored quest givers.
	var quest_actors: Array[String] = []
	for quest: DomSideQuest in QuestRegistry.DOM_SIDE_QUESTS:
		if not quest.giver_actor_id.is_empty():
			quest_actors.append(quest.giver_actor_id)
		for participant in quest.participant_actor_ids:
			quest_actors.append(participant)
	quest_actors.append("sella-varn")  # BELLHOUSE_REPAIR giver
	for actor_id in quest_actors:
		assert_int(NpcRoutines.present_phase_count(actor_id)).override_failure_message(
			"Quest-critical NPC '%s' must be present in at least two phases." % actor_id
		).is_greater_equal(2)


func test_declared_agnostic_and_routines_are_disjoint() -> void:
	for npc_id in NpcRoutines.DECLARED_PHASE_AGNOSTIC:
		assert_bool(NpcRoutines.has_routine(npc_id)).override_failure_message(
			"'%s' is both routined and declared phase-agnostic." % npc_id
		).is_false()


func test_placement_contract() -> void:
	assert_bool(NpcRoutines.placement("no-such-npc", &"morning").is_empty()).is_true()
	var night := NpcRoutines.placement("sella-varn", &"night")
	assert_bool(bool(night["present"])).is_false()
	var morning := NpcRoutines.placement("sella-varn", &"morning")
	assert_bool(bool(morning["present"])).is_true()
	assert_bool(morning["position"] is Vector2).is_true()


func test_unrouted_npc_counts_all_phases_reachable() -> void:
	assert_int(NpcRoutines.present_phase_count("branek-coiljaw")).is_equal(4)


func test_routines_are_read_from_the_character_documents() -> void:
	# #385: the table is a READ of canon, not a literal that happens to agree
	# with it. Editing an NPC's document must move the NPC.
	assert_bool(NpcRoutines.ROUTINES.is_empty()).override_failure_message(
		"no routines loaded — canon/<hub>/characters is unreadable from the runtime"
	).is_false()
	for npc_id: String in NpcRoutines.ROUTINES:
		var document := _document(npc_id)
		var authored: Dictionary = document["routine"]
		assert_int(authored.size()).override_failure_message(
			"'%s' routine size disagrees with its document" % npc_id
		).is_equal((NpcRoutines.ROUTINES[npc_id] as Dictionary).size())
		for phase: String in authored:
			var row := NpcRoutines.placement(npc_id, StringName(phase))
			if authored[phase] == null:
				assert_bool(bool(row["present"])).override_failure_message(
					"'%s' is authored absent in %s but the table says present" % [npc_id, phase]
				).is_false()
				continue
			var position: Array = authored[phase]["position"]
			assert_vector(row["position"]).override_failure_message(
				"'%s' %s position drifted from its document" % [npc_id, phase]
			).is_equal(Vector2(float(position[0]), float(position[1])))
			assert_str(String(row["state"])).is_equal(String(authored[phase]["state"]))


func test_the_declared_phase_agnostic_list_is_read_from_canon() -> void:
	for npc_id in NpcRoutines.DECLARED_PHASE_AGNOSTIC:
		assert_bool(bool(_document(npc_id)["phase_agnostic"])).override_failure_message(
			"'%s' is listed phase-agnostic but its document does not say so" % npc_id
		).is_true()


func test_the_dom_routine_roster_is_unchanged_by_the_canon_move() -> void:
	# #385 required a LOSSLESS migration, so these three values are pinned here
	# rather than read back out of canon: a compare against the source it came
	# from could not fail. Sella's morning post is her bell-house post.
	assert_array(NpcRoutines.ROUTINES.keys()).contains(
		["sella-varn", "toma-reedhand", "hadrik-vale"]
	)
	assert_int(NpcRoutines.routine_count()).is_equal(3)
	assert_vector(NpcRoutines.placement("sella-varn", &"morning")["position"]).is_equal(
		Vector2(2820, 1525)
	)
	assert_str(
		String(NpcRoutines.placement("toma-reedhand", &"evening")["state"])
	).is_equal("drinking")
	# The clerk does not move between the two working phases; only his evening
	# lamplight seat differs.
	assert_vector(NpcRoutines.placement("hadrik-vale", &"afternoon")["position"]).is_equal(
		NpcRoutines.placement("hadrik-vale", &"morning")["position"]
	)
	assert_array(NpcRoutines.DECLARED_PHASE_AGNOSTIC).is_equal(["branek-coiljaw"])


func _document(npc_id: String) -> Dictionary:
	var path := CANON_CHARACTERS.path_join("%s.json" % npc_id)
	var file := FileAccess.open(path, FileAccess.READ)
	assert_object(file).override_failure_message("no canon document at %s" % path).is_not_null()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	assert_bool(parsed is Dictionary).is_true()
	return parsed
