extends RefCounted
## One look per tone, and a flourish per class (owner 2026-11-02: "one look per tone + class
## flourishes"). A look is a recipe of drawn primitives over a beat's progress `t` in [0, 1];
## the caller's `_draw()` calls `draw()`, so every look is deterministic (no RNG, no frame
## count) and reduced motion simply never asks for one.
##
## The tone looks follow each tone's sound in the hexgame Element Atlas the owner shared
## (sul "struck crystal", luth "a low liquid pulse", vekh "a sound being taken away", ...):
## presentation only, in the ratified DS.WHEEL colours. The class flourishes take their shape
## from the class's kit (a clock for Oathclock, a gear for Locksmirk) and their colour from the
## class's suggested Major. All sizes and counts are PROVISIONAL for the art pass.

const TONE_LOOKS := {
	"sul": [{"kind": "flash"}, {"kind": "rays", "n": 12, "reach": 2.6}, {"kind": "shards", "n": 6}],
	"vel": [{"kind": "motes", "mode": "spiral", "n": 14, "size": 2.4}, {"kind": "rings", "n": 1}],
	"luth": [{"kind": "rings", "n": 3, "delay": 0.18}, {"kind": "motes", "mode": "out", "n": 8, "size": 2.0}],
	"khor": [{"kind": "rings", "n": 3, "delay": 0.26, "width": 1.0}, {"kind": "rays", "n": 8, "reach": 1.5}],
	"tham": [{"kind": "rings", "n": 1, "width": 3.0}, {"kind": "motes", "mode": "down", "n": 10, "size": 3.0, "square": true}],
	"vekh": [{"kind": "drain", "dark": true}, {"kind": "motes", "mode": "in", "n": 16, "size": 2.0}],
	"mozh": [{"kind": "motes", "mode": "down", "n": 18, "size": 1.8, "slow": true}, {"kind": "rings", "n": 1, "width": 1.0}],
	"khash": [{"kind": "flash"}, {"kind": "motes", "mode": "up", "n": 16, "size": 2.2}],
	"zhem": [{"kind": "drain"}, {"kind": "rings", "n": 1, "width": 1.0}],
	"zhur": [{"kind": "bolt"}, {"kind": "flash"}, {"kind": "rays", "n": 6, "reach": 1.6}],
}

const CLASS_LOOKS := {
	"mirrorblade": [{"kind": "shards", "n": 8}, {"kind": "rays", "n": 4, "reach": 2.2}],
	"river-mother": [{"kind": "rings", "n": 2, "delay": 0.22}, {"kind": "motes", "mode": "up", "n": 6, "size": 1.8}],
	"ironbrand": [{"kind": "flash"}, {"kind": "motes", "mode": "up", "n": 12, "size": 1.8}],
	"lensbearer": [{"kind": "rays", "n": 10, "reach": 2.2}, {"kind": "rings", "n": 1, "width": 1.0}],
	"husk-bearer": [{"kind": "drain", "dark": true}, {"kind": "motes", "mode": "in", "n": 12, "size": 1.8}],
	"flamebinder": [{"kind": "rings", "n": 1, "width": 3.0}, {"kind": "motes", "mode": "up", "n": 10, "size": 2.0}],
	"stormbearer": [{"kind": "bolt"}, {"kind": "rays", "n": 6, "reach": 1.4}],
	"oathclock": [{"kind": "ticks"}],
	"locksmirk": [{"kind": "gear"}],
	"threadwalker": [{"kind": "threads", "n": 6}, {"kind": "motes", "mode": "in", "n": 6, "size": 1.6}],
}

## A look's flourish colour when its class suggests no Major (Locksmirk chooses its own).
const FALLBACK_COLOR := DS.BRONZE_3
const FALLBACK_GLOW := DS.BRONZE_4

static var _glow_texture: GradientTexture2D


static func tone_look(tone_id: String) -> Array:
	return TONE_LOOKS.get(tone_id, []) as Array


