extends GdUnitTestSuite
## All authored content below is in-memory fixture text, never shipped content.

const Audit := preload("res://tools/audit_field_coverage.gd")
const Schema := preload("res://globals/stats/dramgid_schema.gd")
const DOM := "res://world/fixture_dom.tscn"
const WILD := "res://world/test_room.tscn"


func test_dialogue_parser_counts_calls_not_prose_tags_comments_or_string_arguments() -> void:
	var source := """
# if check("bellow", 40)
Speaker: check("bellow", 40) is only prose.
- "check('bellow', 40) is quoted." [#tag=Bellow]
- "A real check." [#tag=Sounding] [if check("sounding", 40) /]
if check('slip', 20) and check("sway", 40)
elif SkillCheck.check("bellow", 30)
do GameState.set_flag("check('bellow', 40)", true)
do check("recall", 30) # check("bellow", 40)
if other.check("bellow", 40)
"""
	var checks: Array[Dictionary] = Audit.dialogue_checks(source)
	var skills: Array[String] = []
	for check: Dictionary in checks:
		skills.append(check["skill"])
	assert_array(skills).contains_exactly(["sounding", "slip", "sway", "bellow", "recall"])
	assert_int(checks[0]["line"]).is_equal(5)


func test_bellow_and_distinct_skills_use_only_the_22_field_skills() -> void:
	var fixture := _fixture()
	fixture["dialogues"] = {"res://dialogue/fixture.dialogue":
		"if check(\"bellow\", 10)\nif check(\"bellow\", 10)\nif check(\"keen\", 10)\nif check(\"invented\", 10)"}
	var result: Dictionary = Audit.audit_sources(fixture)
	assert_bool(result["bellow"]).is_true()
	assert_int(result["skills"]["bellow"]).is_equal(2)
	assert_int(result["distinct_skills"]).is_equal(1)
	assert_int((result["skills"] as Dictionary).size()).is_equal(22)
	assert_int((result["warnings"] as PackedStringArray).size()).is_equal(2)
	assert_bool(Audit.audit_sources(_fixture())["bellow"]).is_false()


func test_locks_pockets_containers_and_theft_are_structural_and_separate() -> void:
	var fixture := _fixture()
	fixture["scenes"][DOM] = _scene([
		_node("Force", "Chest", {"container_id": "force", "lock_skill": "strain", "owned_by_faction": "owner"}),
		_node("Latch", "SMInteractable", {"lock_id": "latch", "lock_skill": "slip"}),
		_node("OnlyAFlag", "SMInteractable", {"required_flag": "locked", "display_name": "LOCKED CACHE"}),
		_node("NoDurableLock", "SMInteractable", {"lock_skill": "bellow"}),
		_node("Pocket", "NPC", {"pocket_id": "pocket"}),
		_node("NotAPocket", "NPC", {"pocket_skill": "bellow"}),
		_node("Owned", "Pickup", {"item_id": "fixture/item", "owned_by_faction": "owner"}),
	])
	var result: Dictionary = Audit.audit_sources(fixture)
	assert_int(result["verbs"]["lockpick"]).is_equal(2)
	assert_int(result["verbs"]["pickpocket/steal"]).is_equal(3)
	assert_int(result["verbs"]["loot container"]).is_equal(1)
	assert_int(_row(result, "Hub dom: locks")["count"]).is_equal(2)
	assert_int(_row(result, "Hub dom: pockets")["count"]).is_equal(1)
	assert_int(result["skills"]["strain"]).is_equal(1)
	assert_int(result["skills"]["slip"]).is_equal(2)
	assert_bool(result["bellow"]).is_false()


func test_cache_means_a_chest_in_a_wild_location_regardless_of_its_name() -> void:
	var fixture := _fixture()
	fixture["scenes"][DOM] = _scene([_node("Cache", "Chest", {"container_id": "town"})])
	fixture["scenes"][WILD] = _scene([
		_node("OrdinaryBox", "Chest", {"container_id": "wild-one"}),
		_node("CacheSign", "SMInteractable", {"display_name": "cache"}),
	])
	var result: Dictionary = Audit.audit_sources(fixture)
	assert_int(result["verbs"]["loot container"]).is_equal(2)
	assert_int(result["verbs"]["cache"]).is_equal(1)
	assert_int(_row(result, "Wild wilds: caches")["count"]).is_equal(1)


