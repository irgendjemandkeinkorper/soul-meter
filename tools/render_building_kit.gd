extends Node
## Painterly pieces for walk-in buildings (#631, owner-approved skin pass 2026-11-09).
## Kenney Fantasy Town geometry is composed into the kit's pieces at the
## kit spec and rendered with the sprite tool's camera (tools/render_isometric_sprites.gd) at the
## kit's own pitch (KIT_PITCH_RADIANS), so these pieces and the owner's later Blender
## captures sit on one grid. The spec:
##   - one model unit is one cell edge: a unit square on the floor is one 64 x 32 tile;
##   - a wall is 1 unit long and 4 tall, and stands in the middle of the cell it blocks; a `-half`
##     piece is half a cell long and meets a post at the cell's centre; its cutaway stub is 0.5
##     tall; a doorway is 3 tall; a free-standing pillar is 0.5 square (BuildingPlan's constants);
##   - a piece's pivot is on the floor at the middle of its base; a roof's is at the back corner of
##     its layout's grid; a piece of furniture's is the centre of its footprint. Each piece's pivot
##     pixel is in building_kit.json.
##   - one roof per walk-in building on the maps (BUILDINGS), computed from the layout's outline
##     (`BuildingPlan.roof_triangles()`): it rises from every outer wall and sits ROOF_SEAT above
##     the post tops, so no post or wall corner shows through it.
## Painted materials replace the palette without moving vertices, silhouettes or pivots.
## Furniture retains its existing shapes and footprints. Each layout size has its long side along x
## or, for a piece longer along z, turned to run along z with its front still facing the camera.
## Wall pieces come in two runs: `-x` runs along the ground's +x cells (screen right and down),
## `-z` along its +y cells (screen left and down).
##
## Run as a temporary autoload under Xvfb (the viewport needs a renderer), from the repo root:
##   cp project.godot /tmp/project.godot.bak
##   sed -i '/^Pandora=/a BuildingKitRender="*res://tools/render_building_kit.gd"' project.godot
##   SOUL_METER_BUILDING_KIT=1 xvfb-run -a -s "-screen 0 1280x1024x24" "$GODOT_BIN" --path .
##   cp /tmp/project.godot.bak project.godot
##   "$GODOT_BIN" --headless --path . --import
## Prints BUILDING-KIT: ok|FAILED lines; judge those, not the exit code.

const Iso := preload("res://tools/render_isometric_sprites.gd")
const RUN_ENV := "SOUL_METER_BUILDING_KIT"
const KIT := "res://assets/kenney3d/fantasy-town-kit/Models/GLB format/"
const OUT_DIR := "res://assets/generated/sprites/building-kit/"
const MANIFEST := OUT_DIR + "building_kit.json"
const MATERIALS := OUT_DIR + "materials/"
## World-space material coordinates survive the modules' nonuniform scales. The source
## palette is used only to separate the existing timber/plaster/iron faces, never as paint.
## Roof UVs follow each slope's eaves; no displacement or alpha changes are permitted.
const PAINT_SHADER := """
shader_type spatial;
render_mode cull_disabled, diffuse_lambert, specular_disabled;
uniform sampler2D paint : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D timber : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D metal : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D palette : source_color, filter_nearest, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform float scale = 1.0;
uniform int kind = 0;
varying vec3 place;
varying vec3 facing;
void vertex() {
	place = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	facing = normalize(MODEL_NORMAL_MATRIX * NORMAL);
}
void fragment() {
	vec3 n = abs(normalize(facing));
	vec2 uv = n.y > max(n.x, n.z) ? place.xz :
		(n.x > n.z ? vec2(place.z, -place.y) : vec2(place.x, -place.y));
	uv *= scale;
	if (kind == 4) { uv = UV; }
	vec3 colour = texture(paint, uv).rgb;
	if (kind == 1) {
		// Kenney's dark faces are structural timber; light faces are infill.
		vec3 original = texture(palette, UV).rgb;
		if (original.r < 0.4) { colour = texture(timber, uv).rgb; }
	}
	if (kind == 2) {
		vec3 original = texture(palette, UV).rgb;
		if (original.b > original.r) { colour = texture(metal, uv).rgb; }
	}
	if (kind == 8) {
		// Painted relief breaks up the existing small ember panels without a glow halo.
		float grain = dot(colour, vec3(0.333));
		colour = mix(vec3(0.16, 0.022, 0.004), vec3(0.9, 0.32, 0.035), clamp(grain * 5.0, 0.0, 1.0));
		EMISSION = colour * 0.3;
	}
	ALBEDO = colour * tint.rgb;
	ROUGHNESS = 0.94;
}
"""

