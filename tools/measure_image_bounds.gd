extends SceneTree

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Usage: ... -- IMAGE")
		quit(2)
		return
	var image := Image.load_from_file(args[0])
	if image == null or image.is_empty():
		push_error("Could not load %s" % args[0])
		quit(2)
	var minimum := Vector2i(image.get_width(), image.get_height())
	var maximum := Vector2i(-1, -1)
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a <= 0.01:
				continue
			minimum.x = mini(minimum.x, x)
			minimum.y = mini(minimum.y, y)
			maximum.x = maxi(maximum.x, x)
			maximum.y = maxi(maximum.y, y)
	print("%s size=%dx%d alpha=%s bounds=%s" % [
		args[0], image.get_width(), image.get_height(),
		"ALPHA_BLEND" if image.detect_alpha() == Image.ALPHA_BLEND else "not-alpha-blend",
		Rect2i(minimum, maximum - minimum + Vector2i.ONE),
	])
	print("corners=%s,%s,%s,%s" % [
		image.get_pixel(0, 0), image.get_pixel(image.get_width() - 1, 0),
		image.get_pixel(0, image.get_height() - 1), image.get_pixel(image.get_width() - 1, image.get_height() - 1),
	])
	print("samples=%s,%s,%s,%s,%s" % [
		image.get_pixel(10, 10), image.get_pixel(10, image.get_height() / 2),
		image.get_pixel(image.get_width() / 2, 10), image.get_pixel(image.get_width() / 2, image.get_height() / 2),
		image.get_pixel(image.get_width() - 10, image.get_height() / 2),
	])
	quit(0)
