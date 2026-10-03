extends RefCounted
## Field-side half of the #282 populated-field benchmark: deterministic placement and
## synthesis of `Hostile` instances on a live `FieldMap`.
##
## Kept apart from `populated_field_benchmark.gd` on purpose. A `--script` SceneTree harness is
## compiled before the autoloads exist, so it cannot name `Hostile`, `FieldMap` or `Battle`
## (their scripts reference `GameState` and friends) — it `load()`s this helper at runtime
## instead and talks to the field through it. Unit tests preload it directly.

const HOSTILE_SCENE := "res://actors/hostile/hostile.tscn"
## The committed archetype every synthesized hostile uses. A fixture choice, the same unit the
## hostile and session suites use; not an encounter composition.
const FIXTURE_UNIT_ID := &"bog-wight"
## Fixture spacing so the synthesized block is not a solid phalanx: every other cell on both
## axes. Placement is otherwise row-major from the grid's used rect, so it is deterministic.
const PLACEMENT_STRIDE := Vector2i(2, 2)
## World-space margin added to the alert and chain radii when keeping the party and authored
## hostiles clear of the synthesized block, so the idle window really has no session.
const PLACEMENT_CLEAR_MARGIN := 64.0


## Deterministic placement: row-major over the grid's used rect with `stride`, skipping cells
## the shared IsoGrid reports blocked and cells inside any keep-clear zone. Two calls on the
## same field return the same cells, and no cell repeats.
static func plan_cells(
	grid: IsoGrid,
	count: int,
	keep_clear: Array[Dictionary] = [],
	stride: Vector2i = PLACEMENT_STRIDE,
) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if grid == null or count <= 0:
		return cells
	var step := Vector2i(maxi(stride.x, 1), maxi(stride.y, 1))
	var rect := grid.get_used_rect()
	var y := rect.position.y
	while y < rect.end.y and cells.size() < count:
		var x := rect.position.x
		while x < rect.end.x and cells.size() < count:
			var cell := Vector2i(x, y)
			if not grid.is_blocked_for(cell) and _is_clear(grid.cell_to_world(cell), keep_clear):
				cells.append(cell)
			x += step.x
		y += step.y
	return cells


## Zones no synthesized hostile may stand in: the alert radius around every party body (so the
## idle window has no session) and the chain radius around every hostile already on the field
## (so a measure's chain hop cannot pull authored mobs into the synthesized session).
static func keep_clear_zones(
	field: FieldMap, margin: float = PLACEMENT_CLEAR_MARGIN
) -> Array[Dictionary]:
	var zones: Array[Dictionary] = []
	if field == null:
		return zones
	var probe := Hostile.new()
	var alert_radius := probe.alert_radius
	var chain_radius := probe.chain_radius
	probe.free()
	var lead := field.player()
	if lead != null:
		zones.append({"position": lead.global_position, "radius": alert_radius + margin})
	var followers := field.party_followers()
	if followers != null:
		for follower: PartyFollower in followers.followers():
			zones.append({"position": follower.global_position, "radius": alert_radius + margin})
	for hostile: Hostile in field.hostiles():
		zones.append(
			{
				"position": hostile.global_position,
				"radius": maxf(chain_radius, hostile.chain_radius) + margin,
			}
		)
	return zones


## Instantiates one `hostile.tscn` per cell under the field's scene root, seats it on the cell
## and registers it through `FieldMap.register_hostile`. Synthesized hostiles carry no group id:
## they belong to no authored encounter, so no `defeated_*` flag can retire them and no ledger
## row is written for them.
static func synthesize_hostiles(
	field: FieldMap,
	cells: Array[Vector2i],
	unit_id: StringName = FIXTURE_UNIT_ID,
) -> Array[Hostile]:
	var hostiles: Array[Hostile] = []
	if field == null:
		return hostiles
	var grid := field.iso_grid()
	var packed := load(HOSTILE_SCENE) as PackedScene
	if grid == null or packed == null:
		return hostiles
	var parent: Node = field.get_parent() if field.get_parent() != null else field
	for index: int in cells.size():
		var hostile := packed.instantiate() as Hostile
		hostile.name = "BenchHostile%03d" % index
		hostile.unit_id = unit_id
		hostile.group_id = &""
		# Set before entering the tree: `_ready` snaps from the position it finds, and a cell
		# center on open ground is its own snap target.
		hostile.position = grid.cell_to_world(cells[index])
		parent.add_child(hostile)
		hostile.sync_cell()
		field.register_hostile(hostile)
		hostiles.append(hostile)
	return hostiles


static func placement_is_distinct(hostiles: Array[Hostile]) -> bool:
	var seen: Dictionary = {}
	for hostile: Hostile in hostiles:
		var cell := hostile.sync_cell()
		if seen.has(cell):
			return false
		seen[cell] = true
	return true


## How many synthesized hostiles `_ready`'s walkable-cell snap moved off their planned cell.
static func off_plan_count(hostiles: Array[Hostile], cells: Array[Vector2i]) -> int:
	var moved := 0
	for index: int in mini(hostiles.size(), cells.size()):
		if hostiles[index].sync_cell() != cells[index]:
			moved += 1
	return moved


## Untyped bridges for the harness, which cannot name these classes at compile time.


static func field_hostile_count(field: Node) -> int:
	var typed := field as FieldMap
	return typed.hostiles().size() if typed != null else 0


static func plan_for_field(field: Node, count: int) -> Array[Vector2i]:
	var typed := field as FieldMap
	if typed == null:
		return []
	return plan_cells(typed.iso_grid(), count, keep_clear_zones(typed))


static func synthesize_on_field(field: Node, cells: Array[Vector2i]) -> Array:
	var typed := field as FieldMap
	if typed == null:
		return []
	return Array(synthesize_hostiles(typed, cells))


static func hostiles_are_distinct(hostiles: Array) -> bool:
	var typed: Array[Hostile] = []
	typed.assign(hostiles)
	return placement_is_distinct(typed)


static func hostiles_off_plan(hostiles: Array, cells: Array[Vector2i]) -> int:
	var typed: Array[Hostile] = []
	typed.assign(hostiles)
	return off_plan_count(typed, cells)


## The first `limit` hostiles that stand off their planned cell, with where they went.
static func off_plan_examples(hostiles: Array, cells: Array[Vector2i], limit: int) -> Array[Dictionary]:
	var examples: Array[Dictionary] = []
	for index: int in mini(hostiles.size(), cells.size()):
		var hostile := hostiles[index] as Hostile
		if hostile == null:
			continue
		var actual := hostile.sync_cell()
		if actual == cells[index]:
			continue
		examples.append(
			{
				"hostile": hostile.name,
				"planned": {"x": cells[index].x, "y": cells[index].y},
				"actual": {"x": actual.x, "y": actual.y},
				"position": {"x": hostile.global_position.x, "y": hostile.global_position.y},
			}
		)
		if examples.size() >= limit:
			break
	return examples


static func is_in_combat(hostile: Node) -> bool:
	var typed := hostile as Hostile
	return typed != null and typed.state == Hostile.State.IN_COMBAT


static func hostile_state(hostile: Node) -> int:
	var typed := hostile as Hostile
	return typed.state if typed != null else -1


static func guard_action_id() -> StringName:
	return Battle.ACTION_GUARD


static func _is_clear(position: Vector2, keep_clear: Array[Dictionary]) -> bool:
	for zone: Dictionary in keep_clear:
		var center: Vector2 = zone.get("position", Vector2.INF)
		var radius := float(zone.get("radius", 0.0))
		if center.distance_to(position) <= radius:
			return false
	return true
