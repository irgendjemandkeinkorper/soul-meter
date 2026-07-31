extends "res://addons/gdUnit4/src/GdUnitTestSuite.gd"

const StandingUI = preload("res://ui/screens/standing.gd")
const RepEvent = preload("res://globals/reputation_event.gd")
const RenEvent = preload("res://globals/renown_event.gd")

func test_format_renown_event() -> void:
	var e = RenEvent.new()
	e.delta = 15.0
	e.cause = "Defeated the boss"
	assert_str(StandingUI.format_renown_event(e)).is_equal("+15.0: Defeated the boss")

	e.delta = -2.5
	e.cause = "Failed the challenge"
	assert_str(StandingUI.format_renown_event(e)).is_equal("-2.5: Failed the challenge")

	e.delta = 0.0
	e.cause = "Stood still"
	assert_str(StandingUI.format_renown_event(e)).is_equal("0.0: Stood still")

func test_format_event() -> void:
	var e = RepEvent.new()
	e.delta = 10.0
	e.cause = "Saved the village"
	assert_str(StandingUI.format_event(e)).is_equal("+10.0: Saved the village")

	e.delta = -5.5
	e.cause = "Stole an apple"
	assert_str(StandingUI.format_event(e)).is_equal("-5.5: Stole an apple")

	e.delta = 0.0
	e.cause = "Did nothing"
	assert_str(StandingUI.format_event(e)).is_equal("0.0: Did nothing")
