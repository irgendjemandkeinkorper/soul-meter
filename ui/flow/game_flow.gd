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
##   │   ├── Title                 (Options/Credits states land with Maaack's menus)
##   │   └── CharacterCreation     the Register of Persons (#98/#129) — new-game only;
##   │                             "Continue" skips straight to Playing (save already
##   │                             has a character)
##   └── Playing
##       ├── Loading               calls loader for `_target_scene`; leaves on "level_ready"
##       ├── Active                re-enters Loading on "travel" (see travel())
##       ├── Paused                pause overlay + tree pause live here
##       └── Battle                battle overlay + tree pause live here (combat scaffold)
##
## Events: boot_done · start_chargen · new_game · level_ready · pause · resume ·
##         to_main_menu · enter_battle · battle_end · travel

const MAIN_MENU_SCENE := "res://ui/screens/main_menu.tscn"
## The starting town (Dom) — the first gameplay scene loaded on a new game.
const TOWN_SCENE := "res://world/starting_town.tscn"
## The original field/wilds vertical slice (Iris, Bog Wight, the Loamroot fetch
## quest) — now reached from the town via a TravelExit, not booted directly.
const WILDS_SCENE := "res://world/test_room.tscn"
const DORTHKOR_SCENE := "res://world/dorthkor_road.tscn"
const WOUND_LIP_SCENE := "res://world/wound_lip.tscn"
## Every scene UIManager should treat as "in gameplay" (see _in_gameplay()).
var GAMEPLAY_SCENES: Array[String] = LocationRegistry.gameplay_scenes()
const LOADING_SCREEN := (
	"res://addons/maaacks_game_template/base/nodes/loading_screen/" + "loading_screen.tscn"
)
const PAUSE_MENU := preload("res://ui/screens/pause_menu.tscn")
const CHARACTER_CREATION_SCREEN := preload("res://ui/screens/character_creation.tscn")
const BATTLE_SCREEN := preload("res://ui/screens/battle.tscn")
const CHAPTER_COMPLETE_SCREEN := preload("res://ui/screens/chapter_complete.tscn")

var _waiting_for_level := false
var _pending_fast_travel_cost := 0
var _fast_travel_in_progress := false
var _loading_fallback_scene := ""
var _recovering_from_failure := false
## Set by a failed scene load, read (and cleared) by the next screen that can
## report it to the player — currently the region map, the only fast-travel UI.
var last_travel_error := ""
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
	if not SaveGame.load_requested.is_connected(load_destination):
		SaveGame.load_requested.connect(load_destination)
	# Mirror derived standings into chart expression properties so transition
	# GUARDS (not if-blocks) can read them: e.g. expression `rep_mirror_choir >= 15`.
	Reputation.reputation_changed.connect(
		func(faction: String, standing: float, _e: ReputationEvent) -> void:
			chart.set_expression_property("rep_" + faction.replace("-", "_"), standing)
	)

	$StateChart/Root/Menus/Title.state_entered.connect(_on_title_entered)
	$StateChart/Root/Menus/CharacterCreation.state_entered.connect(_on_character_creation_entered)
	$StateChart/Root/Menus/CharacterCreation.state_exited.connect(_on_character_creation_exited)
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
func travel(scene_path: String, spawn_id: StringName = &"default") -> bool:
	var location := LocationRegistry.by_scene(scene_path)
	if location == null or not location.allowed_gameplay:
		push_error("Refusing travel to non-gameplay scene: %s" % scene_path)
		return false
	var destination := LoadDestination.new(location.id, location.resolve_spawn(spawn_id))
	SaveGame.pending_spawn_id = destination.spawn_id
	SaveGame.has_pending_player_position = false
	return load_destination(destination)


## Validates and purchases a discovered-hub trip as one operation. The optional
## scene path is a deterministic test seam; production callers omit it.
func fast_travel(hub_id: StringName, current_scene_path: String = "") -> Dictionary:
	if _fast_travel_in_progress:
		return {"ok": false, "error": "travel_in_progress"}
	var hub := FastTravelRegistry.by_id(hub_id)
	if hub.is_empty():
		return {"ok": false, "error": "unknown_destination"}
	if not GameState.is_fast_travel_hub_discovered(hub_id):
		return {"ok": false, "error": "undiscovered"}
	var current_path := current_scene_path
	if current_path.is_empty():
		var current := get_tree().current_scene
		current_path = current.scene_file_path if current != null else ""
	if current_path == hub["scene_path"]:
		return {"ok": false, "error": "current_destination"}
	var cost := int(hub["base_cost_gp"])
	if not GameState.can_afford(cost):
		return {"ok": false, "error": "insufficient_gp"}
	if not GameState.spend_gp(cost):
		return {"ok": false, "error": "purchase_failed"}
	_pending_fast_travel_cost = cost
	_fast_travel_in_progress = true
	if get_tree().paused:
		send_event("resume")
	if not travel(str(hub["scene_path"])):
		_refund_pending_fast_travel()
		return {"ok": false, "error": "route_rejected"}
	return {"ok": true, "cost_gp": cost, "destination": hub_id}


