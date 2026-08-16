class_name DeploymentScreen
extends Screen

enum Step { SLATE, ATTUNE, LOADOUT, PLACE }

var current_step := Step.SLATE
## Typed to the FR-105 seam, not the grid implementation: placement goes through the
## same move()/set_facing() surface on whichever model the battle is running.
var battlefield_model: BattlefieldModel
var placement_actor: BattleActor
@onready var title: Label = %Title
@onready var body: Label = %Body
@onready var advance_button: Button = %Advance


func _ready() -> void:
	advance_button.pressed.connect(_advance)
	_render()


func configure_step(step: Step) -> void:
	current_step = step
	if is_node_ready():
		_render()


func configure_placement(model: BattlefieldModel, actor: BattleActor) -> void:
	battlefield_model = model
	placement_actor = actor


func place_unit(position: StringName, facing: StringName) -> Dictionary:
	if battlefield_model == null or placement_actor == null:
		return {"allowed": false, "blocked_by": &"deployment_context"}
	var moved := battlefield_model.move(placement_actor, position)
	if not bool(moved.get("allowed", false)):
		return moved
	var faced := battlefield_model.set_facing(placement_actor, facing)
	if not bool(faced.get("allowed", false)):
		return faced
	return {"allowed": true, "position": battlefield_model.position_of(placement_actor), "facing": battlefield_model.facing_of(placement_actor)}


func _advance() -> void:
	GameFlow.send_event(&"accept_slate" if current_step == Step.PLACE else &"deployment_next")


func _render() -> void:
	var names := ["SLATE", "ATTUNE", "LOADOUT", "PLACE"]
	title.text = "%d  %s" % [current_step + 1, names[current_step]]
	match current_step:
		Step.SLATE:
			body.text = "ROSTER · SIGIL · NAME · JOB · LEVEL"
		Step.ATTUNE:
			body.text = "THE TEN, SIGNED · −3 TO +3 · ONE AFFINITY STRIP"
		Step.LOADOUT:
			body.text = "PRIMARY · SECONDARY · REACTION · PASSIVE · EQUIPMENT"
		Step.PLACE:
			body.text = "STARTING POSITION · FACING"
	advance_button.text = "ACCEPT THE SLATE" if current_step == Step.PLACE else "CONTINUE"
