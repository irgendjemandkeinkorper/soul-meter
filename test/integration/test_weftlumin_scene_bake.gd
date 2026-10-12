extends GdUnitTestSuite
## E3.5 (#344): a scene command log bakes into surgical `.tscn` patches through
## `TscnDocument`, report-only by default, with the Dom fixture log and Soul Meter's scene
## contract tests as validators (`WeftluminBake`, `WeftluminScenesKind`).
##
## The committed fixture `test/fixtures/weftlumin/dom_scene_bake/commands.jsonl` was recorded by
## `_record_dom_session()` against Dom as committed. Re-record it after a deliberate Dom change
## (the live-session test writes it; the fixture-reading tests fail until the next run):
##   SOUL_METER_SCENE_BAKE_RECORD_FIXTURE=1 … scripts/test.sh -a test/integration/test_weftlumin_scene_bake.gd
## Rendered evidence (Xvfb or a display): set SOUL_METER_SCENE_BAKE_CAPTURE_DIR.

const DOM := "res://world/starting_town.tscn"
const FIXTURE_LOG := "res://test/fixtures/weftlumin/dom_scene_bake/commands.jsonl"
const TARGET_ROOT := "user://weftlumin_scene_bake_test"
const PACKAGE := "dom-scene-bake"
const COVER: Array = [0, 1, 0, 0]
const NEW_TEXTURE := "res://assets/generated/sprites/world/loamroot-grove/loamroot-grove--mud.png"
const CRATE_TEXTURE := "res://assets/generated/sprites/world/dom-crate-wood--stacked.png"
const GRAYSCALE_SHADER := "res://ui/debug/layout_grayscale.gdshader"
const GROUND_TILE_SET := "res://assets/generated/sprites/ground/ground_tileset.tres"
## Every node the fixture edits or adds, for the live-versus-baked comparison.
const FIXTURE_PATHS: Array[String] = [
	"TownscapeDressing/GroundDetails/PuddleRiverWest",
	"TownscapeDressing/SoftDetails/BushRegistryCorner",
	"TownscapeDressing/SoftDetails/BushBellWall",
	"WoundLip/SignSprite",
	"TownscapeDressing/SolidProps/MarketCratesWest",
	"TownscapeDressing/SolidProps/MarketCratesWest/CollisionShape2D",
	"MarshalCoiljaw",
	"TownscapeDressing/GroundDetails",
	"TownscapeDressing/GroundDetails/BakeMudPatch",
	"TownscapeDressing/SolidProps/BakeCrates",
	"TownscapeDressing/SolidProps/BakeCrates/Sprite2D",
	"TownscapeDressing/SolidProps/BakeCrates/CollisionShape2D",
	"TownscapeDressing/SoftDetails/BushShrineBankCopy",
	"BakeChest",
	"SpawnBakeFixture",
	"TownscapeDressing/GroundDetails/PuddleRiverEast",
]

func after_test() -> void:
	_remove_tree(TARGET_ROOT)


# --- report and write modes ---------------------------------------------------------------------


func test_report_mode_plans_the_dom_fixture_and_writes_nothing() -> void:
	var source: String = FileAccess.get_file_as_string(DOM)
	var kind := WeftluminScenesKind.new()
	var commands: Array[Dictionary] = _fixture(kind)
	var report: Dictionary = kind.bake(commands, TARGET_ROOT, false, false)
	assert_str(report["schema"]).is_equal("weftlumin.bake.v1")
	assert_str(report["mode"]).is_equal("report")
	assert_str(report["package"]).is_equal(PACKAGE)
	assert_array(report["errors"]).override_failure_message(JSON.stringify(report["errors"], "  ")).is_empty()
	assert_array(report["planned"]).has_size(1)
	var planned: Dictionary = report["planned"][0]
	assert_str(planned["path"]).is_equal(DOM)
	assert_str(planned["target"]).is_equal(TARGET_ROOT.path_join("world/starting_town.tscn"))
	assert_str(planned["action"]).is_equal("create")
	# 14 effective commands: the undone nudge stays out.
	assert_int(planned["ops"]).is_equal(14)
	assert_array(report["written"]).is_empty()
	assert_bool(DirAccess.dir_exists_absolute(TARGET_ROOT)).is_false()
	# In place, report mode plans an update and still writes nothing.
	var in_place: Dictionary = kind.bake(commands, "res://", false, false)
	assert_array(in_place["errors"]).is_empty()
	assert_str(in_place["planned"][0]["action"]).is_equal("update")
	assert_array(in_place["written"]).is_empty()
	assert_str(FileAccess.get_file_as_string(DOM)).is_equal(source)
	# The transient load-check copies are gone too.
	for file: String in DirAccess.get_files_at("user://"):
		assert_bool(file.begins_with(WeftluminBake.CHECK_PREFIX.get_file())).override_failure_message(file).is_false()


