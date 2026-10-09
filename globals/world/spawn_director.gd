class_name SpawnDirector
extends RefCounted
## E4.1 (#345): per-map random spawns, `docs/architecture-in-game-editor.md` §4.10.
##
## Owns the persistent slot state (`spawn_state` on the save) and, when a field scene becomes
## current, puts its spawn-slot hostiles on the map: **rehydrate first, then roll**. Survivors of
## an earlier visit come back at their slot anchor under their stored `group_id`; a slot that is
## empty and past its respawn cadence rolls again from a seed that is a pure function of
## `(world_seed, table_id, slot_id, day_index)`, so the same save on the same day always rolls
## the same map.
##
## The numbers are `SpawnMath`'s (E1.6, #327). This file only sequences them, holds state, and
## instantiates `Hostile`s. Travel encounters stay with `EncounterDirector`; both read the same
## archetype ids.
##
## Spawn-slot hostiles respawn by design (owner ruling 5, recorded as the F0 clarification in
## §8). A member downed in combat never returns; when every member of a slot is down, the slot
## clears and its next roll carries a new day-stamped `group_id`, so an old group never blocks it.

const HOSTILE_SCENE_PATH := "res://actors/hostile/hostile.tscn"
const CANON_ROOT := "res://canon"
const TABLE_DIR := "spawn_tables"
const TABLE_SCHEMA := "weftlumin.spawn_table.v1"

## `cleared_day` for a slot that has never been cleared. §4.10 writes this as `null`; an int
## sentinel keeps every slot field one JSON type, so validation and arithmetic need no branch.
const NEVER_CLEARED := -1

## Pixels between the members of one pack, laid out around the anchor before each snaps to the
## nearest open cell. Presentation spacing only: the grid decides where they actually stand.
const PACK_SPACING := 40.0

## `scene_path` -> tables targeting that scene, ordered by id (§4.10 step 3: deterministic order).
static var _tables_by_scene: Dictionary = {}
static var _tables_loaded := false

## `"<table_id>:<slot_id>"` -> `{group_id, spawned_day, cleared_day, members, blocked_by_cap}`;
## each member is `{archetype_id, downed}`.
var _slots: Dictionary = {}
## The world seed of the `populate()` call in progress; #412 salts each member's variation with it.
var _world_seed: int = 0


# --- Tables -------------------------------------------------------------------------------------


## Spawn tables targeting `scene_path`, ordered by id. Read once from `canon/*/spawn_tables/`.
static func tables_for_scene(scene_path: String) -> Array[Dictionary]:
	if not _tables_loaded:
		_tables_by_scene = load_tables()
		_tables_loaded = true
	var result: Array[Dictionary] = []
	for table: Dictionary in _tables_by_scene.get(scene_path, []):
		result.append(table)
	return result


## Test seam: replace the loaded tables (pass `{}` plus `reload = true` to read canon again).
static func set_tables_for_testing(tables_by_scene: Dictionary, reload: bool = false) -> void:
	_tables_by_scene = tables_by_scene
	_tables_loaded = not reload


## Walks `<root>/<hub>/spawn_tables/*.json`. A table with schema problems is reported and left
## out rather than half-applied: a bad table must not be able to stop a scene loading.
static func load_tables(root: String = CANON_ROOT) -> Dictionary:
	var by_scene: Dictionary = {}
	var hubs := DirAccess.get_directories_at(root)
	for hub: String in hubs:
		var directory := "%s/%s/%s" % [root, hub, TABLE_DIR]
		if not DirAccess.dir_exists_absolute(directory):
			continue
		for file_name: String in DirAccess.get_files_at(directory):
			if not file_name.ends_with(".json"):
				continue
			var path := "%s/%s" % [directory, file_name]
			var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
			if not parsed is Dictionary:
				push_error("Spawn table '%s' is not a JSON object." % path)
				continue
			var table: Dictionary = parsed
			var problems := table_problems(table)
			if not problems.is_empty():
				push_error("Spawn table '%s' rejected: %s" % [path, "; ".join(problems)])
				continue
			var scene_path := str(table["scene_path"])
			if not by_scene.has(scene_path):
				by_scene[scene_path] = []
			(by_scene[scene_path] as Array).append(table)
	for scene_path: String in by_scene:
		(by_scene[scene_path] as Array).sort_custom(
			func(a: Dictionary, b: Dictionary) -> bool: return str(a["id"]) < str(b["id"])
		)
	return by_scene


