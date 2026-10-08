extends SceneTree
## Normalizes generated prop masters and renders a review sheet in an isolated project.
## Usage: XDG_DATA_HOME=/tmp/soul-meter-prop-data godot --path ISOLATED_PROJECT
##        --script /absolute/path/to/this.gd --
##        /absolute/path/to/repository /absolute/path/to/batch.json [--preview]
## The batch JSON is the prompt/provenance source. This tool never edits that file.

const OUTPUT_SIZE := Vector2i(256, 256)
const CONTENT_SIZE := 224
const BASELINE := 240


class ReviewSheet:
	extends Node2D

	var rows: Array[Dictionary] = []

	func _draw() -> void:
		var font := ThemeDB.fallback_font
		draw_string(
			font,
			Vector2(24, 30),
			"SOUL METER / DOM PROP BATCH / 24 ASSETS",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			Color("e2e8f0")
		)
		draw_string(
			font,
			Vector2(24, 54),
			"256 px exports + 64 px thumbnails | dark and light alpha check | prepared, not placed",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color("94a3b8")
		)
		for index: int in rows.size():
			var row: Dictionary = rows[index]
			var origin := Vector2(16 + (index % 6) * 280, 76 + (index / 6) * 380)
			draw_rect(Rect2(origin, Vector2(268, 364)), Color("1b1f27"))
			draw_texture(row["texture"], origin + Vector2(6, 0))
			draw_line(
				origin + Vector2(14, BASELINE), origin + Vector2(254, BASELINE), Color("4e5665")
			)
			draw_string(
				font,
				origin + Vector2(12, 280),
				row["title"],
				HORIZONTAL_ALIGNMENT_LEFT,
				245,
				15,
				Color("e2e8f0")
			)
			draw_rect(Rect2(origin + Vector2(12, 290), Vector2(64, 64)), Color("07080b"))
			draw_rect(Rect2(origin + Vector2(88, 290), Vector2(64, 64)), Color("b8b5ad"))
			draw_texture_rect(
				row["texture"], Rect2(origin + Vector2(12, 290), Vector2(64, 64)), false
			)
			draw_texture_rect(
				row["texture"], Rect2(origin + Vector2(88, 290), Vector2(64, 64)), false
			)
			draw_string(
				font,
				origin + Vector2(168, 328),
				row["category"],
				HORIZONTAL_ALIGNMENT_LEFT,
				92,
				12,
				Color("94a3b8")
			)


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("Expected repository root and batch JSON path.")
		quit(2)
		return
	var repo: String = args[0]
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string(args[1]))
	if not document is Dictionary or not document.get("assets", null) is Array:
		push_error("Invalid asset batch.")
		quit(2)
		return
	var preview_rows: Array[Dictionary] = []
	var failures := 0
	for value: Variant in document["assets"]:
		var row: Dictionary = value
		var source_path: String = repo.path_join(str(row["source_path"]))
		if not FileAccess.file_exists(source_path):
			push_error("Missing master: %s" % source_path)
			failures += 1
			continue
		var master := Image.load_from_file(source_path)
		if master == null or master.is_empty():
			push_error("Cannot decode master: %s" % source_path)
			failures += 1
			continue
		master.convert(Image.FORMAT_RGBA8)
		# Match measure_image_bounds.gd: ignore sub-1% alpha noise when locating
		# the visible silhouette; preserve the original pixels within those bounds.
		var bounds := _visible_bounds(master)
		if bounds.size == Vector2i.ZERO or master.detect_alpha() == Image.ALPHA_NONE:
			push_error("Master has no usable transparency: %s" % source_path)
			failures += 1
			continue
		if (
			bounds.position.x <= 0
			or bounds.position.y <= 0
			or bounds.end.x >= master.get_width()
			or bounds.end.y >= master.get_height()
		):
			push_error("Master touches canvas edge; regenerate framing: %s" % source_path)
			failures += 1
			continue
		var cropped := master.get_region(bounds)
		var ratio := float(CONTENT_SIZE) / float(maxi(bounds.size.x, bounds.size.y))
		var fitted := Vector2i(
			maxi(1, roundi(bounds.size.x * ratio)), maxi(1, roundi(bounds.size.y * ratio))
		)
		cropped.resize(fitted.x, fitted.y, Image.INTERPOLATE_LANCZOS)
		var output := Image.create_empty(OUTPUT_SIZE.x, OUTPUT_SIZE.y, false, Image.FORMAT_RGBA8)
		output.fill(Color.TRANSPARENT)
		var placement := Vector2i((OUTPUT_SIZE.x - fitted.x) / 2, BASELINE - fitted.y)
		output.blit_rect(cropped, Rect2i(Vector2i.ZERO, fitted), placement)
		var output_path: String = repo.path_join(str(row["output_path"]))
		DirAccess.make_dir_recursive_absolute(output_path.get_base_dir())
		var result := output.save_png(output_path)
		if result != OK:
			push_error("PNG export failed: %s (%d)" % [output_path, result])
			failures += 1
			continue
		print(
			JSON.stringify(
				{
					"id": row["id"],
					"source_size": [master.get_width(), master.get_height()],
					"source_bounds":
					[bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
					"source_sha256": FileAccess.get_sha256(source_path),
					"output_sha256": FileAccess.get_sha256(output_path),
					"output_size": [256, 256],
					"pivot_px": [128, BASELINE],
					"status": "exported"
				}
			)
		)
		preview_rows.append(
			{
				"texture": ImageTexture.create_from_image(output),
				"title": row["title"],
				"category": row["category"]
			}
		)
	if failures > 0:
		push_error("%d asset(s) need attention." % failures)
		quit(1)
		return
	if "--preview" in args:
		root.size = Vector2i(1712, 1612)
		var sheet := ReviewSheet.new()
		sheet.rows = preview_rows
		sheet.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		root.add_child(sheet)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var preview_path: String = repo.path_join(str(document["source_directory"])).path_join(
			"review-sheet.png"
		)
		var result := root.get_texture().get_image().save_png(preview_path)
		if result != OK:
			push_error("Review sheet export failed: %d" % result)
			quit(1)
			return
		print("REVIEW_SHEET=" + preview_path)
	print("EXPORTED=%d FAILED=%d" % [preview_rows.size(), failures])
	quit(0)


func _visible_bounds(image: Image) -> Rect2i:
	var minimum := image.get_size()
	var maximum := Vector2i(-1, -1)
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).a <= 0.01:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < 0:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
