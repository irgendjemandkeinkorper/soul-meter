extends GdUnitTestSuite
## Owner item 25 (2026-10-30): Hollowmere's Reed Landing is Chapter 1's re-Agreed place. Mender
## Corrin Vell's "The Instrument Stake" restores the `hollowmere-reed-landing` AccordZone on
## `hold-the-stake` (+8 Soul); `file-the-true-reading` pays no Soul and leaves the zone thin.

const HOLLOWMERE_SCENE := preload("res://world/hollowmere.tscn")
const AGREEMENT_ID := &"hollowmere-reed-landing"

var _soul_before: float
var _flags_before: Dictionary


func before_test() -> void:
	_soul_before = GameState.soul_meter
	_flags_before = GameState.flags.duplicate(true)


func after_test() -> void:
	GameState.flags = _flags_before
	GameState.soul_meter = _soul_before


func test_the_quest_is_a_routed_complete_field_side_quest() -> void:
	var quest := QuestRegistry.INSTRUMENT_STAKE
	assert_bool(quest.has_complete_outcome_schema()).is_true()
	assert_str(quest.ledger_scene).is_equal("hollowmere")
	assert_bool(QuestRegistry.DOM_SIDE_QUESTS.has(quest)).override_failure_message("not in Dom's denominator").is_false()
	assert_bool(QuestRegistry.all_quests().has(quest)).is_true()
	assert_object(QuestRegistry.side_quest_for_giver("hollowmere-mender")).is_same(quest)
	var route := QuestRegistry.dialogue_route_for_actor("hollowmere-mender", "res://dialogue/hollowmere_townsfolk.dialogue", "x")
	assert_str(str(route["error"])).is_empty()
	assert_str(str(route["title"])).is_equal(quest.dialogue_title)
	assert_bool(QuestRegistry.restorable_agreement_ids().has(String(AGREEMENT_ID))).is_true()
	var hold := quest.outcome_for("hold-the-stake")
	assert_array(hold["restores_agreement"]).contains_exactly([String(AGREEMENT_ID)])
	assert_float(float(hold["soul_delta"])).is_equal(8.0)
	assert_float(float(quest.outcome_for("file-the-true-reading")["soul_delta"])).is_equal(0.0)


func test_every_outcome_has_its_dialogue_choice_and_readback() -> void:
	var quest := QuestRegistry.INSTRUMENT_STAKE
	var source := FileAccess.get_file_as_string(quest.dialogue_path)
	assert_str(source).contains("~ %s\n" % quest.dialogue_title)
	for outcome_id: String in quest.outcome_ids:
		assert_str(source).contains('resolve_side_quest(QuestRegistry.INSTRUMENT_STAKE, "%s")' % outcome_id)
		assert_str(source).contains('GameState.get_flag("%s") == "%s"' % [quest.resolution_flag, outcome_id])
		assert_str(source).contains(str(quest.outcome_for(outcome_id)["readback"]))
	assert_object(load(quest.dialogue_path)).is_not_null()


func test_the_reed_landing_zone_is_authored_at_the_stake() -> void:
	var root := auto_free(HOLLOWMERE_SCENE.instantiate()) as Node
	var zone := root.get_node("ReedLandingAccord") as AccordZone
	assert_str(String(zone.agreement_id)).is_equal(String(AGREEMENT_ID))
	assert_int(zone.accord_delta).is_equal(-15)
	assert_int(zone.half_width_cells).is_equal(2)
	assert_int(zone.half_height_cells).is_equal(1)
	var stake := root.get_node("HollowmereDressing/SolidProps/InstrumentStake") as Node2D
	assert_vector(zone.position).is_equal(stake.position)


func test_holding_the_stake_re_agrees_the_reed_landing_for_eight_soul() -> void:
	var root := auto_free(HOLLOWMERE_SCENE.instantiate()) as Node
	var field := root.get_node("FieldMap") as FieldMap
	var zone := root.get_node("ReedLandingAccord") as AccordZone
	var cell := field.zone_anchor_cell(zone)
	assert_float(field.zone_delta(cell)).is_equal(-15.0)
	GameState.soul_meter = 30.0
	_ready_to_resolve()
	assert_bool(QuestRegistry.resolve_side_quest(QuestRegistry.INSTRUMENT_STAKE, &"hold-the-stake")).is_true()
	assert_float(GameState.soul_meter).is_equal(38.0)
	assert_float(field.zone_delta(cell)).is_equal(0.0)
	var events: Array[ReputationEvent] = Reputation.events_for("wayfare-menders")
	assert_str(events[events.size() - 1].scene).is_equal("hollowmere")


func test_filing_the_true_reading_leaves_the_mere_thin_and_the_gauge_alone() -> void:
	GameState.soul_meter = 30.0
	_ready_to_resolve()
	assert_bool(QuestRegistry.resolve_side_quest(QuestRegistry.INSTRUMENT_STAKE, &"file-the-true-reading")).is_true()
	assert_float(GameState.soul_meter).is_equal(30.0)
	assert_bool(GameState.flag_is_true(AccordMath.agreement_flag(AGREEMENT_ID))).is_false()


func _ready_to_resolve() -> void:
	QuestRegistry.reset()
	assert_bool(QuestRegistry.offer_side_quest(QuestRegistry.INSTRUMENT_STAKE)).is_true()
	GameState.set_flag("hollowmere_instrument_stake_read", true)
