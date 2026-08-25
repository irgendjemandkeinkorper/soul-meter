extends GdUnitTestSuite
## Living-world texture criteria: FR-402 (≥3 band-gated reactions per hub),
## FR-308 (Zhavar tracked + telegraphed), FR-506 (thinning gradient).

const DOM_DIALOGUE_FILES := [
	"res://dialogue/sella_varn.dialogue",
	"res://dialogue/toma_reedhand.dialogue",
	"res://dialogue/hadrik_vale.dialogue",
	"res://dialogue/marshal_coiljaw.dialogue",
]

var _zhavar_before: Dictionary
var _flags_before: Dictionary


func before_test() -> void:
	_zhavar_before = SaveGame.zhavar.duplicate(true)
	_flags_before = GameState.flags.duplicate(true)
	SaveGame.zhavar = {}


func after_test() -> void:
	SaveGame.zhavar = _zhavar_before
	GameState.flags = _flags_before


# --- FR-402 ------------------------------------------------------------------


func test_dom_has_at_least_three_band_gated_reactions() -> void:
	var gated := 0
	for path: String in DOM_DIALOGUE_FILES:
		var file := FileAccess.open(path, FileAccess.READ)
		assert_object(file).is_not_null()
		var text := file.get_as_text()
		file.close()
		for line in text.split("\n"):
			if line.contains("[if") and line.contains("Reputation.band("):
				gated += 1
	assert_int(gated).is_greater_equal(3)


func test_band_names_used_in_dialogue_are_real_bands() -> void:
	var valid := ["hostile", "cold", "neutral", "warm", "allied"]
	var regex := RegEx.new()
	regex.compile("Reputation\\.band\\(\"[a-z-]+\"\\)\\s*[!=]=\\s*\"([a-z]+)\"")
	for path: String in DOM_DIALOGUE_FILES:
		var file := FileAccess.open(path, FileAccess.READ)
		var text := file.get_as_text()
		file.close()
		for m in regex.search_all(text):
			assert_bool(m.get_string(1) in valid).override_failure_message(
				"Unknown band '%s' in %s" % [m.get_string(1), path]
			).is_true()


# --- FR-308 ------------------------------------------------------------------


func test_zhavar_defaults_to_low_and_climbs_the_ladder() -> void:
	assert_str(SaveGame.zhavar_rung("wilds")).is_equal("low")
	assert_str(SaveGame.raise_zhavar("wilds")).is_equal("rising")
	assert_str(SaveGame.raise_zhavar("wilds")).is_equal("tolling")
	assert_str(SaveGame.raise_zhavar("wilds")).is_equal("ringing")
	assert_str(SaveGame.raise_zhavar("wilds")).is_equal("unprecedented")
	# Capped at the top rung.
	assert_str(SaveGame.raise_zhavar("wilds")).is_equal("unprecedented")


func test_reaching_tolling_sets_the_scripted_event_flag_once() -> void:
	assert_bool(GameState.flag_is_true("zhavar_tolling_wilds")).is_false()
	SaveGame.raise_zhavar("wilds")
	assert_bool(GameState.flag_is_true("zhavar_tolling_wilds")).is_false()
	SaveGame.raise_zhavar("wilds")
	assert_bool(GameState.flag_is_true("zhavar_tolling_wilds")).is_true()


func test_raise_zhavar_rejects_an_invalid_zone_id() -> void:
	assert_str(SaveGame.raise_zhavar(" not a zone ")).is_equal("")
	assert_bool(SaveGame.zhavar.is_empty()).is_true()


func test_raised_zhavar_still_passes_save_validation() -> void:
	SaveGame.raise_zhavar("wilds")
	var payload: Dictionary = SaveGame._build_payload()
	assert_bool(SaveGame.validate_payload(payload)).is_true()


func test_rung_change_emits_signal() -> void:
	var seen: Array = []
	var handler := func(zone_id: String, rung: String) -> void:
		seen.append([zone_id, rung])
	SaveGame.zhavar_rung_changed.connect(handler)
	SaveGame.raise_zhavar("wilds")
	SaveGame.zhavar_rung_changed.disconnect(handler)
	assert_array(seen).is_equal([["wilds", "rising"]])


# --- FR-506 ------------------------------------------------------------------


func test_thinning_tiers_rise_monotonically_toward_the_front() -> void:
	var dom := LocationRegistry.DOM.thinning_tier
	var wilds := LocationRegistry.WILDS.thinning_tier
	var road := LocationRegistry.DORTHKOR.thinning_tier
	var front := LocationRegistry.WOUND_LIP.thinning_tier
	assert_int(dom).is_equal(0)
	assert_bool(dom < wilds and wilds < road and road < front).is_true()


func test_location_fizzle_integrity_shifts_toward_the_front() -> void:
	var base := 90.0
	var in_dom := SkillCheck.location_fizzle_integrity(base, LocationRegistry.DOM.scene_path)
	var at_front := SkillCheck.location_fizzle_integrity(
		base, LocationRegistry.WOUND_LIP.scene_path
	)
	assert_float(in_dom).is_equal(base)
	assert_bool(at_front < in_dom).is_true()
	# Unknown scenes stay town-stable and the result never goes negative.
	assert_float(SkillCheck.location_fizzle_integrity(base, "res://nope.tscn")).is_equal(base)
	assert_float(
		SkillCheck.location_fizzle_integrity(1.0, LocationRegistry.WOUND_LIP.scene_path)
	).is_equal(0.0)
