class_name UnitFrames
extends RefCounted
## Read-only unit manifest: assets[] rows identify a presentation_id and explicit
## output_paths using <id>--<state>--<dir>--f<NN>.png. Paths are never invented.
## Optional race_id, class_id, role and variant are identity metadata.
## directions: array of authored direction keys; states: object of state -> frame
## count. Legacy direction/state/frame rows remain valid without either field.
## drawn_height_px: measured occupied height; height_factor: target-height multiplier
## (defaults to 1.0; non-1.0 race factors require an owner ruling).
## Existing output_sha256/source_sha256 provenance is unchanged. A future writer
## must hash every output and bump its generator_version when changing contracts.

const MANIFEST_PATH := "res://assets/generated/sprites/manifests/units.json"
const ROOT := "res://assets/generated/sprites/units"
const DIRECTIONS: PackedStringArray = ["e", "se", "s", "sw", "w", "nw", "n", "ne"]
const STATES: PackedStringArray = ["idle", "walk", "attack", "hit", "down"]


class Frame extends RefCounted:
	var path: String
	var flip: bool

	func _init(texture_path: String = "", flipped: bool = false) -> void:
		path = texture_path
		flip = flipped


static var _units: Dictionary[String, Dictionary] = {}
static var _loaded: bool = false


static func texture_path(unit_id: String, state: String = "idle", dir: String = "se", frame: int = 0) -> String:
	return lookup(unit_id, state, dir, frame).path


## Missing states/frames and incomplete multi-direction sets return an empty path.
## Only se-only sets mirror: west-facing keys use the same frame with flip=true.
static func lookup(unit_id: String, state: String = "idle", dir: String = "se", frame: int = 0) -> Frame:
	_ensure_loaded()
	if not DIRECTIONS.has(dir) or frame < 0:
		return Frame.new()
	var unit: Dictionary = _units.get(unit_id, {})
	var frames: Dictionary = unit.get("frames", {})
	var by_direction: Dictionary = frames.get(state, {})
	var directions := directions_for(unit_id)
	var resolved_dir := dir
	var flip := false
	if directions == PackedStringArray(["se"]):
		resolved_dir = "se"
		flip = dir.contains("w")
	var by_frame: Dictionary = by_direction.get(resolved_dir, {})
	return Frame.new(str(by_frame.get(frame, "")), flip)


## Authored availability, not mirrored availability.
static func has_direction(unit_id: String, dir: String) -> bool:
	return directions_for(unit_id).has(dir)


static func directions_for(unit_id: String) -> PackedStringArray:
	_ensure_loaded()
	var unit: Dictionary = _units.get(unit_id, {})
	var directions: PackedStringArray = unit.get("directions", PackedStringArray())
	return directions.duplicate()


static func metadata_for(unit_id: String) -> Dictionary:
	_ensure_loaded()
	var unit: Dictionary = _units.get(unit_id, {})
	var metadata: Dictionary = unit.get("metadata", {})
	return metadata.duplicate(true)


static func unit_ids_for_race(race_id: String) -> PackedStringArray:
	_ensure_loaded()
	var ids := PackedStringArray()
	if race_id.is_empty():
		return ids
	for unit_id: String in _units:
		if str(_units[unit_id]["metadata"].get("race_id", "")) == race_id:
			ids.append(unit_id)
	ids.sort()
	return ids


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var manifest := load(MANIFEST_PATH) as JSON
	if manifest == null or not manifest.data is Dictionary:
		push_error("UnitFrames: missing or invalid unit manifest.")
		return
	_units = _index_manifest(manifest.data)


static func _index_manifest(manifest: Dictionary) -> Dictionary[String, Dictionary]:
	var units: Dictionary[String, Dictionary] = {}
	var rows: Variant = manifest.get("assets", [])
	if not rows is Array:
		return units
	for value: Variant in rows:
		if not value is Dictionary:
			continue
		var row: Dictionary = value
		var unit_id := str(row.get("presentation_id", ""))
		var paths: Variant = row.get("output_paths", [])
		if unit_id.is_empty() or not paths is Array:
			continue
		var frames: Dictionary = {}
		var authored_directions := PackedStringArray()
		for output: Variant in paths:
			if not output is String:
				continue
			var path := str(output)
			if not path.begins_with("res://"):
				path = "res://" + path
			if path.get_base_dir() != ROOT + "/" + unit_id or ".." in path:
				continue
			var parts := path.get_file().get_basename().split("--")
			if path.get_extension() != "png" or parts.size() != 4 or parts[0] != unit_id:
				continue
			var state := parts[1]
			var dir := parts[2]
			var number := parts[3].trim_prefix("f")
			if not STATES.has(state) or not DIRECTIONS.has(dir):
				continue
			if not parts[3].begins_with("f") or not number.is_valid_int() or int(number) < 0:
				continue
			var frame := int(number)
			if not _declares_frame(row, state, dir, frame):
				continue
			if not frames.has(state):
				frames[state] = {}
			if not frames[state].has(dir):
				frames[state][dir] = {}
			frames[state][dir][frame] = path
			if not authored_directions.has(dir):
				authored_directions.append(dir)
		var ordered_directions := PackedStringArray()
		for dir: String in DIRECTIONS:
			if authored_directions.has(dir):
				ordered_directions.append(dir)
		if not frames.is_empty():
			units[unit_id] = {"frames": frames, "directions": ordered_directions, "metadata": row.duplicate(true)}
	return units


static func _declares_frame(row: Dictionary, state: String, dir: String, frame: int) -> bool:
	if row.has("directions"):
		var directions: Variant = row["directions"]
		if not directions is Array or not directions.has(dir):
			return false
	elif str(row.get("direction", "se")) != dir:
		return false
	if row.has("states"):
		var states: Variant = row["states"]
		if not states is Dictionary:
			return false
		var count: Variant = states.get(state, 0)
		return (count is int or count is float) and frame < int(count)
	return state == str(row.get("state", "idle")) and frame == int(row.get("frame", 0))
