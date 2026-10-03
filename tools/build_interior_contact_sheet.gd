extends SceneTree

const CELL_SIZE := Vector2i(256, 256)
const COLUMNS := 3
const ROWS := 4
const ASSETS := [
	"dom-interior-table--long.png",
	"dom-interior-bench--plank.png",
	"dom-interior-stool--round.png",
	"dom-interior-counter--bar.png",
	"dom-interior-sign--hanging.png",
	"dom-interior-chest--closed.png",
	"dom-interior-chest--open.png",
	"dom-interior-switch--off.png",
	"dom-interior-switch--on.png",
	"dom-interior-floor--stone-flag.png",
	"dom-interior-wall--brick-dark.png",
]


func _init() -> void:
	var output_path := "res://assets/generated/sprites/interior/batch2-contact-sheet.png"
	var sheet := Image.create(CELL_SIZE.x * COLUMNS, CELL_SIZE.y * ROWS, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("17191d"))
	for index in ASSETS.size():
		var image := Image.load_from_file("res://assets/generated/sprites/interior/" + ASSETS[index])
		if image == null or image.is_empty():
			push_error("Could not load %s" % ASSETS[index])
			quit(2)
			return
		image.convert(Image.FORMAT_RGBA8)
		var cell := Vector2i(index % COLUMNS, index / COLUMNS)
		var destination := cell * CELL_SIZE
		var fitted := image
		var scale := minf(float(CELL_SIZE.x - 16) / float(image.get_width()), float(CELL_SIZE.y - 16) / float(image.get_height()))
		var width := maxi(1, roundi(float(image.get_width()) * scale))
		var height := maxi(1, roundi(float(image.get_height()) * scale))
		if width != image.get_width() or height != image.get_height():
			fitted = image.duplicate()
			fitted.resize(width, height, Image.INTERPOLATE_LANCZOS)
		var centered := destination + Vector2i((CELL_SIZE.x - width) / 2, (CELL_SIZE.y - height) / 2)
		sheet.blend_rect(fitted, Rect2i(Vector2i.ZERO, fitted.get_size()), centered)
	var error := sheet.save_png(output_path)
	if error != OK:
		push_error("Could not save contact sheet: %s" % error)
		quit(2)
		return
	print("saved %s (%dx%d)" % [output_path, sheet.get_width(), sheet.get_height()])
	quit(0)
