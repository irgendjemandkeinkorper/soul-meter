extends GdUnitTestSuite

const PACKAGE := "res://addons/weftlumin/core/package.gd"
const REGISTRY := "res://addons/weftlumin/core/kind_registry.gd"


class RecordingKind extends WeftluminKind:
	var calls: int = 0
	var reject: bool = false
	var live: Array[Dictionary] = []

	func _init(kind_id: StringName) -> void:
		id = kind_id

	func validate(documents: Array[Dictionary], errors: Array[Dictionary]) -> Array[Dictionary]:
		for document: Dictionary in documents:
			if document.has("invalid"):
				errors.append({"file": "fixture.json", "field": "invalid", "code": "invalid_fixture"})
		return documents.duplicate(true)

	func register(normalised: Array[Dictionary]) -> bool:
		calls += 1
		if reject:
			return false
		live = normalised.duplicate(true)
		return true

	func diff(previous: Array[Dictionary], next: Array[Dictionary]) -> Dictionary:
		return {"changed": previous != next}


func test_manifest_defaults_preserve_legacy_fields_and_reject_unknown_kinds() -> void:
	assert_bool(ResourceLoader.exists(PACKAGE)).is_true()
	if not ResourceLoader.exists(PACKAGE):
		return
	var package = load(PACKAGE).new()
	package.manifest = {"id": "test", "locations": ["dom"], "title": "Exact\n title "}
	var errors: Array[Dictionary] = []
	var known_kinds: Array[StringName] = [&"quests", &"encounters"]
	package.validate_manifest(known_kinds, errors)
	assert_array(errors).is_empty()
	assert_str(package.manifest.schema).is_equal("weftlumin.package.v1")
	assert_array(package.manifest.kinds).contains_exactly(["quests", "encounters"])
	assert_array(package.manifest.locations).contains_exactly(["dom"])
	assert_str(package.manifest.title).is_equal("Exact\n title ")
	assert_str(package.manifest.base_commit).is_empty()
	assert_dict(package.manifest.provenance).is_empty()
	package.manifest.kinds = ["quests", "characters"]
	package.validate_manifest(known_kinds, errors)
	assert_str(errors[0].field).is_equal("kinds[1]")
	assert_str(errors[0].code).is_equal("unknown_package_kind")


func test_malformed_manifest_metadata_is_attributed() -> void:
	var package = load(PACKAGE).new()
	package.source = "memory/campaign.json"
	package.manifest = {"schema": 2, "kinds": "quests", "base_commit": 42, "provenance": []}
	var errors: Array[Dictionary] = []
	var known_kinds: Array[StringName] = [&"quests"]
	package.validate_manifest(known_kinds, errors)
	var fields: Array[String] = []
	for error: Dictionary in errors:
		assert_str(error.file).is_equal("memory/campaign.json")
		fields.append(error.field)
	assert_array(fields).contains_exactly(["schema", "kinds", "base_commit", "provenance"])


func test_apply_changes_only_declared_changed_kinds_and_retries_failed_kind() -> void:
	assert_bool(ResourceLoader.exists(REGISTRY)).is_true()
	if not ResourceLoader.exists(REGISTRY):
		return
	var registry = load(REGISTRY).new()
	var quests := RecordingKind.new(&"quests")
	var encounters := RecordingKind.new(&"encounters")
	assert_bool(registry.add(quests)).is_true()
	assert_bool(registry.add(encounters)).is_true()
	assert_bool(registry.add(RecordingKind.new(&"quests"))).is_false()
	var package = load(PACKAGE).new()
	package.manifest = {"kinds": ["quests", "encounters"]}
	package.documents = {"quests": [{"id": "q1"}], "encounters": [{"id": "e1"}]}
	assert_bool(registry.apply(package).ok).is_true()
	assert_bool(registry.apply(package).ok).is_true()
	assert_int(quests.calls).is_equal(1)
	assert_int(encounters.calls).is_equal(1)
	package.documents = {"quests": [{"id": "q2"}], "encounters": [{"id": "e2"}]}
	encounters.reject = true
	var failed: Dictionary = registry.apply(package)
	assert_bool(failed.ok).is_false()
	assert_array(failed.applied).contains_exactly([&"quests"])
	assert_array(quests.live).contains_exactly([{"id": "q2"}])
	assert_array(encounters.live).contains_exactly([{"id": "e1"}])
	encounters.reject = false
	assert_bool(registry.apply(package).ok).is_true()
	assert_int(quests.calls).is_equal(2)
	assert_int(encounters.calls).is_equal(3)
	package.manifest.kinds = ["quests"]
	package.documents = {"quests": []}
	assert_bool(registry.apply(package).ok).is_true()
	assert_array(quests.live).is_empty()
	assert_array(encounters.live).contains_exactly([{"id": "e2"}])


func test_validation_errors_prevent_any_kind_registration() -> void:
	assert_bool(ResourceLoader.exists(REGISTRY)).is_true()
	if not ResourceLoader.exists(REGISTRY):
		return
	var registry = load(REGISTRY).new()
	var quests := RecordingKind.new(&"quests")
	var encounters := RecordingKind.new(&"encounters")
	registry.add(quests)
	registry.add(encounters)
	var package = load(PACKAGE).new()
	package.manifest = {"kinds": ["quests", "encounters"]}
	package.documents = {"quests": [{"id": "q1"}], "encounters": [{"invalid": true}]}
	var result: Dictionary = registry.apply(package)
	assert_bool(result.ok).is_false()
	assert_str(result.errors[0].file).is_equal("fixture.json")
	assert_int(quests.calls).is_equal(0)
	assert_int(encounters.calls).is_equal(0)
	package.documents = {"quests": [42], "encounters": []}
	result = registry.apply(package)
	assert_bool(result.ok).is_false()
	assert_str(result.errors[0].field).is_equal("quests[0]")
