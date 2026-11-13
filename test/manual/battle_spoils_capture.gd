extends GdUnitTestSuite
## Capture harness, not an assertion suite (test/manual is excluded from tree runs). Playtest
## 2026-11-02: battle spoils over the battle HUD, opened the way production opens them — the
## battle in UIManager's stack, the loot panel on top. Run under Xvfb:
##   CAPTURE_OUT=/abs/out.png scripts/test.sh -a test/manual/battle_spoils_capture.gd

const CAPTURE_SIZE := Vector2i(1920, 1080)


func test_capture_battle_spoils_over_the_battle() -> void:
	get_tree().root.size = CAPTURE_SIZE
	var boot_scene := get_tree().current_scene
	if boot_scene != null:
		boot_scene.hide()
	Battle.start(&"dorthkor-vanguard")
	UIManager.open(load("res://ui/screens/battle.tscn") as PackedScene, false, true)
	await await_millis(600)
	var loot := UIManager.open(UIManager.LOOT_PANEL) as LootPanel
	loot.configure("BATTLE SPOILS", [
		{"item_id": ItemIds.CONSUMABLES_HEARTHLOAF, "quantity": 2},
		{"item_id": ItemIds.WEAPONS_TAUBSTUMMER_AXE, "quantity": 1},
	] as Array[Dictionary])
	await await_millis(600)
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image := get_tree().root.get_texture().get_image()
	var out := OS.get_environment("CAPTURE_OUT")
	if out.is_empty():
		out = ProjectSettings.globalize_path("user://battle_spoils.png")
	image.save_png(out)
	print("SAVED ", out, " ", image.get_size())
	await UIManager.close_all()

