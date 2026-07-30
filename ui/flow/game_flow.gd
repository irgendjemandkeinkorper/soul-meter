extends Node
## GameFlow — the explicit state machine that owns menu/game flow.
##
## THE CHART IS POLICY; LOADERS ARE MECHANISM (see docs/godot-architecture.md):
##  - UI code sends events here (`GameFlow.send_event("new_game")`) and NEVER names a
##    destination or calls change_scene_to_file().
##  - This script's state handlers call SceneLoader (Maaack) to move scenes, and
##    UIManager to draw overlay screens.
##
## Chart shape (see game_flow.tscn):
##   Root
##   ├── Boot                      splash/config; auto-advances via "boot_done"
##   ├── Menus
##   │   └── Title                 (Options/Credits states land with Maaack's menus)
##   └── Playing
##       ├── Loading               calls loader; leaves on "level_ready"
##       ├── Active
##       ├── Paused                pause overlay + tree pause live here
##       └── Battle                battle overlay + tree pause live here (combat scaffold)
##
## Events: boot_done · new_game · level_ready · pause · resume · to_main_menu ·
##         enter_battle · battle_end

const MAIN_MENU_SCENE := "res://ui/screens/main_menu.tscn"
const FIELD_SCENE := "res://world/test_room.tscn"
const LOADING_SCREEN := "res://addons/maaacks_game_template/base/nodes/loading_screen/loading_screen.tscn"
const PAUSE_MENU := preload("res://ui/screens/pause_menu.tscn")
const BATTLE_SCREEN := preload("res://ui/screens/battle.tscn")

@onready var chart: StateChart = $StateChart

var _waiting_for_level := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	SceneLoader.set_loading_screen(LOADING_SCREEN)
	SceneLoader.scene_loaded.connect(_on_scene_loaded)
	# Mirror derived standings into chart expression properties so transition
	# GUARDS (not if-blocks) can read them: e.g. expression `rep_mirror_choir >= 15`.
	Reputation.reputation_changed.connect(func(faction: String, standing: float, _e: ReputationEvent) -> void:
		chart.set_expression_property("rep_" + faction.replace("-", "_"), standing))

	$StateChart/Root/Menus/Title.state_entered.connect(_on_title_entered)
	$StateChart/Root/Playing/Loading.state_entered.connect(_on_loading_entered)
	$StateChart/Root/Playing/Paused.state_entered.connect(_on_paused_entered)
	$StateChart/Root/Playing/Paused.state_exited.connect(_on_paused_exited)
	$StateChart/Root/Playing/Battle.state_entered.connect(_on_battle_entered)
	$StateChart/Root/Playing/Battle.state_exited.connect(_on_battle_exited)

	# Boot is where splash/config-load will live; nothing to wait on yet.
	send_event.call_deferred("boot_done")


## The single entry point UI code uses to talk to the chart.
func send_event(event: StringName) -> void:
	chart.send_event(event)


# --- state handlers (policy → mechanism) --------------------------------------

func _on_title_entered() -> void:
	UIManager.close_all()
	var cur := get_tree().current_scene
	if cur == null or cur.scene_file_path != MAIN_MENU_SCENE:
		SceneLoader.load_scene(MAIN_MENU_SCENE)


func _on_loading_entered() -> void:
	_waiting_for_level = true
	SceneLoader.load_scene(FIELD_SCENE)


func _on_scene_loaded() -> void:
	if _waiting_for_level:
		_waiting_for_level = false
		send_event("level_ready")


func _on_paused_entered() -> void:
	get_tree().paused = true
	UIManager.open(PAUSE_MENU, false, true)


func _on_paused_exited() -> void:
	UIManager.close_all()
	get_tree().paused = false


func _on_battle_entered() -> void:
	get_tree().paused = true
	UIManager.open(BATTLE_SCREEN, false, true)


func _on_battle_exited() -> void:
	UIManager.close_all()
	get_tree().paused = false
