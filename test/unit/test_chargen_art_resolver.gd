extends GdUnitTestSuite

const ChargenArtResolverScript := preload("res://ui/screens/chargen/chargen_art_resolver.gd")
const UnitArtScript := preload("res://globals/unit_art.gd")

const TEMP_ROOT := "user://gdunit_chargen_art"


func after_test() -> void:
	var portrait_path := "%s/portrait_guard.png" % TEMP_ROOT
	var ancestry_path := "%s/ancestry_vael.png" % TEMP_ROOT
	for path: String in [portrait_path, ancestry_path]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var absolute_root := ProjectSettings.globalize_path(TEMP_ROOT)
	if DirAccess.dir_exists_absolute(absolute_root):
		DirAccess.remove_absolute(absolute_root)


func test_missing_portrait_falls_back_to_the_existing_field_sprite() -> void:
	var actual: String = ChargenArtResolverScript.portrait_path(
		"crowd-guard-a", "%s/portrait_%%s.png" % TEMP_ROOT
	)
	assert_str(actual).is_equal(UnitArtScript.texture_path("crowd-guard-a"))


func test_existing_portrait_art_is_preferred() -> void:
	var expected := "%s/portrait_guard.png" % TEMP_ROOT
	_write_test_png(expected)
	var actual: String = ChargenArtResolverScript.portrait_path(
		"guard", "%s/portrait_%%s.png" % TEMP_ROOT
	)
	assert_str(actual).is_equal(expected)


func test_missing_ancestry_art_returns_an_empty_fallback_marker() -> void:
	var actual: String = ChargenArtResolverScript.ancestry_path(
		"vael", "%s/ancestry_%%s.png" % TEMP_ROOT
	)
	assert_str(actual).is_empty()


func test_existing_ancestry_art_is_preferred() -> void:
	var expected := "%s/ancestry_vael.png" % TEMP_ROOT
	_write_test_png(expected)
	var actual: String = ChargenArtResolverScript.ancestry_path(
		"vael", "%s/ancestry_%%s.png" % TEMP_ROOT
	)
	assert_str(actual).is_equal(expected)


func test_gallery_likeness_without_a_plate_falls_back_to_its_paired_unit_sprite() -> void:
	var actual: String = ChargenArtResolverScript.portrait_path(
		"likeness_01", "%s/portrait_%%s.png" % TEMP_ROOT
	)
	assert_str(actual).is_equal(
		UnitArtScript.texture_path(str(ChargenData.likeness_by_id("likeness_01")["unit"]))
	)


func test_likeness_table_ids_are_unique_and_every_paired_unit_sprite_exists() -> void:
	assert_int(ChargenData.LIKENESSES.size()).is_equal(10)
	var seen_ids: Dictionary = {}
	for likeness: Dictionary in ChargenData.LIKENESSES:
		var likeness_id := str(likeness.get("id", ""))
		assert_bool(seen_ids.has(likeness_id)).override_failure_message(
			"duplicate likeness id %s" % likeness_id
		).is_false()
		seen_ids[likeness_id] = true
		var unit_id := str(likeness.get("unit", ""))
		assert_bool(UnitArtScript.has_unit(unit_id)).override_failure_message(
			"likeness %s pairs a missing field sprite '%s'" % [likeness_id, unit_id]
		).is_true()


func _write_test_png(path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	var image := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	image.fill(Color.WHITE)
	assert_int(image.save_png(path)).is_equal(OK)
