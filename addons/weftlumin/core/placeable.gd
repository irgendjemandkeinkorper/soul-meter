class_name WeftluminPlaceable
extends RefCounted
## One entry of the host's placeable registry (architecture §4.6.4, E3.1b). The palette lists
## these and the scene model instances them; neither knows the host's actor types.
##
## A placeable is either a `scene` (instanced) or, for plain engine nodes such as spawn markers,
## a `node_type` the engine can construct. `group` is the palette category the host assigns —
## carried on the entry, never derived from a file path at display time.

## Stable registry id, recorded in the `add_node` command.
var id: StringName = &""
## Instanced scene. Null when `node_type` names an engine class instead.
var scene: PackedScene = null
## Engine `Node2D` class constructed when `scene` is null (e.g. `Marker2D`).
var node_type: StringName = &""
## Palette label.
var display: String = ""
## Palette category.
var group: String = ""
## Export values applied before the instance enters the tree, as `{property: value}`.
var default_exports: Dictionary = {}
## Node name stem; the model appends a number to keep siblings unique.
var base_name: String = ""


static func make(
	placeable_id: StringName,
	label: String,
	category: String,
	packed: PackedScene = null,
	engine_type: StringName = &"",
	stem: String = "",
	exports: Dictionary = {},
) -> WeftluminPlaceable:
	var entry := WeftluminPlaceable.new()
	entry.id = placeable_id
	entry.display = label
	entry.group = category
	entry.scene = packed
	entry.node_type = engine_type
	entry.base_name = stem if not stem.is_empty() else label.to_pascal_case()
	entry.default_exports = exports.duplicate(true)
	return entry


## `res://` path of the scene, or "" for an engine-class placeable.
func scene_path() -> String:
	return scene.resource_path if scene != null else ""
