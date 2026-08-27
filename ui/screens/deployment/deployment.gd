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
@onready var skip_button: Button = %Skip


func _ready() -> void:
	advance_button.pressed.connect(_advance)
	skip_button.pressed.connect(_skip)
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


## Walk the remaining chart states instead of jumping, so every deployment
## state's enter/exit side effects (screen swaps, PLACE's model handoff) still
## run. Count first — the first event frees this screen instance.
func _skip() -> void:
	var steps_remaining := int(Step.PLACE) - int(current_step)
	for _i in steps_remaining:
		GameFlow.send_event(&"deployment_next")
	GameFlow.send_event(&"accept_slate")


func _render() -> void:
	var names := ["SLATE", "ATTUNE", "LOADOUT", "PLACE"]
	title.text = "%d  %s" % [current_step + 1, names[current_step]]
	match current_step:
		Step.SLATE:
			body.text = (
				"YOUR PARTY TAKES THE FIELD.\n\n"
				+ "This step will become the roster sheet — sigil, name, job, level.\n"
				+ "Nothing to choose yet; your active party deploys as-is."
			)
		Step.ATTUNE:
			body.text = (
				"ELEMENTAL AFFINITIES ACROSS THE TEN.\n\n"
				+ "This step will let you tune each fighter's signed affinities (−3 to +3),\n"
				+ "which scale elemental damage dealt and taken.\n"
				+ "Editing isn't built yet; current values apply."
			)
		Step.LOADOUT:
			body.text = (
				"ACTIONS AND EQUIPMENT.\n\n"
				+ "This step will become the loadout picker — primary, secondary,\n"
				+ "reaction, passive, equipment. Defaults apply for now."
			)
		Step.PLACE:
			body.text = (
				"STARTING POSITIONS AND FACING.\n\n"
				+ "This step will let you place each fighter on the field.\n"
				+ "Default positions apply for now."
			)
	advance_button.text = "ACCEPT THE SLATE" if current_step == Step.PLACE else "CONTINUE"
	skip_button.visible = current_step != Step.PLACE
