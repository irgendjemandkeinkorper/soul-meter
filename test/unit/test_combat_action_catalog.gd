extends GdUnitTestSuite

func test_all_returns_authored_actions_sorted_and_player_actions_are_filtered() -> void:
	var actions := CombatActionCatalog.all()
	assert_bool(actions.is_empty()).is_false()
	for action in CombatActionCatalog.player_actions():
		assert_bool(action.player_available).is_true()

func test_by_id_returns_a_copy_and_unknown_ids_return_null() -> void:
	var original := CombatActionCatalog.all()[0]
	var found := CombatActionCatalog.by_id(original.id)
	assert_object(found).is_not_null()
	assert_bool(found != original).is_true()
	assert_object(CombatActionCatalog.by_id(&"missing-action")).is_null()
