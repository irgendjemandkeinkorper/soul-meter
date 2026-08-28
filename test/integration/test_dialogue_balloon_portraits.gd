extends GdUnitTestSuite


const IRIS_PORTRAIT := (
	"res://assets/generated/portraits/iris_illepah_portrait_neutral.png"
)


func after_test() -> void:
	get_tree().paused = false


func test_iris_dialogue_uses_production_portrait() -> void:
	var balloon: Node = load("res://ui/dialogue/dialogue_balloon.tscn").instantiate()
	add_child(balloon)
	balloon.call("start", load("res://dialogue/iris_illepah.dialogue"), "start")
	await get_tree().process_frame
	await get_tree().process_frame

	var portrait := balloon.get("_portrait") as SMPortrait
	assert_object(portrait).is_not_null()
	var portrait_image := portrait.get("_image") as TextureRect
	assert_object(portrait_image.texture).is_not_null()
	if portrait_image.texture != null:
		assert_str(portrait_image.texture.resource_path).is_equal(IRIS_PORTRAIT)

	balloon.free()


func test_iris_portrait_has_real_transparency() -> void:
	var image := Image.load_from_file(IRIS_PORTRAIT)
	assert_bool(image.is_empty()).is_false()
	assert_int(image.detect_alpha()).is_not_equal(Image.ALPHA_NONE)
	assert_object(image.get_size()).is_equal(Vector2i(512, 512))
