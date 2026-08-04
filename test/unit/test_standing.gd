extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const StandingUI = preload("res://ui/screens/standing.gd")
const RepEvent = preload("res://globals/reputation_event.gd")
const RenEvent = preload("res://globals/renown_event.gd")

func test_format_renown_event() -> void:
	var e = RenEvent.new()
	e.kind = &"reputation"
	e.delta = 15.0
	e.cause = "Defeated the boss"
	e.scene = "field"
	assert_str(StandingUI.format_renown_event(e)).is_equal(
		"Your name carried farther because Defeated the boss. Renown +15.0. Entered at Field."
	)

	e.kind = &"infamy"
	e.delta = -2.5
	e.cause = "Failed the challenge"
	e.scene = "res://world/dorthkor_road.tscn"
	assert_str(StandingUI.format_renown_event(e)).is_equal(
		"Your name darkened because Failed the challenge. Infamy -2.5. Entered at Dorthkor Road."
	)

	e.delta = 0.0
	e.cause = "Stood still"
	e.scene = ""
	assert_str(StandingUI.format_renown_event(e)).is_equal(
		"Your name darkened because Stood still. Infamy 0.0. Entered at an unentered place."
	)

func test_format_event() -> void:
	var e = RepEvent.new()
	e.faction = "mirror-choir"
	e.delta = 10.0
	e.cause = "Saved the village"
	e.scene = "mirror-hall"
	assert_str(StandingUI.format_event(e)).is_equal(
		"Mirror Choir remembers: Saved the village. Standing +10.0. Entered at Mirror Hall."
	)

	e.delta = -5.5
	e.cause = "Stole an apple"
	assert_str(StandingUI.format_event(e)).contains("Standing -5.5")

	e.delta = 0.0
	e.cause = "Did nothing"
	assert_str(StandingUI.format_event(e)).contains("Standing 0.0")


func test_band_theme_types_keep_band_text_color_independent() -> void:
	assert_str(StandingUI.band_theme_type(&"hostile")).is_equal("StandingHostileLabel")
	assert_str(StandingUI.band_theme_type(&"cold")).is_equal("StandingColdLabel")
	assert_str(StandingUI.band_theme_type(&"neutral")).is_equal("StandingNeutralLabel")
	assert_str(StandingUI.band_theme_type(&"warm")).is_equal("StandingWarmLabel")
	assert_str(StandingUI.band_theme_type(&"allied")).is_equal("StandingAlliedLabel")
