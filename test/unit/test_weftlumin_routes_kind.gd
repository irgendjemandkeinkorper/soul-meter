extends GdUnitTestSuite
## Canon validation, package overlays and deterministic route baking; no production writes.

const GeneratorScript := preload("res://tools/generate_locations.gd")
const AdapterScript := preload("res://addons/weftlumin/shell/soul_meter_adapter.gd")
const CliScript := preload("res://addons/weftlumin/tools/cli.gd")
const SCRATCH := "user://gdunit-weftlumin-routes"
const ROUTE_PATH := "res://canon/dom/routes/dom-dorthkor_road.json"


func after_test() -> void:
	_remove_tree(SCRATCH)


func _route() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(ROUTE_PATH)) as Dictionary


func _errors(document: Dictionary) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var batch: Array[Dictionary] = [document]
	assert_array(WeftluminRoutesKind.new().validate(batch, errors)).is_empty()
	assert_array(errors).is_not_empty()
	for error: Dictionary in errors:
		for key: String in ["file", "field", "expected", "code", "message"]:
			assert_bool(error.has(key)).is_true()
	return errors


func test_all_eight_canon_routes_validate_and_keep_the_allied_zero() -> void:
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = WeftluminRoutesKind.load_canon(errors)
	var rows: Array[Dictionary] = WeftluminRoutesKind.new().validate(documents, errors)
	assert_array(errors).override_failure_message(str(errors)).is_empty()
	assert_int(rows.size()).is_equal(8)
	assert_int(int(rows[0]["band_encounter_weights"]["bands"]["allied"]["dorthkor-vanguard"])).is_equal(0)
	var ids: Array[String] = []
	for row: Dictionary in rows:
		ids.append(row["id"])
		assert_bool(row.has("$file")).is_false()
		assert_bool(row.has("$hub")).is_false()
	var sorted: Array[String] = ids.duplicate()
	sorted.sort()
	assert_array(ids).is_equal(sorted)


func test_canon_routes_are_filed_with_their_origins_and_keep_canonical_text() -> void:
	var errors: Array[Dictionary] = []
	var hubs: Dictionary = {}
	for location: Dictionary in WeftluminLocationsKind.load_canon(errors):
		hubs[location["id"]] = location["$hub"]
	for document: Dictionary in WeftluminRoutesKind.load_canon(errors):
		assert_str(document["$hub"]).is_equal(hubs[document["origin_id"]])
		var batch: Array[Dictionary] = [document]
		var rows: Array[Dictionary] = WeftluminRoutesKind.new().validate(batch, errors)
		assert_str(WeftluminRoutesKind.canon_text(rows[0])).is_equal(FileAccess.get_file_as_string(document["$file"]))
	assert_array(errors).is_empty()


func test_route_fields_and_endpoints_reject_invalid_documents() -> void:
	for pair: Array in [
		["schema", "weftlumin.route.v0"], ["id", "wrong-id"], ["origin_id", "missing"],
		["destination_id", "loamgate"], ["risk_tier", "extreme"], ["risk_modifier", "5"],
		["steps", 1.5], ["phases_cost", -1], ["min_encounters", 3], ["max_encounters", null],
		["extra_field", true], ["encounter_table", {}],
	]:
		var document: Dictionary = _route()
		document[pair[0]] = pair[1]
		_errors(document)


func test_duplicate_routes_are_refused() -> void:
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = [_route(), _route()]
	assert_array(WeftluminRoutesKind.new().validate(documents, errors)).is_empty()
	assert_str(errors[0]["code"]).is_equal("duplicate_id")


func test_reversed_pair_is_a_duplicate_route() -> void:
	var reversed: Dictionary = _route()
	reversed["id"] = "%s-%s" % [reversed["destination_id"], reversed["origin_id"]]
	var origin: String = reversed["origin_id"]
	reversed["origin_id"] = reversed["destination_id"]
	reversed["destination_id"] = origin
	var errors: Array[Dictionary] = []
	var documents: Array[Dictionary] = [_route(), reversed]
	assert_array(WeftluminRoutesKind.new().validate(documents, errors)).is_empty()
	assert_str(errors[0]["code"]).is_equal("duplicate_pair")


