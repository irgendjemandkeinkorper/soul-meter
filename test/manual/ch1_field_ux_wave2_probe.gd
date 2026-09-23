extends GdUnitTestSuite
## Isolated rendered probe for Wave 2 interior presentation (reviewer evidence).


func test_tavern_alone() -> void:
	await _probe("res://world/interiors/dom_tavern.tscn", "w2_tavern_alone")


func test_item_shop_alone() -> void:
	await _probe("res://world/interiors/item_shop.tscn", "w2_item_shop_alone")


func _probe(scene_path: String, shot_name: String) -> void:
	var runner := scene_runner(scene_path)
	var scene := runner.scene() as Node2D
	await runner.simulate_frames(40)
	var floor := scene.get_node_or_null("Floor") as Polygon2D
	print("PROBE %s floor_texture=%s floor_color=%s floor_visible=%s" % [
		shot_name,
		floor.texture if floor != null else null,
		floor.color if floor != null else null,
		floor.is_visible_in_tree() if floor != null else null,
	])
	for layer: Node in scene.get_tree().root.find_children("*", "CanvasLayer", true, false):
		var canvas := layer as CanvasLayer
		print("PROBE %s canvas_layer=%s layer=%d visible=%s path=%s" % [
			shot_name, canvas.name, canvas.layer, canvas.visible, canvas.get_path()
		])
	var player := scene.get_node_or_null("Player") as Node2D
	if player != null:
		var camera := player.get_node_or_null("Camera2D") as Camera2D
		print("PROBE %s player=%s limits=%s,%s,%s,%s" % [
			shot_name, player.global_position,
			camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom
		])
	var boot := scene.get_tree().current_scene
	print("PROBE %s current_scene=%s path=%s visible=%s" % [
		shot_name, boot, boot.scene_file_path if boot != null else "",
		(boot as CanvasItem).visible if boot is CanvasItem else "n/a",
	])
	for child: Node in scene.get_tree().root.get_children():
		print("PROBE %s root_child=%s class=%s" % [shot_name, child.name, child.get_class()])
	DirAccess.make_dir_recursive_absolute("user://qa")
	var image := scene.get_viewport().get_texture().get_image()
	image.save_png("user://qa/%s.png" % shot_name)
	print("SHOT %s %s" % [shot_name, image.get_size()])
	if boot != null and boot != scene and boot is CanvasItem:
		(boot as CanvasItem).hide()
		await runner.simulate_frames(3)
		image = scene.get_viewport().get_texture().get_image()
		image.save_png("user://qa/%s_boot_hidden.png" % shot_name)
		print("SHOT %s_boot_hidden %s" % [shot_name, image.get_size()])
		(boot as CanvasItem).show()
	runner.scene().queue_free()
