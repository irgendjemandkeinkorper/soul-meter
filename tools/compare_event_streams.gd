extends SceneTree
## Compares two controller event dumps written by `populated_field_benchmark.gd --event-dump`
## (#642: a controller performance change must not change one event). Each line is one event:
## a base64 `var_to_bytes` record of its sequence, type, actor, target and payload, snapshot
## included. Two events are the same when their decoded records are equal (`==`, so dictionary
## key order does not count; array order does).
##
##   godot --headless --path . --script res://tools/compare_event_streams.gd -- BEFORE AFTER
##
## Prints one JSON line: the event counts, how many matched, and the first difference with
## the key path where the two values part. Exits 0 only when every event matches.

const MAX_REPORTED := 5


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		printerr("usage: -- BEFORE_DUMP AFTER_DUMP")
		quit(2)
		return
	var before_value: Variant = _read(args[0])
	var after_value: Variant = _read(args[1])
	if before_value == null or after_value == null:
		quit(2)
		return
	var before: PackedStringArray = before_value
	var after: PackedStringArray = after_value
	var differences: Array[Dictionary] = []
	var matched := 0
	for index: int in mini(before.size(), after.size()):
		if before[index] == after[index]:
			matched += 1
			continue
		var left: Variant = bytes_to_var(Marshalls.base64_to_raw(before[index]))
		var right: Variant = bytes_to_var(Marshalls.base64_to_raw(after[index]))
		if left == right:
			matched += 1
			continue
		if differences.size() < MAX_REPORTED:
			differences.append({
				"line": index,
				"before_type": str((left as Dictionary).get("type", "")),
				"after_type": str((right as Dictionary).get("type", "")),
				"path": first_difference(left, right, ""),
			})
	var identical := differences.is_empty() and before.size() == after.size()
	print(JSON.stringify({
		"identical": identical,
		"events_before": before.size(),
		"events_after": after.size(),
		"matched": matched,
		"first_differences": differences,
	}))
	quit(0 if identical else 1)


## The dump's lines, or null when the file cannot be read.
func _read(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		printerr("cannot read %s" % path)
		return null
	var lines := PackedStringArray()
	while not file.eof_reached():
		var line := file.get_line()
		if not line.is_empty():
			lines.append(line)
	return lines


## The first key path where `left` and `right` part, with both values when they are scalars.
static func first_difference(left: Variant, right: Variant, path: String) -> String:
	if typeof(left) != typeof(right):
		return "%s: type %s != %s" % [path, type_string(typeof(left)), type_string(typeof(right))]
	if left is Dictionary:
		var a := left as Dictionary
		var b := right as Dictionary
		for key: Variant in a:
			if not b.has(key):
				return "%s/%s: missing after" % [path, str(key)]
			if a[key] != b[key]:
				return first_difference(a[key], b[key], "%s/%s" % [path, str(key)])
		for key: Variant in b:
			if not a.has(key):
				return "%s/%s: missing before" % [path, str(key)]
		return "%s: equal" % path
	if left is Array:
		var a := left as Array
		var b := right as Array
		for index: int in mini(a.size(), b.size()):
			if a[index] != b[index]:
				return first_difference(a[index], b[index], "%s[%d]" % [path, index])
		return "%s: size %d != %d" % [path, a.size(), b.size()]
	return "%s: %s != %s" % [path, str(left), str(right)]
