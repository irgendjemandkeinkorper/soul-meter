extends GdUnitTestSuite
## E3.4 (#343): `new_scene` renders a field or interior template into the package scratch
## (`user://weftlumin/<package>/`), never `res://`; the scene loads from there, passes the field
## contract, registers live, travels, undoes cleanly, and bakes to `res://world/` from the log alone.

const PACKAGE := "gdunit-new-scene"
const BAKE_ROOT := "user://gdunit-new-scene-bake"
const GUARDED: Array[String] = [
	"res://data/generated/location_index.json", "res://canon/dom/locations/wilds.json", "res://world/test_room.tscn",
]

var _bus: WeftluminCommandBus
## The bus holds callables into the creator; keep it alive.
var _creator: WeftluminSceneCreator
var _game_state_before: Dictionary
var _target_scene_before: String
var _target_spawn_before: StringName
var _current_scene_before: Node
var _world_clock_before: Dictionary


func before_test() -> void:
	_game_state_before = GameState.to_dict().duplicate(true)
	# Travel stages GameFlow's target and spends a WorldClock phase; hand both back (as the tavern suite does).
	_target_scene_before = GameFlow._target_scene
	_target_spawn_before = GameFlow._target_spawn_id
	_current_scene_before = get_tree().current_scene
	_world_clock_before = WorldClock.to_dict()
	_bus = WeftluminCommandBus.new(PACKAGE)
	_bus.persist_log = false
	_creator = WeftluminSceneCreator.new()
	_creator.register_ops(_bus)


func after_test() -> void:
	LocationRegistry._clear_runtime()
	GameState.from_dict(_game_state_before)
	if get_tree().current_scene != _current_scene_before:
		get_tree().current_scene = _current_scene_before
	GameFlow._target_scene = _target_scene_before
	GameFlow._target_spawn_id = _target_spawn_before
	WorldClock.from_dict(_world_clock_before)
	_remove_tree(WeftluminSceneTemplate.package_dir(PACKAGE))
	_remove_tree(BAKE_ROOT)


func test_params_are_checked_before_anything_is_written() -> void:
	var errors: Array[String] = []
	assert_dict(WeftluminSceneTemplate.normalise({"hub": "Dom", "id": "bad-id", "size_cells": [4, 900], "template": "cave"}, errors)).is_empty()
	assert_int(errors.size()).is_equal(4)
	errors.clear()
	var params: Dictionary = WeftluminSceneTemplate.normalise({"hub": "dom", "id": "mire_hollow"}, errors)
	assert_array(errors).is_empty()
	assert_array(params["size_cells"]).is_equal([70, 70])
	assert_str(str(params["backdrop"])).is_equal(WeftluminSceneTemplate.DEFAULT_BACKDROP)
	assert_str(str(params["template"])).is_equal(WeftluminSceneTemplate.FIELD)


func test_new_field_scene_writes_only_scratch_and_registers_live() -> void:
	var hashes: Dictionary = _hashes()
	var outcome: Dictionary = _new_scene({"hub": "dom", "id": "mire_hollow", "size_cells": [40, 48]})
	assert_bool(bool(outcome["allowed"])).override_failure_message(str(outcome)).is_true()
	var scene: String = WeftluminSceneTemplate.scratch_scene_path(PACKAGE, "mire_hollow")
	assert_bool(FileAccess.file_exists(scene)).is_true()
	assert_bool(FileAccess.file_exists("res://world/mire_hollow.tscn")).is_false()
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WeftluminSceneTemplate.scratch_document_path(PACKAGE, "mire_hollow")))
	assert_str(str(document["scene_path"])).is_equal("res://world/mire_hollow.tscn")
	assert_str(str(document["definition_path"])).is_equal("res://world/locations/mire_hollow.tres")
	assert_bool(bool(document["no_combat_zone"])).is_false()
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WeftluminSceneTemplate.manifest_path(PACKAGE)))
	assert_str(str(manifest["hub"])).is_equal("dom")
	assert_array(manifest["kinds"]).contains(["scenes", "locations"])
	var location: LocationDefinition = LocationRegistry.by_id(&"mire_hollow")
	assert_object(location).is_not_null()
	assert_str(location.scene_path).is_equal(scene)
	assert_bool(LocationRegistry.is_gameplay_scene(scene)).is_true()
	assert_array(GameFlow.GAMEPLAY_SCENES).contains([scene])
	# Overlay boundary (§4.14): canon, the index and committed scenes are untouched.
	assert_dict(_hashes()).is_equal(hashes)


