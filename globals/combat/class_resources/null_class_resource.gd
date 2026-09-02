class_name NullClassResource
extends ClassResource
## No-op resource for actors without a patron class (enemies, ad-hoc test actors). Exists so
## controller dispatch never null-checks and so `snapshot()` is uniform across the roster.


func snapshot() -> Dictionary:
	return {}


func is_null() -> bool:
	return true
