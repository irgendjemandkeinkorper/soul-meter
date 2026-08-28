extends GdUnitTestSuite

const Generator := preload("res://tools/generate_gloot.gd")
const NpcRosterScript := preload("res://globals/npc_roster.gd")
const PortraitScript := preload("res://ui/dialogue/portrait.gd")
const ROSTER_PATH := "res://data/generated/dom_npc_roster.json"
const PLACEMENTS_PATH := "res://data/generated/dom_npc_placements.json"
const DIALOGUE_PATH := "res://dialogue/dom_townsfolk.dialogue"
const INVOLVEMENT_TYPES := [
	"giver", "target", "information", "gate", "state_change", "reputation_reaction"
]


func test_generated_dom_roster_has_exactly_sixty_complete_unique_people() -> void:
	var data := _json(ROSTER_PATH)
	var npcs: Dictionary = data["npcs"]
	assert_str(data["town_id"]).is_equal("dom")
	assert_int(npcs.size()).is_equal(60)
	var names := {}
	for npc_id: String in npcs:
		var row: Dictionary = npcs[npc_id]
		assert_str(row["id"]).is_equal(npc_id)
		assert_bool(StableIds.is_valid_record(StableIds.ACTOR, row["stable_id"])).is_true()
		for field: String in ["display_name", "role", "home", "district", "faction_id"]:
			assert_bool(not str(row.get(field, "")).is_empty()).is_true()
		assert_bool(names.has(row["display_name"])).is_false()
		names[row["display_name"]] = true


func test_at_least_fifty_of_sixty_townsfolk_carry_a_real_quest_hook() -> void:
	var npcs: Dictionary = _json(ROSTER_PATH)["npcs"]
	var involved_count := 0
	for npc_id: String in npcs:
		var row: Dictionary = npcs[npc_id]
		var hooks: Array = row["quest_hooks"]
		if hooks.is_empty():
			continue
		involved_count += 1
		for hook: Dictionary in hooks:
			assert_array(INVOLVEMENT_TYPES).contains(str(hook["involvement"]))
			assert_bool(StableIds.is_valid_record(StableIds.QUEST, hook["stable_id"])).is_true()
			assert_bool(not str(hook["summary"]).is_empty()).is_true()
			match str(hook["involvement"]):
				"gate", "state_change":
					assert_str(hook["state_source"]).is_equal("GameState")
					assert_bool(
						StableIds.is_valid_record(
							StableIds.WORLD_FACT, hook["world_fact_stable_id"]
						)
					).is_true()
				"reputation_reaction":
					assert_str(hook["state_source"]).is_equal("Reputation.band")
					assert_str(hook["faction_id"]).is_equal(row["faction_id"])
				_:
					assert_str(hook["state_source"]).is_equal("QuestRegistry")
	assert_int(involved_count).is_greater_equal(50)
	assert_int(npcs.size() - involved_count).is_less_equal(10)


func test_every_portrait_descriptor_is_stable_distinct_and_resolvable() -> void:
	var signatures := {}
	for row: Dictionary in NpcRosterScript.all():
		var portrait: Dictionary = NpcRosterScript.portrait_descriptor(row["id"])
		assert_str(portrait["id"]).is_equal(row["id"])
		assert_array(["asset", "monogram"]).contains(str(portrait["kind"]))
		if portrait["kind"] == "asset":
			var asset_path := str(portrait["asset_path"])
			assert_bool(NpcRosterScript.is_safe_portrait_path(asset_path)).is_true()
			assert_bool(FileAccess.file_exists(asset_path)).is_true()
		assert_bool(not str(portrait["monogram"]).is_empty()).is_true()
		assert_int(str(portrait["mark"]).length()).is_equal(4)
		assert_int(int(portrait["palette_index"])).is_between(0, 9)
		var signature := "%s:%s:%s" % [
			portrait["monogram"], portrait["mark"], portrait["palette_index"]
		]
		assert_bool(signatures.has(signature)).is_false()
		signatures[signature] = true
	assert_int(signatures.size()).is_equal(60)