## The kit's camera pitch: asin(½) = 30°, the pitch at which a unit square on the floor renders as
## an exact 64 x 32 diamond. The sprite tool's atan(½) (26.57°) draws it 64 x 28.6: a small prop
## hides that, but a roof over 12 x 9 cells landed about 15 px off the ground grid, so its corner
## posts showed above it (item 35 polish, 2026-11-04).
const KIT_PITCH_RADIANS := PI / 6.0
const WALL_TIERS := int(BuildingPlan.WALL_HEIGHT)
const STUB_HEIGHT := BuildingPlan.STUB_HEIGHT
const DOOR_HEIGHT := int(BuildingPlan.DOOR_HEIGHT)
const WALL_THICKNESS := BuildingPlan.WALL_THICKNESS
const POST_SIZE := BuildingPlan.POST_SIZE
const PILLAR_SIZE := BuildingPlan.PILLAR_SIZE
const FLOOR_THICKNESS := 0.06
## The walk-in buildings on the maps: layout and quarter turns, as each building node sets them.
## A building whose roof is missing here reports it (WalkInBuilding) and the walk-in tests fail.
const BUILDINGS: Array[Array] = [["tavern", 0], ["shop", 0], ["cottage", 1], ["warehouse", 1]]
const LAYOUT_DIR := "res://world/buildings/layouts/"
const ROOF_COLOUR := Color(0.34, 0.36, 0.4)
const FASCIA_COLOUR := Color(0.24, 0.17, 0.12)
## The roof's edge board: how far it hangs below the roof surface at the eaves.
const FASCIA_DEPTH := 0.12
const STONE := Color(0.46, 0.44, 0.41)
const GRADE_SATURATION := 0.85
const GRADE_VALUE := 0.95

const PIECE_VIEW := Vector2i(160, 256)
const FURNITURE_VIEW := Vector2i(320, 288)
## Furniture covers whole cells and stands FURNITURE_MARGIN inside them.
const FURNITURE_MARGIN := 0.1
## Dark, warm wood so the furniture reads against the pale plank floor after `_grade`.
const WOOD := Color(0.4, 0.22, 0.11)
const WOOD_DARK := Color(0.24, 0.13, 0.07)
const WOOD_TOP := Color(0.5, 0.3, 0.16)
const IRON := Color(0.16, 0.16, 0.18)
const FIRE := Color(0.95, 0.45, 0.12)
const CLOTH := Color(0.5, 0.2, 0.16)
const LINEN := Color(0.8, 0.76, 0.66)

var _viewport: SubViewport
var _camera: Camera3D
var _stage: Node3D
var _log: PackedStringArray = []
var _manifest := {}
var _paint_textures: Dictionary[String, Texture2D] = {}
var _paint_shader: Shader


func _ready() -> void:
	if OS.get_environment(RUN_ENV).is_empty():
		return
	_run.call_deferred()