func test_fractional_weights_are_refused_in_base_and_band_tables() -> void:
	var document: Dictionary = _route()
	document["encounter_table"][0]["weight"] = 0.5
	assert_str(_errors(document)[0]["code"]).is_equal("out_of_range")
	var banded: Dictionary = _route()
	var bands: Dictionary = banded["band_encounter_weights"]["bands"]
	var band: String = String(bands.keys()[0])
	var encounter: String = String(bands[band].keys()[0])
	bands[band][encounter] = 1.5
	assert_str(_errors(banded)[0]["code"]).is_equal("out_of_range")


func test_base_weights_require_positive_numbers_and_known_encounters() -> void:
	for value: Variant in [0, -1, "2", null]:
		var document: Dictionary = _route()
		document["encounter_table"][0]["weight"] = value
		_errors(document)
	var document: Dictionary = _route()
	document["encounter_table"][0]["encounter_id"] = "missing-encounter"
	assert_str(_errors(document)[0]["code"]).is_equal("unknown_encounter")


func test_band_weights_allow_zero_but_refuse_negative_or_unknown_encounters() -> void:
	for value: Variant in [-1, "0", null]:
		var document: Dictionary = _route()
		document["band_encounter_weights"]["bands"]["allied"]["dorthkor-vanguard"] = value
		_errors(document)
	var document: Dictionary = _route()
	document["band_encounter_weights"]["bands"]["allied"] = {"missing-encounter": 0}
	assert_str(_errors(document)[0]["code"]).is_equal("unknown_encounter")


func test_band_shape_errors_are_attributed() -> void:
	for value: Variant in [[], {}, {"faction_id": 7, "bands": {}},
		{"faction_id": "iron-companies", "bands": []},
		{"faction_id": "iron-companies", "bands": {"allied": []}},
	]:
		var document: Dictionary = _route()
		document["band_encounter_weights"] = value
		_errors(document)


func test_generator_bakes_sorted_routes_without_schema_or_metadata_and_repeats_without_drift() -> void:
	var first: Dictionary = GeneratorScript.generate(false, "res://canon", SCRATCH)
	assert_array(first["errors"]).is_empty()
	var index: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SCRATCH + "/data/generated/location_index.json"))
	var errors: Array[Dictionary] = []
	var expected: Array[Dictionary] = WeftluminRoutesKind.new().validate(WeftluminRoutesKind.load_canon(errors), errors)
	for row: Dictionary in expected:
		row.erase("schema")
	# JSON has one numeric type; runtime Variant types are pinned by the registry fixture.
	var json_expected: Array = JSON.parse_string(JSON.stringify(expected))
	assert_array(index["routes"]).is_equal(json_expected)
	assert_bool(GeneratorScript.generate(true, "res://canon", SCRATCH)["drift"]).is_false()


func test_invalid_route_prevents_any_generator_write() -> void:
	var errors: Array[Dictionary] = []
	for document: Dictionary in WeftluminLocationsKind.load_canon(errors):
		var path: String = String(document["$file"]).trim_prefix("res://canon/")
		_write(SCRATCH + "/canon/" + path, FileAccess.get_file_as_string(document["$file"]))
	var document: Dictionary = _route()
	document["destination_id"] = "missing"
	_write(SCRATCH + "/canon/dom/routes/invalid.json", JSON.stringify(document))
	var result: Dictionary = GeneratorScript.generate(false, SCRATCH + "/canon", SCRATCH + "/out")
	assert_array(result["errors"]).is_not_empty()
	assert_bool(DirAccess.dir_exists_absolute(SCRATCH + "/out")).is_false()


