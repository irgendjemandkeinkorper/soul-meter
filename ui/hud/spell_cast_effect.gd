extends Node2D
## A committed cast's visual lifetime. Reads event data only; never advances combat.
## Anchors stay in the parent's coordinates so camera motion and board resizing work.
signal impact_reached

const HitPulseScript := preload("res://ui/hud/hit_pulse.gd")
const WINDUP := DS.DUR_FAST
const TRAVEL := DS.DUR_BASE
const RELEASE := DS.DUR_SLOW
const DURATION := WINDUP + TRAVEL + RELEASE
const SIGIL_FONT := preload(DS.FONT_DISPLAY)

static var _glow_texture: GradientTexture2D

var _source: Callable
var _targets: Array[Callable] = []
var _palette: Array[Dictionary] = []
var _elapsed := 0.0
var _visual_scale := 1.0
var _fizzled := false
var _hit := true
var _impacted := false
var _reduced := false


static func is_cast(event: CombatEvent) -> bool:
	return event.type == &"action_resolved" \
		and int(event.data.get("verb", -1)) == CombatAction.Verb.CAST \
		and not palette_for(event).is_empty()


static func palette_for(event: CombatEvent) -> Array[Dictionary]:
	var resolution: Dictionary = event.data.get("resolution", {})
	var composition: Dictionary = resolution.get("composition", {})
	var elements: Array = composition.get("elements", [])
	if elements.is_empty():
		var relationship: Dictionary = resolution.get("element_relationship", {})
		elements = [relationship.get("attack_element", "")]
	var result: Array[Dictionary] = []
	for entry: Dictionary in DS.WHEEL:
		if elements.has(StringName(entry["id"])) or elements.has(entry["id"]):
			result.append(entry)
	return result


func setup(event: CombatEvent, source: Callable, targets: Array[Callable], visual_scale: float) -> void:
	_source = source
	_targets = targets
	_visual_scale = maxf(0.1, visual_scale)
	_palette = palette_for(event)
	var resolution: Dictionary = event.data.get("resolution", {})
	_fizzled = bool(resolution.get("fizzled", false))
	_hit = HitPulseScript.did_hit(event)
	_reduced = _reduced_motion()


func _ready() -> void:
	if _glow_texture == null:
		var gradient := Gradient.new()
		gradient.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
		gradient.colors = PackedColorArray([Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.4), Color(1, 1, 1, 0.12), Color(1, 1, 1, 0)])
		_glow_texture = GradientTexture2D.new()
		_glow_texture.gradient = gradient
		_glow_texture.width = 128
		_glow_texture.height = 128
		_glow_texture.fill = GradientTexture2D.FILL_RADIAL
		_glow_texture.fill_from = Vector2(0.5, 0.5)
		_glow_texture.fill_to = Vector2(1.0, 0.5)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func is_animating() -> bool:
	return not _reduced_motion() and not is_queued_for_deletion()


func _process(delta: float) -> void:
	_elapsed += delta
	_reduced = _reduced_motion()
	if not _impacted and (_reduced or _elapsed >= impact_time()):
		_impacted = true
		impact_reached.emit()
	if _elapsed >= (RELEASE if _reduced else impact_time() + RELEASE):
		queue_free()
	queue_redraw()


func impact_time() -> float:
	return WINDUP if _fizzled else WINDUP + TRAVEL


func _reduced_motion() -> bool:
	return bool(GameState.get_setting("accessibility", "reduced_motion", false))


func _draw() -> void:
	if _palette.is_empty() or not _source.is_valid():
		return
	var origin_value: Variant = _source.call()
	if not origin_value is Vector2:
		return
	var origin: Vector2 = origin_value
	var radius := float(DS.SPACE_6) * _visual_scale
	if _reduced:
		# A stationary seal conveys the element without travel, shake, or a burst.
		if _fizzled:
			_draw_seal(origin, radius, 0.65, true)
		else:
			for anchor: Callable in _targets:
				var point: Variant = anchor.call() if anchor.is_valid() else null
				if point is Vector2:
					_draw_seal(point, radius, 0.8, not _hit)
		return
	var gathering := smoothstep(0.0, WINDUP, _elapsed)
	var source_alpha := 1.0 - smoothstep(WINDUP, impact_time() + RELEASE, _elapsed)
	_draw_glow(origin, radius * (1.0 + gathering), _palette[0]["color"], source_alpha * 0.6)
	_draw_seal(origin, radius * lerpf(1.3, 0.85, gathering), source_alpha, _fizzled)
	if _fizzled:
		# Break at the caster; a failed cast never travels to or strikes a target.
		_draw_motes(origin, radius, clampf((_elapsed - WINDUP) / RELEASE, 0.0, 1.0), 0, false)
		return
	for anchor: Callable in _targets:
		var point: Variant = anchor.call() if anchor.is_valid() else null
		if not point is Vector2:
			continue
		var destination: Vector2 = point
		if not _hit:
			destination += Vector2(radius * 1.6, -radius * 0.6)
		if _elapsed >= WINDUP and _elapsed < impact_time():
			_draw_travel(origin, destination, radius)
		elif _elapsed >= impact_time():
			var progress := clampf((_elapsed - impact_time()) / RELEASE, 0.0, 1.0)
			var fade := 1.0 - smoothstep(0.05, 1.0, progress)
			if _hit:
				_draw_glow(destination, radius * 3.0, _palette[0]["color"], fade * 0.65)
				_draw_seal(destination, radius * lerpf(0.65, 1.7, ease(progress, 0.5)), fade, false)
			for index: int in _palette.size():
				_draw_motes(destination, radius, progress, index, _hit)


