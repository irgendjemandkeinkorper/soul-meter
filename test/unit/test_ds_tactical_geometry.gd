extends GdUnitTestSuite
## DS tactical-layer geometry ported from the Elemental Architecture Developer Annex
## (docs/prd-amendment-tactical-layer.md, GitHub #143).
##
## These exist because a flipped sign in an isometric projection mirrors the board silently —
## it looks plausible, renders without error, and is only ever caught by eye. Same for a
## dropped elevation term, which would make height invisible on screen while remaining real in
## combat: a model/view divergence that no gameplay test would notice.


func test_iso_projection_matches_the_annex_formula() -> void:
	# screenX = originX + (x - y) * TILE_W/2
	# screenY = originY + (x + y) * TILE_H/2 - h * ELEV_PX
	var origin := Vector2(100.0, 100.0)
	assert_vector(DS.iso_project(0, 0, 0, origin)).is_equal(origin)
	# +x goes right and down; +y goes left and down. A sign flip mirrors the board.
	assert_vector(DS.iso_project(1, 0, 0, origin)).override_failure_message(
		"+x must move right and down"
	).is_equal(Vector2(128.0, 114.0))
	assert_vector(DS.iso_project(0, 1, 0, origin)).override_failure_message(
		"+y must move LEFT and down — a flipped sign here mirrors the whole board"
	).is_equal(Vector2(72.0, 114.0))
	# Elevation must lift, not be dropped.
	assert_vector(DS.iso_project(2, 1, 2, origin)).is_equal(Vector2(128.0, 118.0))


func test_elevation_raises_and_never_shifts_horizontally() -> void:
	var flat := DS.iso_project(3, 2, 0)
	var raised := DS.iso_project(3, 2, 3)
	assert_float(raised.x).override_failure_message(
		"elevation must not move a tile sideways"
	).is_equal(flat.x)
	assert_float(flat.y - raised.y).override_failure_message(
		"3 height steps must lift by 3 * ELEV_PX"
	).is_equal(float(DS.ELEVATION_MAX * DS.ELEV_PX))


func test_painters_z_order_increases_with_depth() -> void:
	assert_int(DS.iso_z(0, 0)).is_equal(1)
	assert_int(DS.iso_z(3, 2)).is_equal(11)
	# A tile further from the camera must never sort in front of a nearer one.
	assert_int(DS.iso_z(2, 2)).is_greater(DS.iso_z(1, 1))


func test_charge_tint_alpha_follows_the_annex_curve_and_clamps() -> void:
	var khor: Color = DS.WHEEL[3]["color"]
	assert_float(DS.charge_tint(khor, 0).a).override_failure_message(
		"charge 0 must draw nothing"
	).is_equal(0.0)
	assert_float(DS.charge_tint(khor, 1).a).is_equal_approx(0.34, 0.001)
	assert_float(DS.charge_tint(khor, 2).a).is_equal_approx(0.48, 0.001)
	assert_float(DS.charge_tint(khor, 3).a).is_equal_approx(0.62, 0.001)
	assert_float(DS.charge_tint(khor, 99).a).override_failure_message(
		"charge above CHARGE_MAX must clamp, not keep brightening"
	).is_equal_approx(DS.charge_tint(khor, DS.CHARGE_MAX).a, 0.001)
	# Hue is carried through untouched; only alpha encodes charge.
	var tinted := DS.charge_tint(khor, 2)
	assert_float(tinted.r).is_equal(khor.r)
	assert_float(tinted.g).is_equal(khor.g)
	assert_float(tinted.b).is_equal(khor.b)


func test_wheel_sigils_carry_text_presentation_where_the_ds_marks_them() -> void:
	# "No emoji, ever" is a DS rule that would otherwise be violated at RUNTIME rather than at
	# authoring time: without U+FE0E several of these codepoints render as colour emoji on
	# some platforms. Exactly five are marked, matching the DS.
	var marked: Array[String] = []
	for entry in DS.WHEEL:
		var sigil: String = entry["sigil"]
		if sigil.length() > 1 and sigil.unicode_at(1) == 0xFE0E:
			marked.append(String(entry["id"]))
	assert_array(marked).override_failure_message(
		"the VS15-marked sigils drifted from the DS set"
	).contains_exactly(["bloei", "khor", "daar", "scor", "nul"])


func test_wheel_is_the_closed_canon_order() -> void:
	# Guards the one thing every element system reads. Never an eleventh, never reordered.
	var ids: Array[String] = []
	for entry in DS.WHEEL:
		ids.append(String(entry["id"]))
	assert_array(ids).contains_exactly([
		"suul", "bloei", "aqua", "khor", "terra", "daar", "molm", "scor", "nul", "strom"
	])
	assert_array(ids).is_equal(ElementWheel.ORDER.map(func(e: StringName) -> String:
		return String(e)
	))