func test_write_mode_output_passes_the_contracts_and_keeps_dom_intact() -> void:
	var source: String = FileAccess.get_file_as_string(DOM)
	var kind := WeftluminScenesKind.new()
	var report: Dictionary = kind.bake(_fixture(kind), TARGET_ROOT, true, false)
	assert_array(report["errors"]).override_failure_message(JSON.stringify(report["errors"], "  ")).is_empty()
	var target: String = TARGET_ROOT.path_join("world/starting_town.tscn")
	assert_array(report["written"]).contains_exactly([target])
	assert_str(FileAccess.get_file_as_string(DOM)).is_equal(source)
	var baked: String = FileAccess.get_file_as_string(target)
	assert_bool(FileAccess.file_exists(target + WeftluminBake.TEMP_SUFFIX)).is_false()
	var before: TscnDocument = TscnDocument.parse(source)
	var after: TscnDocument = TscnDocument.parse(baked)
	# Format 3, every declaration (and so every uid:// reference) and all 21 editable instances kept.
	assert_str(after.header["attributes"]["format"]).is_equal("3")
	for section: Dictionary in before.ext_resources:
		assert_bool(baked.contains(section["header_line"])).is_true()
	assert_array(_editable_blocks(after)).contains_exactly(_editable_blocks(before))
	assert_int(_editable_blocks(after).size()).is_equal(21)
	# The new texture is declared once with the project's uid; the crate texture is reused.
	var declared: String = '[ext_resource type="Texture2D" uid="%s" path="%s" id="2_weftlumin"]' % [
		ResourceUID.id_to_text(ResourceLoader.get_resource_uid(NEW_TEXTURE)), NEW_TEXTURE,
	]
	assert_bool(baked.contains(declared)).override_failure_message(declared).is_true()
	assert_bool(baked.contains('[ext_resource type="Shader" uid="%s" path="%s" id="1_weftlumin"]' % [
		ResourceUID.id_to_text(ResourceLoader.get_resource_uid(GRAYSCALE_SHADER)), GRAYSCALE_SHADER,
	])).is_true()
	assert_int(baked.count('path="%s"' % CRATE_TEXTURE)).is_equal(1)
	# Dom's Blocking block is byte-identical (ruling 9).
	assert_str(_block(after, "Blocking")).is_equal(_block(before, "Blocking"))
	# load_steps counts every declaration the bake added: three resources, three sub-resources.
	assert_int(after.ext_resources.size() - before.ext_resources.size()).is_equal(3)
	assert_int(after.sub_resources.size() - before.sub_resources.size()).is_equal(3)
	assert_str(after.header["header_line"]).is_equal(before.header["header_line"].replace("load_steps=83", "load_steps=89"))

	var town: Node2D = _load(target)
	assert_vector((town.get_node("TownscapeDressing/GroundDetails/PuddleRiverWest") as Node2D).position).is_equal(Vector2(736, 1518))
	assert_bool((town.get_node("TownscapeDressing/SoftDetails/BushRegistryCorner") as Sprite2D).flip_h).is_true()
	assert_bool(baked.contains('[node name="SignSprite" parent="WoundLip"]\nflip_h = true\n')).is_true()
	assert_bool((town.get_node("WoundLip/SignSprite") as Sprite2D).flip_h).is_true()
	var gray := (town.get_node("TownscapeDressing/SoftDetails/BushBellWall") as Sprite2D).material as ShaderMaterial
	assert_object(gray).is_not_null()
	assert_str(gray.shader.resource_path).is_equal(GRAYSCALE_SHADER)
	var resized := (town.get_node("TownscapeDressing/SolidProps/MarketCratesWest/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	assert_vector(resized.size).is_equal(Vector2(80, 32))
	# The shared source rectangle is untouched for the other crates.
	var shared := (town.get_node("TownscapeDressing/SolidProps/MarketCratesSouth/CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D
	assert_vector(shared.size).is_equal(Vector2(62, 28))
	assert_float(town.get_node("MarshalCoiljaw").get("interaction_radius")).is_equal(132.0)
	var patch := town.get_node("TownscapeDressing/GroundDetails/BakeMudPatch") as Sprite2D
	assert_str(patch.texture.resource_path).is_equal(NEW_TEXTURE)
	var crates := town.get_node("TownscapeDressing/SolidProps/BakeCrates") as StaticBody2D
	assert_vector(crates.position).is_equal(Vector2(900, 1460))
	assert_vector(((crates.get_node("CollisionShape2D") as CollisionShape2D).shape as RectangleShape2D).size).is_equal(Vector2(48, 20))
	assert_str((crates.get_node("Sprite2D") as Sprite2D).texture.resource_path).is_equal(CRATE_TEXTURE)
	var copy := town.get_node("TownscapeDressing/SoftDetails/BushShrineBankCopy") as Sprite2D
	var original := town.get_node("TownscapeDressing/SoftDetails/BushShrineBank") as Sprite2D
	assert_vector(copy.position).is_equal(original.position + Vector2(8, 8))
	assert_vector(copy.offset).is_equal(original.offset)
	var chest := town.get_node("BakeChest") as Node2D
	assert_str(chest.scene_file_path).is_equal("res://actors/chest/chest.tscn")
	assert_vector(chest.position).is_equal(Vector2(656, 1590))
	assert_str(str(chest.get("container_id"))).is_equal("dom_bake_fixture_chest")
	assert_object(town.get_node("SpawnBakeFixture") as Marker2D).is_not_null()
	assert_object(town.get_node_or_null("TownscapeDressing/GroundDetails/CobbleCornerMarket")).is_null()
	# The undone nudge stays out.
	assert_vector((town.get_node("TownscapeDressing/GroundDetails/PuddleRiverEast") as Node2D).position).is_equal(
		(_load(DOM).get_node("TownscapeDressing/GroundDetails/PuddleRiverEast") as Node2D).position
	)
	assert_array(town.get_node("Terrain").get("cover_cells")).contains_exactly([Vector2i(3, 3)])
	# Dom survival: the hidden legacy facade override survives the bake.
	assert_bool((town.get_node("TavernDoor/Facade") as Polygon2D).visible).is_false()


func test_baking_the_same_log_twice_is_identical() -> void:
	var kind := WeftluminScenesKind.new()
	var stream: Array[Dictionary] = WeftluminCommandBus.effective_stream(_fixture(kind))
	var first: Dictionary = WeftluminBake.bake_scene(DOM, stream, kind.contract_validators())
	var second: Dictionary = WeftluminBake.bake_scene(DOM, stream, kind.contract_validators())
	assert_array(first["errors"]).is_empty()
	assert_str(first["text"]).is_not_empty()
	assert_str(first["text"]).is_not_equal(first["source"])
	assert_str(second["text"]).is_equal(first["text"])
	# Written twice to the same target, the second bake finds nothing to do.
	var once: Dictionary = kind.bake(_fixture(kind), TARGET_ROOT, true, false)
	assert_array(once["written"]).has_size(1)
	var twice: Dictionary = kind.bake(_fixture(kind), TARGET_ROOT, true, false)
	assert_array(twice["errors"]).is_empty()
	assert_str(twice["planned"][0]["action"]).is_equal("unchanged")
	assert_array(twice["written"]).is_empty()
	assert_bool(WeftluminBake.report_is_clean(twice)).is_true()
	assert_str(FileAccess.get_file_as_string(TARGET_ROOT.path_join("world/starting_town.tscn"))).is_equal(first["text"])


func test_a_live_session_bakes_into_a_scene_equal_to_the_live_one() -> void:
	var live: Node2D = _dom()
	var model: WeftluminSceneModel = _record_dom_session(live)
	var entries: Array[Dictionary] = model.bus.log_entries()
	_maybe_record_fixture(entries)
	var kind := WeftluminScenesKind.new()
	var report: Dictionary = kind.bake(kind.validate(entries, []), TARGET_ROOT, true, false)
	assert_array(report["errors"]).override_failure_message(JSON.stringify(report["errors"], "  ")).is_empty()
	var baked: Node2D = _load(TARGET_ROOT.path_join("world/starting_town.tscn"))
	for path: String in FIXTURE_PATHS:
		var expected: Node = live.get_node_or_null(path)
		var actual: Node = baked.get_node_or_null(path)
		assert_object(actual).override_failure_message("%s is missing from the bake" % path).is_not_null()
		if expected == null or actual == null:
			continue
		var wanted: Dictionary = WeftluminBake._storage(expected)
		var got: Dictionary = WeftluminBake._storage(actual)
		for key: String in wanted:
			assert_bool(WeftluminBake._equivalent(wanted[key], got.get(key))) \
				.override_failure_message("%s:%s live %s, baked %s" % [path, key, wanted[key], got.get(key)]) \
				.is_true()
	assert_object(baked.get_node_or_null("TownscapeDressing/GroundDetails/CobbleCornerMarket")).is_null()
	var terrain_live: Array = live.get_node("Terrain").get("cover_cells")
	assert_array(baked.get_node("Terrain").get("cover_cells")).is_equal(terrain_live)
	model.dispose()


# --- validators refuse bad bakes -----------------------------------------------------------------


func test_contract_validators_refuse_bad_bakes_and_write_nothing() -> void:
	var kind := WeftluminScenesKind.new()
	# Removing a building breaks the Dom contract.
	var removed_building: Array[Dictionary] = _session_entries(func(model: WeftluminSceneModel, root: Node2D) -> void:
		_ok(model.select_only(root.get_node("FourArmsTavern") as Node2D))
		_ok(model.delete_selection())
	)
	var report: Dictionary = kind.bake(removed_building, TARGET_ROOT, true, false)
	assert_array(_codes(report)).contains(["dom_contract"])
	assert_array(report["written"]).is_empty()
	assert_bool(FileAccess.file_exists(TARGET_ROOT.path_join("world/starting_town.tscn"))).is_false()
	assert_str(report["planned"][0]["action"]).is_equal("refused")
	# Removing a spawn marker canon declares breaks the location contract.
	var removed_spawn: Array[Dictionary] = _session_entries(func(model: WeftluminSceneModel, root: Node2D) -> void:
		_ok(model.select_only(root.get_node("SpawnFromTavern") as Node2D))
		_ok(model.delete_selection())
	)
	assert_array(_codes(kind.bake(removed_spawn, TARGET_ROOT, true, false))).contains(["location_contract"])
	# Ruling 9: Dom's Blocking is never re-authored, even when the op itself would succeed.
	var normalize: WeftluminCommand = WeftluminTileBake.normalize_command(DOM, "Blocking", "IsometricGround", GROUND_TILE_SET, PACKAGE)
	var probe: WeftluminTileBake = WeftluminTileBake.open(FileAccess.get_file_as_string(DOM), DOM)
	assert_bool(probe.execute(normalize)["allowed"]).is_true()
	probe.close()
	var ruling: Dictionary = kind.bake([normalize.to_dict()] as Array[Dictionary], TARGET_ROOT, true, false)
	assert_array(_codes(ruling)).contains(["dom_blocking_ruling"])
	assert_array(ruling["written"]).is_empty()
	assert_bool(DirAccess.dir_exists_absolute(TARGET_ROOT)).is_false()


func test_drift_mixed_layers_stale_targets_and_bad_flags_refuse() -> void:
	var kind := WeftluminScenesKind.new()
	# A log recorded against a different Dom refuses rather than guessing.
	var drifted: Array[Dictionary] = _fixture(kind)
	for entry: Dictionary in drifted:
		if str(entry.get("op", "")) == "set_property" and (entry["params"] as Dictionary).get("key", "") == "position":
			(entry["pre_state"] as Dictionary)["value"] = [1.0, 2.0]
			break
	var drift: Dictionary = kind.bake(drifted, TARGET_ROOT, true, false)
	assert_array(_codes(drift)).contains(["pre_state_drift"])
	assert_array(drift["written"]).is_empty()
	# A layout edit of a layer painted earlier in the same log is refused, not half-written.
	var mixed: Array[Dictionary] = _session_entries(func(model: WeftluminSceneModel, root: Node2D) -> void:
		var painter: WeftluminTilePainter = _terrain_painter(model, root)
		_ok(painter.paint(&"Terrain", [Vector2i(4, 4)] as Array[Vector2i], COVER))
		_ok(model.select_only(root.get_node("Terrain") as Node2D))
		_ok(model.nudge(Vector2(8, 0)))
	)
	assert_array(_codes(kind.bake(mixed, TARGET_ROOT, false, false))).contains(["handler_refusal"])
	# A target holding something else needs --force.
	var target: String = TARGET_ROOT.path_join("world/starting_town.tscn")
	DirAccess.make_dir_recursive_absolute(target.get_base_dir())
	var file := FileAccess.open(target, FileAccess.WRITE)
	file.store_string("[gd_scene format=3]\n\n[node name=\"Stale\" type=\"Node2D\"]\n")
	file.close()
	var stale: Dictionary = kind.bake(_fixture(kind), TARGET_ROOT, true, false)
	assert_array(_codes(stale)).contains_exactly(["stale_target"])
	assert_str(FileAccess.get_file_as_string(target)).contains("Stale")
	var forced: Dictionary = kind.bake(_fixture(kind), TARGET_ROOT, true, true)
	assert_array(forced["errors"]).is_empty()
	assert_array(forced["written"]).contains_exactly([target])
	# --force without --write is an argument error.
	assert_array(_codes(kind.bake(_fixture(kind), TARGET_ROOT, false, true))).contains(["force_without_write"])


# --- rendered evidence ---------------------------------------------------------------------------


func test_rendered_bake_capture() -> void:
	var directory := OS.get_environment("SOUL_METER_SCENE_BAKE_CAPTURE_DIR")
	if directory.is_empty():
		return
	assert_str(DisplayServer.get_name()).is_not_equal("headless")
	if DisplayServer.get_name() == "headless":
		return
	assert_int(DirAccess.make_dir_recursive_absolute(directory)).is_equal(OK)
	var kind := WeftluminScenesKind.new()
	var report: Dictionary = kind.bake(_fixture(kind), TARGET_ROOT, true, false)
	assert_array(report["errors"]).is_empty()
	var summary: String = "%s · %s · %s" % [report["mode"], report["planned"][0]["action"], report["summary"]]
	await _capture(DOM, directory.path_join("01-dom-source.jpg"), "Dom as committed (res://world/starting_town.tscn)")
	await _capture(TARGET_ROOT.path_join("world/starting_town.tscn"), directory.path_join("02-dom-baked.jpg"), "Baked fixture log — " + summary)


func _capture(scene: String, path: String, caption: String) -> void:
	var town := (ResourceLoader.load(scene, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate() as Node2D
	# Out of the player's reach: freeze the field so only the authored scene renders.
	town.process_mode = Node.PROCESS_MODE_DISABLED
	# The HUD would cover the comparison; the caption names what is shown.
	var hud := town.get_node_or_null("FieldHUD") as CanvasLayer
	if hud != null:
		hud.visible = false
	var layer := CanvasLayer.new()
	var backing := ColorRect.new()
	backing.color = Color(0, 0, 0, 0.72)
	backing.size = Vector2(1920, 56)
	layer.add_child(backing)
	var label := Label.new()
	label.text = caption
	label.position = Vector2(20, 12)
	label.add_theme_font_size_override("font_size", 26)
	layer.add_child(label)
	var camera := Camera2D.new()
	camera.position = Vector2(770, 1530)
	camera.zoom = Vector2(2.4, 2.4)
	get_tree().root.add_child(town)
	town.add_child(camera)
	get_tree().root.add_child(layer)
	camera.make_current()
	for _frame: int in 4:
		await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	image.resize(image.get_width() / 2, image.get_height() / 2, Image.INTERPOLATE_LANCZOS)
	assert_int(image.save_jpg(path, 0.72)).is_equal(OK)
	layer.free()
	town.free()


# --- the Dom fixture session -------------------------------------------------------------------


## Drive a live scene model over `root` (a fresh Dom) through every op class the scene bake
## writes: layout moves, flips, grayscale, a collision resize, an export edit, dressing props in
## two layers, a duplicate, two placeables, a removal, an undone nudge and a Terrain paint.
func _record_dom_session(root: Node2D) -> WeftluminSceneModel:
	var bus := WeftluminCommandBus.new(PACKAGE)
	bus.persist_log = false
	var model := WeftluminSceneModel.new()
	model.configure(root, bus)
	model.editable_roots_provider = func(scene_root: Node) -> Array: return [scene_root]
	var painter: WeftluminTilePainter = _terrain_painter(model, root)
	_select(model, root, "TownscapeDressing/GroundDetails/PuddleRiverWest")
	_ok(model.nudge(Vector2(16, 8)))
	_select(model, root, "TownscapeDressing/SoftDetails/BushRegistryCorner")
	_ok(model.set_primary_properties({"flip_h": true}))
	_select(model, root, "TownscapeDressing/SoftDetails/BushBellWall")
	_ok(model.set_primary_properties({"grayscale": true}))
	# The exit's sign lives inside its instanced scene: the bake writes an override block.
	_select(model, root, "WoundLip")
	_ok(model.set_primary_properties({"flip_h": true}))
	_select(model, root, "TownscapeDressing/SolidProps/MarketCratesWest")
	_ok(model.set_primary_properties({"collision": [80.0, 32.0]}))
	_select(model, root, "MarshalCoiljaw")
	_ok(model.set_primary_export("interaction_radius", 132.0))
	_ok(model.add_prop({
		"layer": "GroundDetails", "texture": NEW_TEXTURE, "name": "BakeMudPatch",
		"position": [820.0, 1560.0], "scale": [0.75, 0.75], "collision": [64.0, 24.0],
	}))
	_ok(model.add_prop({
		"layer": "SolidProps", "texture": CRATE_TEXTURE, "name": "BakeCrates",
		"position": [900.0, 1460.0], "scale": [1.0, 1.0], "collision": [48.0, 20.0],
	}))
	_select(model, root, "TownscapeDressing/SoftDetails/BushShrineBank")
	_ok(model.duplicate_selection())
	_ok(model.add_instance(root, {
		"placeable": "chest", "scene": "res://actors/chest/chest.tscn", "type": "", "name": "BakeChest",
		"position": [640.0, 1580.0], "exports": {"container_id": var_to_str("dom_bake_fixture_chest")},
	}))
	_ok(model.add_instance(root, {
		"placeable": "spawn_marker", "scene": "", "type": "Marker2D", "name": "SpawnBakeFixture",
		"position": [780.0, 1450.0], "exports": {},
	}))
	_select(model, root, "BakeChest")
	_ok(model.nudge(Vector2(16, 10)))
	_select(model, root, "TownscapeDressing/GroundDetails/CobbleCornerMarket")
	_ok(model.delete_selection())
	_select(model, root, "TownscapeDressing/GroundDetails/PuddleRiverEast")
	_ok(model.nudge(Vector2(40, 0)))
	_ok(model.undo())
	_ok(painter.paint(&"Terrain", [Vector2i(3, 3)] as Array[Vector2i], COVER))
	return model


func _terrain_painter(model: WeftluminSceneModel, root: Node2D) -> WeftluminTilePainter:
	var painter := WeftluminTilePainter.new()
	painter.attach(model)
	var terrain := root.get_node("Terrain") as TileMapLayer
	var lists: Dictionary = {"1,0": "cover_cells", "2,0": "elevation_one_cells", "3,0": "elevation_two_cells"}
	painter.add_layer(&"Terrain", terrain, terrain, {"kind": WeftluminTilePainter.STORE_LISTS, "source": 0, "lists": lists}, [{"label": "Cover", "tile": COVER}])
	return painter


## Record the commands `steps` issues on a fresh Dom.
func _session_entries(steps: Callable) -> Array[Dictionary]:
	var root: Node2D = _dom()
	var bus := WeftluminCommandBus.new(PACKAGE)
	bus.persist_log = false
	var model := WeftluminSceneModel.new()
	model.configure(root, bus)
	model.editable_roots_provider = func(scene_root: Node) -> Array: return [scene_root]
	steps.call(model, root)
	var entries: Array[Dictionary] = bus.log_entries()
	model.dispose()
	return entries


func _maybe_record_fixture(entries: Array[Dictionary]) -> void:
	if OS.get_environment("SOUL_METER_SCENE_BAKE_RECORD_FIXTURE").is_empty():
		return
	var path: String = ProjectSettings.globalize_path(FIXTURE_LOG)
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var lines: PackedStringArray = []
	for entry: Dictionary in entries:
		lines.append(JSON.stringify(entry))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines) + "\n")
	file.close()


func _fixture(kind: WeftluminScenesKind) -> Array[Dictionary]:
	var errors: Array[Dictionary] = []
	var entries: Array[Dictionary] = WeftluminScenesKind.load_log(FIXTURE_LOG, errors)
	var normalised: Array[Dictionary] = kind.validate(entries, errors)
	assert_array(errors).override_failure_message(JSON.stringify(errors)).is_empty()
	return normalised


# --- helpers -----------------------------------------------------------------------------------


func _dom() -> Node2D:
	return auto_free((load(DOM) as PackedScene).instantiate()) as Node2D


func _load(path: String) -> Node2D:
	return auto_free((ResourceLoader.load(path, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene).instantiate()) as Node2D


func _select(model: WeftluminSceneModel, root: Node2D, path: String) -> void:
	assert_bool(model.select_only(root.get_node(path) as Node2D)).override_failure_message("cannot select %s" % path).is_true()


func _ok(outcome: Variant) -> void:
	if outcome is bool:
		assert_bool(outcome).is_true()
		return
	var result: Dictionary = outcome
	assert_bool(bool(result.get("allowed", false))).override_failure_message(str(result.get("message", ""))).is_true()


func _codes(report: Dictionary) -> Array[String]:
	var codes: Array[String] = []
	for error: Dictionary in report["errors"]:
		if not codes.has(str(error["code"])):
			codes.append(str(error["code"]))
	return codes


func _block(document: TscnDocument, path: String) -> String:
	for section: Dictionary in document.nodes:
		if WeftluminBake._section_path(section) == path:
			return section["raw_text"]
	return ""


func _editable_blocks(document: TscnDocument) -> Array[String]:
	var result: Array[String] = []
	for section: Dictionary in document.nodes:
		if "editable_children = true" in section["property_lines"]:
			result.append(section["raw_text"])
	return result


func _remove_tree(path: String) -> void:
	if not DirAccess.dir_exists_absolute(path):
		return
	for directory: String in DirAccess.get_directories_at(path):
		_remove_tree(path.path_join(directory))
	for file: String in DirAccess.get_files_at(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path.path_join(file)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