## §4.10 step 5's schema invariants. The anchor-exists check needs the scene, so it runs at
## populate time instead (`populate()` reports a missing anchor and skips the slot).
static func table_problems(table: Dictionary) -> PackedStringArray:
	var problems := PackedStringArray()
	if str(table.get("schema", "")) != TABLE_SCHEMA:
		problems.append("schema must be \"%s\"" % TABLE_SCHEMA)
	if str(table.get("id", "")).is_empty():
		problems.append("id is required")
	if not str(table.get("scene_path", "")).begins_with("res://"):
		problems.append("scene_path must be a res:// path")
	var raw_slots: Variant = table.get("slots", [])
	if not raw_slots is Array or (raw_slots as Array).is_empty():
		problems.append("slots must be a non-empty array")
		return problems
	var seen: Dictionary = {}
	for raw_slot: Variant in raw_slots:
		if not raw_slot is Dictionary:
			problems.append("every slot must be an object")
			continue
		var slot: Dictionary = raw_slot
		var slot_id := str(slot.get("id", ""))
		if slot_id.is_empty():
			problems.append("every slot needs an id")
		elif seen.has(slot_id):
			problems.append("slot id \"%s\" is repeated" % slot_id)
		seen[slot_id] = true
		if str(slot.get("anchor", "")).is_empty():
			problems.append("slot \"%s\" needs an anchor" % slot_id)
		if _int_field(slot, "respawn_days", 0) < 1:
			problems.append("slot \"%s\" respawn_days must be at least 1" % slot_id)
		var pack: Variant = slot.get("pack_size", {})
		var pack_min := _int_field(pack, "min", 0) if pack is Dictionary else 0
		var pack_max := _int_field(pack, "max", pack_min) if pack is Dictionary else 0
		if pack_min < 1 or pack_max < pack_min:
			problems.append("slot \"%s\" pack_size needs 1 <= min <= max" % slot_id)
		var raw_entries: Variant = slot.get("entries", [])
		var has_creature := false
		for raw_entry: Variant in raw_entries if raw_entries is Array else []:
			if not raw_entry is Dictionary:
				problems.append("slot \"%s\" has a non-object entry" % slot_id)
				continue
			var entry: Dictionary = raw_entry
			var weight: Variant = entry.get("weight", 0)
			if not _is_whole_number(weight) or int(weight) <= 0:
				problems.append("slot \"%s\" weights must be positive integers" % slot_id)
				continue
			if not bool(entry.get("empty", false)):
				if str(entry.get("archetype_id", "")).is_empty():
					problems.append("slot \"%s\" has an entry with no archetype_id" % slot_id)
				else:
					has_creature = true
		if not has_creature:
			problems.append("slot \"%s\" needs a non-empty entry with weight > 0" % slot_id)
	return problems


# --- The roll -----------------------------------------------------------------------------------


## One slot roll. Pure: the seed is `hash([world_seed, table_id, slot_id, day_index])`, one
## generator per roll, and `SpawnMath` consumes a fixed number of draws from it. Returns
## `{empty: bool, archetype_id: StringName, count: int}`. `entries` arrive already scaled by the
## location's thinning tier.
static func roll(
	world_seed: int,
	table_id: String,
	slot_id: String,
	day_index: int,
	entries: Array,
	pack_range: Dictionary,
) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash([world_seed, table_id, slot_id, day_index])
	var picked := SpawnMath.pick(entries, rng)
	if bool(picked["empty"]):
		return {"empty": true, "archetype_id": &"", "count": 0}
	return {
		"empty": false,
		"archetype_id": StringName(picked["archetype_id"]),
		"count": SpawnMath.pack_size(pack_range, rng),
	}


static func group_id_for(table_id: String, slot_id: String, day_index: int) -> StringName:
	return StringName("%s:%s:%d" % [table_id, slot_id, day_index])


static func slot_key(table_id: String, slot_id: String) -> String:
	return "%s:%s" % [table_id, slot_id]


# --- Populating a scene -------------------------------------------------------------------------


## The world inputs `populate()` reads, gathered from the live globals for `scene_path`. Split
## out so a test can drive `populate()` with a fixed context instead of a whole save.
static func live_context(scene_path: String) -> Dictionary:
	var location := LocationRegistry.by_scene(scene_path)
	var zone_id := String(location.id) if location != null else ""
	return {
		"world_seed": GameState.world_seed,
		"day_index": WorldClock.day_index(),
		"respawn_policy": location.respawn_policy if location != null else "none",
		"thinning_tier": location.thinning_tier if location != null else 0,
		"zhavar_rung_index": maxi(SaveGame.ZHAVAR_RUNGS.find(SaveGame.zhavar_rung(zone_id)), 0),
	}