func test_table_checks_are_once_per_distinct_skill_per_placed_container() -> void:
	var fixture := _fixture()
	fixture["tables"] = {
		"used": {"rows": [{"skill": "sounding"}, {"skill": "sounding"}, {"skill": "recall"}, {"weight": 2}]},
		"unused": {"rows": [{"skill": "bellow"}]},
	}
	fixture["scenes"][DOM] = _scene([
		_node("One", "Chest", {"container_id": "one", "loot_table_id": &"used"}),
		_node("Two", "Chest", {"container_id": "two", "loot_table_id": &"used"}),
		_node("Override", "Chest", {"container_id": "override", "loot_table_id": &"used", "loot": [{"item_id": "fixed"}]}),
		_node("Unknown", "Chest", {"container_id": "unknown", "loot_table_id": &"missing"}),
	])
	var result: Dictionary = Audit.audit_sources(fixture)
	assert_int(result["skills"]["sounding"]).is_equal(2)
	assert_int(result["skills"]["recall"]).is_equal(2)
	assert_bool(result["bellow"]).is_false()
	assert_int(_row(result, "Hub dom: loot-table containers")["count"]).is_equal(2)
	assert_int(_row(result, "Loot tables")["count"]).is_equal(2)
	assert_int((result["warnings"] as PackedStringArray).size()).is_equal(1)


func test_inherited_nested_scene_instances_resolve_overrides_and_script_defaults() -> void:
	var fixture := _fixture()
	var base := "res://actors/fixture/box.tscn"
	var derived := "res://actors/fixture/derived.tscn"
	fixture["scenes"][base] = """
[gd_scene format=3]
[ext_resource type="Script" path="res://actors/fixture/Chest.gd" id="script"]
[node name="Box" type="Area2D"]
script = ExtResource("script")
container_id = "template"
lock_skill = "strain"
[node name="Nested" type="Area2D" parent="."]
script = ExtResource("script")
container_id = "nested"
"""
	fixture["scenes"][derived] = """
[gd_scene format=3]
[ext_resource type="PackedScene" path="res://actors/fixture/box.tscn" id="base"]
[node name="Derived" instance=ExtResource("base")]
lock_skill = "slip"
"""
	fixture["scenes"][DOM] = """
[gd_scene format=3]
[ext_resource type="PackedScene" path="res://actors/fixture/derived.tscn" id="box"]
[node name="World" type="Node2D"]
[node name="One" parent="." instance=ExtResource("box")]
container_id = "one"
[node name="Nested" parent="One"]
lock_skill = "bellow"
[node name="Two" parent="." instance=ExtResource("box")]
container_id = "two"
lock_skill = ""
"""
	var result: Dictionary = Audit.audit_sources(fixture)
	assert_int(result["verbs"]["loot container"]).is_equal(4)
	assert_int(result["verbs"]["lockpick"]).is_equal(2)
	assert_int(result["skills"]["strain"]).is_equal(0)
	assert_int(result["skills"]["slip"]).is_equal(1)
	assert_int(result["skills"]["bellow"]).is_equal(1)


func test_hub_rollup_follows_nested_interior_registry_links() -> void:
	var fixture := _fixture()
	var first := "res://world/interiors/fixture_first.tscn"
	var second := "res://world/interiors/fixture_second.tscn"
	fixture["locations"].append(_location("first", first, false, DOM))
	fixture["locations"].append(_location("second", second, false, first))
	fixture["scenes"][first] = _scene([_node("Pocket", "NPC", {"pocket_id": "first"})])
	fixture["scenes"][second] = _scene([_node("Lock", "Chest", {"container_id": "second", "lock_skill": "strain", "loot_table_id": &"table"})])
	fixture["tables"] = {"table": {"rows": []}}
	var result: Dictionary = Audit.audit_sources(fixture)
	assert_int(_row(result, "Hub dom: locks")["count"]).is_equal(1)
	assert_int(_row(result, "Hub dom: pockets")["count"]).is_equal(1)
	assert_int(_row(result, "Hub dom: loot-table containers")["count"]).is_equal(1)
	assert_int(_row(result, "Hub ashlaren: pockets")["count"]).is_equal(0)
	assert_int(result["verbs"]["cache"]).is_equal(0)


