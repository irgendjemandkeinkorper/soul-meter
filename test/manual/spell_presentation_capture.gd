extends GdUnitTestSuite
## Explicit rendered QA: captures go to the test wrapper's isolated user://qa.
## Sample times are fixed so the contact sheet is comparable across machines.

const SpellCastScript := preload("res://ui/hud/spell_cast_effect.gd")
const StageScene := preload("res://ui/hud/regions/stage/battle_stage_region.tscn")
var _reduced_before: bool


func before_test() -> void:
	_reduced_before = bool(GameState.get_setting("accessibility", "reduced_motion", false))
	GameState.set_setting("accessibility", "reduced_motion", false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://qa"))


func after_test() -> void:
	GameState.set_setting("accessibility", "reduced_motion", _reduced_before)


func test_capture_wheel_spell_impacts() -> void:
	var viewport := _viewport()
	var effects: Array[Node2D] = []
	for index: int in DS.WHEEL.size():
		var entry: Dictionary = DS.WHEEL[index]
		var offset := Vector2(float(index % 5) * 384.0, float(index / 5) * 540.0)
		var panel := PanelContainer.new()
		panel.theme = ThemeBuilder.build()
		panel.position = offset + Vector2(DS.SPACE_4, DS.SPACE_4)
		panel.size = Vector2(368, 524)
		viewport.add_child(panel)
		var label := Label.new()
		label.theme = panel.theme
		label.theme_type_variation = &"HeadingLabel"
		label.text = str(entry["name"]).to_upper()
		label.position = offset + Vector2(24, 24)
		viewport.add_child(label)
		var origin := offset + Vector2(92, 340)
		var target := offset + Vector2(266, 248)
		_add_unit(viewport, origin, "vex", 112.0)
		_add_unit(viewport, target, "bog-wight", 112.0)
		var effect := SpellCastScript.new()
		effect.setup(_cast([str(entry["id"])]), func() -> Vector2: return origin - Vector2(0, 50),
			[func() -> Vector2: return target - Vector2(0, 50)], 2.0)
		viewport.add_child(effect)
		effect.set_process(false)
		effects.append(effect)
	for phase: Dictionary in [{"name": "travel", "time": 0.27}, {"name": "impact", "time": 0.46}]:
		for effect: Node2D in effects:
			effect._elapsed = phase.time
			effect.queue_redraw()
		await _capture(viewport, "spell-wheel-%s.png" % phase.name)
	GameState.set_setting("accessibility", "reduced_motion", true)
	for effect: Node2D in effects:
		effect._reduced = true
		effect.queue_redraw()
	await _capture(viewport, "spell-wheel-reduced-motion.png")


func test_capture_board_cast_sequence_and_cell_working() -> void:
	var viewport := _viewport()
	var stage := StageScene.instantiate() as BattleStageRegion
	stage.theme = ThemeBuilder.build()
	stage.size = Vector2(1920, 1080)
	viewport.add_child(stage)
	var initial := CombatEvent.new()
	initial.data = {"snapshot": _snapshot()}
	stage.consume_event(initial)
	await get_tree().process_frame
	for sample: Dictionary in [
		{"name": "khash", "elements": ["khash"]},
		{"name": "luth", "elements": ["luth"]},
		{"name": "zhur", "elements": ["zhur"]},
		{"name": "chord", "elements": ["sul", "vel"]},
		{"name": "firebreak", "elements": ["khash"], "cells": [{"x": 2, "y": 0}, {"x": 3, "y": 0}, {"x": 4, "y": 0}]},
	]:
		var event := _cast(sample.elements)
		if sample.has("cells"):
			event.target_id = &""
			event.data["cells"] = sample.cells
		stage.consume_event(event)
		var effect := stage.get_node("FxLayer/SpellCast") as Node2D
		effect.set_process(false)
		for frame: int in 24:
			effect._elapsed = float(frame) / 30.0
			effect.queue_redraw()
			await _capture(viewport, "spell-%s-%02d.png" % [sample.name, frame])
		stage.get_node("FxLayer").remove_child(effect)
		effect.free()


func test_capture_field_cast_uses_borrowed_sprites() -> void:
	var viewport := _viewport()
	var field := Node2D.new()
	field.position = Vector2(740, 580)
	field.scale = Vector2(3, 3)
	viewport.add_child(field)
	var ground := TileMapLayer.new()
	ground.tile_set = TileSet.new()
	ground.tile_set.tile_size = Vector2i(64, 32)
	ground.tile_set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	var source := TileSetAtlasSource.new()
	source.texture = preload("res://assets/generated/sprites/ground/ground_tiles.png")
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(IsometricSpriteCatalog.GROUND_GRASS)
	ground.tile_set.add_source(source, 0)
	for x: int in 6:
		for y: int in 4:
			ground.set_cell(Vector2i(x, y), 0, IsometricSpriteCatalog.GROUND_GRASS)
	field.add_child(ground)
	var grid := IsoGrid.new()
	grid.build(ground)
	var overlay := CombatOverlay.new()
	field.add_child(overlay)
	overlay.z_index = 1
	overlay.bind_grid(grid, ground)
	var hero := Node2D.new()
	field.add_child(hero)
	_add_unit(hero, Vector2.ZERO, "vex", 64.0)
	var enemy := Node2D.new()
	field.add_child(enemy)
	_add_unit(enemy, Vector2.ZERO, "bog-wight", 64.0)
	overlay.bind_actor(&"ally", hero)
	overlay.bind_actor(&"enemy", enemy)
	overlay.consume_event(_cast(["zhur"]))
	var effect := overlay.get_node("SpellCast") as Node2D
	effect.set_process(false)
	effect._elapsed = 0.27
	effect.queue_redraw()
	await _capture(viewport, "spell-field-travel.png")
	effect._elapsed = 0.46
	effect.queue_redraw()
	await _capture(viewport, "spell-field-impact.png")


func _add_unit(parent: Node, foot: Vector2, unit_id: String, height: float) -> void:
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(UnitArt.texture_path(UnitArt.resolve(unit_id)))
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	sprite.scale = Vector2.ONE * height / float(sprite.texture.get_height())
	sprite.position = foot + Vector2(0, -height * 0.5)
	parent.add_child(sprite)


func _viewport() -> SubViewport:
	var viewport := auto_free(SubViewport.new()) as SubViewport
	viewport.size = Vector2i(1920, 1080)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var background := ColorRect.new()
	background.color = DS.VOID_1
	background.size = Vector2(1920, 1080)
	viewport.add_child(background)
	return viewport


func _capture(viewport: SubViewport, filename: String) -> void:
	await get_tree().process_frame
	RenderingServer.force_draw()
	await RenderingServer.frame_post_draw
	assert_int(viewport.get_texture().get_image().save_png("user://qa/" + filename)).is_equal(OK)


func _cast(elements: Array) -> CombatEvent:
	var event := CombatEvent.new()
	event.type = &"action_resolved"
	event.actor_id = &"ally"
	event.target_id = &"enemy"
	event.data = {"verb": CombatAction.Verb.CAST, "damage": 7,
		"resolution": {"hit": true, "fizzled": false, "composition": {"elements": elements}},
		"snapshot": _snapshot()}
	return event


func _snapshot() -> Dictionary:
	var tiles: Array[Dictionary] = []
	for x: int in 6:
		for y: int in 4:
			tiles.append({"x": x, "y": y})
	return {"encounter_id": "bog-presentation", "tiles": tiles,
		"allies": [{"id": "ally", "display_name": "Vex", "side": "ally", "hp": 100, "max_hp": 100, "position": Vector2i(1, 2)}],
		"enemies": [{"id": "enemy", "display_name": "Bog Wight", "archetype_id": "bog-wight", "side": "enemy", "hp": 93, "max_hp": 100, "position": Vector2i(4, 1)}],
	}
