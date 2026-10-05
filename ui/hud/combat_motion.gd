extends RefCounted
## Ease once across the complete path so a unit does not stop at every grid cell.
## The caller owns the tween and cancels it when replacing movement or leaving battle.

static func along_path(owner_node: Node, points: PackedVector2Array, apply_position: Callable) -> Tween:
	var lengths := PackedFloat32Array([0.0])
	for index: int in range(1, points.size()):
		lengths.append(lengths[index - 1] + points[index - 1].distance_to(points[index]))
	var tween := owner_node.create_tween()
	tween.tween_method(
		func(progress: float) -> void:
			var distance := progress * lengths[lengths.size() - 1]
			for index: int in range(1, points.size()):
				if distance <= lengths[index]:
					var span := lengths[index] - lengths[index - 1]
					var weight := (distance - lengths[index - 1]) / span if span > 0.0 else 1.0
					apply_position.call(points[index - 1].lerp(points[index], weight))
					return
			apply_position.call(points[points.size() - 1]),
		0.0, 1.0, DS.DUR_FAST * maxi(1, points.size() - 1)
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	return tween
