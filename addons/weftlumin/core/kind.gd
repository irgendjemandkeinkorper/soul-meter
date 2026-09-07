class_name WeftluminKind
extends RefCounted
## Per-kind authoring boundary from architecture §4.2.
## Concrete host kinds validate, replace their runtime overlay, and report bakes.

var id: StringName
var subdir: String
var ext: String
var stable_id_kind: StringName


## Pure validation returning normalized documents and appending attributed errors.
@warning_ignore("unused_parameter")
func validate(documents: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]:
	return []


## Atomically replace this kind's runtime overlay. The base stub refuses.
@warning_ignore("unused_parameter")
func register(normalised: Array[Dictionary]) -> bool:
	return false


## Clear only this kind's runtime overlay.
func clear() -> void:
	pass


## Describe changes between normalized document sets.
@warning_ignore("unused_parameter")
func diff(previous: Array[Dictionary], next: Array[Dictionary]) -> Dictionary:
	return {}


## Return a weftlumin.bake.v1 report; the base stub makes no success claim.
@warning_ignore("unused_parameter")
func bake(normalised: Array[Dictionary], target_root: String, write: bool, force: bool) -> Dictionary:
	return {}
