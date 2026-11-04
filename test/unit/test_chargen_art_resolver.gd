extends GdUnitTestSuite

const ChargenArtResolverScript := preload("res://ui/screens/chargen/chargen_art_resolver.gd")
const UnitArtScript := preload("res://globals/unit_art.gd")

const TEMP_ROOT := "user://gdunit_chargen_art"

var _saved_units: Dictionary[String, Dictionary]
var _fixture_textures: Array[Texture2D] = []


func before_test() -> void:
	UnitFrames._ensure_loaded()
	_saved_units = UnitFrames._units.duplicate(true)


func after_test() -> void:
	UnitFrames._units = _saved_units
	_fixture_textures.clear()
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


func test_corrupt_plate_file_falls_through_to_the_paired_unit_texture() -> void:
	# Gate r1: existence is not validity — a plate that exists but cannot load
	# as a texture must still yield the paired field sprite, never null/blank.
	var corrupt_path := "%s/portrait_likeness_01.png" % TEMP_ROOT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEMP_ROOT))
	var file := FileAccess.open(corrupt_path, FileAccess.WRITE)
	file.store_string("this is not a png")
	file.close()

	var texture: Texture2D = ChargenArtResolverScript.portrait_texture(
		"likeness_01", "%s/portrait_%%s.png" % TEMP_ROOT
	)
	assert_object(texture).is_not_null()
	assert_str(texture.resource_path).is_equal(
		UnitArtScript.texture_path(str(ChargenData.likeness_by_id("likeness_01")["unit"]))
	)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(corrupt_path))


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


func test_painted_portrait_and_field_likeness_survive_save_round_trip() -> void:
	var member := PartyMember.new()
	member.id = "custom-recruit"
	member.portrait = ChargenArtResolverScript.portrait_texture("likeness_01")
	var restored := PartyMember.from_dict(member.to_dict())
	assert_str(PartyMemberVisuals.ensure_portrait(restored).resource_path).is_equal(
		"res://assets/generated/portraits/player/likeness_01.png"
	)
	assert_str(PartyMemberVisuals.field_texture(restored).resource_path).is_equal(
		UnitArtScript.texture_path("crowd-acolyte-a")
	)


func test_named_companion_keeps_its_existing_full_body_art() -> void:
	var member := PartyMember.new()
	member.id = "serai-lun"
	assert_str(PartyMemberVisuals.field_texture(member).resource_path).is_equal(
		UnitArtScript.texture_path("serai-lun")
	)


func test_saved_chargen_identity_selects_class_then_ancestry_without_replacing_portrait() -> void:
	var member := PartyMember.new()
	member.id = "custom-recruit"
	member.race = "Vael"
	member.class_id = "ironbrand"
	member.portrait = ChargenArtResolverScript.portrait_texture("likeness_01")
	var restored := PartyMember.from_dict(member.to_dict())
	var portrait_path := restored.portrait.resource_path
	assert_str(PartyMemberVisuals.field_texture(restored).resource_path).is_equal(
		UnitArtScript.texture_path("crowd-acolyte-a")
	)
	_add_unit("player-vael")
	assert_str(PartyMemberVisuals.field_texture(restored).resource_path).is_equal(
		UnitArtScript.texture_path("player-vael")
	)
	_add_unit("player-vael-ironbrand")
	assert_str(PartyMemberVisuals.field_texture(restored).resource_path).is_equal(
		UnitArtScript.texture_path("player-vael-ironbrand")
	)
	assert_str(PartyMemberVisuals.ensure_portrait(restored).resource_path).is_equal(portrait_path)
	assert_str(restored.race).is_equal("Vael")
	assert_str(restored.class_id).is_equal("ironbrand")


func test_legacy_field_portrait_uses_build_art_but_named_companions_keep_their_identity() -> void:
	_add_unit("player-vael-ironbrand")
	var member := PartyMember.new()
	member.id = "legacy-player"
	member.race = "vael"
	member.class_id = "ironbrand"
	member.portrait = load(UnitArtScript.texture_path("crowd-guard-a")) as Texture2D
	assert_str(PartyMemberVisuals.field_texture(member).resource_path).is_equal(
		UnitArtScript.texture_path("player-vael-ironbrand")
	)
	member.id = "ressa-quickfingers"
	member.portrait = load(UnitArtScript.texture_path(member.id)) as Texture2D
	assert_str(PartyMemberVisuals.field_texture(member).resource_path).is_equal(
		UnitArtScript.texture_path(member.id)
	)


func test_unknown_likeness_and_missing_paired_unit_reach_the_crowd_fallback() -> void:
	for likeness: String in ["missing-likeness", "likeness_01"]:
		UnitFrames._units.erase("crowd-acolyte-a")
		var expected := UnitArtScript.texture_path(
			UnitArtScript.fallback_for(ChargenData.likeness_fallback_unit(likeness))
		)
		assert_str(ChargenArtResolverScript.portrait_path(likeness, "%s/missing_%%s.png" % TEMP_ROOT)).is_equal(expected)
		assert_str(ChargenArtResolverScript.portrait_texture(likeness, "%s/missing_%%s.png" % TEMP_ROOT).resource_path) \
			.is_equal(expected)


func _add_unit(unit_id: String) -> void:
	var path := "%s/%s/%s--idle--se--f00.png" % [UnitArtScript.ROOT, unit_id, unit_id]
	var texture := ImageTexture.create_from_image(Image.create(2, 2, false, Image.FORMAT_RGBA8))
	texture.take_over_path(path)
	_fixture_textures.append(texture)
	UnitFrames._units.merge(UnitFrames._index_manifest({"assets": [{
		"presentation_id": unit_id, "output_paths": [path], "direction": "se", "state": "idle", "frame": 0,
	}]}), true)