func _run() -> void:
	for i in 10:
		await get_tree().process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_create_viewport()
	var ok := true
	for run: String in ["x", "z"]:
		ok = await _piece("wall-" + run, _wall(run, false, 1.0), PIECE_VIEW) and ok
		ok = await _piece("wall-half-" + run, _wall(run, false, 0.5), PIECE_VIEW) and ok
		ok = await _piece("wall-window-" + run, _wall(run, true, 1.0), PIECE_VIEW) and ok
		ok = await _piece("wall-stub-" + run, _stub(run, 1.0), PIECE_VIEW) and ok
		ok = await _piece("wall-stub-half-" + run, _stub(run, 0.5), PIECE_VIEW) and ok
		ok = await _piece("lintel-" + run, _lintel(run), PIECE_VIEW) and ok
	ok = await _piece("post", _post("pillar-wood", POST_SIZE, float(WALL_TIERS)), PIECE_VIEW) and ok
	ok = await _piece("post-stub", _post("pillar-wood", POST_SIZE, STUB_HEIGHT), PIECE_VIEW) and ok
	ok = await _piece("pillar", _post("pillar-stone", PILLAR_SIZE, float(WALL_TIERS)), PIECE_VIEW) and ok
	ok = await _piece("pillar-stub", _post("pillar-stone", PILLAR_SIZE, STUB_HEIGHT), PIECE_VIEW) and ok
	ok = await _piece("floor-planks", _floor(), PIECE_VIEW) and ok
	ok = await _piece("floor-footing", _footing(), PIECE_VIEW) and ok
	var furniture := {}
	for building: Array in BUILDINGS:
		var plan := (load(LAYOUT_DIR + str(building[0]) + ".tres") as BuildingLayout).plan(int(building[1]))
		var problems := plan.problems()
		if not problems.is_empty():
			_log.append("BUILDING-KIT: FAILED %s: %s" % [building[0], "; ".join(problems)])
			ok = false
			continue
		var roof_name := "roof-%s-t%d" % [building[0], building[1]]
		ok = await _piece(roof_name, _roof(plan), _roof_view(plan)) and ok
		for item: Dictionary in plan.furniture:
			var rect: Rect2i = item["rect"]
			furniture["%s-%dx%d" % [item["kind"], rect.size.x, rect.size.y]] = [item["kind"], rect.size]
	var names := furniture.keys()
	names.sort()
	for piece: String in names:
		ok = await _piece(piece, _furniture(furniture[piece][0], furniture[piece][1]), FURNITURE_VIEW) and ok
	var manifest := {
		"generator": "tools/render_building_kit.gd",
		"note": "GENERATED by tools/render_building_kit.gd. Do not edit. Painterly materials (#631); prompts in provenance.json.",
		"spec": {
			"unit": "one cell edge", "wall_height": WALL_TIERS, "stub_height": STUB_HEIGHT,
			"door_height": DOOR_HEIGHT, "wall_thickness": WALL_THICKNESS, "post_size": POST_SIZE,
			"pillar_size": PILLAR_SIZE, "roof_pitch_degrees": BuildingPlan.ROOF_PITCH_DEGREES,
			"camera_pitch_degrees": rad_to_deg(KIT_PITCH_RADIANS),
			"roof_seat": snappedf(BuildingPlan.ROOF_SEAT, 0.001),
		},
		"pieces": _manifest,
	}
	var file := FileAccess.open(MANIFEST, FileAccess.WRITE)
	ok = file != null and ok
	if file != null:
		file.store_string(JSON.stringify(manifest, "\t", true) + "\n")
		file.close()
	_log.append("BUILDING-KIT: %s" % ("ok" if ok else "FAILED"))
	print("\n".join(_log))
	get_tree().quit(0 if ok else 1)