func test_a_new_field_scene_loads_from_user_and_passes_the_field_contract() -> void:
	_new_scene({"hub": "dom", "id": "mire_hollow", "size_cells": [40, 48]})
	var path: String = WeftluminSceneTemplate.scratch_scene_path(PACKAGE, "mire_hollow")
	var scene: Node = (load(path) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	assert_bool((scene as Node2D).y_sort_enabled).is_true()
	var field := scene.find_child("FieldMap", false, false) as FieldMap
	assert_object(field).is_not_null()
	assert_object(field.ground()).is_not_null()
	assert_object(field.blocking()).is_not_null()
	assert_bool(field.no_combat_zone()).is_false()
	assert_bool(field.ground().get_used_rect().has_area()).is_true()
	assert_vector(Vector2(field.ground().get_used_rect().size)).is_equal(Vector2(40, 48))
	var controller := scene.find_child("ClickMoveController", true, false) as ClickMoveController
	assert_object(controller).is_not_null()
	assert_object(field.iso_grid()).is_same(controller.get_iso_grid())
	var location: LocationDefinition = LocationRegistry.by_id(&"mire_hollow")
	assert_object(scene.get_node_or_null("Spawn" + String(location.resolve_spawn(&"default")).capitalize())).is_not_null()
	for layer: String in ["GroundDetails", "SoftDetails", "SolidProps"]:
		assert_object(scene.get_node_or_null("MireHollowDressing/" + layer)).override_failure_message(layer).is_not_null()
	for node: String in ["TerrainBackdrop", "Terrain", "Walls", "Player", "PartyFollowers", "FieldHUD"]:
		assert_object(scene.get_node_or_null(node)).override_failure_message(node).is_not_null()
	scene.queue_free()
	await get_tree().process_frame


func test_a_new_interior_is_a_no_combat_zone() -> void:
	var outcome: Dictionary = _new_scene({"hub": "dom", "id": "reed_cellar", "template": "interior", "display_name": "Reed Cellar"})
	assert_bool(bool(outcome["allowed"])).override_failure_message(str(outcome)).is_true()
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(WeftluminSceneTemplate.scratch_document_path(PACKAGE, "reed_cellar")))
	assert_str(str(document["scene_path"])).is_equal("res://world/interiors/reed_cellar.tscn")
	assert_bool(bool(document["no_combat_zone"])).is_true()
	var path: String = WeftluminSceneTemplate.scratch_scene_path(PACKAGE, "reed_cellar")
	var scene: Node = (load(path) as PackedScene).instantiate()
	add_child(scene)
	await get_tree().process_frame
	assert_str(scene.name).is_equal("ReedCellarInterior")
	var field := scene.find_child("FieldMap", true, false) as FieldMap
	assert_object(field).is_not_null()
	assert_bool(field.no_combat_zone()).is_true()
	assert_object(scene.find_child("SpawnEntry", true, false)).is_not_null()
	scene.queue_free()
	await get_tree().process_frame


func test_travel_reaches_the_new_scene_through_game_flow() -> void:
	assert_bool(WeftluminSceneCreator.travel_to("mire_hollow")).is_false()
	_new_scene({"hub": "dom", "id": "mire_hollow"})
	assert_bool(WeftluminSceneCreator.travel_to("mire_hollow")).is_true()
	assert_str(GameFlow._target_scene).is_equal(WeftluminSceneTemplate.scratch_scene_path(PACKAGE, "mire_hollow"))
	assert_str(String(GameFlow._target_spawn_id)).is_equal("default")


func test_undo_removes_the_scratch_and_the_registration_and_redo_restores_them() -> void:
	_new_scene({"hub": "dom", "id": "mire_hollow"})
	var scene: String = WeftluminSceneTemplate.scratch_scene_path(PACKAGE, "mire_hollow")
	assert_bool(bool(_bus.undo()["allowed"])).is_true()
	assert_bool(FileAccess.file_exists(scene)).is_false()
	assert_bool(FileAccess.file_exists(WeftluminSceneTemplate.manifest_path(PACKAGE))).is_false()
	assert_object(LocationRegistry.by_id(&"mire_hollow")).is_null()
	assert_array(GameFlow.GAMEPLAY_SCENES).not_contains([scene])
	assert_bool(bool(_bus.redo()["allowed"])).is_true()
	assert_bool(FileAccess.file_exists(scene)).is_true()
	assert_object(LocationRegistry.by_id(&"mire_hollow")).is_not_null()


