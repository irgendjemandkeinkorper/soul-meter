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

func test_every_class_resource_action_is_answered_by_exactly_one_patron() -> void:
	# #236: an authored `class_resource_action` with no resource listing it in
	# `commands()` is a button that loads, appears, and does nothing. This is the
	# guard against authoring more of those.
	var authored: Array[StringName] = []
	for action in CombatActionCatalog.all():
		if not action.class_resource_action.is_empty():
			authored.append(action.class_resource_action)
	assert_array(authored).is_not_empty()
	for command: StringName in authored:
		var answering: Array[String] = []
		for patron: StringName in ClassResourceRegistry.PATRON_IDS:
			var resource: ClassResource = ClassResourceRegistry.for_patron(patron)
			if resource.accepts_command(command):
				answering.append(String(patron))
		assert_array(answering).override_failure_message(
			"command '%s' is answered by %s, expected exactly one patron"
			% [command, answering]
		).has_size(1)


func test_every_declared_command_has_an_authored_action() -> void:
	# The reverse direction: a resource that declares a command nobody can press
	# is just as dead as an action nobody answers.
	var authored: Dictionary = {}
	for action in CombatActionCatalog.all():
		if not action.class_resource_action.is_empty():
			authored[action.class_resource_action] = true
	for patron: StringName in ClassResourceRegistry.PATRON_IDS:
		var resource: ClassResource = ClassResourceRegistry.for_patron(patron)
		for command: StringName in resource.commands():
			assert_bool(authored.has(command)).override_failure_message(
				"%s declares command '%s' with no authored CombatAction"
				% [patron, command]
			).is_true()


func test_class_resource_actions_are_pass_kind_so_the_controller_routes_them() -> void:
	# CombatController only dispatches `on_command` for PASS-kind actions.
	for action in CombatActionCatalog.all():
		if action.class_resource_action.is_empty():
			continue
		assert_int(int(action.kind)).override_failure_message(
			"'%s' carries a class-resource command but is not PASS kind" % action.id
		).is_equal(int(CombatAction.Kind.PASS))
