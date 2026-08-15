extends GdUnitTestSuite


func test_chart_routes_enter_battle_through_all_four_deployment_states() -> void:
	var chart := FileAccess.get_file_as_string("res://ui/flow/game_flow.tscn")
	for state: String in ["DeploymentSlate", "DeploymentAttune", "DeploymentLoadout", "DeploymentPlace"]:
		assert_str(chart).contains("name=\"%s\"" % state)
	assert_str(chart).contains("event = &\"enter_battle\"")
	assert_str(chart).contains("event = &\"accept_slate\"")
	assert_str(chart).not_contains("change_scene_to_file")


func test_deployment_screen_has_ordered_steps_and_final_accept_copy() -> void:
	var runner := scene_runner("res://ui/screens/deployment/deployment.tscn")
	var deployment := runner.scene() as DeploymentScreen
	for step: int in DeploymentScreen.Step.values():
		deployment.configure_step(step)
		assert_int(deployment.current_step).is_equal(step)
	deployment.configure_step(DeploymentScreen.Step.PLACE)
	assert_str((runner.find_child("Advance", true, false) as Button).text).is_equal("ACCEPT THE SLATE")
