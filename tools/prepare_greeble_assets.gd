extends SceneTree
## Normalizes a greeble batch's generated masters into game sprites.
## Usage (pure image work, no autoloads):
##   godot --headless --path . --script tools/prepare_greeble_assets.gd -- \
##       res://assets/generated/sources/<batch>/batch.json
##
## The batch JSON is the prompt and provenance source; this tool reads it and never edits it.
## Each asset's `placement` picks its export contract (batch.json `export_contracts`):
## - standing (`solid`, `walkable`): crop to alpha, fit inside 224 px, centre x, sit the
##   lowest opaque row on the 240 px baseline of a 256x256 canvas (pivot 128,240), the same
##   contract as the Dom prop batches.
## - `ground`: crop to alpha, fit inside 496x240, centre on a 512x256 canvas (pivot 256,128).
## Masters that are missing are reported and skipped, so a partial batch can be prepared.

const STANDING_SIZE := Vector2i(256, 256)
const STANDING_CONTENT := 224
const STANDING_BASELINE := 240
const GROUND_SIZE := Vector2i(512, 256)
const GROUND_CONTENT := Vector2i(496, 240)
## Ground decals fade out from this share of their elliptical radius (strips keep more), with
## the edge pushed in and out by noise, so a decal melts into the ground instead of reading as
## a diamond tile. The generator paints crisp diamond outlines and sometimes a pale rim.
const FEATHER_START := 0.22
const STRIP_FEATHER_START := 0.55
const FEATHER_NOISE := 0.28


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("usage: -- res://.../batch.json")
		quit(2)
		return
	var batch_path := args[0]
	var batch: Variant = JSON.parse_string(FileAccess.get_file_as_string(batch_path))
	if not batch is Dictionary:
		push_error("cannot read %s" % batch_path)
		quit(2)
		return
	var prepared: Dictionary = {}
	var missing: Array[String] = []
	for asset: Dictionary in (batch as Dictionary)["assets"]:
		var source := "res://" + str(asset["source_path"])
		var output := "res://" + str(asset["output_path"])
		if not FileAccess.file_exists(source):
			missing.append(str(asset["id"]))
			continue
		var image := Image.load_from_file(ProjectSettings.globalize_path(source))
		if image == null or image.is_empty():
			missing.append(str(asset["id"]))
			continue
		var ground := str(asset["placement"]) == "ground"
		var normalized := normalize(image, ground)
		if ground:
			feather(normalized, hash(str(asset["id"])), str(asset["id"]).contains("road") or str(asset["id"]).contains("ruts"))
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
		normalized.save_png(ProjectSettings.globalize_path(output))
		prepared[str(asset["id"])] = output
	print("PREPARED ", prepared.size(), " MISSING ", missing.size(), " ", ", ".join(missing))
	quit(0)


## Crops to the opaque bounds and fits the subject onto its export canvas.
static func normalize(source: Image, ground: bool) -> Image:
	source.convert(Image.FORMAT_RGBA8)
	var bounds := opaque_bounds(source)
	var cropped := source.get_region(bounds)
	var canvas_size := GROUND_SIZE if ground else STANDING_SIZE
	var box := Vector2(GROUND_CONTENT) if ground else Vector2(STANDING_CONTENT, STANDING_CONTENT)
	var fit := minf(box.x / bounds.size.x, box.y / bounds.size.y)
	var scaled_size := Vector2i(maxi(1, roundi(bounds.size.x * fit)), maxi(1, roundi(bounds.size.y * fit)))
	cropped.resize(scaled_size.x, scaled_size.y, Image.INTERPOLATE_LANCZOS)
	var canvas := Image.create(canvas_size.x, canvas_size.y, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var origin := Vector2i((canvas_size.x - scaled_size.x) / 2, 0)
	if ground:
		origin.y = (canvas_size.y - scaled_size.y) / 2
	else:
		origin.y = STANDING_BASELINE - scaled_size.y
	canvas.blit_rect(cropped, Rect2i(Vector2i.ZERO, scaled_size), origin)
	return canvas


static func opaque_bounds(image: Image) -> Rect2i:
	var used := image.get_used_rect()
	return used if used.size != Vector2i.ZERO else Rect2i(Vector2i.ZERO, image.get_size())



## Fades a ground decal's alpha toward a noisy ellipse inscribed in its canvas.
static func feather(image: Image, seed_value: int, strip: bool) -> void:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var start := STRIP_FEATHER_START if strip else FEATHER_START
	var centre := Vector2(image.get_size()) * 0.5
	var radius := Vector2(image.get_size()) * 0.5
	for y: int in image.get_height():
		for x: int in image.get_width():
			var pixel := image.get_pixel(x, y)
			if pixel.a <= 0.0:
				continue
			var offset := (Vector2(x, y) - centre) / radius
			var distance := offset.length() + noise.get_noise_2d(x, y) * FEATHER_NOISE
			var keep := 1.0 - smoothstep(start, 1.0, distance)
			pixel.a *= keep
			image.set_pixel(x, y, pixel)
