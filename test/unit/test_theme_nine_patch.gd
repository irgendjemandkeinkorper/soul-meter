extends GdUnitTestSuite
## Guards the 9-patch chrome (FR-605 / #297).
##
## The pass shipped without a regression test, so replacing every notched
## StyleBoxTexture with a flat StyleBoxFlat would have been a green build. These
## cases assert the SHAPE of the chrome — textured, with real nine-patch margins,
## reached through type variations rather than per-node overrides — and
## deliberately assert nothing about which colours or corner art it uses, so a
## restyle stays free and a regression to flat boxes does not.

const FRAMED_CONTROLS: Dictionary = {
	"PanelContainer": ["panel"],
	"Button": ["normal", "hover", "pressed", "focus", "disabled"],
}

## Every control whose frame is drawn by the notched atlas. A variation that
## loses its stylebox falls back to its base type and looks almost right, which
## is why the list is explicit rather than derived from the theme itself.
const FRAMED_VARIATIONS: Dictionary = {
	"MainMenuMirrorFrame": "panel",
	"MainMenuButtonWell": "panel",
	"MainMenuPrimaryButton": "normal",
	"DangerButton": "normal",
	"BronzeButton": "normal",
	"DialogueChoice": "normal",
	"DialogueLinePanel": "panel",
}

var theme: Theme


func before_test() -> void:
	theme = ThemeBuilder.build()


func after_test() -> void:
	theme = null


func test_every_framed_control_state_is_a_textured_nine_patch() -> void:
	for type_name: String in FRAMED_CONTROLS:
		for state: String in FRAMED_CONTROLS[type_name]:
			var box: StyleBox = theme.get_stylebox(state, type_name)
			assert_object(box).override_failure_message(
				"%s/%s has no stylebox at all" % [type_name, state]
			).is_not_null()
			assert_bool(box is StyleBoxTexture).override_failure_message(
				(
					"%s/%s is a %s, not a StyleBoxTexture. The 9-patch pass (FR-605, "
					+ "#297) put notched chrome on every framed control; a flat box here "
					+ "means it was reverted, and nothing else in the suite would notice"
				)
				% [type_name, state, box.get_class()]
			).is_true()


func test_framed_controls_carry_real_nine_patch_margins() -> void:
	# A StyleBoxTexture with zero texture margins stretches the whole bitmap and
	# is a nine-patch in name only — the corners smear. This is the case that
	# catches art swapped in without its margins.
	for type_name: String in FRAMED_CONTROLS:
		for state: String in FRAMED_CONTROLS[type_name]:
			var box := theme.get_stylebox(state, type_name) as StyleBoxTexture
			if box == null:
				continue
			for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				assert_float(box.get_texture_margin(side)).override_failure_message(
					(
						"%s/%s has a zero texture margin on side %d — the corners will "
						+ "stretch instead of holding their shape"
					)
					% [type_name, state, side]
				).is_greater(0.0)


func test_every_notched_variation_still_owns_its_stylebox() -> void:
	for variation: String in FRAMED_VARIATIONS:
		var state: String = FRAMED_VARIATIONS[variation]
		assert_bool(theme.has_stylebox(state, variation)).override_failure_message(
			(
				"variation %s lost its '%s' stylebox. It would silently fall back to its "
				+ "base type and render almost right, which is the hardest kind of "
				+ "regression to see in a screenshot"
			)
			% [variation, state]
		).is_true()
		var box: StyleBox = theme.get_stylebox(state, variation)
		assert_bool(box is StyleBoxTexture).override_failure_message(
			"variation %s/%s is a %s, not a StyleBoxTexture" % [variation, state, box.get_class()]
		).is_true()


func test_the_notched_atlas_is_the_one_source_of_frame_art() -> void:
	# Guards the architecture rule, not the look: chrome comes from the project's
	# own atlas, so a restyle is one asset edit rather than a hunt through the
	# theme for stray textures.
	var atlas: Texture2D = ThemeBuilder.NOTCHED_ATLAS
	assert_object(atlas).is_not_null()
	var button := theme.get_stylebox("normal", "Button") as StyleBoxTexture
	var region := button.texture as AtlasTexture
	assert_object(region).override_failure_message(
		"Button/normal no longer reads from the notched atlas"
	).is_not_null()
	assert_object(region.atlas).is_same(atlas)
	assert_float(region.region.size.x).is_equal(ThemeBuilder.NOTCHED_TILE_SIZE)
	assert_float(region.region.size.y).is_equal(ThemeBuilder.NOTCHED_TILE_SIZE)


func test_button_states_are_visually_distinct() -> void:
	# Five states drawn from the same atlas tile would compile, pass every other
	# case here, and leave the player with no feedback on hover or press.
	var tiles := {}
	for state: String in FRAMED_CONTROLS["Button"]:
		var box := theme.get_stylebox(state, "Button") as StyleBoxTexture
		var region := box.texture as AtlasTexture
		if region == null:
			continue
		tiles[state] = region.region.position.x
	assert_int(tiles.size()).is_greater(1)
	var distinct := {}
	for state: String in tiles:
		distinct[tiles[state]] = true
	assert_int(distinct.size()).override_failure_message(
		(
			"Button states share atlas tiles %s — hover and press would look identical "
			+ "to the player even though the theme technically has five styleboxes"
		)
		% [str(tiles)]
	).is_equal(tiles.size())