func _create_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	_viewport.msaa_3d = Viewport.MSAA_4X
	add_child(_viewport)
	_stage = Node3D.new()
	_viewport.add_child(_stage)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.0, 0.0, 0.0, 0.0)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Iso.AMBIENT_LIGHT_COLOR
	environment.ambient_light_energy = 0.45
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED
	var world_environment := WorldEnvironment.new()
	world_environment.environment = environment
	_viewport.add_child(world_environment)
	var sunlight := DirectionalLight3D.new()
	sunlight.rotation_degrees = Iso.SUN_ROTATION_DEGREES
	sunlight.light_color = Iso.SUN_LIGHT_COLOR
	sunlight.light_energy = 1.15
	sunlight.shadow_enabled = true
	_viewport.add_child(sunlight)
	_camera = Camera3D.new()
	_camera.projection = Iso.CAMERA_PROJECTION
	_camera.near = 0.05
	_camera.far = 200.0
	_camera.current = true
	_viewport.add_child(_camera)


## Renders `piece` (its origin is the pivot) into OUT_DIR/<name>.png, cropped to its pixels.
func _piece(name: String, piece: Node3D, view: Vector2i) -> bool:
	_viewport.size = view
	_camera.size = float(view.y) / Iso.PIXELS_PER_WORLD_UNIT
	_stage.add_child(piece)
	var bounds := Iso._model_bounds(piece)
	var target := bounds.get_center()
	var direction := Vector3(
		sin(deg_to_rad(Iso.CAMERA_YAW_DEGREES)) * cos(KIT_PITCH_RADIANS),
		sin(KIT_PITCH_RADIANS),
		cos(deg_to_rad(Iso.CAMERA_YAW_DEGREES)) * cos(KIT_PITCH_RADIANS)
	)
	_camera.look_at_from_position(target + direction * 60.0, target, Vector3.UP)
	await get_tree().process_frame
	_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var pivot := _camera.unproject_position(Vector3.ZERO)
	var image := _viewport.get_texture().get_image()
	_stage.remove_child(piece)
	piece.free()
	if image == null or image.is_empty():
		_log.append("BUILDING-KIT: FAILED %s (empty render)" % name)
		return false
	if image.get_format() != Image.FORMAT_RGBA8:
		image.convert(Image.FORMAT_RGBA8)
	var used := image.get_used_rect()
	if used.size.x == 0 or used.size.y == 0:
		_log.append("BUILDING-KIT: FAILED %s (nothing drawn)" % name)
		return false
	var touches := used.position.x == 0 or used.position.y == 0 \
		or used.end.x == view.x or used.end.y == view.y
	image = image.get_region(used)
	if name in ["floor-planks", "floor-footing"]:
		# The model's 0.06-deep side faces used to spill 1–2 px into the next tile.
		# Keep the model, camera and base pivot; give its projected ground surface
		# the exact pixel-centre ownership of a 64×32 diamond, with no shared pixels.
		image = _floor_coverage(image)
		used.size = image.get_size()
	_grade(image)
	var path := OUT_DIR + name + ".png"
	if image.save_png(path) != OK:
		_log.append("BUILDING-KIT: FAILED %s (cannot write)" % name)
		return false
	_manifest[name] = {
		"file": name + ".png",
		"pivot": [snappedf(pivot.x - used.position.x, 0.01), snappedf(pivot.y - used.position.y, 0.01)],
		"size": [used.size.x, used.size.y],
	}
	_log.append("BUILDING-KIT: %s %s %dx%d" % ["ok" if not touches else "FAILED (clipped)", name, used.size.x, used.size.y])
	return not touches


static func _floor_coverage(rendered: Image) -> Image:
	var tile := rendered.get_region(Rect2i(0, 0, 64, 32))
	for y in 32:
		for x in 64:
			var colour := tile.get_pixel(x, y)
			var distance := absf(float(x) + 0.5 - 32.0) / 32.0 \
				+ absf(float(y) + 1.0 - 16.0) / 16.0
			colour.a = 1.0 if distance < 1.0 else 0.0
			tile.set_pixel(x, y, colour)
	return tile