static func class_look(class_id: String) -> Array:
	return CLASS_LOOKS.get(class_id, []) as Array


## The flourish colours for a class: its suggested Major's wheel colour and glow.
static func class_colors(class_id: String) -> Array[Color]:
	var major := str(ClassCatalog.by_id(class_id).get("suggested_major", ""))
	for entry: Dictionary in DS.WHEEL:
		if str(entry["id"]) == major:
			return [entry["color"] as Color, entry["glow"] as Color]
	return [FALLBACK_COLOR, FALLBACK_GLOW]


## Draws `look` on `canvas` (call from the canvas's own `_draw()`). `center` is the effect
## anchor the overlay uses for result cards (DS.SPACE_8 above the feet); ground pieces (rings,
## drains) sit at the feet.
static func draw(
	canvas: CanvasItem, look: Array, center: Vector2, radius: float, t: float,
	color: Color, glow: Color, unit: float
) -> void:
	if t <= 0.0 or t >= 1.0:
		return
	var ground := center + Vector2(0.0, DS.SPACE_8)
	for step: Dictionary in look:
		match str(step.get("kind", "")):
			"flash":
				_flash(canvas, center, radius, t, color)
			"rings":
				_rings(canvas, ground, radius, t, glow, int(step.get("n", 1)), float(step.get("delay", 0.0)), float(step.get("width", 1.6)) * unit)
			"rays":
				_rays(canvas, center, radius, t, color, glow, int(step.get("n", 8)), float(step.get("reach", 2.0)), unit)
			"motes":
				_motes(canvas, center, radius, t, color, glow, step, unit)
			"bolt":
				_bolt(canvas, center, radius, t, color, glow, unit)
			"shards":
				_shards(canvas, center, radius, t, glow, int(step.get("n", 6)), unit)
			"ticks":
				_ticks(canvas, center, radius, t, color, glow, unit)
			"gear":
				_gear(canvas, center, radius, t, color, glow, unit)
			"threads":
				_threads(canvas, center, radius, t, color, glow, int(step.get("n", 6)), unit)
			"drain":
				_drain(canvas, ground, radius, t, color, bool(step.get("dark", false)), unit)


static func _fade(t: float) -> float:
	return pow(1.0 - t, 1.5)


## Deterministic 0..1 per index: the same mote always takes the same path.
static func _hash(index: int, salt: float) -> float:
	var value := sin(float(index) * 12.9898 + salt * 78.233) * 43758.5453
	return value - floorf(value)


static func _ellipse(canvas: CanvasItem, center: Vector2, rx: float, color: Color, width: float) -> void:
	var points := PackedVector2Array()
	for index: int in 41:
		var angle := TAU * float(index) / 40.0
		points.append(center + Vector2(cos(angle) * rx, sin(angle) * rx * 0.5))
	canvas.draw_polyline(points, color, width, true)


static func _flash(canvas: CanvasItem, center: Vector2, radius: float, t: float, color: Color) -> void:
	var size := radius * 3.2 * (1.0 - t * 0.3)
	canvas.draw_texture_rect(
		_glow(), Rect2(center - Vector2.ONE * size, Vector2.ONE * size * 2.0), false,
		Color(color, pow(1.0 - t, 2.0) * 0.85)
	)


## Iso-flat rings spreading at the feet; `n` of them, each `delay` after the last.
static func _rings(canvas: CanvasItem, ground: Vector2, radius: float, t: float, glow: Color, n: int, delay: float, width: float) -> void:
	var span := maxf(0.2, 1.0 - delay * float(n - 1))
	for index: int in n:
		var local := clampf((t - delay * float(index)) / span, 0.0, 1.0)
		if local <= 0.0 or local >= 1.0:
			continue
		var reach := radius * lerpf(0.3, 2.4, ease(local, 0.4))
		_ellipse(canvas, ground, reach, Color(glow, pow(1.0 - local, 2.0)), width)