func test_no_scene_rows_cover_all_five_hubs_and_unbuilt_mapped_wilds() -> void:
	var fixture := _fixture()
	fixture["locations"].append(_location("unbuilt", "res://world/absent.tscn", true))
	fixture["locations"].append(_location("no_path", "", true))
	fixture["locations"].append({"id": "lore_city", "scene_path": "", "world_map": null})
	var result: Dictionary = Audit.audit_sources(fixture)
	for id: String in Audit.HUB_IDS:
		var row := _row(result, "Hub %s: locks" % id)
		assert_bool(row["has_scene"]).is_equal(id == "dom")
		assert_bool(row["pass"]).is_false()
	for id: String in ["unbuilt", "no_path"]:
		var row := _row(result, "Wild %s: caches" % id)
		assert_bool(row["has_scene"]).is_false()
		assert_int(row["gap"]).is_equal(2)
	assert_str(Audit.report(result)).contains("Hub hollowmere: locks | 0 (no scene) | >= 4 | FAIL")
	assert_bool(_row(result, "Wild lore_city: caches").is_empty()).is_true()


func test_registry_wild_view_is_retained_for_brief_hubs() -> void:
	var fixture := _fixture()
	fixture["locations"].append(_location("long_verge", "res://world/verge.tscn", true))
	fixture["scenes"]["res://world/verge.tscn"] = _scene([_node("Box", "Chest", {"container_id": "box", "lock_skill": "strain"})])
	var result: Dictionary = Audit.audit_sources(fixture)
	assert_int(_row(result, "Wild long_verge: caches")["count"]).is_equal(1)
	assert_int(_row(result, "Hub long_verge: locks")["count"]).is_equal(1)
	assert_str(" ".join(result["warnings"])).contains("brief hub long_verge")


func test_runtime_rosters_and_vendor_sites_require_scene_spawners_and_anchors() -> void:
	var fixture := _fixture()
	var interior := "res://world/interiors/fixture_shop.tscn"
	fixture["locations"].append(_location("shop", interior, false, DOM))
	fixture["scenes"][DOM] = _scene([_node("Spawn", "TownNpcSpawner"), _node("Anchor", "")])
	fixture["scenes"][interior] = _scene([_node("VendorSpot", ""), _node("Anchor", "")], "BuildingInterior", {"exit_transition_id": &"fixture_shop_exit"})
	fixture["rosters"] = {
		"outdoor": {"dialogue": {"path": "res://dialogue/fixture.dialogue"}, "pocket_id": "ignored"},
		"indoor": {"dialogue": {"path": "res://dialogue/fixture.dialogue"}},
		"no_anchor": {"dialogue": {"path": "res://dialogue/fixture.dialogue"}},
		"unplaced": {"dialogue": {"path": "res://dialogue/fixture.dialogue"}},
	}
	fixture["placements"] = {
		"outdoor": {"scene": DOM, "anchor": "Anchor"},
		"indoor": {"scene": interior, "anchor": "Anchor"},
		"no_anchor": {"scene": DOM, "anchor": "Missing"},
	}
	fixture["vendors"] = {"placed": {}, "unplaced": {}}
	fixture["vendor_sites"] = {interior: ["placed"], "res://world/absent.tscn": ["unplaced"]}
	var result: Dictionary = Audit.audit_sources(fixture)
	assert_int(result["verbs"]["talk"]).is_equal(2)
	assert_int(result["verbs"]["barter"]).is_equal(1)
	assert_int(result["verbs"]["pickpocket/steal"]).is_equal(0)
	assert_int((result["warnings"] as PackedStringArray).size()).is_equal(1)


func test_vendor_site_constant_resolves_ids_without_executing_gameplay() -> void:
	var ids: Dictionary = Audit._string_constants('const ONE := "one"\nconst TWO := "two"')
	var sites: Dictionary = Audit._dictionary_constant("""
# A comment must not become a vendor row.
const VENDORS_BY_INTERIOR := {
    "res://world/interiors/shop.tscn": [VendorIdsData.ONE, VendorIdsData.TWO],
}
""", "VENDORS_BY_INTERIOR", ids)
	assert_array(sites["res://world/interiors/shop.tscn"]).contains_exactly(["one", "two"])


