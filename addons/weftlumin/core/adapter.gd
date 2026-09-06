class_name WeftluminGameAdapter
extends RefCounted
## Host-game boundary from architecture §5. Base methods are inert placeholders.
## A host supplies policy, runtime integration, and game-specific authoring kinds.


## Name of the host's opt-in environment flag.
func env_flag() -> String:
	return ""


## Theme supplied by the host for editor controls.
func theme() -> Theme:
	return null


## Inform the host's chart/pause mechanism of editor ownership.
@warning_ignore("unused_parameter")
func set_editor_open(open: bool) -> void:
	pass


## Current gameplay root, or null outside gameplay.
func gameplay_scene_root() -> Node:
	return null


## Roots whose descendants the host allows the editor to modify.
@warning_ignore("unused_parameter")
func editable_roots(scene_root: Node) -> Array[Node]:
	return []


## Host-owned world/cell conversion and walkability boundary.
func grid() -> WeftluminGridAdapter:
	return null


## Host-owned placeable descriptors.
func placeables() -> Array[WeftluminPlaceable]:
	return []


## Authoring kinds supplied by the host.
func kinds() -> Array[WeftluminKind]:
	return []


## Host panel scenes implementing WeftluminPanel.
func panels() -> Array[PackedScene]:
	return []


## Capture the host's reversible runtime surfaces.
func capture_runtime_state() -> Dictionary:
	return {}


## Restore a prior host snapshot; the base stub always refuses.
@warning_ignore("unused_parameter")
func restore_runtime_state(s: Dictionary) -> bool:
	return false


## Whether production currently owns a battle or dialogue session.
func production_owner_live() -> bool:
	return false


## Semantic pickers for flags, factions, locations, items, units, and dialogue.
func pickers() -> Dictionary:
	return {}


## Repository canon root supplied by the host.
func canon_root() -> String:
	return ""


## Optional recorder event sink supplied by the host.
func recorder() -> Node:
	return null