## Puts this scene's spawn-slot hostiles on the map. Call once per arrival, after the scene is
## current. Returns the hostiles it instantiated (rehydrated and freshly rolled).
func populate(scene_root: Node, context: Dictionary = {}) -> Array[Hostile]:
	var spawned: Array[Hostile] = []
	if scene_root == null:
		return spawned
	var scene_path := scene_root.scene_file_path
	var tables := tables_for_scene(scene_path)
	if tables.is_empty():
		return spawned
	if context.is_empty():
		context = live_context(scene_path)
	var policy := str(context.get("respawn_policy", "none"))
	var rung := int(context.get("zhavar_rung_index", 0))
	var usable: Array[Dictionary] = []
	for table: Dictionary in tables:
		var violations := SpawnMath.policy_violations(policy, table)
		if violations.is_empty():
			usable.append(table)
		else:
			push_error("Spawn table '%s' refused: %s" % [table["id"], "; ".join(violations)])
	if usable.is_empty():
		return spawned
	var cap := _scene_cap(usable, policy, rung)
	_world_seed = int(context.get("world_seed", 0))

	# Step 3a — rehydrate every surviving member before anything rolls, so the cap sees them.
	var alive := 0
	for table: Dictionary in usable:
		for slot: Dictionary in table["slots"]:
			var key := slot_key(str(table["id"]), str(slot["id"]))
			var state: Dictionary = _slots.get(key, {})
			if state.is_empty() or _living_count(state) == 0:
				continue
			var anchor := _anchor(scene_root, slot)
			if anchor == null:
				continue
			spawned.append_array(_instantiate_members(anchor, key, state))
			alive += _living_count(state)

	# Step 3b — roll every eligible slot, tables by id and slots in file order.
	var day := int(context.get("day_index", 0))
	var world_seed := int(context.get("world_seed", 0))
	var thinning := int(context.get("thinning_tier", 0))
	for table: Dictionary in usable:
		var table_id := str(table["id"])
		for slot: Dictionary in table["slots"]:
			var slot_id := str(slot["id"])
			var key := slot_key(table_id, slot_id)
			var state := _state_for(key)
			if not _eligible(state, slot, day, rung):
				continue
			var anchor := _anchor(scene_root, slot)
			if anchor == null:
				continue
			var entries := SpawnMath.scaled_weights(slot.get("entries", []), thinning)
			var rolled := roll(world_seed, table_id, slot_id, day, entries, slot.get("pack_size", {}))
			if bool(rolled["empty"]):
				state["cleared_day"] = day
				state["blocked_by_cap"] = false
				continue
			var count := int(rolled["count"])
			if alive + count > cap:
				# Stays eligible: no `cleared_day`, so the next visit rolls it again.
				state["blocked_by_cap"] = true
				continue
			var members: Array = []
			for _index: int in count:
				members.append({"archetype_id": String(rolled["archetype_id"]), "downed": false})
			state["group_id"] = String(group_id_for(table_id, slot_id, day))
			state["spawned_day"] = day
			state["members"] = members
			state["blocked_by_cap"] = false
			spawned.append_array(_instantiate_members(anchor, key, state))
			alive += count
	return spawned


## Per-scene cap (§4.10: `max_alive` counts living members across every table of the scene).
## Tables may each author one; the strictest authored value wins so no table can widen another's.
static func _scene_cap(tables: Array[Dictionary], policy: String, rung: int) -> int:
	var authored := 0
	for table: Dictionary in tables:
		var caps: Variant = table.get("caps", {})
		var value := _int_field(caps, "max_alive", 0) if caps is Dictionary else 0
		if value > 0 and (authored == 0 or value < authored):
			authored = value
	return SpawnMath.max_alive_for(policy, rung, authored)


static func _eligible(state: Dictionary, slot: Dictionary, day: int, rung: int) -> bool:
	if not (state["members"] as Array).is_empty():
		return false
	var cleared := int(state["cleared_day"])
	if cleared == NEVER_CLEARED:
		return true
	return day >= cleared + SpawnMath.respawn_days(_int_field(slot, "respawn_days", 1), rung)


func _instantiate_members(anchor: Node2D, key: String, state: Dictionary) -> Array[Hostile]:
	var result: Array[Hostile] = []
	var packed := load(HOSTILE_SCENE_PATH) as PackedScene
	var parent := anchor.get_parent()
	if packed == null or parent == null:
		return result
	var members: Array = state["members"]
	var group_id := StringName(state["group_id"])
	for index: int in members.size():
		var member: Dictionary = members[index]
		if bool(member["downed"]):
			continue
		var actor := EncounterCatalog.make_actor(StringName(member["archetype_id"]))
		if actor == null:
			continue
		# #412: a wild instance rolls its own numbers once, here, and they are frozen into the
		# actor. The seed is persisted state (world seed, slot group, place in the pack), so a
		# survivor rehydrated on a later visit is the same creature.
		var variation := EnemyDerived.roll(EnemyDerived.spawn_seed(_world_seed, group_id, index))
		EnemyDerived.apply(actor, variation)
		var hostile := packed.instantiate() as Hostile
		hostile.name = "Spawn_%s_%d" % [key.replace(":", "_"), index]
		hostile.spawn_into_slot(
			actor, group_id, StringName("spawn:%s:%d" % [group_id, index]), int(variation["tier"])
		)
		hostile.position = anchor.position + _pack_offset(index, members.size())
		hostile.downed.connect(_on_member_downed.bind(key, String(group_id), index))
		parent.add_child(hostile)
		result.append(hostile)
	return result


