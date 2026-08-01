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
##       ├── Loading               calls loader for `_target_scene`; leaves on "level_ready"
##       ├── Active                re-enters Loading on "travel" (see travel())
##       ├── Paused                pause overlay + tree pause live here
##       └── Battle                battle overlay + tree pause live here (combat scaffold)
##
## Events: boot_done · new_game · level_ready · pause · resume · to_main_menu ·
##         enter_battle · battle_end · travel

const MAIN_MENU_SCENE := "res://ui/screens/main_menu.tscn"
## The starting town (Dom) — the first gameplay scene loaded on a new game.
const TOWN_SCENE := "res://world/starting_town.tscn"
## The original field/wilds vertical slice (Iris, Bog Wight, the Loamroot fetch
## quest) — now reached from the town via a TravelExit, not booted directly.
const WILDS_SCENE := "res://world/test_room.tscn"
const DORTHKOR_SCENE := "res://world/dorthkor_road.tscn"
const WOUND_LIP_SCENE := "res://world/wound_lip.tscn"
## Every scene UIManager should treat as "in gameplay" (see _in_gameplay()).
const GAMEPLAY_SCENES: Array[String] = [
	TOWN_SCENE,
	WILDS_SCENE,
	DORTHKOR_SCENE,
	WOUND_LIP_SCENE,
]
const LOADING_SCREEN := (
	"res://addons/maaacks_game_template/base/nodes/loading_screen/" + "loading_screen.tscn"
)
const PAUSE_MENU := preload("res://ui/screens/pause_menu.tscn")
const BATTLE_SCREEN := preload("res://ui/screens/battle.tscn")
const CHAPTER_COMPLETE_SCREEN := preload("res://ui/screens/chapter_complete.tscn")

var _waiting_for_level := false
## Which scene Loading loads next — TOWN_SCENE on the initial new_game, or
## whatever travel() set it to on a re-entry.
var _target_scene := TOWN_SCENE
var _target_spawn_id: StringName = &"default"

@onready var chart: StateChart = $StateChart


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Local visual-regression captures can launch a gameplay scene directly
	# without the Boot state immediately replacing it with the title screen.
	if OS.get_cmdline_user_args().has("capture-scene"):
		return
	SceneLoader.set_loading_screen(LOADING_SCREEN)
	SceneLoader.scene_loaded.connect(_on_scene_loaded)
	# Mirror derived standings into chart expression properties so transition
	# GUARDS (not if-blocks) can read them: e.g. expression `rep_mirror_choir >= 15`.
	Reputation.reputation_changed.connect(
		func(faction: String, standing: float, _e: ReputationEvent) -> void:
			chart.set_expression_property("rep_" + faction.replace("-", "_"), standing)
	)

	$StateChart/Root/Menus/Title.state_entered.connect(_on_title_entered)
	$StateChart/Root/Playing/Loading.state_entered.connect(_on_loading_entered)
	$StateChart/Root/Playing/Paused.state_entered.connect(_on_paused_entered)
	$StateChart/Root/Playing/Paused.state_exited.connect(_on_paused_exited)
	$StateChart/Root/Playing/Battle.state_entered.connect(_on_battle_entered)
	$StateChart/Root/Playing/Battle.state_exited.connect(_on_battle_exited)
	$StateChart/Root/Playing/ChapterComplete.state_entered.connect(_on_chapter_complete_entered)
	$StateChart/Root/Playing/ChapterComplete.state_exited.connect(_on_chapter_complete_exited)

	# Boot is where splash/config-load will live; nothing to wait on yet.
	send_event.call_deferred("boot_done")


## The single entry point UI code uses to talk to the chart.
func send_event(event: StringName) -> void:
	chart.send_event(event)


## The single entry point for moving between gameplay scenes (e.g. a
## TravelExit) — never call SceneLoader or change_scene_to_file() directly
## from game code (see the header note above).
func travel(scene_path: String, spawn_id: StringName = &"default") -> void:
	if scene_path not in GAMEPLAY_SCENES:
		push_error("Refusing travel to non-gameplay scene: %s" % scene_path)
		return
	_target_scene = scene_path
	_target_spawn_id = spawn_id
	SaveGame.pending_spawn_id = spawn_id
	SaveGame.has_pending_player_position = false
	send_event("travel")


func notify_dialogue_closed() -> void:
	if ChapterOneProgress.current_stage() == ChapterOneProgress.Stage.COMPLETE:
		send_event.call_deferred("chapter_complete")


# --- state handlers (policy → mechanism) --------------------------------------


func _on_title_entered() -> void:
	UIManager.close_all()
	var cur := get_tree().current_scene
	if cur == null or cur.scene_file_path != MAIN_MENU_SCENE:
		SceneLoader.load_scene(MAIN_MENU_SCENE)


func _on_loading_entered() -> void:
	_waiting_for_level = true
	SceneLoader.load_scene(_target_scene)


func _on_scene_loaded() -> void:
	if _waiting_for_level:
		SaveGame.apply_pending_location(get_tree().current_scene)
		_waiting_for_level = false
		send_event("level_ready")
		SaveGame.flush_pending_autosave.call_deferred()
		if ChapterOneProgress.current_stage() == ChapterOneProgress.Stage.COMPLETE:
			notify_dialogue_closed()


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
	SaveGame.flush_pending_autosave.call_deferred()


func _on_chapter_complete_entered() -> void:
	get_tree().paused = true
	UIManager.open(CHAPTER_COMPLETE_SCREEN, false, true)


func _on_chapter_complete_exited() -> void:
	UIManager.close_all()
	get_tree().paused = false
