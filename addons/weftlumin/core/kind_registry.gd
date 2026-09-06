class_name WeftluminKindRegistry
extends RefCounted
## Validates before applying; each successful kind owns an atomic overlay replacement.
## A later refusal leaves earlier successful kinds applied and is safe to retry.

var _kinds: Dictionary = {}
var _applied: Dictionary = {}


func add(kind: WeftluminKind) -> bool:
	if kind == null or kind.id == &"" or _kinds.has(kind.id):
		return false
	_kinds[kind.id] = kind
	return true


func apply(package: WeftluminPackage, force_kinds: Array[StringName] = []) -> Dictionary:
	var errors: Array[Dictionary] = []
	var applied: Array[StringName] = []
	var result: Dictionary = {"ok": false, "errors": errors, "applied": applied}
	if package == null:
		errors.append({"file": "", "field": "$", "expected": "package", "code": "missing_package", "message": "Package is required."})
		return result
	var known_kinds: Array[StringName] = []
	known_kinds.assign(_kinds.keys())
	package.validate_manifest(known_kinds, errors)
	if not errors.is_empty():
		return result
	var normalised: Dictionary = {}
	for kind_value: String in package.manifest.kinds:
		var kind_id := StringName(kind_value)
		var raw: Variant = package.documents.get(kind_value, [])
		var documents: Array[Dictionary] = []
		if not raw is Array:
			package.add_error(errors, kind_value, "array of documents", "invalid_kind_documents")
			continue
		var error_count: int = errors.size()
		for index: int in raw.size():
			if not raw[index] is Dictionary:
				package.add_error(errors, "%s[%d]" % [kind_value, index], "document object", "invalid_kind_document")
			else:
				documents.append(raw[index].duplicate(true))
		if errors.size() == error_count:
			var kind: WeftluminKind = _kinds[kind_id]
			normalised[kind_id] = kind.validate(documents, errors)
	if not errors.is_empty():
		return result
	for kind_value: String in package.manifest.kinds:
		var kind_id := StringName(kind_value)
		var kind: WeftluminKind = _kinds[kind_id]
		var next: Array[Dictionary] = normalised[kind_id]
		var previous: Array[Dictionary] = []
		previous.assign(_applied.get(kind_id, []))
		if (
			_applied.has(kind_id)
			and not force_kinds.has(kind_id)
			and not kind.diff(previous.duplicate(true), next.duplicate(true)).get("changed", true)
		):
			continue
		if not kind.register(next.duplicate(true)):
			package.add_error(errors, kind_value, "atomic runtime replacement", "runtime_kind_registration_failed")
			return result
		_applied[kind_id] = next.duplicate(true)
		applied.append(kind_id)
	result["ok"] = true
	return result