## A light family-wide dusk grade; the generated textures already carry the dark palette.
static func _grade(image: Image) -> void:
	for y in image.get_height():
		for x in image.get_width():
			var colour := image.get_pixel(x, y)
			if colour.a <= 0.0:
				continue
			var grey := colour.get_luminance()
			var graded := Color(grey, grey, grey).lerp(colour, GRADE_SATURATION) * GRADE_VALUE
			graded.a = colour.a
			image.set_pixel(x, y, graded)


## A Kenney model scaled to `size` (x along the run, y up, z across), base on the floor, centred.
func _module(model_name: String, size: Vector3) -> Node3D:
	var source := KIT + model_name + ".glb"
	var model := (load(source) as PackedScene).instantiate() as Node3D
	Iso._apply_external_colormap(model, source)
	_paint_module(model, model_name)
	var bounds := Iso._model_bounds(model)
	var turn := bounds.size.z > bounds.size.x * 1.5
	var holder := Node3D.new()
	var spin := Node3D.new()
	holder.add_child(spin)
	spin.add_child(model)
	model.position = Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z)
	var along := bounds.size.z if turn else bounds.size.x
	var across := bounds.size.x if turn else bounds.size.z
	if turn:
		spin.rotation.y = PI / 2.0
	holder.scale = Vector3(size.x / along, size.y / maxf(bounds.size.y, 0.001), size.z / maxf(across, 0.001))
	return holder


func _run_root(run: String) -> Node3D:
	var root := Node3D.new()
	if run == "z":
		root.rotation.y = -PI / 2.0
	return root


func _wall(run: String, window: bool, length: float) -> Node3D:
	var root := _run_root(run)
	for tier in WALL_TIERS:
		var model_name := "wall-wood-window-shutters" if window and tier == 1 else "wall-wood"
		var module := _module(model_name, Vector3(length, 1.0, WALL_THICKNESS))
		module.position.y = float(tier)
		root.add_child(module)
	return root


func _stub(run: String, length: float) -> Node3D:
	var root := _run_root(run)
	root.add_child(_module("wall-wood", Vector3(length, STUB_HEIGHT, WALL_THICKNESS)))
	return root


func _lintel(run: String) -> Node3D:
	var root := _run_root(run)
	for tier in range(DOOR_HEIGHT, WALL_TIERS):
		var module := _module("wall-wood", Vector3(1.0, 1.0, WALL_THICKNESS))
		module.position.y = float(tier)
		root.add_child(module)
	return root


func _post(model_name: String, width: float, height: float) -> Node3D:
	var root := Node3D.new()
	root.add_child(_module(model_name, Vector3(width, height, width)))
	return root


func _floor() -> Node3D:
	var root := Node3D.new()
	var module := _module("planks", Vector3(1.0, FLOOR_THICKNESS, 1.0))
	module.position.y = -FLOOR_THICKNESS
	root.add_child(module)
	return root


## The stone footing under a wall cell: the wall stands on its middle.
func _footing() -> Node3D:
	var root := Node3D.new()
	root.add_child(_box(Vector3(1.0, FLOOR_THICKNESS, 1.0), Vector3(0, -FLOOR_THICKNESS, 0), STONE))
	return root


