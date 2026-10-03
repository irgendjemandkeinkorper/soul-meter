extends SceneTree
## Resizes an opaque generated texture and validates its edge-to-edge dimensions.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 4:
		push_error("Usage: ... -- SRC DST WIDTH HEIGHT")
		quit(2)
		return
	var image := Image.load_from_file(args[0])
	if image == null or image.is_empty():
		push_error("Could not load source: %s" % args[0])
		quit(2)
		return
	image.convert(Image.FORMAT_RGBA8)
	image.resize(int(args[2]), int(args[3]), Image.INTERPOLATE_LANCZOS)
	var error := image.save_png(args[1])
	if error != OK:
		push_error("Could not save %s: %s" % [args[1], error])
		quit(2)
		return
	print("%s -> %s; output=%dx%d alpha=%s" % [
		args[0],
		args[1],
		image.get_width(),
		image.get_height(),
		"ALPHA_BLEND" if image.detect_alpha() == Image.ALPHA_BLEND else "opaque",
	])
	quit(0)
