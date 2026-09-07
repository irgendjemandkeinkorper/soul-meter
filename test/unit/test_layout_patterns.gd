extends GdUnitTestSuite
## The reusable pattern library's document format (globals/layout_patterns.gd).
##
## This is the half of the feature that outlives the F10 editor — Weftlumin re-hosts the UI
## (#338/#339) but reads the same JSON — so the format is tested on its own, with no editor,
## no input, and no Control anywhere in the suite. Everything below is a pure transform over
## nodes and dictionaries.

const Patterns := preload("res://globals/layout_patterns.gd")
const TEXTURE_A := "res://assets/generated/sprites/world/objects/dom-chest-wood--closed.png"
const TEXTURE_B := "res://assets/generated/sprites/world/objects/dom-door-wood--closed.png"


func _layer(layer_name: StringName, offset: Vector2 = Vector2.ZERO) -> Node2D:
	var layer := auto_free(Node2D.new()) as Node2D
	layer.name = String(layer_name)
	layer.position = offset
	add_child(layer)
	return layer


func _sprite(layer: Node2D, node_name: String, texture_path: String, at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.name = node_name
	sprite.texture = load(texture_path) as Texture2D
	layer.add_child(sprite)
	sprite.global_position = at
	return sprite


## Resolvers stand in for the editor's scene lookups, so stamping is testable without a scene.
func _layer_resolver(layers: Dictionary) -> Callable:
	return func(layer_name: StringName) -> Node2D:
		return layers.get(layer_name) as Node2D


## Mirrors what the editor really does: derive a name from the texture, then disambiguate only
## against what already exists. Deliberately NOT a counter — a counter can never collide, which
## would hide the bug where two same-texture props in one stamp claim the same name.
func _name_resolver() -> Callable:
	return func(layer: Node2D, texture_path: String, reserved: PackedStringArray) -> String:
		var base: String = texture_path.get_file().get_basename().to_pascal_case()
		var candidate := base
		var suffix := 2
		while (
			(layer != null and layer.get_node_or_null(NodePath(candidate)) != null)
			or reserved.has(candidate)
		):
			candidate = "%s%d" % [base, suffix]
			suffix += 1
		return candidate


func test_ids_are_kebab_cased_and_collapse_punctuation() -> void:
	assert_str(String(Patterns.id_for_name("Market Stall Cluster"))).is_equal(
		"market-stall-cluster"
	)
	assert_str(String(Patterns.id_for_name("  Dom / East Gate!!  "))).is_equal("dom-east-gate")
	assert_str(String(Patterns.id_for_name("Row 2"))).is_equal("row-2")
	# Nothing to build an id from must be detectable by the caller, not guessed at.
	assert_str(String(Patterns.id_for_name("!!!"))).is_empty()


func test_capture_stores_offsets_relative_to_the_selection_anchor() -> void:
	var ground := _layer(&"GroundDetails")
	var first := _sprite(ground, "First", TEXTURE_A, Vector2(300.0, 200.0))
	var second := _sprite(ground, "Second", TEXTURE_B, Vector2(340.0, 260.0))

	var result := Patterns.capture([first, second], "Market Stall Cluster")
	assert_bool(result["allowed"]).override_failure_message(
		"%s" % result.get("message", "")
	).is_true()
	var pattern: Dictionary = result["pattern"]
	assert_str(str(pattern["id"])).is_equal("market-stall-cluster")
	assert_str(str(pattern["name"])).is_equal("Market Stall Cluster")
	var nodes: Array = pattern["nodes"]
	assert_int(nodes.size()).is_equal(2)
	# Anchor is the minimum corner, so the first record sits at the origin and the second
	# carries the true delta. Absolute scene coordinates must not leak into a pattern.
	assert_array(nodes[0]["offset"]).is_equal([0.0, 0.0])
	assert_array(nodes[1]["offset"]).is_equal([40.0, 60.0])
	for record: Dictionary in nodes:
		assert_bool(record.has("name")).override_failure_message(
			"a stamp assigns fresh names; the pattern must not carry one"
		).is_false()
		assert_bool(record.has("position")).override_failure_message(
			"position is recomputed per destination layer"
		).is_false()


func test_capture_refuses_authored_nodes_by_name_but_keeps_the_rest() -> void:
	var ground := _layer(&"GroundDetails")
	var prop := _sprite(ground, "Prop", TEXTURE_A, Vector2(100.0, 100.0))
	# A node the editor cannot recreate as an addition: an authored actor stands in here as a
	# plain Node2D, which supports_addition() rejects for not being a supported sprite.
	var actor := Node2D.new()
	actor.name = "AuthoredNPC"
	ground.add_child(actor)

	var result := Patterns.capture([prop, actor], "Mixed")
	assert_bool(result["allowed"]).is_true()
	assert_int((result["pattern"]["nodes"] as Array).size()).is_equal(1)
	assert_array(result["refused"]).override_failure_message(
		"a refused node must be named, not silently dropped"
	).contains(["AuthoredNPC"])


func test_capture_refuses_a_selection_with_nothing_patternable() -> void:
	var ground := _layer(&"GroundDetails")
	var actor := Node2D.new()
	actor.name = "AuthoredNPC"
	ground.add_child(actor)

	var result := Patterns.capture([actor], "Nope")
	assert_bool(result["allowed"]).is_false()
	assert_str(str(result["nearest_unblock"]["type"])).is_equal("patternable_selection")


func test_capture_requires_a_usable_name() -> void:
	var ground := _layer(&"GroundDetails")
	var prop := _sprite(ground, "Prop", TEXTURE_A, Vector2.ZERO)
	assert_bool(Patterns.capture([prop], "   ")["allowed"]).is_false()
	assert_str(str(Patterns.capture([prop], "!!!")["nearest_unblock"]["type"])).is_equal(
		"pattern_name"
	)


func test_stamp_places_additions_at_the_cursor_in_each_layers_local_space() -> void:
	var source := _layer(&"GroundDetails")
	var first := _sprite(source, "First", TEXTURE_A, Vector2(300.0, 200.0))
	var second := _sprite(source, "Second", TEXTURE_B, Vector2(340.0, 260.0))
	var pattern: Dictionary = Patterns.capture([first, second], "Cluster")["pattern"]

	# The destination layer is offset, so a pattern that stored local coordinates would land
	# in the wrong place here. This is the case world-space offsets exist to survive.
	var destination := _layer(&"GroundDetails", Vector2(1000.0, 500.0))
	var result := Patterns.stamp(
		pattern,
		Vector2(700.0, 400.0),
		_layer_resolver({&"GroundDetails": destination}),
		_name_resolver()
	)
	assert_bool(result["allowed"]).override_failure_message(
		"%s" % result.get("message", "")
	).is_true()
	var additions: Array = result["additions"]
	assert_int(additions.size()).is_equal(2)
	# world 700,400 -> local (700-1000, 400-500)
	assert_array(additions[0]["position"]).is_equal([-300.0, -100.0])
	assert_array(additions[1]["position"]).is_equal([-260.0, -40.0])
	assert_str(str(additions[0]["name"])).is_not_empty()
	assert_str(str(additions[0]["name"])).is_not_equal(str(additions[1]["name"]))


func test_stamp_snaps_the_anchor_when_a_step_is_given() -> void:
	var source := _layer(&"GroundDetails")
	var prop := _sprite(source, "Prop", TEXTURE_A, Vector2.ZERO)
	var pattern: Dictionary = Patterns.capture([prop], "One")["pattern"]
	var destination := _layer(&"GroundDetails")

	var result := Patterns.stamp(
		pattern,
		Vector2(103.0, 197.0),
		_layer_resolver({&"GroundDetails": destination}),
		_name_resolver(),
		8.0
	)
	# Only the anchor snaps; the pattern's internal spacing is preserved exactly.
	assert_array(result["additions"][0]["position"]).is_equal([104.0, 200.0])


func test_stamp_reports_layers_this_scene_does_not_have() -> void:
	var ground := _layer(&"GroundDetails")
	var solid := _layer(&"SolidProps")
	var a := _sprite(ground, "A", TEXTURE_A, Vector2.ZERO)
	var body := StaticBody2D.new()
	body.name = "B"
	solid.add_child(body)
	var body_sprite := Sprite2D.new()
	body_sprite.name = "Sprite2D"
	body_sprite.texture = load(TEXTURE_B) as Texture2D
	body.add_child(body_sprite)
	var collision := CollisionShape2D.new()
	collision.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(64.0, 24.0)
	collision.shape = rectangle
	body.add_child(collision)
	body.global_position = Vector2(50.0, 0.0)

	var pattern: Dictionary = Patterns.capture([a, body], "Two Layers")["pattern"]
	assert_int((pattern["nodes"] as Array).size()).is_equal(2)

	# An interior with no SolidProps layer still gets the ground half, and is told what it lost.
	var destination := _layer(&"GroundDetails")
	var partial := Patterns.stamp(
		pattern, Vector2.ZERO, _layer_resolver({&"GroundDetails": destination}), _name_resolver()
	)
	assert_bool(partial["allowed"]).is_true()
	assert_int((partial["additions"] as Array).size()).is_equal(1)
	assert_array(partial["skipped_layers"]).contains(["SolidProps"])

	# No layers at all is a refusal, not an empty success.
	var refused := Patterns.stamp(
		pattern, Vector2.ZERO, _layer_resolver({}), _name_resolver()
	)
	assert_bool(refused["allowed"]).is_false()
	assert_str(str(refused["nearest_unblock"]["type"])).is_equal("present_layers")


## Godot's JSON parser returns EVERY number as a float, so a captured `z_index: 0` reads back
## as `0.0` and exact dictionary equality cannot survive one round trip. That is a property of
## JSON, not a defect, and `layout_overrides` documents have always behaved the same way. The
## two properties that actually matter are tested instead: the file is stable once loaded (so
## promoting a pattern into the repo does not churn its diff on every open), and a reloaded
## pattern stamps identically to the one that was captured.
func test_patterns_are_stable_across_reload_and_reject_a_foreign_schema() -> void:
	var ground := _layer(&"GroundDetails")
	var prop := _sprite(ground, "Prop", TEXTURE_A, Vector2(10.0, 20.0))
	var pattern: Dictionary = Patterns.capture([prop], "Round Trip")["pattern"]

	var restored: Dictionary = Patterns.from_json(Patterns.to_json(pattern))
	assert_dict(restored).is_not_empty()
	assert_str(str(restored["id"])).is_equal("round-trip")
	assert_int((restored["nodes"] as Array).size()).is_equal(1)

	var once: String = Patterns.to_json(restored)
	var twice: String = Patterns.to_json(Patterns.from_json(once))
	assert_str(twice).override_failure_message(
		"a saved pattern must reload and re-save byte-identically, or every open churns its diff"
	).is_equal(once)

	# Behavioural equivalence: the reloaded pattern places exactly what the captured one places.
	var destination := _layer(&"GroundDetails")
	var from_original := Patterns.stamp(
		pattern, Vector2(64.0, 32.0), _layer_resolver({&"GroundDetails": destination}),
		func(_l: Node2D, _t: String, _reserved: PackedStringArray) -> String: return "Fixed"
	)
	var from_restored := Patterns.stamp(
		restored, Vector2(64.0, 32.0), _layer_resolver({&"GroundDetails": destination}),
		func(_l: Node2D, _t: String, _reserved: PackedStringArray) -> String: return "Fixed"
	)
	# Compared field by field rather than dict to dict, for the same JSON int/float reason:
	# what "stamps identically" means is that the same texture lands on the same layer at the
	# same coordinates, not that a bool-and-int payload kept its Variant types through a parse.
	var original_additions: Array = from_original["additions"]
	var restored_additions: Array = from_restored["additions"]
	assert_int(restored_additions.size()).is_equal(original_additions.size())
	for index in original_additions.size():
		var expected: Dictionary = original_additions[index]
		var actual: Dictionary = restored_additions[index]
		for key: String in ["layer", "texture", "name"]:
			assert_str(str(actual[key])).override_failure_message(
				"addition %d differs on %s" % [index, key]
			).is_equal(str(expected[key]))
		assert_array(actual["position"]).override_failure_message(
			"addition %d landed somewhere else after a reload" % index
		).is_equal(expected["position"])

	var foreign: Dictionary = pattern.duplicate(true)
	foreign["schema"] = Patterns.SCHEMA_VERSION + 1
	assert_dict(Patterns.from_json(JSON.stringify(foreign))).is_empty()
	assert_dict(Patterns.from_json("not json")).is_empty()


func test_saved_patterns_reload_from_disk_and_list_in_a_stable_order() -> void:
	var directory := "user://layout_patterns_test_%d" % Time.get_ticks_usec()
	var ground := _layer(&"GroundDetails")
	var prop := _sprite(ground, "Prop", TEXTURE_A, Vector2.ZERO)
	for name: String in ["Zeta Row", "Alpha Row"]:
		var pattern: Dictionary = Patterns.capture([prop], name)["pattern"]
		var path := directory.path_join("%s.json" % str(pattern["id"]))
		assert_int(Patterns.save_file(path, pattern)).is_equal(OK)

	var listed: Array[Dictionary] = Patterns.list_patterns(directory)
	assert_int(listed.size()).is_equal(2)
	# Sorted by id, so the library panel does not reshuffle between sessions.
	assert_str(str(listed[0]["id"])).is_equal("alpha-row")
	assert_str(str(listed[1]["id"])).is_equal("zeta-row")

	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(directory.path_join("alpha-row.json"))
	)
	DirAccess.remove_absolute(
		ProjectSettings.globalize_path(directory.path_join("zeta-row.json"))
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(directory))


