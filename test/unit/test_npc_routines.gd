extends GdUnitTestSuite
## FR-504a §2/§5 routine-table invariants: the cap is a number (criterion 7),
## absence is declared rather than accidental (criterion 4), and quest-critical
## NPCs stay reachable in at least two phases (criterion 5 / FR-905 §3.4).


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
