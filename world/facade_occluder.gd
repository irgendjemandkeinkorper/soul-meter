class_name FacadeOccluder
extends Node
## Presentation-only fade for actors whose feet are behind opaque facade art.

const ACTOR_GROUPS: Array[StringName] = [
	&"player", &"party_follower", &"party_followers", &"generated_townsfolk",
]
const FADE_DURATION := 0.15

var _facade: Sprite2D
var _building: Node2D
var _town: Node
var _image: Image
var _occluded := false
var _fade: Tween


func _init(facade: Sprite2D = null) -> void:
	_facade = facade


func _ready() -> void:
	if _facade == null or _facade.texture == null:
		set_physics_process(false)
		return
	_building = _facade.get_parent() as Node2D
	_town = _building.get_parent()
	# Texture readback happens once, never in the actor/physics loop.
	_image = _facade.texture.get_image()
	if _image == null or _image.is_empty():
		set_physics_process(false)
		return
	if _image.is_compressed():
		if _image.decompress() != OK:
			set_physics_process(false)


func _physics_process(_delta: float) -> void:
	var occluded := _any_actor_behind()
	if occluded == _occluded:
		return
	_occluded = occluded
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = create_tween()
	_fade.tween_property(
		_facade, "modulate:a", DS.FACADE_OCCLUDED_ALPHA if occluded else 1.0, FADE_DURATION
	)


func _any_actor_behind() -> bool:
	for group: StringName in ACTOR_GROUPS:
		for node: Node in get_tree().get_nodes_in_group(group):
			if node is Node2D and _town.is_ancestor_of(node) and _covers_actor(node):
				return true
	# Authored named NPCs need no new group or scene wiring. Include children
	# created after town setup, such as the existing deferred NPC spawner.
	for child: Node in _town.get_children():
		if child is NPC and _covers_actor(child):
			return true
	return false


func _covers_actor(actor: Node2D) -> bool:
	if not actor.is_visible_in_tree() or actor.global_position.y >= _building.global_position.y:
		return false
	var rect := _facade.get_rect()
	var feet := _facade.to_local(actor.global_position)
	if not rect.has_point(feet):
		return false
	var uv := (feet - rect.position) / rect.size
	var pixel := Vector2i(uv * Vector2(_image.get_size()))
	if _facade.flip_h:
		pixel.x = _image.get_width() - 1 - pixel.x
	if _facade.flip_v:
		pixel.y = _image.get_height() - 1 - pixel.y
	return _image.get_pixelv(pixel).a > 0.1