func test_fuzzy_score_matches_subsequences_and_ranks_tight_matches_first() -> void:
	# Every query character must appear in order.
	assert_int(Patterns.fuzzy_score("mkt", "market-stall")).is_greater_equal(0)
	assert_int(Patterns.fuzzy_score("xyz", "market-stall")).is_equal(-1)
	# An empty query matches everything equally, so the palette shows its full list.
	assert_int(Patterns.fuzzy_score("", "anything")).is_equal(0)
	# Lower is better: a tight, early match outranks a scattered one.
	var tight := Patterns.fuzzy_score("mark", "market-stall")
	var scattered := Patterns.fuzzy_score("mark", "mossy-arch-rockface")
	assert_int(tight).is_less(scattered)
	# Case-insensitive both ways.
	assert_int(Patterns.fuzzy_score("MARK", "market-stall")).is_equal(tight)


func test_repeated_textures_in_one_stamp_get_distinct_names() -> void:
	# Three of the same crate is the ordinary case for a pattern. None of them are parented
	# when the names are chosen, so a resolver that only looks at the tree would return the
	# same name three times and the editor would silently place one prop instead of three.
	var source := _layer(&"GroundDetails")
	var pattern: Dictionary = Patterns.capture(
		[
			_sprite(source, "CrateA", TEXTURE_A, Vector2.ZERO),
			_sprite(source, "CrateB", TEXTURE_A, Vector2(64.0, 0.0)),
			_sprite(source, "CrateC", TEXTURE_A, Vector2(128.0, 0.0)),
		],
		"Crates"
	)["pattern"]

	var destination := _layer(&"GroundDetails")
	var result := Patterns.stamp(
		pattern,
		Vector2(400.0, 400.0),
		_layer_resolver({&"GroundDetails": destination}),
		_name_resolver()
	)
	assert_bool(result["allowed"]).is_true()
	var names := {}
	for addition: Dictionary in result["additions"] as Array:
		names[str(addition["name"])] = true
	assert_int(names.size()).override_failure_message(
		"every prop in a stamp needs its own name, or the scene silently loses props"
	).is_equal(3)