static func _rays(canvas: CanvasItem, center: Vector2, radius: float, t: float, color: Color, glow: Color, n: int, reach: float, unit: float) -> void:
	var alpha := _fade(t)
	for index: int in n:
		var direction := Vector2.from_angle(TAU * float(index) / float(n) + t * 0.4)
		var inner := center + direction * radius * 0.45
		var outer := center + direction * radius * lerpf(0.7, reach, ease(t, 0.35))
		canvas.draw_line(inner, outer, Color(color, alpha * 0.45), 3.0 * unit, true)
		canvas.draw_line(inner, outer, Color(glow, alpha), unit, true)


## `mode`: out (burst), up (embers rise), down (debris or spores fall), in (drawn to the
## centre), spiral (rising around it).
static func _motes(canvas: CanvasItem, center: Vector2, radius: float, t: float, color: Color, glow: Color, step: Dictionary, unit: float) -> void:
	var n := int(step.get("n", 10))
	var size := float(step.get("size", 2.0)) * unit
	var mode := str(step.get("mode", "out"))
	var pace := 0.6 if bool(step.get("slow", false)) else 1.0
	var square := bool(step.get("square", false))
	var alpha := _fade(t)
	for index: int in n:
		var spread := 0.6 + 0.4 * _hash(index, 1.0)
		var angle := TAU * float(index) / float(n) + _hash(index, 2.0) * 0.6
		var direction := Vector2.from_angle(angle)
		var point := center
		match mode:
			"up":
				point = center + Vector2(direction.x * radius * 1.5 * spread, radius * 0.6) \
					+ Vector2(sin(t * 6.0 + float(index)) * radius * 0.15, -radius * 2.4 * t * spread * pace)
			"down":
				point = center + Vector2(direction.x * radius * 1.8 * spread, -radius * 1.4) \
					+ Vector2(sin(t * 3.0 + float(index)) * radius * 0.2, radius * 2.6 * t * spread * pace)
			"in":
				point = (center + direction * radius * 2.6 * spread).lerp(center, ease(t, 2.2))
			"spiral":
				var turn := angle + t * TAU * 0.8
				point = center + Vector2(cos(turn), sin(turn) * 0.5) * radius * lerpf(1.6, 0.6, t) * spread \
					+ Vector2(0.0, -radius * 1.8 * t)
			_:
				point = center + direction * radius * lerpf(0.2, 2.4, ease(t, 0.4)) * spread \
					+ Vector2(0.0, radius * 0.6 * t * t)
		var mote := size * (1.0 - t * 0.5)
		if square:
			canvas.draw_rect(Rect2(point - Vector2.ONE * mote, Vector2.ONE * mote * 2.0), Color(color, alpha))
		else:
			canvas.draw_circle(point, mote * 2.0, Color(color, alpha * 0.25), true, -1.0, true)
			canvas.draw_circle(point, mote, Color(glow, alpha), true, -1.0, true)


## A forked strike from above that flickers twice.
static func _bolt(canvas: CanvasItem, center: Vector2, radius: float, t: float, color: Color, glow: Color, unit: float) -> void:
	if not (t < 0.16 or (t > 0.26 and t < 0.4)):
		return
	var top := center + Vector2(radius * 0.5, -radius * 5.0)
	var points := PackedVector2Array([top])
	for index: int in range(1, 7):
		var along := float(index) / 6.0
		var jag := (_hash(index, 3.0) - 0.5) * radius * 0.9 * (1.0 - along)
		points.append(top.lerp(center, along) + Vector2(jag, 0.0))
	canvas.draw_polyline(points, Color(color, 0.55), 5.0 * unit, true)
	canvas.draw_polyline(points, Color(glow, 1.0), 1.6 * unit, true)
	var fork := points[3]
	canvas.draw_line(fork, fork + Vector2(-radius * 0.9, radius * 0.7), Color(glow, 0.7), unit, true)


