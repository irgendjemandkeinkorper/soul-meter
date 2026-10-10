extends WeftluminShell
## Host lifecycle wiring stays out of the reusable dock and the resident bootstrap.

const HOST_ADAPTER := preload("res://addons/weftlumin/shell/soul_meter_adapter.gd")


func _ready() -> void:
	if adapter == null:
		adapter = HOST_ADAPTER.new()
	WeftluminSandbox.shared().add_default_surfaces(SaveGame, SkillCheck)
	GameFlow.get_node("StateChart/Root/Playing/Loading").state_entered.connect(close)
	super._ready()


func _exit_tree() -> void:
	var loading := GameFlow.get_node("StateChart/Root/Playing/Loading")
	if loading.state_entered.is_connected(close):
		loading.state_entered.disconnect(close)
	super._exit_tree()


func _abandon_sandbox_session() -> void:
	Battle.abandon()