## The roof over `plan`: its outline roof (`BuildingPlan.roof_triangles()`) with flat faces, and
## a fascia board hanging FASCIA_DEPTH below its edge. Its origin is the grid's back corner.
func _roof(plan: BuildingPlan) -> Node3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	for triangle: PackedVector3Array in plan.roof_triangles():
		var normal := (triangle[1] - triangle[0]).cross(triangle[2] - triangle[0]).normalized()
		for point: Vector3 in triangle:
			# Courses run along the eave, at the same height across hips and valleys.
			var along := point.z if absf(normal.x) > absf(normal.z) else point.x
			tool.set_uv(Vector2(along * 0.5, -point.y))
			tool.add_vertex(point)
	tool.generate_normals()
	var root := Node3D.new()
	root.add_child(_surface(tool.commit(), ROOF_COLOUR))
	var fascia := SurfaceTool.new()
	fascia.begin(Mesh.PRIMITIVE_TRIANGLES)
	fascia.set_smooth_group(-1)
	for cell: Vector2i in plan.footprint_cells():
		for step: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			if plan.is_footprint(cell + step):
				continue
			var mid := Vector2(cell.x + 0.5, cell.y + 0.5) + Vector2(step) * 0.5
			var along := Vector2(absf(step.y), absf(step.x)) * 0.5
			var a := mid - along
			var b := mid + along
			var top_a := Vector3(a.x, plan.roof_height(a.x, a.y), a.y)
			var top_b := Vector3(b.x, plan.roof_height(b.x, b.y), b.y)
			var down := Vector3(0.0, FASCIA_DEPTH, 0.0)
			_quad(fascia, top_a, top_b, top_b - down, top_a - down)
	fascia.generate_normals()
	root.add_child(_surface(fascia.commit(), FASCIA_COLOUR))
	return root


## A view that holds `plan`'s whole roof at the kit's scale, with a margin.
static func _roof_view(plan: BuildingPlan) -> Vector2i:
	var span := float(plan.size.x + plan.size.y)
	var top := 0.0
	for cell: Vector2i in plan.footprint_cells():
		top = maxf(top, plan.roof_top(cell))
	return Vector2i(int(span * BuildingPlan.HALF_WIDTH) + 128, int(span * BuildingPlan.HALF_HEIGHT + top * BuildingPlan.PIXELS_PER_UNIT) + 128)