func test_new_scene_refuses_an_existing_location_and_a_foreign_target() -> void:
	var taken: Dictionary = _new_scene({"hub": "dom", "id": "dom"})
	assert_bool(bool(taken["allowed"])).is_false()
	assert_str(str(taken["message"])).contains("already exists")
	var errors: Array[String] = []
	var command: WeftluminCommand = WeftluminSceneCreator.command({"hub": "dom", "id": "mire_hollow"}, PACKAGE, errors)
	command.target["scene"] = "res://world/mire_hollow.tscn"
	assert_bool(bool(_bus.execute(command)["allowed"])).is_false()
	assert_bool(FileAccess.file_exists("res://world/mire_hollow.tscn")).is_false()
	assert_array(_bus.log_entries()).is_empty()


func test_the_bake_renders_the_scene_from_the_log_and_replays_its_edits() -> void:
	_new_scene({"hub": "dom", "id": "mire_hollow"})
	var scratch: String = WeftluminSceneTemplate.scratch_scene_path(PACKAGE, "mire_hollow")
	var edit: WeftluminCommand = WeftluminCommand.make(
		WeftluminSceneModel.KIND, WeftluminSceneModel.OP_SET, {"scene": scratch, "node": "SpawnDefault"},
		{"key": "position", "value": [240.0, 610.0]}, PACKAGE,
	)
	edit.pre_state = {"value": [180.0, 600.0]}
	var entries: Array = _bus.log_entries()
	entries.append(edit.to_dict())
	# The bake must not depend on the scratch scene existing (another machine, a PR worktree).
	DirAccess.remove_absolute(ProjectSettings.globalize_path(scratch))
	var report: Dictionary = WeftluminBake.bake(entries, BAKE_ROOT, true)
	assert_array(report["errors"]).override_failure_message(str(report["errors"])).is_empty()
	var baked: String = BAKE_ROOT.path_join("world/mire_hollow.tscn")
	assert_array(report["written"]).contains_exactly([baked])
	assert_str(str(report["planned"][0]["action"])).is_equal("create")
	var instance: Node = (ResourceLoader.load(baked, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()
	assert_vector((instance.get_node("SpawnDefault") as Node2D).position).is_equal(Vector2(240, 610))
	assert_object(instance.get_node_or_null("FieldMap")).is_not_null()
	instance.free()
	assert_bool(FileAccess.file_exists("res://world/mire_hollow.tscn")).is_false()


func test_the_locations_kind_accepts_a_package_document_for_its_new_scene() -> void:
	_new_scene({"hub": "dom", "id": "mire_hollow"})
	var path: String = WeftluminSceneTemplate.scratch_document_path(PACKAGE, "mire_hollow")
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(path))
	document[WeftluminLocationsKind.META_FILE] = path
	var errors: Array[Dictionary] = []
	assert_array(WeftluminLocationsKind.new().validate([document], errors)).has_size(1)
	assert_array(errors).is_empty()
	# Without the package's scene, the same document names a scene that does not exist.
	DirAccess.remove_absolute(ProjectSettings.globalize_path(WeftluminSceneTemplate.scratch_scene_path(PACKAGE, "mire_hollow")))
	errors.clear()
	WeftluminLocationsKind.new().validate([document], errors)
	assert_str(JSON.stringify(errors)).contains("missing_scene")


# --- helpers ------------------------------------------------------------------------------------


func _new_scene(params: Dictionary) -> Dictionary:
	var errors: Array[String] = []
	var command: WeftluminCommand = WeftluminSceneCreator.command(params, PACKAGE, errors)
	assert_array(errors).is_empty()
	return _bus.execute(command)


func _hashes() -> Dictionary:
	var hashes: Dictionary = {}
	for path: String in GUARDED:
		hashes[path] = FileAccess.get_md5(path)
	return hashes


static func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(path.path_join(file))
	DirAccess.remove_absolute(path)