func test_other_field_verbs_count_authored_instances_and_barter_is_not_a_skill_roll() -> void:
	var fixture := _fixture()
	fixture["vendors"] = {"vendor": {}}
	fixture["scenes"][DOM] = _scene([
		_node("Reader", "NPC", {"dialogue_path": "res://dialogue/fixture.dialogue"}),
		_node("Vendor", "NPC", {"vendor_id": "vendor"}),
		_node("Shop", "SMInteractable", {"shop_type": "items"}),
		_node("Sign", "SMInteractable"),
		_node("Save", "SMInteractable", {"save_point": true}),
		_node("Toggle", "InteractiveSwitch", {"interaction_flag": "toggle"}),
		_node("Pickup", "Pickup", {"item_id": "fixture/item"}),
		_node("Door", "BuildingDoor"), _node("Exit", "TravelExit"), _node("Tavern", "TavernDoor"),
		_node("Damage", "DestructibleStructure", {"interaction_damage": 10}),
	], "DomTavern")
	var result: Dictionary = Audit.audit_sources(fixture)
	for verb: String in ["talk", "inspect/interact", "save", "switch", "pickup", "party selection", "damage structure"]:
		assert_int(result["verbs"][verb]).override_failure_message(verb).is_equal(1)
	assert_int(result["verbs"]["barter"]).is_equal(2)
	assert_int(result["verbs"]["travel"]).is_equal(4)
	assert_int(result["skills"]["sway"]).is_equal(0)


func test_unregistered_templates_and_test_sources_do_not_contribute() -> void:
	var fixture := _fixture()
	var chest_scene := _scene([_node("Chest", "Chest", {"container_id": "box"})])
	fixture["scenes"]["res://world/unplaced_template.tscn"] = chest_scene
	fixture["scenes"]["res://test/fixture.tscn"] = chest_scene
	fixture["scenes"]["res://world/fixtures/yard.tscn"] = chest_scene
	fixture["locations"].append(_location("test", "res://test/fixture.tscn", false))
	fixture["locations"].append(_location("yard", "res://world/fixtures/yard.tscn", false))
	fixture["dialogues"] = {"res://test/fixture.dialogue": 'if check("bellow", 40)'}
	fixture["scenes"][WILD] = chest_scene
	var result: Dictionary = Audit.audit_sources(fixture)
	assert_int(result["verbs"]["loot container"]).is_equal(1)
	assert_int(result["verbs"]["cache"]).is_equal(1)
	assert_int(result["scene_count"]).is_equal(2)
	assert_bool(result["bellow"]).is_false()


func test_density_rows_fail_below_and_pass_at_their_thresholds() -> void:
	for offset: int in [-1, 0, 1]:
		var fixture := _fixture()
		var nodes: Array[Dictionary] = []
		for i: int in 4 + offset:
			nodes.append(_node("Lock%d" % i, "Chest", {"container_id": "lock%d" % i, "lock_skill": "strain", "loot_table_id": &"table0"}))
		for i: int in 3 + offset:
			nodes.append(_node("Pocket%d" % i, "NPC", {"pocket_id": "pocket%d" % i}))
		for i: int in 5 + offset:
			nodes.append(_node("Toggle%d" % i, "InteractiveSwitch", {"interaction_flag": "toggle%d" % i}))
		fixture["scenes"][DOM] = _scene(nodes)
		var caches: Array[Dictionary] = []
		for i: int in 2 + offset:
			caches.append(_node("Box%d" % i, "Chest", {"container_id": "cache%d" % i}))
		fixture["scenes"][WILD] = _scene(caches)
		for i: int in 8 + offset:
			fixture["tables"]["table%d" % i] = {"rows": []}
		for i: int in 40 + offset:
			fixture["items"]["item%d" % i] = {}
		var result: Dictionary = Audit.audit_sources(fixture)
		for label: String in ["Hub dom: locks", "Hub dom: pockets", "Hub dom: loot-table containers", "Wild wilds: caches", "Verb: switch", "Loot tables", "Items"]:
			var row := _row(result, label)
			assert_bool(row["pass"]).override_failure_message("%s offset %d" % [label, offset]).is_equal(offset >= 0)
			assert_int(row["gap"]).is_equal(1 if offset < 0 else 0)


func test_distinct_skill_and_superseded_thresholds_are_independent() -> void:
	for count: int in [14, 15, 16]:
		var fixture := _fixture()
		fixture["dialogues"] = {"res://dialogue/fixture.dialogue": _skill_dialogue(count, 1)}
		var result: Dictionary = Audit.audit_sources(fixture)
		assert_bool(_row(result, "Distinct field skills / 22")["pass"]).is_equal(count >= 15)
		assert_bool(result["superseded"]["pass"]).is_false()
	for count: int in [11, 12, 13]:
		for repeats: int in [2, 3]:
			var fixture := _fixture()
			fixture["dialogues"] = {"res://dialogue/fixture.dialogue": _skill_dialogue(count, repeats)}
			var result: Dictionary = Audit.audit_sources(fixture)
			assert_bool(result["superseded"]["pass"]).is_equal(count >= 12 and repeats == 3)
			assert_int(result["superseded_skills"]).is_equal(count if repeats == 3 else 0)
			assert_bool(_row(result, "Distinct field skills / 22")["pass"]).is_false()