## Members sit on a small ring around the anchor; a lone member stands on it.
static func _pack_offset(index: int, count: int) -> Vector2:
	if count <= 1:
		return Vector2.ZERO
	return Vector2.RIGHT.rotated(TAU * float(index) / float(count)) * PACK_SPACING


## Step 4: a downed member never returns; the last one down clears the slot for its cadence.
## Bound to the `group_id` it was spawned under, so a body from an earlier roll that is still on
## the field cannot clear the slot's next group.
func _on_member_downed(_hostile: Hostile, key: String, group_id: String, index: int) -> void:
	var state: Dictionary = _slots.get(key, {})
	if state.is_empty() or str(state["group_id"]) != group_id:
		return
	var members: Array = state["members"]
	if index < 0 or index >= members.size():
		return
	(members[index] as Dictionary)["downed"] = true
	if _living_count(state) == 0:
		state["members"] = []
		state["cleared_day"] = WorldClock.day_index()


static func _anchor(scene_root: Node, slot: Dictionary) -> Node2D:
	var anchor_name := str(slot.get("anchor", ""))
	var anchor := scene_root.find_child(anchor_name, true, false) as Node2D
	if anchor == null:
		push_error(
			"Spawn slot '%s' anchor '%s' is missing from '%s'."
			% [slot.get("id", "?"), anchor_name, scene_root.scene_file_path]
		)
	return anchor


static func _living_count(state: Dictionary) -> int:
	var living := 0
	for member: Dictionary in state.get("members", []):
		if not bool(member["downed"]):
			living += 1
	return living


func _state_for(key: String) -> Dictionary:
	if not _slots.has(key):
		_slots[key] = {
			"group_id": "",
			"spawned_day": NEVER_CLEARED,
			"cleared_day": NEVER_CLEARED,
			"members": [],
			"blocked_by_cap": false,
		}
	return _slots[key]


## Read-only view of one slot's state, for tests and the debug panel.
func slot_state(table_id: String, slot_id: String) -> Dictionary:
	return (_slots.get(slot_key(table_id, slot_id), {}) as Dictionary).duplicate(true)


# --- Save surface (`spawn_state`, additive key) -------------------------------------------------


func to_dict() -> Dictionary:
	return {"slots": _slots.duplicate(true)}


## Older saves carry no key and start with every slot unrolled. An invalid section is ignored
## the same way; `validate_save_data()` is what the load path uses to refuse a corrupt one.
func from_dict(data: Variant) -> void:
	_slots = {}
	if not validate_save_data(data):
		return
	var slots: Dictionary = (data as Dictionary).get("slots", {})
	for key: String in slots:
		var row: Dictionary = slots[key]
		var members: Array = []
		for member: Dictionary in row["members"]:
			members.append({
				"archetype_id": str(member["archetype_id"]),
				"downed": bool(member["downed"]),
			})
		_slots[key] = {
			"group_id": str(row["group_id"]),
			"spawned_day": int(row["spawned_day"]),
			"cleared_day": int(row["cleared_day"]),
			"members": members,
			"blocked_by_cap": bool(row["blocked_by_cap"]),
		}


static func validate_save_data(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	var data: Dictionary = value
	if data.is_empty():
		return true
	if not data.get("slots") is Dictionary:
		return false
	var slots: Dictionary = data["slots"]
	for key: Variant in slots:
		var row: Variant = slots[key]
		if not key is String or not row is Dictionary:
			return false
		var slot: Dictionary = row
		if not slot.get("group_id") is String or not slot.get("members") is Array:
			return false
		for field: String in ["spawned_day", "cleared_day"]:
			if not _is_whole_number(slot.get(field)):
				return false
		if not slot.get("blocked_by_cap") is bool:
			return false
		for member: Variant in slot["members"]:
			if not member is Dictionary:
				return false
			if not (member as Dictionary).get("archetype_id") is String:
				return false
			if not (member as Dictionary).get("downed") is bool:
				return false
	return true


## JSON hands every number back as a float, so a whole number is either type.
static func _is_whole_number(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_equal_approx(value, roundf(value))


static func _int_field(source: Variant, field: String, fallback: int) -> int:
	if not source is Dictionary:
		return fallback
	var value: Variant = (source as Dictionary).get(field, fallback)
	return int(value) if _is_whole_number(value) else fallback
