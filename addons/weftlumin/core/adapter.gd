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


# --- Headless CLI (§4.13, E7.1). `addons/weftlumin/tools/weftlumin.gd` calls these; the base
# stubs make no claim, so a host without them validates and bakes nothing game-specific.


## Kinds the CLI validates and bakes from a package directory, keyed by kind id. A kind with a
## `subdir` reads `<package>/<subdir>/*.<ext>`; the `scenes` kind reads `<package>/commands.jsonl`.
func cli_kinds() -> Array[WeftluminKind]:
	return kinds()


## Validate one kind's package documents against the host's canon. Attributed errors. `package`
## is the CLI's loaded package (`dir`, `id`, `hub`, `manifest`, `kinds`, `log_entries`, `dialogue`).
@warning_ignore("unused_parameter")
func validate_package_documents(kind: WeftluminKind, documents: Array[Dictionary], package: Dictionary) -> Array[Dictionary]:
	return []


## Bake one kind's package documents (`weftlumin.bake.v1`-shaped report). Writes only when `write`.
@warning_ignore("unused_parameter")
func bake_package_documents(
	kind: WeftluminKind, documents: Array[Dictionary], package: Dictionary, write: bool, force: bool,
) -> Dictionary:
	return {}


## Contract validators the scene bake runs before anything is written (`WeftluminBake` options).
func scene_bake_validators() -> Array[Callable]:
	return []


## Host lint over a loaded package: `{errors: Array[Dictionary], warnings: Array[Dictionary]}`.
@warning_ignore("unused_parameter")
func lint_package(package: Dictionary) -> Dictionary:
	return {"errors": [], "warnings": []}


## Translation template files whose msgids count as "already in the POT pipeline".
func pot_files() -> Array[String]:
	return []


## Scene-export keys whose string values are player-facing (POT-delta candidates).
func player_facing_keys() -> Array[String]:
	return []


## Seed and regenerate derived data from canon. Report-only (drift checks) unless `write`.
## `{stages: [{name, ok, message}], errors, regenerated}`.
@warning_ignore("unused_parameter")
func regen(write: bool) -> Dictionary:
	return {"stages": [], "errors": [], "regenerated": []}


## Run one logged live-state verb against the running autoloads. `{handled, ok, output}`.
@warning_ignore("unused_parameter")
func run_live_verb(entry: Dictionary) -> Dictionary:
	return {"handled": false, "ok": false, "output": []}


## The fixed kind → test-glob map the PR flow runs as "affected" tests (res-relative globs).
@warning_ignore("unused_parameter")
func affected_test_globs(kind_ids: Array[String]) -> Array[String]:
	return []
