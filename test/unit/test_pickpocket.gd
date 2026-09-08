extends GdUnitTestSuite
## #284 / game-identity ruling 7 ("stats matter outside combat"). Verb 3 of 4.
##
## Pickpocketing is ONE committed `slip` check per NPC. Two things are pinned:
## the attempt cannot be repeated (an unlimited retry turns any non-zero chance
## into a certainty and makes the skill decorative), and being caught writes to
## the consequence ledgers rather than printing a message and moving on.

const NPC_SCENE := preload("res://actors/npc/npc.tscn")
const POCKET_GP := 12

var _flags_before: Dictionary
var _gp_before: int
var _renown_before: Dictionary
var _reputation_before: Dictionary
var _party_before: Array[PartyMember] = []


func before_test() -> void:
	_flags_before = GameState.flags.duplicate(true)
	_gp_before = GameState.gp
	_renown_before = Renown.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_party_before = GameState.party.duplicate()
	# `SkillCheck.preview()` returns 0.0 without a protagonist, and a 0% check
	# cannot succeed on ANY roll — so without one every case here would pass or
	# fail for the wrong reason. The id must be PROTAGONIST_ID specifically:
	# `GameState.protagonist()` matches on that id (or the protagonist's display
	# name), not on party position, so an arbitrarily named party[0] resolves to
	# null and silently makes every check impossible.
	var thief := PartyMember.new()
	thief.id = GameState.PROTAGONIST_ID
	thief.attributes["alacrity"] = 4
	GameState.party = [thief]


func after_test() -> void:
	GameState.flags = _flags_before.duplicate(true)
	GameState.gp = _gp_before
	GameState.party = _party_before
	Renown.from_dict(_renown_before)
	Reputation.from_dict(_reputation_before)


func _npc_with_pocket(pocket_id: String, faction: String = "") -> NPC:
	var npc: NPC = auto_free(NPC_SCENE.instantiate())
	npc.npc_name = "Test Bystander"
	npc.pocket_id = pocket_id
	npc.pocket_skill = "slip"
	npc.pocket_gp = POCKET_GP
	npc.pocket_faction = faction
	return npc


## A roll of 1 beats any effective percentage; 100 loses to all of them. The
## check caps at MAX_EFFECTIVE_PERCENT (95), so nothing else forces an outcome.
func _certain_success() -> Array[int]:
	var rolls: Array[int] = [1]
	return rolls


func _certain_failure() -> Array[int]:
	var rolls: Array[int] = [100, 100]
	return rolls


func test_an_npc_without_a_pocket_id_cannot_be_robbed() -> void:
	var npc := _npc_with_pocket("")
	assert_bool(npc.has_pocket()).is_false()
	var result := npc.attempt_pickpocket()
	assert_bool(bool(result["attempted"])).is_false()
	assert_str(str(result["reason"])).is_equal("no_pocket")


func test_a_successful_lift_grants_the_pocket_and_closes_it() -> void:
	var npc := _npc_with_pocket("test-pocket-success")
	var before := GameState.gp

	var result := npc.attempt_pickpocket(_certain_success())

	assert_bool(bool(result["attempted"])).is_true()
	assert_bool(bool(result["success"])).is_true()
	assert_int(GameState.gp).override_failure_message(
		"a lifted pocket must actually reach the purse"
	).is_equal(before + POCKET_GP)
	assert_bool(GameState.flag_is_true(npc.pocket_lifted_flag())).is_true()
	assert_bool(npc.pocket_is_live()).is_false()


func test_a_failed_attempt_takes_nothing_and_closes_the_pocket() -> void:
	var npc := _npc_with_pocket("test-pocket-failure")
	var before := GameState.gp

	var result := npc.attempt_pickpocket(_certain_failure())

	assert_bool(bool(result["success"])).is_false()
	assert_int(GameState.gp).override_failure_message(
		"a fumbled lift must not pay out"
	).is_equal(before)
	assert_bool(GameState.flag_is_true(npc.pocket_failed_flag())).is_true()