func _surface(mesh: Mesh, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _paint_material("roof-slate", Color.WHITE, 4) if colour == ROOF_COLOUR \
		else _paint_material("furniture-wood", Color(0.65, 0.65, 0.65))
	return instance


## A piece of furniture of `kind` covering `cells`, its origin the centre of its footprint on the
## floor. It is built along x with its front (a counter's customer side, a chest's lock, a hearth's
## fire) facing +z; a piece longer along z turns a quarter so it runs along z, front to +x. Both
## faces are towards the camera.
func _furniture(kind: String, cells: Vector2i) -> Node3D:
	var root := Node3D.new()
	var long_cells := maxi(cells.x, cells.y)
	if cells.y > cells.x:
		root.rotation.y = PI / 2.0
	var length := float(long_cells) - 2.0 * FURNITURE_MARGIN
	var depth := float(mini(cells.x, cells.y)) - 2.0 * FURNITURE_MARGIN
	match kind:
		"counter":
			var body_depth := depth - 0.25
			root.add_child(_box(Vector3(length - 0.06, 0.08, body_depth), Vector3.ZERO, WOOD_DARK))
			root.add_child(_box(Vector3(length - 0.1, 0.95, body_depth - 0.06), Vector3(0, 0.08, 0), WOOD))
			root.add_child(_box(Vector3(length, 0.07, depth - 0.1), Vector3(0, 1.03, 0), WOOD_TOP))
			for stile in long_cells + 1:
				var x := lerpf(-(length - 0.1) * 0.5, (length - 0.1) * 0.5, float(stile) / float(long_cells))
				root.add_child(_box(Vector3(0.07, 0.95, 0.03), Vector3(x, 0.08, (body_depth - 0.06) * 0.5), WOOD_DARK))
		"table":
			var height := 0.8
			root.add_child(_box(Vector3(length, 0.08, depth), Vector3(0, height - 0.08, 0), WOOD_TOP))
			for plank in range(1, 4):
				var z := lerpf(-depth * 0.5, depth * 0.5, float(plank) / 4.0)
				root.add_child(_box(Vector3(length, 0.006, 0.025), Vector3(0, height, z), WOOD_DARK))
			root.add_child(_box(Vector3(length - 0.3, 0.1, depth - 0.3), Vector3(0, height - 0.18, 0), WOOD_DARK))
			for sx: float in [-1.0, 1.0]:
				for sz: float in [-1.0, 1.0]:
					var leg_at := Vector3(sx * (length * 0.5 - 0.16), 0, sz * (depth * 0.5 - 0.16))
					root.add_child(_box(Vector3(0.12, height - 0.08, 0.12), leg_at, WOOD_DARK))
		"chest":
			# One chest or crate per cell, the middle ones stacked for a store's look.
			for k in long_cells:
				var x := float(k) - float(long_cells - 1) * 0.5
				var width := 0.8
				var chest_depth := minf(0.56, depth)
				root.add_child(_box(Vector3(width, 0.42, chest_depth), Vector3(x, 0, 0), WOOD))
				root.add_child(_box(Vector3(width + 0.03, 0.18, chest_depth + 0.03), Vector3(x, 0.42, 0), WOOD_TOP))
				for sx: float in [-1.0, 1.0]:
					root.add_child(_box(Vector3(0.06, 0.61, chest_depth + 0.05), Vector3(x + sx * width * 0.3, -0.005, 0), IRON))
				root.add_child(_box(Vector3(0.12, 0.14, 0.03), Vector3(x, 0.33, chest_depth * 0.5 + 0.015), IRON))
		"shelves":
			var height := 2.2
			var shelf_depth := minf(0.45, depth)
			for sx: float in [-1.0, 1.0]:
				root.add_child(_box(Vector3(0.08, height, shelf_depth), Vector3(sx * (length * 0.5 - 0.04), 0, 0), WOOD_DARK))
			root.add_child(_box(Vector3(length, height, 0.04), Vector3(0, 0, -shelf_depth * 0.5 + 0.02), WOOD_DARK))
			for board in 4:
				var y := 0.1 + float(board) * 0.68
				root.add_child(_box(Vector3(length - 0.12, 0.05, shelf_depth), Vector3(0, y, 0), WOOD))
				if board < 3:
					for k in long_cells * 2:
						var x := lerpf(-length * 0.5 + 0.3, length * 0.5 - 0.3, (float(k) + 0.5) / float(long_cells * 2))
						var colour := LINEN if (k + board) % 3 == 0 else (CLOTH if (k + board) % 3 == 1 else WOOD_TOP)
						root.add_child(_box(Vector3(0.22, 0.26 + 0.08 * float((k * 7 + board) % 3), 0.24), Vector3(x, y + 0.05, 0.02), colour))
		"hearth":
			var height := 1.3
			root.add_child(_box(Vector3(length, height, depth * 0.9), Vector3(0, 0, -depth * 0.05), STONE))
			root.add_child(_box(Vector3(length + 0.08, 0.1, depth), Vector3(0, height, 0), STONE.darkened(0.2)))
			root.add_child(_box(Vector3(length * 0.6, 0.55, 0.06), Vector3(0, 0.12, depth * 0.4), IRON))
			root.add_child(_box(Vector3(length * 0.45, 0.3, 0.07), Vector3(0, 0.14, depth * 0.41), FIRE))
		"stove":
			root.add_child(_box(Vector3(length, 0.85, depth * 0.85), Vector3.ZERO, IRON))
			root.add_child(_box(Vector3(length + 0.04, 0.06, depth * 0.9), Vector3(0, 0.85, 0), IRON.lightened(0.15)))
			root.add_child(_box(Vector3(0.18, 0.9, 0.18), Vector3(length * 0.5 - 0.2, 0.91, -depth * 0.25), IRON))
			root.add_child(_box(Vector3(0.3, 0.16, 0.04), Vector3(-length * 0.2, 0.3, depth * 0.43), FIRE))
		"bed":
			root.add_child(_box(Vector3(length, 0.32, depth), Vector3.ZERO, WOOD_DARK))
			root.add_child(_box(Vector3(length - 0.06, 0.14, depth - 0.06), Vector3(0, 0.32, 0), LINEN))
			root.add_child(_box(Vector3(length * 0.66, 0.06, depth - 0.02), Vector3(length * 0.16, 0.44, 0), CLOTH))
			root.add_child(_box(Vector3(0.3, 0.1, depth * 0.7), Vector3(-length * 0.5 + 0.22, 0.46, 0), LINEN.lightened(0.1)))
			root.add_child(_box(Vector3(0.08, 0.75, depth), Vector3(-length * 0.5 + 0.04, 0, 0), WOOD_DARK))
	return root


## A box `size` standing with the middle of its base at `at`.
func _box(size: Vector3, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _solid(mesh, at + Vector3(0.0, size.y * 0.5, 0.0), colour)


## An upright cylinder standing with the middle of its base at `at`.
func _cylinder(radius: float, height: float, at: Vector3, colour: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	return _solid(mesh, at + Vector3(0.0, height * 0.5, 0.0), colour)


func _solid(mesh: Mesh, centre: Vector3, colour: Color) -> MeshInstance3D:
	var material := _paint_material("furniture-wood")
	if colour == WOOD_DARK:
		material = _paint_material("furniture-wood", Color(0.6, 0.6, 0.6))
	elif colour == WOOD_TOP:
		material = _paint_material("floor-planks", Color(1.2, 1.15, 1.08))
	elif colour == STONE or colour == STONE.darkened(0.2):
		material = _paint_material("footing-stone" if centre.y < 0.0 else "hearth-stone")
	elif colour == IRON or colour == IRON.lightened(0.15):
		material = _paint_material("iron", Color(0.8, 0.8, 0.8))
	elif colour == CLOTH:
		material = _paint_material("cloth", Color(0.65, 0.24, 0.19))
	elif colour == LINEN or colour == LINEN.lightened(0.1):
		material = _paint_material("cloth", Color(1.25, 1.2, 1.1))
	elif colour == FIRE:
		material = _paint_material("hearth-stone", Color.WHITE, 8)
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material
	instance.position = centre
	return instance


func _paint_material(texture_name: String, tint := Color.WHITE, kind := 0) -> ShaderMaterial:
	if _paint_shader == null:
		_paint_shader = Shader.new()
		_paint_shader.code = PAINT_SHADER
	var material := ShaderMaterial.new()
	material.shader = _paint_shader
	material.set_shader_parameter("paint", _paint_texture(texture_name))
	material.set_shader_parameter("timber", _paint_texture("furniture-wood"))
	material.set_shader_parameter("metal", _paint_texture("iron"))
	material.set_shader_parameter("tint", tint)
	material.set_shader_parameter("kind", kind)
	return material


func _paint_texture(texture_name: String) -> Texture2D:
	if not _paint_textures.has(texture_name):
		var image := Image.load_from_file(MATERIALS + texture_name + ".png")
		image.generate_mipmaps()
		_paint_textures[texture_name] = ImageTexture.create_from_image(image)
	return _paint_textures[texture_name]


func _paint_module(node: Node, model_name: String) -> void:
	if node is MeshInstance3D:
		var instance := node as MeshInstance3D
		for surface in instance.mesh.get_surface_count():
			var original := instance.get_active_material(surface) as BaseMaterial3D
			var texture_name := "furniture-wood"
			var kind := 0
			if model_name.begins_with("wall-"):
				texture_name = "wall-plaster"
				kind = 1
			elif model_name == "pillar-wood":
				kind = 2
			elif model_name == "pillar-stone":
				texture_name = "footing-stone"
			elif model_name == "planks":
				texture_name = "floor-planks"
			var material := _paint_material(texture_name, Color.WHITE, kind)
			if kind == 1:
				material.set_shader_parameter("scale", 0.25)
			if original != null:
				material.set_shader_parameter("palette", original.albedo_texture)
			instance.set_surface_override_material(surface, material)
	for child: Node in node.get_children():
		_paint_module(child, model_name)


static func _quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for point: Vector3 in [a, b, c, a, c, d]:
		tool.add_vertex(point)
