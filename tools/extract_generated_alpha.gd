extends SceneTree
## Extracts edge-connected neutral/checkerboard backgrounds from generated props.
## Usage: godot --headless --path . -s tools/extract_generated_alpha.gd -- SRC DST WIDTH HEIGHT

const BG_NEUTRAL_TOLERANCE := 48
const BG_MIN_VALUE := 80
const FIT_MARGIN := 4


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		push_error("Usage: ... -- SRC DST WIDTH HEIGHT")
		quit(2)
		return
	var source_path := args[0]
	var destination_path := args[1]
	var target_width := int(args[2])
	var target_height := int(args[3])
	var source := Image.load_from_file(source_path)
	if source == null or source.is_empty():
		push_error("Could not load source: %s" % source_path)
		quit(2)
		return
	source.convert(Image.FORMAT_RGBA8)
	var mask := _edge_connected_background(source)
	var bounds := _opaque_bounds(source, mask)
	if bounds.size.x <= 0 or bounds.size.y <= 0:
		push_error("No subject found after background extraction: %s" % source_path)
		quit(2)
		return
	var cropped := Image.create(bounds.size.x, bounds.size.y, false, Image.FORMAT_RGBA8)
	for y in bounds.size.y:
		for x in bounds.size.x:
			var source_position := bounds.position + Vector2i(x, y)
			var color := source.get_pixelv(source_position)
			if mask[source_position.y * source.get_width() + source_position.x]:
				color.a = 0.0
			else:
				color.a = 1.0
			cropped.set_pixel(x, y, color)
	var max_width := maxi(1, target_width - FIT_MARGIN * 2)
	var max_height := maxi(1, target_height - FIT_MARGIN * 2)
	var fit_scale := minf(float(max_width) / float(cropped.get_width()), float(max_height) / float(cropped.get_height()))
	var fitted_width := maxi(1, roundi(float(cropped.get_width()) * fit_scale))
	var fitted_height := maxi(1, roundi(float(cropped.get_height()) * fit_scale))
	cropped.resize(fitted_width, fitted_height, Image.INTERPOLATE_LANCZOS)
	var result := Image.create(target_width, target_height, false, Image.FORMAT_RGBA8)
	result.fill(Color(0.0, 0.0, 0.0, 0.0))
	var destination := Vector2i((target_width - fitted_width) / 2, target_height - fitted_height - FIT_MARGIN)
	result.blit_rect(cropped, Rect2i(Vector2i.ZERO, cropped.get_size()), destination)
	var error := result.save_png(destination_path)
	if error != OK:
		push_error("Could not save %s: %s" % [destination_path, error])
		quit(2)
		return
	print("%s -> %s; source=%dx%d bounds=%s output=%dx%d alpha=%s" % [
		source_path,
		destination_path,
		source.get_width(),
		source.get_height(),
		bounds,
		target_width,
		target_height,
		"ALPHA_BLEND" if result.detect_alpha() == Image.ALPHA_BLEND else "NOT_ALPHA_BLEND",
	])
	quit(0)


func _edge_connected_background(image: Image) -> PackedByteArray:
	var width := image.get_width()
	var height := image.get_height()
	var visited := PackedByteArray()
	visited.resize(width * height)
	var queue: Array[Vector2i] = []
	for x in width:
		_queue_if_background(image, Vector2i(x, 0), visited, queue)
		_queue_if_background(image, Vector2i(x, height - 1), visited, queue)
	for y in height:
		_queue_if_background(image, Vector2i(0, y), visited, queue)
		_queue_if_background(image, Vector2i(width - 1, y), visited, queue)
	var head := 0
	while head < queue.size():
		var position := queue[head]
		head += 1
		for offset in [
			Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
			Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(1, 1),
		]:
			_queue_if_background(image, position + offset, visited, queue)
	return visited


func _queue_if_background(image: Image, position: Vector2i, visited: PackedByteArray, queue: Array[Vector2i]) -> void:
	if position.x < 0 or position.y < 0 or position.x >= image.get_width() or position.y >= image.get_height():
		return
	var index := position.y * image.get_width() + position.x
	if visited[index] != 0 or not _is_neutral_background(image.get_pixelv(position)):
		return
	visited[index] = 1
	queue.append(position)


func _is_neutral_background(color: Color) -> bool:
	var minimum := mini(mini(roundi(color.r * 255.0), roundi(color.g * 255.0)), roundi(color.b * 255.0))
	var maximum := maxi(maxi(roundi(color.r * 255.0), roundi(color.g * 255.0)), roundi(color.b * 255.0))
	return maximum - minimum <= BG_NEUTRAL_TOLERANCE and minimum >= BG_MIN_VALUE


func _opaque_bounds(image: Image, mask: PackedByteArray) -> Rect2i:
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if mask[y * image.get_width() + x] != 0:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	if maximum.x < minimum.x:
		return Rect2i()
	return Rect2i(minimum, maximum - minimum + Vector2i.ONE)
