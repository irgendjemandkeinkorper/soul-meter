extends GdUnitTestSuite

const SCENE_PATH := "res://world/wound_lip.tscn"


func test_scene_instantiates_with_gameplay_contract() -> void:
	var packed_scene := load(SCENE_PATH) as PackedScene
	assert_object(packed_scene).is_not_null()

	var wound_lip: Node = auto_free(packed_scene.instantiate())
	add_child(wound_lip)
	await get_tree().process_frame

	assert_bool(wound_lip.is_node_ready()).is_true()
	assert_object(wound_lip.get_node_or_null("Player")).is_not_null()
	assert_object(wound_lip.get_node_or_null("FieldHUD")).is_not_null()
	assert_object(wound_lip.get_node_or_null("LedgeCache")).is_not_null()
	assert_object(wound_lip.get_node_or_null("GuardKit")).is_not_null()
	assert_object(wound_lip.get_node_or_null("ReturnToDom")).is_not_null()
