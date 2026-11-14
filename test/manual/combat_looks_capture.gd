extends GdUnitTestSuite
## Contact sheet for slice 5 (owner 2026-11-02: "one look per tone + class flourishes"): the
## ten tone looks (top row) and the ten class flourishes (bottom row) over a field-dark ground,
## one sheet per moment of the beat (t 0.3, t 0.6). Run explicitly under Xvfb:
##   CAPTURE_OUT=<dir> scripts/test.sh -a test/manual/combat_looks_capture.gd

const CombatLookScript := preload("res://ui/hud/combat_look.gd")


class Sheet extends Node2D:
	var cells: Array[Dictionary] = []
	var font: Font

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2(1920, 1080)), Color("#14161B"))
		for cell: Dictionary in cells:
			var center: Vector2 = cell["center"]
			draw_rect(Rect2(center - Vector2(90, 90), Vector2(180, 200)), Color("#1C1F26"))
			CombatLookScript.draw(
				self, cell["look"], center, 22.0, float(cell["t"]), cell["color"], cell["glow"], 1.4
			)
			draw_string(font, center + Vector2(-86, 100), str(cell["label"]), HORIZONTAL_ALIGNMENT_LEFT, 172, 14, DS.PARCHMENT)


func test_every_look_on_one_sheet() -> void:
	get_tree().root.size = Vector2i(1920, 1080)
	var out_dir := OS.get_environment("CAPTURE_OUT")
	if out_dir.is_empty():
		out_dir = ProjectSettings.globalize_path("user://qa/combat-looks")
	DirAccess.make_dir_recursive_absolute(out_dir)
	for child: Node in get_tree().root.get_children():
		if child is CanvasItem:
			(child as CanvasItem).hide()
	var layer := CanvasLayer.new()
	layer.layer = 100
	get_tree().root.add_child(layer)
	var sheet := Sheet.new()
	sheet.font = load(DS.FONT_NUMERIC) as Font
	layer.add_child(sheet)
	var rows: Array[Dictionary] = []
	for entry: Dictionary in DS.WHEEL:
		rows.append({"label": "%s" % str(entry["name"]).to_upper(), "look": CombatLookScript.tone_look(str(entry["id"])),
			"color": entry["color"], "glow": entry["glow"]})
	for row: Dictionary in ClassCatalog.ALL:
		var colors := CombatLookScript.class_colors(str(row["id"]))
		rows.append({"label": str(row["name"]).to_upper(), "look": CombatLookScript.class_look(str(row["id"])),
			"color": colors[0], "glow": colors[1]})
	for t: float in [0.3, 0.6]:
		sheet.cells.clear()
		for index: int in rows.size():
			var row := rows[index]
			var cell := row.duplicate()
			cell["t"] = t
			cell["center"] = Vector2(110 + (index % 10) * 190, 150 + int(index / 10) * 480)
			cell["label"] = "%s · t %.1f" % [row["label"], t]
			sheet.cells.append(cell)
		sheet.queue_redraw()
		await get_tree().process_frame
		await get_tree().process_frame
		RenderingServer.force_draw()
		await RenderingServer.frame_post_draw
		var path := "%s/looks-t%02d.png" % [out_dir, int(t * 10)]
		assert_int(get_viewport().get_texture().get_image().save_png(path)).is_equal(OK)
		print("SHOT ", path)
	layer.queue_free()