static func _shards(canvas: CanvasItem, center: Vector2, radius: float, t: float, glow: Color, n: int, unit: float) -> void:
	var alpha := _fade(t)
	for index: int in n:
		var direction := Vector2.from_angle(TAU * float(index) / float(n) + 0.3)
		var point := center + direction * radius * lerpf(0.3, 2.1, ease(t, 0.4))
		var spin := t * 4.0 + float(index)
		var along := Vector2.from_angle(spin) * 5.0 * unit
		var across := along.orthogonal() * 0.4
		canvas.draw_colored_polygon(
			PackedVector2Array([point - along, point + across, point + along, point - across]),
			Color(glow, alpha)
		)


## A clock face: twelve ticks and a hand sweeping once round.
static func _ticks(canvas: CanvasItem, center: Vector2, radius: float, t: float, color: Color, glow: Color, unit: float) -> void:
	var alpha := 1.0 - t * t
	var face := radius * 1.5
	canvas.draw_arc(center, face, 0.0, TAU, 48, Color(color, alpha * 0.5), 2.0 * unit, true)
	for index: int in 12:
		var direction := Vector2.from_angle(TAU * float(index) / 12.0)
		var length := 0.22 if index % 3 == 0 else 0.12
		canvas.draw_line(center + direction * face, center + direction * face * (1.0 - length), Color(glow, alpha), unit, true)
	var hand := Vector2.from_angle(-PI * 0.5 + ease(t, 0.6) * TAU)
	canvas.draw_line(center, center + hand * face * 0.85, Color(glow, alpha), 1.6 * unit, true)


## A turning gear: a toothed ring a quarter-turn round.
static func _gear(canvas: CanvasItem, center: Vector2, radius: float, t: float, color: Color, glow: Color, unit: float) -> void:
	var alpha := 1.0 - t * t
	var outer := radius * 1.45
	var inner := radius * 1.2
	var turn := ease(t, 0.5) * PI * 0.5
	var points := PackedVector2Array()
	for index: int in 41:
		var angle := TAU * float(index) / 40.0 + turn
		var r := outer if index % 4 < 2 else inner
		points.append(center + Vector2.from_angle(angle) * r)
	canvas.draw_polyline(points, Color(color, alpha * 0.6), 2.5 * unit, true)
	canvas.draw_polyline(points, Color(glow, alpha), unit, true)
	canvas.draw_arc(center, radius * 0.45, 0.0, TAU, 24, Color(glow, alpha), unit, true)


## Threads drawn in from round the body to it.
static func _threads(canvas: CanvasItem, center: Vector2, radius: float, t: float, color: Color, glow: Color, n: int, unit: float) -> void:
	var alpha := _fade(t)
	var reach := clampf(t * 1.6, 0.0, 1.0)
	for index: int in n:
		var start := center + Vector2.from_angle(TAU * float(index) / float(n) - PI * 0.5) * radius * 2.6
		var end := start.lerp(center, ease(reach, 0.5))
		canvas.draw_line(start, end, Color(color, alpha * 0.5), 2.0 * unit, true)
		canvas.draw_line(start, end, Color(glow, alpha), 0.8 * unit, true)


## A pool spreading at the feet: pale (silence) or dark (shelter, hunger).
static func _drain(canvas: CanvasItem, ground: Vector2, radius: float, t: float, color: Color, dark: bool, unit: float) -> void:
	var reach := radius * lerpf(0.4, 2.4, ease(t, 0.4))
	var tint := color.darkened(0.6) if dark else color.lerp(DS.PARCHMENT, 0.5)
	var points := PackedVector2Array()
	for index: int in 32:
		var angle := TAU * float(index) / 32.0
		points.append(ground + Vector2(cos(angle) * reach, sin(angle) * reach * 0.5))
	canvas.draw_colored_polygon(points, Color(tint, 0.32 * _fade(t)))
	_ellipse(canvas, ground, reach, Color(tint.lightened(0.3), 0.6 * _fade(t)), unit)


static func _glow() -> GradientTexture2D:
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
	return _glow_texture
