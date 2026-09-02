extends GdUnitTestSuite

const ResolutionScript := preload("res://globals/combat/resolution.gd")


func test_aftertones_tick_and_anchoring() -> void:
	var actor := BattleActor.new()
	actor.aftertones = [{"element": &"suul", "remaining_rounds": 2, "anchored": false}]
	actor.tick_aftertones()
	assert_int(actor.aftertones[0]["remaining_rounds"]).is_equal(1)
	actor.aftertones[0]["anchored"] = true
	actor.tick_aftertones()
	assert_int(actor.aftertones[0]["remaining_rounds"]).is_equal(1)


func test_rule_bends_anchor_consume_clear_and_hold_notes() -> void:
	var terra := _resolve(&"terra", [{"element": &"suul", "remaining_rounds": 2}])
	assert_bool(_has_aftertone(terra, true)).is_true()
	var scor := _resolve(&"scor", [{"element": &"suul", "remaining_rounds": 2}])
	assert_int(scor["damage"]).is_equal(2)
	assert_bool(_has_aftertone(scor, false)).is_false()
	var nul := _resolve(&"nul", [{"element": &"suul", "remaining_rounds": 2}], 3)
	assert_bool(_has_write(nul, "tempo")).is_true()
	assert_bool(_aftertone_write_is_empty(nul)).is_true()
	var khor := _resolve(&"khor", [{"element": &"suul", "remaining_rounds": 2}])
	assert_bool(_has_aftertone(khor, true)).is_true()


func test_every_pandora_triad_emits_its_declarative_effect() -> void:
	for triad: TriadDefinition in ElementsData.all_triads():
		var result: Dictionary = ResolutionScript.resolve({
			"unit": {"id": "caster", "harmony": 10},
			"ability": {"id": "triad", "element_id": triad.center_element, "elements": triad.elements, "magnitude": "song", "power": 1},
			"target": {"id": "target", "hp": 10, "element_id": "suul"},
		})
		assert_bool(result["allowed"]).is_true()
		assert_str(str(result["composition"]["triad_effect_id"])).is_equal(str(triad.unique_effect_id))
		assert_bool(_has_write(result, "triad_effect")).is_true()


func _resolve(element: StringName, aftertones: Array, tempo: int = 0) -> Dictionary:
	return ResolutionScript.resolve({
		"unit": {"id": "caster", "harmony": 10, "aftertones": aftertones, "tempo": tempo},
		"ability": {"id": "bend", "element_id": element, "magnitude": "note", "power": 1},
		"target": {"id": "target", "hp": 10, "element_id": "suul"},
	})


func _has_write(result: Dictionary, kind: String) -> bool:
	for write: Dictionary in result.get("writes", []):
		if str(write.get("kind", "")) == kind:
			return true
	return false


func _has_aftertone(result: Dictionary, anchored: bool) -> bool:
	for write: Dictionary in result.get("writes", []):
		if write.get("kind", "") == "aftertones":
			for aftertone: Dictionary in write.get("after", []):
				if bool(aftertone.get("anchored", false)) == anchored:
					return true
	return false


func _aftertone_write_is_empty(result: Dictionary) -> bool:
	for write: Dictionary in result.get("writes", []):
		if write.get("kind", "") == "aftertones":
			return (write.get("after", []) as Array).is_empty()
	return false