func test_portrait_component_uses_generated_unit_art_without_node_overrides() -> void:
	var row := NpcRosterScript.get_npc("sella-varn")
	var portrait: SMPortrait = auto_free(PortraitScript.new())
	portrait.theme = ThemeBuilder.build()
	portrait.character_name = row["display_name"]
	portrait.portrait_id = row["portrait"]["id"]
	add_child(portrait)
	var frame := portrait.get("_frame") as PanelContainer
	var monogram := portrait.get("_monogram") as Label
	var placeholder := portrait.get("_placeholder") as VBoxContainer
	var image := portrait.get("_image") as TextureRect
	assert_str(frame.theme_type_variation).starts_with("NpcPortraitFrame")
	assert_str(monogram.theme_type_variation).starts_with("NpcPortraitMonogram")
	assert_bool(frame.has_theme_stylebox_override("panel")).is_false()
	assert_str(monogram.text).is_equal(row["portrait"]["monogram"])
	assert_bool(image.visible).is_true()
	assert_object(image.texture).is_not_null()
	assert_bool(placeholder.visible).is_false()

	var missing: SMPortrait = auto_free(PortraitScript.new())
	missing.theme = ThemeBuilder.build()
	missing.character_name = "Missing Art"
	missing.portrait_id = "no-such-npc"
	add_child(missing)
	await get_tree().process_frame
	assert_bool((missing.get("_image") as TextureRect).visible).is_false()
	assert_bool((missing.get("_placeholder") as VBoxContainer).visible).is_true()


func test_marshal_dialogue_portrait_uses_authored_source_art() -> void:
	var expected_path := (
		"res://assets/generated/portraits/marshal_coiljaw_portrait_neutral.png"
	)
	var descriptor := NpcRosterScript.portrait_descriptor("branek-coiljaw")
	assert_str(str(descriptor.get("asset_path", ""))).is_equal(expected_path)
	assert_bool(FileAccess.file_exists(expected_path)).is_true()

	var texture := NpcRosterScript.load_portrait_texture(expected_path)
	assert_object(texture).is_not_null()
	assert_vector(texture.get_size()).is_equal(Vector2(512, 512))


func test_sella_dialogue_portrait_uses_authored_source_art() -> void:
	var expected_path := (
		"res://assets/generated/portraits/sella_varn_portrait_neutral.png"
	)
	var descriptor := NpcRosterScript.portrait_descriptor("sella-varn")
	assert_str(str(descriptor.get("asset_path", ""))).is_equal(expected_path)
	assert_bool(FileAccess.file_exists(expected_path)).is_true()

	var texture := NpcRosterScript.load_portrait_texture(expected_path)
	assert_object(texture).is_not_null()
	assert_vector(texture.get_size()).is_equal(Vector2(512, 512))


func test_hadrik_dialogue_portrait_uses_authored_source_art() -> void:
	var expected_path := (
		"res://assets/generated/portraits/hadrik_vale_portrait_neutral.png"
	)
	var descriptor := NpcRosterScript.portrait_descriptor("hadrik-vale")
	assert_str(str(descriptor.get("asset_path", ""))).is_equal(expected_path)
	assert_bool(FileAccess.file_exists(expected_path)).is_true()

	var texture := NpcRosterScript.load_portrait_texture(expected_path)
	assert_object(texture).is_not_null()
	assert_vector(texture.get_size()).is_equal(Vector2(512, 512))


func test_toma_dialogue_portrait_uses_authored_source_art() -> void:
	var expected_path := (
		"res://assets/generated/portraits/toma_reedhand_portrait_neutral.png"
	)
	var descriptor := NpcRosterScript.portrait_descriptor("toma-reedhand")
	assert_str(str(descriptor.get("asset_path", ""))).is_equal(expected_path)
	assert_bool(FileAccess.file_exists(expected_path)).is_true()

	var texture := NpcRosterScript.load_portrait_texture(expected_path)
	assert_object(texture).is_not_null()
	assert_vector(texture.get_size()).is_equal(Vector2(512, 512))