func _draw_travel(origin: Vector2, destination: Vector2, radius: float) -> void:
	var progress := smoothstep(0.0, 1.0, (_elapsed - WINDUP) / TRAVEL)
	for index: int in _palette.size():
		var entry: Dictionary = _palette[index]
		var trail := PackedVector2Array()
		for step: int in 15:
			var t := maxf(0.0, progress - float(14 - step) * 0.025)
			trail.append(_travel_point(origin, destination, t, radius, index))
		var color: Color = entry["color"]
		# Taper both light and width toward the tail; a uniform opaque stroke reads
		# as a UI connector instead of energy moving through the scene.
		for step: int in range(1, trail.size()):
			var weight := float(step) / float(trail.size() - 1)
			var width := lerpf(0.5, 4.0, weight) * _visual_scale
			draw_line(trail[step - 1], trail[step], Color(color, weight * 0.12), width * 3.0, true)
			draw_line(trail[step - 1], trail[step], Color(color, weight * 0.55), width, true)
			draw_line(trail[step - 1], trail[step], Color(entry["glow"], weight * weight), _visual_scale, true)
		var head := trail[trail.size() - 1]
		_draw_glow(head, radius, color, 0.9)
		draw_circle(head, 2.5 * _visual_scale, entry["glow"], true, -1.0, true)


func _travel_point(origin: Vector2, destination: Vector2, t: float, radius: float, index: int) -> Vector2:
	var point := origin.lerp(destination, t)
	# The same eased path feeds head and trail; neither depends on frame count or RNG.
	point.y -= sin(t * PI) * minf(radius * 2.0, origin.distance_to(destination) * 0.2)
	point += (destination - origin).normalized().orthogonal() \
		* sin(t * TAU + float(index) * TAU / float(_palette.size())) * sin(t * PI) * radius * 0.3
	return point


func _draw_seal(center: Vector2, radius: float, opacity: float, broken: bool) -> void:
	if opacity <= 0.0:
		return
	for index: int in _palette.size():
		var entry: Dictionary = _palette[index]
		var start := float(index) * TAU / float(_palette.size()) - PI * 0.5
		var arc_size := TAU / float(_palette.size()) - (0.55 if broken else 0.18)
		var tint: Color = entry["color"]
		draw_arc(center, radius, start, start + arc_size, 40, Color(tint, opacity * 0.2), 6.0 * _visual_scale, true)
		draw_arc(center, radius, start, start + arc_size, 40, Color(entry["glow"], opacity), _visual_scale, true)
		var font_size := maxi(8, roundi(DS.FS_400 * _visual_scale))
		var sigil := str(entry["sigil"])
		var glyph_center := center
		if _palette.size() > 1:
			glyph_center += Vector2.from_angle(start + arc_size * 0.5) * radius * 0.52
		var width := SIGIL_FONT.get_string_size(sigil, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		draw_string(SIGIL_FONT, glyph_center + Vector2(-width * 0.5, font_size * 0.3), sigil,
			HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(entry["glow"], opacity))


func _draw_motes(center: Vector2, radius: float, progress: float, palette_index: int, landed: bool) -> void:
	if progress <= 0.0 or progress >= 1.0:
		return
	var entry: Dictionary = _palette[palette_index]
	var color := Color(entry["glow"], (1.0 - progress) * (1.0 - progress))
	var reach := radius * lerpf(0.35, 2.4 if landed else 1.2, ease(progress, 0.5))
	var unit := _visual_scale
	for index: int in 10:
		var angle := TAU * float(index) / 10.0 + float(palette_index) * 0.3
		var direction := Vector2.from_angle(angle)
		var point := center + direction * reach
		match str(entry["id"]):
			"zhur":
				var side := direction.orthogonal() * radius * 0.2
				draw_polyline(PackedVector2Array([center + direction * reach * 0.45, point - side, point + side, point + direction * radius * 0.35]), color, unit, true)
			"khash", "tham":
				point.y -= radius * progress if entry["id"] == "khash" else -radius * progress * progress
				var shard := PackedVector2Array([point - direction * 5.0 * unit, point + direction.orthogonal() * 2.0 * unit, point + direction * 3.0 * unit, point - direction.orthogonal() * 2.0 * unit])
				draw_colored_polygon(shard, color)
			"luth", "khor", "zhem", "vekh":
				if index % 3 == 0:
					draw_arc(center, reach * (0.5 + float(index) * 0.08), angle, angle + PI * 0.65, 24, color, unit, true)
			"vel":
				draw_line(point, point - direction * radius * 0.4, color, unit, true)
				draw_arc(point, 4.0 * unit, angle, angle + PI, 12, color, unit, true)
			"sul":
				draw_line(point, point + direction * radius * 0.4, color, unit, true)
			_:
				draw_circle(point, 2.0 * unit, color, true, -1.0, true)


func _draw_glow(center: Vector2, radius: float, color: Color, opacity: float) -> void:
	if _glow_texture != null:
		draw_texture_rect(_glow_texture, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false, Color(color, opacity))