## Resolves a stable destination into GameFlow-owned scene state and asks the
## chart to enter its existing loading transition.
func load_destination(destination: LoadDestination) -> bool:
	var location := LocationRegistry.by_id(destination.location_id)
	if location == null or not location.allowed_gameplay:
		push_error("Refusing load of unknown gameplay location: %s" % destination.location_id)
		return false
	_target_scene = location.scene_path
	_target_spawn_id = location.resolve_spawn(destination.spawn_id)
	send_event("travel")
	return true


func notify_dialogue_closed() -> void:
	if ChapterOneProgress.current_stage() == ChapterOneProgress.Stage.COMPLETE:
		send_event.call_deferred("chapter_complete")


# --- state handlers (policy → mechanism) --------------------------------------


func _on_title_entered() -> void:
	UIManager.close_all()
	MusicDirector.play_context("title")
	var cur := get_tree().current_scene
	if cur == null or cur.scene_file_path != MAIN_MENU_SCENE:
		SceneLoader.load_scene(MAIN_MENU_SCENE)


func _on_character_creation_entered() -> void:
	UIManager.open(CHARACTER_CREATION_SCREEN, false, true)


func _on_character_creation_exited() -> void:
	UIManager.close_all()


func _on_loading_entered() -> void:
	var current := get_tree().current_scene
	if current != null and current.scene_file_path != LOADING_SCREEN:
		_loading_fallback_scene = current.scene_file_path
	_waiting_for_level = true
	SceneLoader.load_scene(_target_scene)


func _on_scene_loaded() -> void:
	pass  # completion is polled in _process(); Maaack replaces current_scene on a
	# deferred turn after this signal, so a one-shot call here can run too early
	# and never get retried — poll instead of racing it.


func _process(_delta: float) -> void:
	if not _waiting_for_level:
		return
	var status := SceneLoader.get_status()
	if status in [
		ResourceLoader.THREAD_LOAD_INVALID_RESOURCE,
		ResourceLoader.THREAD_LOAD_FAILED,
	]:
		_handle_scene_load_failure()
		return
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == _target_scene:
		_complete_scene_load()


func _complete_scene_load() -> void:
	if not _waiting_for_level:
		return
	_waiting_for_level = false
	_loading_fallback_scene = ""
	var current := get_tree().current_scene
	if _recovering_from_failure:
		# We're only back at the fallback scene after a failed load, not a
		# genuine arrival — skip apply_pending_location/hub discovery and just
		# surface the failure for the next screen that can report it.
		_recovering_from_failure = false
		send_event("level_ready")
		MusicDirector.play_context("field")
		if not last_travel_error.is_empty():
			UIManager.open(UIManager.REGION_MAP)
		return
	SaveGame.apply_pending_location(current)
	var hub := FastTravelRegistry.by_scene(_target_scene)
	if not hub.is_empty():
		GameState.discover_fast_travel_hub(StringName(hub["id"]))
	_pending_fast_travel_cost = 0
	_fast_travel_in_progress = false
	last_travel_error = ""
	send_event("level_ready")
	MusicDirector.play_context("field")
	SaveGame.flush_pending_autosave.call_deferred()
	if ChapterOneProgress.current_stage() == ChapterOneProgress.Stage.COMPLETE:
		notify_dialogue_closed()


func _handle_scene_load_failure() -> void:
	push_error("Failed to load gameplay scene: %s" % _target_scene)
	_refund_pending_fast_travel()
	last_travel_error = "scene_load_failed"
	if not _loading_fallback_scene.is_empty() and _loading_fallback_scene != _target_scene:
		_target_scene = _loading_fallback_scene
		_recovering_from_failure = true
		SceneLoader.load_scene(_target_scene)
		return
	# No known-good scene to fall back to (e.g. the very first boot load) —
	# nothing plausible to recover into; leave in Loading rather than fake a
	# successful transition to nothing.
	_waiting_for_level = false


func _refund_pending_fast_travel() -> void:
	_fast_travel_in_progress = false
	if _pending_fast_travel_cost <= 0:
		return
	GameState.earn_gp(_pending_fast_travel_cost)
	_pending_fast_travel_cost = 0


func _on_paused_entered() -> void:
	get_tree().paused = true
	UIManager.open(PAUSE_MENU, false, true)


func _on_paused_exited() -> void:
	UIManager.close_all()
	get_tree().paused = false


func _on_battle_entered() -> void:
	get_tree().paused = true
	MusicDirector.push_context("battle")
	UIManager.open(BATTLE_SCREEN, false, true)


func _on_battle_exited() -> void:
	UIManager.close_all()
	get_tree().paused = false
	MusicDirector.pop_context()
	SaveGame.flush_pending_autosave.call_deferred()


func _on_chapter_complete_entered() -> void:
	get_tree().paused = true
	MusicDirector.push_context("chapter_complete")
	UIManager.open(CHAPTER_COMPLETE_SCREEN, false, true)


func _on_chapter_complete_exited() -> void:
	UIManager.close_all()
	get_tree().paused = false
	MusicDirector.pop_context()
