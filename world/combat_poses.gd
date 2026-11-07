extends RefCounted
## Combat poses on the current art (owner 2026-11-02, "motion on current art"): every unit has
## one painted idle frame, so a body's motion is a small transform on its Sprite2D — never on
## the body node, whose position is the battlefield's cell. Each pose starts from the sprite's
## base transform (`capture()`) and, except the slump, ends back on it.
##
## Pose sizes are in world px at camera zoom 1 and are PROVISIONAL for the art pass: real
## walk, attack, hit and fall frames replace them (owner list, art follow-ups).

## Height of one walking step's hop.
const BOB_PX := 5.0
## The recoil's push away from the attacker, and its lean.
const RECOIL_PX := 9.0
const RECOIL_LEAN := 0.12
## The lunge's wind-up lean back, then lean into the strike (radians).
const WINDUP_LEAN := 0.07
const STRIKE_LEAN := 0.16
## A caster rises this far and swells this much while the cast gathers.
const CAST_LIFT_PX := 6.0
const CAST_SWELL := 1.05
## A downed body leans away from its last attacker and settles lower.
const SLUMP_LEAN := 0.34
const SLUMP_SINK_PX := 5.0
const SLUMP_SQUASH := 0.9


static func capture(sprite: Sprite2D) -> Dictionary:
	return {
		"position": sprite.position, "rotation": sprite.rotation,
		"scale": sprite.scale, "self_modulate": sprite.self_modulate,
	}


static func restore(sprite: Sprite2D, base: Dictionary) -> void:
	sprite.position = base["position"]
	sprite.rotation = base["rotation"]
	sprite.scale = base["scale"]
	sprite.self_modulate = base["self_modulate"]


## The tween's closing restore. Leaving a fight mid-animation (back to the title, say, while
## the AI-vs-AI demo plays) frees the sprite before its tween ends; a bound call would then
## fail on the freed object, so the restore checks the sprite is still there.
## A weak reference, because a lambda that captured the sprite itself reports the freed
## capture as an engine error when it runs.
static func _restore_later(sprite: Sprite2D, base: Dictionary) -> Callable:
	var held: WeakRef = weakref(sprite)
	return func() -> void:
		var alive := held.get_ref() as Sprite2D
		if alive != null:
			restore(alive, base)


## One hop per cell, timed to the walk tween (`CombatMotion.along_path`).
static func step_bob(tween: Tween, sprite: Sprite2D, base: Dictionary, steps: int, seconds: float) -> void:
	var rest: Vector2 = base["position"]
	tween.tween_method(
		func(progress: float) -> void:
			sprite.position = rest + Vector2(0.0, -BOB_PX * absf(sin(progress * PI * maxi(1, steps)))),
		0.0, 1.0, seconds
	)
	tween.tween_callback(_restore_later(sprite, base))


## Lean back, then into the strike, timed to the body lunge (two DUR_FAST halves).
static func lunge(tween: Tween, sprite: Sprite2D, base: Dictionary, toward_x: float) -> void:
	var side := signf(toward_x) if not is_zero_approx(toward_x) else 1.0
	var rest: float = base["rotation"]
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", rest - WINDUP_LEAN * side, DS.DUR_INSTANT)
	tween.tween_property(sprite, "rotation", rest + STRIKE_LEAN * side, DS.DUR_FAST)
	tween.tween_property(sprite, "rotation", rest, DS.DUR_FAST)
	tween.tween_callback(_restore_later(sprite, base))


## Knocked back from `away` (a world direction), then settles.
static func recoil(tween: Tween, sprite: Sprite2D, base: Dictionary, away: Vector2) -> void:
	var push := away.normalized() * RECOIL_PX if not away.is_zero_approx() else Vector2(0.0, -RECOIL_PX * 0.5)
	var rest: Vector2 = base["position"]
	var lean: float = float(base["rotation"]) + RECOIL_LEAN * (signf(push.x) if not is_zero_approx(push.x) else 1.0)
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", rest + push, DS.DUR_INSTANT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", lean, DS.DUR_INSTANT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.chain().tween_property(sprite, "position", rest, DS.DUR_BASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", float(base["rotation"]), DS.DUR_BASE).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.chain().tween_callback(_restore_later(sprite, base))


## The caster rises and swells while the cast gathers (`gather` seconds), lit by `glow`, then
## settles as it lands.
static func cast_lift(tween: Tween, sprite: Sprite2D, base: Dictionary, glow: Color, gather: float) -> void:
	var rest: Vector2 = base["position"]
	var size: Vector2 = base["scale"]
	var lit: Color = (base["self_modulate"] as Color) * Color.WHITE.lerp(Color(glow.r * 1.6, glow.g * 1.6, glow.b * 1.6), 0.45)
	tween.set_parallel(true)
	tween.tween_property(sprite, "position", rest + Vector2(0.0, -CAST_LIFT_PX), gather).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", size * CAST_SWELL, gather).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "self_modulate", lit, gather)
	tween.chain().tween_property(sprite, "position", rest, DS.DUR_BASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", size, DS.DUR_BASE)
	tween.tween_property(sprite, "self_modulate", base["self_modulate"], DS.DUR_SLOW)
	tween.chain().tween_callback(_restore_later(sprite, base))


## A downed body leans away from its attacker and settles lower. It stays down (no restore):
## the overlay restores the base when the actor stands again or the fight ends.
static func slump(tween: Tween, sprite: Sprite2D, base: Dictionary, away_x: float) -> void:
	var side := signf(away_x) if not is_zero_approx(away_x) else 1.0
	var size: Vector2 = base["scale"]
	tween.set_parallel(true).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "rotation", float(base["rotation"]) + SLUMP_LEAN * side, DS.DUR_SLOW)
	tween.tween_property(sprite, "position", (base["position"] as Vector2) + Vector2(0.0, SLUMP_SINK_PX), DS.DUR_SLOW)
	tween.tween_property(sprite, "scale", Vector2(size.x, size.y * SLUMP_SQUASH), DS.DUR_SLOW)


## Turning to face the other way: a quick squash through edge-on, flipping at the middle.
static func turn(tween: Tween, sprite: Sprite2D, base: Dictionary, flip_to: bool) -> void:
	var size: Vector2 = base["scale"]
	tween.tween_property(sprite, "scale", Vector2(size.x * 0.12, size.y), DS.DUR_INSTANT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tween.tween_callback(func() -> void: sprite.flip_h = flip_to)
	tween.tween_property(sprite, "scale", size, DS.DUR_INSTANT).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(_restore_later(sprite, base))
