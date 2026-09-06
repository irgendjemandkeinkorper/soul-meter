class_name WeftluminPackage
extends RefCounted
## In-memory package boundary. Discovery and writing remain explicit host operations.

const SCHEMA := "weftlumin.package.v1"

var manifest: Dictionary = {}
var documents: Dictionary = {}
var source: String = ""


## Legacy manifests acquire metadata without losing host-specific fields.
func validate_manifest(known_kinds: Array[StringName], errors: Array[Dictionary]) -> void:
	if not manifest.has("schema"):
		manifest["schema"] = SCHEMA
	if not manifest.get("schema") is String or manifest.schema != SCHEMA:
		add_error(errors, "schema", SCHEMA, "unsupported_package_schema")
	if not manifest.has("kinds"):
		var defaults: Array[String] = []
		for kind_id: StringName in known_kinds:
			defaults.append(String(kind_id))
		manifest["kinds"] = defaults
	var kinds_value: Variant = manifest.get("kinds")
	if not kinds_value is Array:
		add_error(errors, "kinds", "array of registered kind ids", "invalid_field_type")
	else:
		var seen: Dictionary = {}
		for index: int in kinds_value.size():
			var value: Variant = kinds_value[index]
			var field: String = "kinds[%d]" % index
			if not value is String or not known_kinds.has(StringName(value)):
				add_error(errors, field, "registered kind id", "unknown_package_kind")
			elif seen.has(value):
				add_error(errors, field, "unique kind id", "duplicate_package_kind")
			else:
				seen[value] = true
	if not manifest.has("base_commit"):
		manifest["base_commit"] = ""
	if not manifest.get("base_commit") is String:
		add_error(errors, "base_commit", "string", "invalid_field_type")
	if not manifest.has("provenance"):
		manifest["provenance"] = {}
	if not manifest.get("provenance") is Dictionary:
		add_error(errors, "provenance", "object", "invalid_field_type")


func add_error(errors: Array[Dictionary], field: String, expected: String, code: String) -> void:
	errors.append({
		"file": source, "field": field, "expected": expected,
		"code": code, "message": "Expected %s for '%s'." % [expected, field],
	})