func test_cli_recognises_route_manifests_and_bakes_through_the_shared_index() -> void:
	_write(SCRATCH + "/campaign.json", JSON.stringify({
		"schema": "weftlumin.package.v1", "id": "route-test", "kinds": ["routes"],
	}))
	var route: Dictionary = _route()
	route["steps"] = int(route["steps"]) + 1
	_write(SCRATCH + "/routes/" + String(route["id"]) + ".json", JSON.stringify(route))
	var before: PackedByteArray = FileAccess.get_file_as_bytes(WeftluminLocationsKind.INDEX_PATH)
	var cli: RefCounted = CliScript.new(AdapterScript.new())
	cli.set("echo", false)
	var validation: Dictionary = cli.call("run", PackedStringArray(["validate", SCRATCH]))
	assert_int(validation["exit_code"]).override_failure_message(str(validation)).is_equal(0)
	assert_array(validation["report"]["kinds"]).contains_exactly(["routes"])
	var bake: Dictionary = cli.call("run", PackedStringArray(["bake", SCRATCH]))
	assert_int(bake["exit_code"]).override_failure_message(str(bake)).is_equal(0)
	var planned: Array = bake["report"]["planned"]
	assert_bool(planned.any(func(row: Dictionary) -> bool:
		return row["path"] == WeftluminLocationsKind.INDEX_PATH and row["action"] == "update")).is_true()
	assert_bool(FileAccess.get_file_as_bytes(WeftluminLocationsKind.INDEX_PATH) == before).is_true()


func test_package_routes_resolve_new_location_overlays_in_either_manifest_order() -> void:
	var location: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://canon/dom/locations/wilds.json"))
	location["id"] = "route_probe"
	location["definition_path"] = "res://world/locations/route_probe.tres"
	# The package provides the scene just as the scene creator does.
	location["scene_path"] = "res://world/route_probe.tscn"
	_write(SCRATCH + "/scenes/route_probe.tscn", "[gd_scene format=3]\n[node name=\"Probe\" type=\"Node2D\"]\n")
	_write(SCRATCH + "/locations/route_probe.json", JSON.stringify(location))
	var route: Dictionary = _route()
	route["id"] = "dom-route_probe"
	route["destination_id"] = "route_probe"
	_write(SCRATCH + "/routes/dom-route_probe.json", JSON.stringify(route))
	for kinds: Array in [["locations", "routes"], ["routes", "locations"]]:
		_write(SCRATCH + "/campaign.json", JSON.stringify({
			"schema": "weftlumin.package.v1", "id": "route-test", "kinds": kinds,
		}))
		var cli: RefCounted = CliScript.new(AdapterScript.new())
		cli.set("echo", false)
		var result: Dictionary = cli.call("run", PackedStringArray(["validate", SCRATCH]))
		assert_int(result["exit_code"]).override_failure_message(str(result)).is_equal(0)


func test_package_bake_files_each_new_route_with_its_origin() -> void:
	var adapter: RefCounted = AdapterScript.new()
	var documents: Array[Dictionary] = [
		{"id": "wilds-hollowmere", "origin_id": "wilds"},
		{"id": "route_probe-kesselford", "origin_id": "route_probe"},
		{"id": "kesselford-dom", "origin_id": "kesselford"},
	]
	var errors: Array[Dictionary] = []
	var overlay: Dictionary = adapter.call("_overlay_canon", WeftluminRoutesKind.new(), documents,
		{"hub": "ashlaren"}, errors)
	assert_array(errors).is_empty()
	assert_dict(overlay["targets"]).is_equal({
		"wilds-hollowmere": "res://canon/dom/routes/wilds-hollowmere.json",
		"route_probe-kesselford": "res://canon/ashlaren/routes/route_probe-kesselford.json",
		"kesselford-dom": "res://canon/kesselford/routes/kesselford-dom.json",
	})


func _write(path: String, text: String) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for child: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(child))
	for filename: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(filename))
	DirAccess.remove_absolute(path)
