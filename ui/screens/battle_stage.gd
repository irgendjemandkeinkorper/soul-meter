extends Control
## Code-native battle tableau. It gives the command HUD a stage to sit on while
## the project is still using placeholder art. The composition deliberately
## reads as: party in the foreground, enemy at range, commands below.

var _allies: Array[BattleActor] = []
var _enemies: Array[BattleActor] = []
var _target_index := -1
var _active_ally: BattleActor
var _balance := 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_battle_state(
	allies: Array[BattleActor], foes: Array[BattleActor], target_index: int,
	active_ally: BattleActor, balance: int
) -> void:
	_allies = allies
	_enemies = foes
	_target_index = target_index
	_active_ally = active_ally
	_balance = balance
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	if w < 2.0 or h < 2.0:
		return

	# Deep indigo-to-void sky, made from broad bands so the tableau still feels
	# alive without committing the project to a final environment illustration.
	for band in range(12):
		var t := float(band) / 11.0
		var color := Color("#17152D").lerp(Color("#07080B"), t)
		draw_rect(Rect2(0, h * 0.72 * t, w, h * 0.72 / 12.0 + 2.0), color)

	# A pale, broken moon and its violet haze establish a focal point behind the
	# enemy. The rings echo the game's Soul/Balance language.
	var moon := Vector2(w * 0.73, h * 0.24)
	for ring in range(6, 0, -1):
		draw_circle(moon, 42.0 + ring * 18.0, Color(0.45, 0.32, 0.78, 0.015 * ring))
	draw_circle(moon, 42.0, Color("#D9D0FF"))
	draw_circle(moon + Vector2(-10, -8), 34.0, Color("#9E91C9"))

	# Faint suspended motes, concentrated around the encounter focal point.
	for mote in range(18):
		var x := fmod(float(mote * 113 + 37), w * 0.78) + w * 0.08
		var y := fmod(float(mote * 67 + 41), h * 0.58) + h * 0.10
		var radius := 1.0 + float(mote % 3) * 0.7
		draw_circle(Vector2(x, y), radius, Color(0.66, 0.55, 0.92, 0.18))

	# Perspective floor plane. The bottom HUD intentionally covers its lower
	# edge, just as a battle command window would in a 1990s console RPG.
	var horizon := h * 0.48
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(0, horizon), Vector2(w, horizon), Vector2(w, h), Vector2(0, h)
		]),
		Color("#0D101B")
	)
	for row in range(7):
		var y := horizon + pow(float(row + 1) / 7.0, 1.8) * h * 0.62
		draw_line(Vector2(0, y), Vector2(w, y), Color(0.35, 0.31, 0.56, 0.16), 1.0)
	for column in range(-8, 14):
		var top_x := w * 0.5 + column * w * 0.055
		var bottom_x := w * 0.5 + column * w * 0.16
		draw_line(Vector2(top_x, horizon), Vector2(bottom_x, h), Color(0.35, 0.31, 0.56, 0.13), 1.0)

	# Back and front pools of light help separate sides even before real actor
	# sprites arrive.
	_draw_battle_ellipse(Vector2(w * 0.73, h * 0.55), Vector2(w * 0.20, h * 0.055), Color(0.48, 0.30, 0.84, 0.16))
	_draw_battle_ellipse(Vector2(w * 0.25, h * 0.55), Vector2(w * 0.24, h * 0.07), Color(0.10, 0.55, 0.67, 0.11))

	_draw_enemies(w, h)
	_draw_party(w, h)


func _draw_enemies(w: float, h: float) -> void:
	if _enemies.is_empty():
		return
	var count := _enemies.size()
	for i in count:
		var foe := _enemies[i]
		var spread := (float(i) - float(count - 1) * 0.5) * minf(145.0, w * 0.12)
		var center := Vector2(w * 0.73 + spread, h * 0.48 + absf(spread) * 0.03)
		_draw_enemy(center, foe, i == _target_index)