## The mechanic, stated as a test: neither outcome may be rolled twice.
func test_neither_outcome_offers_a_second_roll() -> void:
	var lifted := _npc_with_pocket("test-pocket-lifted-twice")
	lifted.attempt_pickpocket(_certain_success())
	var gp_after_lift := GameState.gp

	var repeat := lifted.attempt_pickpocket(_certain_success())
	assert_bool(bool(repeat["attempted"])).override_failure_message(
		"a lifted pocket must not roll again"
	).is_false()
	assert_int(GameState.gp).override_failure_message(
		"a second attempt on a lifted pocket paid out twice — the pocket is a money printer"
	).is_equal(gp_after_lift)

	var fumbled := _npc_with_pocket("test-pocket-failed-twice")
	fumbled.attempt_pickpocket(_certain_failure())
	var retry := fumbled.attempt_pickpocket(_certain_success())
	assert_bool(bool(retry["attempted"])).override_failure_message(
		"a caught thief must not get a second try — that is the whole mechanic"
	).is_false()
	assert_bool(bool(retry["success"])).is_false()


func test_every_attempt_records_exactly_one_outcome() -> void:
	var npc := _npc_with_pocket("test-pocket-outcome")
	var result := npc.attempt_pickpocket(_certain_success())

	var lifted := GameState.flag_is_true(npc.pocket_lifted_flag())
	var failed := GameState.flag_is_true(npc.pocket_failed_flag())
	assert_bool(lifted or failed).override_failure_message(
		"an attempt that records neither outcome is an attempt that can be repeated"
	).is_true()
	assert_bool(lifted and failed).override_failure_message(
		"a pocket cannot be both lifted and fumbled"
	).is_false()
	assert_bool(lifted).is_equal(bool(result["success"]))


func test_getting_caught_writes_infamy_to_the_renown_ledger() -> void:
	var npc := _npc_with_pocket("test-pocket-infamy")
	var before := Renown.infamy()

	npc.attempt_pickpocket(_certain_failure())

	assert_float(Renown.infamy()).override_failure_message(
		(
			"being caught stealing left no trace. A consequence the world does not "
			+ "record is a message, not a consequence"
		)
	).is_greater(before)


func test_getting_caught_costs_standing_with_the_npcs_faction() -> void:
	var npc := _npc_with_pocket("test-pocket-reputation", "dorthkor-muster")
	var before := Reputation.standing("dorthkor-muster")

	npc.attempt_pickpocket(_certain_failure())

	assert_float(Reputation.standing("dorthkor-muster")).is_less(before)


## An unaffiliated bystander has no faction to be indignant on behalf of, but
## still saw you try — infamy is global, faction standing is not.
func test_an_unaffiliated_victim_costs_infamy_but_no_faction_standing() -> void:
	var npc := _npc_with_pocket("test-pocket-no-faction", "")
	var infamy_before := Renown.infamy()
	var events_before: int = Reputation.to_dict().get("events", []).size()

	npc.attempt_pickpocket(_certain_failure())

	assert_float(Renown.infamy()).is_greater(infamy_before)
	assert_int(Reputation.to_dict().get("events", []).size()).override_failure_message(
		"a victim with no faction must not write a faction event"
	).is_equal(events_before)


func test_a_successful_lift_is_not_punished() -> void:
	var npc := _npc_with_pocket("test-pocket-clean", "dorthkor-muster")
	var infamy_before := Renown.infamy()
	var standing_before := Reputation.standing("dorthkor-muster")

	npc.attempt_pickpocket(_certain_success())

	assert_float(Renown.infamy()).override_failure_message(
		"you were not caught; nothing should have been recorded"
	).is_equal(infamy_before)
	assert_float(Reputation.standing("dorthkor-muster")).is_equal(standing_before)


## Deliberately the opposite of #414's unknown-lock-skill fallback, which OPENS
## the lock. There a typo costs the player content; here it would hand them loot
## with no risk attached. The safe direction differs with the direction of the
## reward.
func test_an_unknown_pocket_skill_seals_rather_than_opens() -> void:
	var npc := _npc_with_pocket("test-pocket-typo")
	npc.pocket_skill = "pickpocketing"
	var before := GameState.gp

	var result := npc.attempt_pickpocket(_certain_success())

	assert_bool(bool(result["success"])).is_false()
	assert_str(str(result["reason"])).is_equal("unknown_skill")
	assert_int(GameState.gp).is_equal(before)
	assert_bool(GameState.flag_is_true(npc.pocket_lifted_flag())).override_failure_message(
		"an authoring typo must not silently consume the pocket either"
	).is_false()


func test_slip_is_the_dramgid_skill_the_verb_rolls() -> void:
	assert_bool(DramgidSchema.is_skill("slip")).is_true()
	assert_str(str(DramgidSchema.SKILLS["slip"]["replaces"])).override_failure_message(
		"slip is DRAMGID's rename of sleight_of_hand (#392)"
	).is_equal("sleight_of_hand")
