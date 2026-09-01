extends GdUnitTestSuite

const TELEGRAPH_SCENE := preload(
	"res://actors/zhavar_telegraph/zhavar_telegraph.tscn"
)

var _flags_before: Dictionary
var _zhavar_before: Dictionary


func before_test() -> void:
	_flags_before = GameState.flags.duplicate(true)
	_zhavar_before = SaveGame.zhavar.duplicate(true)
	SaveGame.zhavar = {}


func after_test() -> void:
	SaveGame.zhavar = _zhavar_before
	GameState.flags = _flags_before


func test_rung_intensity_is_monotonic_and_low_is_zero() -> void:
	var previous := -1.0
	for rung: String in SaveGame.ZHAVAR_RUNGS:
		var current: float = ZhavarTelegraph.intensity_for_rung(rung)
		assert_float(current).is_greater_equal(previous)
		previous = current
	assert_float(ZhavarTelegraph.intensity_for_rung("low")).is_zero()


func test_ready_reads_current_rung_and_signal_updates_live() -> void:
	SaveGame.zhavar["wilds"] = "rising"
	var telegraph := auto_free(TELEGRAPH_SCENE.instantiate()) as ZhavarTelegraph
	add_child(telegraph)
	assert_float(telegraph.intensity).is_equal_approx(
		ZhavarTelegraph.intensity_for_rung("rising"), 0.001
	)

	SaveGame.raise_zhavar("wilds")
	assert_float(telegraph.intensity).is_equal_approx(
		ZhavarTelegraph.intensity_for_rung("tolling"), 0.001
	)


func test_low_is_inert_and_scene_introduces_no_collision_object() -> void:
	var telegraph := auto_free(TELEGRAPH_SCENE.instantiate()) as ZhavarTelegraph
	add_child(telegraph)
	assert_float(telegraph.intensity).is_zero()
	assert_bool(telegraph.get_node("CanvasLayer/Overlay").visible).is_false()
	assert_array(telegraph.find_children("*", "CollisionObject2D", true, false)).is_empty()