func _draw_enemy(center: Vector2, foe: BattleActor, selected: bool) -> void:
	var alive := foe.is_alive()
	var body_color := Color("#5F426D") if "wight" in foe.display_name.to_lower() else Color("#604D45")
	if not alive:
		body_color = Color("#2B2A3A")
	var actor_scale := clampf(0.82 + float(foe.max_hp) / 100.0, 0.82, 1.28)
	var c := center + Vector2(0, -34.0 * actor_scale)

	if selected and alive:
		draw_arc(center + Vector2(0, 14), 78.0 * actor_scale, PI * 0.12, PI * 0.88, 28, Color("#D9AB45"), 3.0, true)
		draw_arc(center + Vector2(0, 14), 88.0 * actor_scale, PI * 0.18, PI * 0.82, 24, Color(0.85, 0.67, 0.27, 0.24), 2.0, true)

	# Hood / head, antlers, and a long coat read as a soul-haunted foe even at
	# small scale. These are deliberately abstract until bespoke sprites exist.
	draw_circle(c + Vector2(0, -42) * actor_scale, 25.0 * actor_scale, Color("#B8A5C9") if alive else body_color)
	draw_line(c + Vector2(-12, -62) * actor_scale, c + Vector2(-35, -92) * actor_scale, body_color, 5.0 * actor_scale)
	draw_line(c + Vector2(12, -62) * actor_scale, c + Vector2(35, -92) * actor_scale, body_color, 5.0 * actor_scale)
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-40, -18) * actor_scale, c + Vector2(40, -18) * actor_scale,
			c + Vector2(60, 72) * actor_scale, c + Vector2(-62, 72) * actor_scale
		]), body_color
	)
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-10, -18) * actor_scale, c + Vector2(10, -18) * actor_scale,
			c + Vector2(6, 72) * actor_scale, c + Vector2(-6, 72) * actor_scale
		]), Color(0.10, 0.08, 0.16, 0.8)
	)
	draw_circle(c + Vector2(-9, -45) * actor_scale, 4.0 * actor_scale, Color("#EF4444") if alive else Color("#343144"))
	draw_circle(c + Vector2(9, -45) * actor_scale, 4.0 * actor_scale, Color("#EF4444") if alive else Color("#343144"))


func _draw_party(w: float, h: float) -> void:
	if _allies.is_empty():
		return
	var count := _allies.size()
	for i in count:
		var ally := _allies[i]
		var spread := (float(i) - float(count - 1) * 0.5) * minf(115.0, w * 0.09)
		var center := Vector2(w * 0.27 + spread, h * 0.50 + absf(spread) * 0.02)
		_draw_ally(center, ally, ally == _active_ally)


func _draw_ally(center: Vector2, ally: BattleActor, selected: bool) -> void:
	var alive := ally.is_alive()
	var accent := Color("#22D3EE") if selected else Color("#607A96")
	if not alive:
		accent = Color("#303542")
	var c := center
	if selected and alive:
		draw_arc(c + Vector2(0, 14), 52.0, PI * 0.18, PI * 0.82, 24, Color("#22D3EE"), 2.0, true)
	# Smaller foreground silhouettes, turned toward the enemy.
	draw_circle(c + Vector2(0, -47), 17.0, Color("#C2CCD8") if alive else Color("#3A3D49"))
	draw_colored_polygon(
		PackedVector2Array([
			c + Vector2(-24, -29), c + Vector2(20, -29),
			c + Vector2(37, 58), c + Vector2(-38, 58)
		]), Color("#283B51") if alive else Color("#20232D")
	)
	draw_line(c + Vector2(18, -18), c + Vector2(48, 34), accent, 5.0 if selected else 3.0)
	draw_line(c + Vector2(48, 34), c + Vector2(64, 27), accent, 3.0)


func _draw_battle_ellipse(center: Vector2, radii: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 32:
		var angle := TAU * float(i) / 32.0
		points.append(center + Vector2(cos(angle) * radii.x, sin(angle) * radii.y))
	draw_colored_polygon(points, color)