func test_report_contains_each_measurement_and_labels_superseded_comparison() -> void:
	var fixture := _fixture()
	fixture["dialogues"] = {"res://dialogue/fixture.dialogue": 'if check("bellow", 40)'}
	var result: Dictionary = Audit.audit_sources(fixture)
	var text: String = Audit.report(result)
	assert_str(text).contains("PROVISIONAL")
	assert_str(text).contains("Bellow checks | 1 | >= 1 | PASS")
	assert_str(text).contains("SUPERSEDED comparison only: >= 12/22 skills, each checked >= 3 times")
	assert_str(text).contains("Judge the printed report, never the exit code.")
	for row: Dictionary in result["rows"]:
		assert_str(text).contains(row["label"])
	assert_str(Audit.report(Audit.audit_sources(fixture))).is_equal(text)


func _fixture() -> Dictionary:
	var scripts: Dictionary = {}
	for type: String in ["SMInteractable", "Chest", "NPC", "Pickup", "InteractiveSwitch", "DestructibleStructure", "BuildingDoor", "TravelExit", "TavernDoor", "DomTavern", "TownNpcSpawner", "BuildingInterior"]:
		var parent := "SMInteractable" if type in ["Chest", "Pickup", "InteractiveSwitch", "DestructibleStructure"] else "Node2D"
		scripts["res://actors/fixture/%s.gd" % type] = "class_name %s\nextends %s\n" % [type, parent]
	scripts["res://actors/fixture/SMInteractable.gd"] += '@export var lock_skill: String = ""\n@export var lock_id: String = ""\n'
	scripts["res://actors/fixture/NPC.gd"] += '@export var pocket_skill: String = "slip"\n'
	return {
		"scripts": scripts, "scenes": {DOM: _scene([]), WILD: _scene([])},
		"locations": [_location("dom", DOM, false), _location("wilds", WILD, true)],
		"dialogues": {}, "tables": {}, "items": {},
	}


func _location(id: String, path: String, wild: bool, parent: String = "") -> Dictionary:
	return {"id": id, "scene_path": path, "world_map": {} if wild else null,
		"fast_travel": {"base_cost_gp": 1} if Audit.HUB_IDS.has(id) and not wild else null,
		"transition": {"source_scene": parent} if not parent.is_empty() else null}


func _node(name: String, type: String, props: Dictionary = {}) -> Dictionary:
	return {"name": name, "type": type, "props": props}


func _scene(nodes: Array[Dictionary], root_type: String = "", root_props: Dictionary = {}) -> String:
	var lines := PackedStringArray(["[gd_scene format=3]"])
	var types: Dictionary = {}
	if not root_type.is_empty():
		types[root_type] = true
	for node: Dictionary in nodes:
		if not String(node["type"]).is_empty():
			types[node["type"]] = true
	for type: String in types:
		lines.append('[ext_resource type="Script" path="res://actors/fixture/%s.gd" id="%s"]' % [type, type])
	lines.append('[node name="World" type="Node2D"]')
	if not root_type.is_empty():
		lines.append('script = ExtResource("%s")' % root_type)
	for key: String in root_props:
		lines.append("%s = %s" % [key, var_to_str(root_props[key])])
	for node: Dictionary in nodes:
		lines.append('[node name="%s" type="Node2D" parent="."]' % node["name"])
		if not String(node["type"]).is_empty():
			lines.append('script = ExtResource("%s")' % node["type"])
		for key: String in node["props"]:
			lines.append("%s = %s" % [key, var_to_str(node["props"][key])])
	return "\n".join(lines)


func _row(result: Dictionary, label: String) -> Dictionary:
	for row: Dictionary in result["rows"]:
		if row["label"] == label:
			return row
	return {}


func _skill_dialogue(count: int, repeats: int) -> String:
	var lines: PackedStringArray = []
	for i: int in count:
		for _repeat: int in repeats:
			lines.append('if check("%s", 40)' % Schema.FIELD_SKILL_IDS[i])
	return "\n".join(lines)