func test_real_portrait_seam_matches_party_member_source_image_allowlist() -> void:
	for extension: String in NpcRosterScript.SAFE_PORTRAIT_EXTENSIONS:
		assert_bool(
			NpcRosterScript.is_safe_portrait_path("res://assets/portraits/person.%s" % extension)
		).is_true()
	assert_bool(NpcRosterScript.is_safe_portrait_path("res://unsafe/person.tres")).is_false()
	assert_bool(NpcRosterScript.is_safe_portrait_path("res://portraits/../unsafe.png")).is_false()
	assert_bool(NpcRosterScript.is_safe_portrait_path("user://person.png")).is_false()


func test_every_npc_dialogue_title_parses_and_contains_three_real_lines() -> void:
	var resource: DialogueResource = load(DIALOGUE_PATH)
	assert_object(resource).is_not_null()
	var source := FileAccess.get_file_as_string(DIALOGUE_PATH)
	for row: Dictionary in NpcRosterScript.all():
		var dialogue: Dictionary = row["dialogue"]
		assert_bool(
			StableIds.is_valid_record(StableIds.DIALOGUE_NODE, dialogue["stable_id"])
		).is_true()
		var line: DialogueLine = await DialogueManager.get_next_dialogue_line(
			resource, dialogue["title"]
		)
		assert_object(line).is_not_null()
		assert_str(line.character).is_equal(row["display_name"])
		var block := _dialogue_block(source, dialogue["title"])
		assert_int(block.count("%s: " % row["display_name"])).is_equal(3)
		assert_str(block).not_contains("...")
		assert_str(block).contains(dialogue["greeting"])
		assert_str(block).contains(dialogue["context"])
		assert_str(block).contains(dialogue["farewell"])
		for condition: String in _conditions(block):
			assert_str(condition).ends_with(" /]")


func test_every_placement_resolves_to_a_named_scene_anchor() -> void:
	var roster: Dictionary = _json(ROSTER_PATH)["npcs"]
	var placements: Dictionary = _json(PLACEMENTS_PATH)["placements"]
	assert_int(placements.size()).is_equal(60)
	var checked_anchors := {}
	for npc_id: String in roster:
		var placement: Dictionary = placements[npc_id]
		assert_bool(placement == roster[npc_id]["placement"]).is_true()
		assert_int((placement["offset"] as Array).size()).is_equal(2)
		var anchor_key := "%s:%s" % [placement["scene"], placement["anchor"]]
		if checked_anchors.has(anchor_key):
			continue
		var packed := load(placement["scene"]) as PackedScene
		assert_object(packed).is_not_null()
		var scene: Node = auto_free(packed.instantiate())
		assert_object(scene.find_child(placement["anchor"], true, false)).is_not_null()
		checked_anchors[anchor_key] = true


func test_generator_reports_sixty_npcs_and_no_committed_drift() -> void:
	if not Pandora.is_loaded():
		Pandora.load_data()
	var result: Dictionary = Generator.generate(true)
	assert_int(result["npc_count"]).is_equal(60)
	assert_bool(result["drift"]).is_false()


func _json(path: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	assert_bool(parsed is Dictionary).is_true()
	return parsed


func _dialogue_block(source: String, title: String) -> String:
	var marker := "~ %s\n" % title
	var start := source.find(marker)
	assert_int(start).is_greater_equal(0)
	var next := source.find("\n~ ", start + marker.length())
	return source.substr(start) if next < 0 else source.substr(start, next - start)


func _conditions(block: String) -> Array[String]:
	var conditions: Array[String] = []
	var regex := RegEx.new()
	regex.compile("\\[if [^\\]]+\\]")
	for result: RegExMatch in regex.search_all(block):
		conditions.append(result.get_string())
	return conditions
