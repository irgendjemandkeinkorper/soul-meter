extends GdUnitTestSuite
## Manual visual QA harness for the post-quest reward reveal.
## Whole-tree runs exclude test/manual; invoke this file explicitly under Xvfb.
## Writes user://reward_reveal_qa.png.

const CAPTURE_SIZE := Vector2i(1920, 1080)
const REVEAL_PATH := "res://ui/components/reward_reveal.tscn"


func test_capture_reward_reveal() -> void:
	get_tree().root.size = CAPTURE_SIZE
	var runner := scene_runner(REVEAL_PATH)
	var reveal := runner.scene() as Control
	reveal.theme = ThemeBuilder.build()
	reveal.present(_reward_summary(), false)
	await runner.simulate_frames(45)

	var boot_scene := reveal.get_tree().current_scene
	if boot_scene != null and boot_scene != reveal:
		boot_scene.hide()
	await runner.simulate_frames(3)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := reveal.get_viewport().get_texture().get_image()
	assert_object(image.get_size()).is_equal(CAPTURE_SIZE)
	image.save_png("user://reward_reveal_qa.png")
	print(
		"SAVED ",
		ProjectSettings.globalize_path("user://reward_reveal_qa.png"),
		" ",
		image.get_size()
	)


func _reward_summary() -> Dictionary:
	return {
		"quest_name": "The Broken Muster",
		"resolution_label": "Held both fronts and split the credit honestly",
		"entries": [
			{
				"kind": "item",
				"id": "weapons/roadwarden_spear",
				"label": "Roadwarden Spear",
				"amount": 1,
				"detail": "New equipment"
			},
			{
				"kind": "faction",
				"id": "iron-companies",
				"delta": 7.0,
				"detail": "They remember the ruling"
			},
			{
				"kind": "renown",
				"id": "renown",
				"delta": 10.0,
				"detail": "Dom knows the company"
			},
			{
				"kind": "currency",
				"id": "gold",
				"label": "Company silver",
				"delta": -2.0,
				"detail": "Road levy paid"
			},
			{
				"kind": "level",
				"id": "milestone-level",
				"delta": 1.0,
				"detail": "Milestone level gained"
			},
		],
	}
