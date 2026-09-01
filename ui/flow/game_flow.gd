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
##   │   ├── CharacterCreation     the Register of Persons (#98/#129) — new-game only
##   │   └── IntroNarration        provisional opening beats — new-game only;
##   │                             "Continue" skips both states (save already has a character)
##   └── Playing
##       ├── Loading               calls loader for `_target_scene`; leaves on "level_ready"
##       ├── Active                re-enters Loading on "travel" (see travel())
##       ├── Paused                pause overlay + tree pause live here
##       └── Battle                battle overlay + tree pause live here (combat scaffold)
##
## Events: boot_done · start_chargen · new_game · intro_done · level_ready · pause ·
##         resume · to_main_menu · enter_battle · battle_end · travel

const MAIN_MENU_SCENE := "res://ui/screens/main_menu.tscn"
## The starting town (Dom) — the first gameplay scene loaded on a new game.
const TOWN_SCENE := "res://world/starting_town.tscn"
## New games enter the opening gauntlet here after the narration. Save loading
## keeps its resolved destination and bypasses this target entirely.
const TRIAL_SCENE := "res://world/interiors/lower_trial_hall.tscn"
## The original field/wilds vertical slice (Iris, Bog Wight, the Loamroot fetch
## quest) — now reached from the town via a TravelExit, not booted directly.
const WILDS_SCENE := "res://world/test_room.tscn"
const DORTHKOR_SCENE := "res://world/dorthkor_road.tscn"
const WOUND_LIP_SCENE := "res://world/wound_lip.tscn"
const TAVERN_SCENE := "res://world/interiors/dom_tavern.tscn"
## Authored reputation-gated doorways → the chart expression property whose
## guard decides them. Keyed by the authored definition itself, so the id,
## destination and band requirement are all READ from the .tres rather than
## copied here. Add a row plus a guarded transition pair in the chart; never
## add a threshold literal to the .tscn.
const AREA_ACCESS_TRANSITIONS := {
	BuildingTransitionRegistry.GARRISON_YARD_ENTER: &"garrison_access_granted",
}
## Derived from the authored transition, never restated. Renaming the .tres id
## or repointing its destination moves these with it.
static var GARRISON_YARD_TRANSITION_ID: StringName = (
	BuildingTransitionRegistry.GARRISON_YARD_ENTER.id
)
static var GARRISON_YARD_SCENE: String = (
	BuildingTransitionRegistry.GARRISON_YARD_ENTER.destination_scene
)
## Every scene UIManager should treat as "in gameplay" (see _in_gameplay()).
var GAMEPLAY_SCENES: Array[String] = _gameplay_scenes()
## Project-owned, DS-styled scene running the Maaack LoadingScreen script —
## replaces the addon's stock grey screen (never edit the addon itself).
const LOADING_SCREEN := "res://ui/flow/loading_screen.tscn"
const PAUSE_MENU := preload("res://ui/screens/pause_menu.tscn")
const CHARACTER_CREATION_SCREEN := preload("res://ui/screens/character_creation.tscn")
const INTRO_NARRATION_SCREEN := preload("res://ui/screens/intro_narration.tscn")
const DEPLOYMENT_SCREEN := preload("res://ui/screens/deployment/deployment.tscn")
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
var _pending_area_scene := ""
var _pending_area_spawn: StringName = &"default"
var _area_access_result := -1
var travel_plan: TravelPlan = null

@onready var chart: StateChart = $StateChart


static func _gameplay_scenes() -> Array[String]:
	# The tavern interior is registered in LocationRegistry like every other
	# interior, so the registry is the single source of gameplay scenes.
	return LocationRegistry.gameplay_scenes()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_restore_travel_plan()
	if not Battle.battle_ended.is_connected(_on_journey_battle_ended):
		Battle.battle_ended.connect(_on_journey_battle_ended)
	# Local visual-regression captures can launch a gameplay scene directly
	# without the Boot state immediately replacing it with the title screen.
	if OS.get_cmdline_user_args().has("capture-scene"):
		return
	SceneLoader.set_loading_screen(LOADING_SCREEN)
	SceneLoader.scene_loaded.connect(_on_scene_loaded)
	if not SaveGame.load_requested.is_connected(_on_load_requested):
		SaveGame.load_requested.connect(_on_load_requested)
	# Mirror derived standings into chart expression properties so transition
	# GUARDS (not if-blocks) can read them: e.g. expression `rep_mirror_choir >= 15`.
	Reputation.reputation_changed.connect(
		func(faction: String, standing: float, _e: ReputationEvent) -> void:
			chart.set_expression_property("rep_" + faction.replace("-", "_"), standing)
			_sync_reputation_guards()
	)
	_sync_reputation_guards()

	$StateChart/Root/Menus/Title.state_entered.connect(_on_title_entered)
	$StateChart/Root/Menus/CharacterCreation.state_entered.connect(_on_character_creation_entered)
	$StateChart/Root/Menus/CharacterCreation.state_exited.connect(_on_character_creation_exited)
	$StateChart/Root/Menus/IntroNarration.state_entered.connect(_on_intro_narration_entered)
	$StateChart/Root/Menus/IntroNarration.state_exited.connect(_on_intro_narration_exited)
	$StateChart/Root/Playing/Loading.state_entered.connect(_on_loading_entered)
	$StateChart/Root/Playing/Active/ToGarrisonLoading.taken.connect(
		_on_area_access_allowed
	)
	$StateChart/Root/Playing/Active/RefuseGarrison.taken.connect(
		_on_area_access_refused
	)
	# A queued area-access event that never drains while Active would otherwise
	# leave its destination staged indefinitely, and a second such request would
	# overwrite the first's staging before either handler consumed it. Leaving
	# Active means no guarded area transition can still fire, so the staging is
	# dead by definition.
	$StateChart/Root/Playing/Active.state_exited.connect(_clear_pending_area)
	$StateChart/Root/Playing/Paused.state_entered.connect(_on_paused_entered)
	$StateChart/Root/Playing/Paused.state_exited.connect(_on_paused_exited)
	var deployment_states := [
		$StateChart/Root/Playing/DeploymentSlate,
		$StateChart/Root/Playing/DeploymentAttune,
		$StateChart/Root/Playing/DeploymentLoadout,
		$StateChart/Root/Playing/DeploymentPlace,
	]
	for index: int in deployment_states.size():
		deployment_states[index].state_entered.connect(_on_deployment_entered.bind(index))
		deployment_states[index].state_exited.connect(_on_deployment_exited)
	$StateChart/Root/Playing/Battle.state_entered.connect(_on_battle_entered)
	$StateChart/Root/Playing/Battle.state_exited.connect(_on_battle_exited)
	$StateChart/Root/Playing/ChapterComplete.state_entered.connect(_on_chapter_complete_entered)
	$StateChart/Root/Playing/ChapterComplete.state_exited.connect(_on_chapter_complete_exited)

	# Boot is where splash/config-load will live; nothing to wait on yet.
	send_event.call_deferred("boot_done")


## The single entry point UI code uses to talk to the chart.
func send_event(event: StringName) -> void:
	chart.send_event(event)


func start_journey(origin_id: StringName, destination_id: StringName) -> bool:
	var route := WorldMapRegistry.route_between(origin_id, destination_id)
	if route.is_empty():
		return false
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.randomize()
	var plan := TravelPlan.new()
	plan.origin_id = origin_id
	plan.destination_id = destination_id
	plan.total_steps = maxi(int(route.get("steps", 0)), 0)
	plan.rng_seed = seed_rng.randi()
	plan.encounter_schedule = EncounterDirector.build_schedule(route, plan.rng_seed)
	travel_plan = plan
	_persist_travel_plan()
	return true


func advance_journey(steps: int = 1) -> Dictionary:
	if travel_plan == null or travel_plan.state != TravelPlan.State.EN_ROUTE:
		return {}
	# A multi-step advance can never carry the party past an unresolved
	# encounter boundary (or the destination): clamp to the first unresolved
	# slot's at_step so every scheduled interruption fires at its own step.
	var target_step := mini(
		travel_plan.progress_step + maxi(steps, 0), travel_plan.total_steps
	)
	for slot: Dictionary in travel_plan.encounter_schedule:
		if not bool(slot.get("resolved", false)):
			target_step = mini(target_step, int(slot.get("at_step", 0)))
			break
	travel_plan.progress_step = maxi(target_step, travel_plan.progress_step)
	var route := _journey_route()
	var slot_index := _next_reached_slot_index()
	if slot_index >= 0:
		travel_plan.state = TravelPlan.State.AVOID_PROMPT
		_persist_travel_plan()
		var slot: Dictionary = travel_plan.encounter_schedule[slot_index]
		return {
			"event": "encounter_prompt",
			"encounter_id": StringName(slot["encounter_id"]),
			"avoidance_chance": EncounterDirector.avoidance_chance(route, GameState.party),
		}
	if travel_plan.progress_step >= travel_plan.total_steps:
		travel_plan.state = TravelPlan.State.ARRIVED
		var phases_cost := maxi(int(route.get("phases_cost", 0)), 0)
		travel_plan.elapsed_phases += phases_cost
		_persist_travel_plan()
		var destination := WorldMapRegistry.location(travel_plan.destination_id)
		if not destination.is_empty() and travel(str(destination["scene_path"])):
			# travel() owns one declared clock advance. The remaining route phases
			# are added here so a journey costs exactly phases_cost in total.
			for phase_index: int in range(1, phases_cost):
				WorldClock.advance(
					"journey:%s:%d" % [travel_plan.destination_id, phase_index + 1]
				)
		return {"event": "arrived"}
	_persist_travel_plan()
	return {
		"event": "en_route",
		"progress_step": travel_plan.progress_step,
		"total_steps": travel_plan.total_steps,
	}


func resolve_encounter_prompt(avoid: bool) -> Dictionary:
	if travel_plan == null or travel_plan.state != TravelPlan.State.AVOID_PROMPT:
		return {}
	var slot_index := _next_reached_slot_index()
	if slot_index < 0:
		return {}
	var route := _journey_route()
	if avoid:
		var chance := EncounterDirector.avoidance_chance(route, GameState.party)
		if _avoidance_succeeds(slot_index, chance):
			travel_plan.encounter_schedule[slot_index]["resolved"] = true
			travel_plan.state = TravelPlan.State.EN_ROUTE
			_persist_travel_plan()
			return {"event": "avoided"}
	travel_plan.state = TravelPlan.State.IN_BATTLE
	_persist_travel_plan()
	var encounter_id := StringName(travel_plan.encounter_schedule[slot_index]["encounter_id"])
	Battle.start(encounter_id)
	if not Battle.ended:
		send_event("enter_battle")
	return {"event": "battle_started"}


func cancel_journey() -> void:
	if travel_plan == null or travel_plan.state not in [
		TravelPlan.State.EN_ROUTE, TravelPlan.State.AVOID_PROMPT
	]:
		return
	var origin := WorldMapRegistry.location(travel_plan.origin_id)
	travel_plan.state = TravelPlan.State.CANCELLED
	_persist_travel_plan()
	if not origin.is_empty():
		travel(str(origin["scene_path"]))
	travel_plan = null
	_persist_travel_plan()


func _avoidance_succeeds(slot_index: int, chance: float) -> bool:
	# Avoidance owns one independent RNG stream per schedule slot. Its seed is
	# plan.rng_seed + zero-based slot index, so saving/reloading never rerolls it.
	var rng := RandomNumberGenerator.new()
	rng.seed = travel_plan.rng_seed + slot_index
	return rng.randf_range(0.0, 100.0) < chance


func _next_reached_slot_index() -> int:
	return travel_plan.next_unresolved_reached_index() if travel_plan != null else -1


func _journey_route() -> Dictionary:
	if travel_plan == null:
		return {}
	return WorldMapRegistry.route_between(travel_plan.origin_id, travel_plan.destination_id)


func _persist_travel_plan() -> void:
	GameState.travel_plan = travel_plan.to_dict() if travel_plan != null else {}


func _restore_travel_plan() -> void:
	travel_plan = (
		TravelPlan.from_dict(GameState.travel_plan)
		if not GameState.travel_plan.is_empty()
		else null
	)
	if travel_plan == null:
		return
	if travel_plan.state in [TravelPlan.State.ARRIVED, TravelPlan.State.CANCELLED]:
		# A finished journey has nothing to resume; keep the envelope clean.
		travel_plan = null
	else:
		travel_plan.reconcile()
	_persist_travel_plan()


func _on_load_requested(destination: LoadDestination) -> void:
	_restore_travel_plan()
	# Reputation.from_dict() restores standings without emitting change signals,
	# so refresh chart-owned access guards after the save payload is applied.
	_sync_reputation_guards()
	load_destination(destination)


## Mirrors each authored reputation gate into the chart as a DERIVED BOOLEAN.
##
## The chart owns the access decision, but it must not own a copy of the data
## behind it: an expression like `rep_iron_companies >= 15.0` duplicates both the
## authored `minimum_reputation_band` on the transition .tres AND the band
## thresholds in Reputation, so either could be rebalanced without moving the
## gate. Comparing bands here — where the authored requirement is read — keeps
## exactly one source of truth for the data and one for the decision.
func _sync_reputation_guards() -> void:
	for transition: BuildingTransitionDefinition in AREA_ACCESS_TRANSITIONS:
		var granted := Reputation.band_at_least(
			transition.reputation_faction, transition.minimum_reputation_band
		)
		chart.set_expression_property(AREA_ACCESS_TRANSITIONS[transition], granted)


func _on_journey_battle_ended(result: BattleResult) -> void:
	if travel_plan == null or travel_plan.state != TravelPlan.State.IN_BATTLE:
		return
	if not result.succeeded():
		travel_plan.state = TravelPlan.State.AVOID_PROMPT
		_persist_travel_plan()
		return
	var slot_index := _next_reached_slot_index()
	if slot_index < 0:
		return
	var slot: Dictionary = travel_plan.encounter_schedule[slot_index]
	slot["resolved"] = true
	if not bool(slot.get("spoils_granted", false)):
		# Travel owns a save-stable per-slot RNG stream, so it replaces the generic
		# encounter roll on the shared result before the battle screen presents it.
		# Closing that transient panel forfeits leftovers: there is no world container
		# to revisit while the route resumes, and the exactly-once bit prevents rerolls.
		result.spoils = SpoilsTable.roll(
			StringName(slot["encounter_id"]), travel_plan.rng_seed, slot_index
		)
		slot["spoils_granted"] = true
	travel_plan.state = TravelPlan.State.EN_ROUTE
	_persist_travel_plan()


## The single entry point for moving between gameplay scenes (e.g. a
## TravelExit) — never call SceneLoader or change_scene_to_file() directly
## from game code (see the header note above).
func travel(scene_path: String, spawn_id: StringName = &"default") -> bool:
	var location := LocationRegistry.by_scene(scene_path)
	if location == null:
		if not GAMEPLAY_SCENES.has(scene_path):
			push_error("Refusing travel to non-gameplay scene: %s" % scene_path)
			return false
		if not _travel_to_gameplay_scene(scene_path, spawn_id):
			return false
		WorldClock.advance("travel:%s" % scene_path)
		return true
	if not location.allowed_gameplay:
		push_error("Refusing travel to non-gameplay scene: %s" % scene_path)
		return false
	var destination := LoadDestination.new(location.id, location.resolve_spawn(spawn_id))
	SaveGame.pending_spawn_id = destination.spawn_id
	SaveGame.has_pending_player_position = false
	# FR-504a §3.1: travel is a declared clock trigger. The advance lives HERE,
	# not in load_destination(), because SaveGame's load path also routes
	# through load_destination() and loading a save must not spend the day.
	if not load_destination(destination):
		return false
	WorldClock.advance("travel:%s" % scene_path)
	return true


func _travel_to_gameplay_scene(scene_path: String, spawn_id: StringName) -> bool:
	SaveGame.pending_spawn_id = spawn_id
	SaveGame.has_pending_player_position = false
	_target_scene = scene_path
	_target_spawn_id = spawn_id
	send_event("travel")
	return true


## Sends the one authored reputation-gated doorway through the chart. The
## transition guard owns the decision; this method only stages the destination
## and observes which guarded transition was taken.
func request_area_access(
	transition_id: StringName, scene_path: String, spawn_id: StringName
) -> bool:
	var gated := _area_access_transition(transition_id)
	if gated == null:
		push_error("Unknown reputation-gated area transition: %s" % transition_id)
		return false
	var location := LocationRegistry.by_scene(scene_path)
	if location == null or not location.allowed_gameplay:
		push_error("Refusing area access to non-gameplay scene: %s" % scene_path)
		return false
	_pending_area_scene = location.scene_path
	_pending_area_spawn = location.resolve_spawn(spawn_id)
	_area_access_result = -1
	send_event(&"garrison_yard_access")
	if _area_access_result == -1:
		if bool(($StateChart/Root/Playing/Active as Node).get("active")):
			# Active IS the guarded pair's source state, so the event matched and
			# was merely QUEUED (the chart was mid-transition). Emulating the
			# decision now would race the real transition. Refuse this call —
			# deliberately without advancing WorldClock — and leave the staged
			# destination in place so the queued transition still finds it.
			push_error(
				"Area access event was queued rather than processed; refusing this "
				+ "call rather than racing the chart: %s" % transition_id
			)
			return false
		if bool(($StateChart/Root/Playing as Node).get("active")):
			# A REAL gameplay state that simply is not Active: Loading, Paused,
			# Battle, Deployment, ChapterComplete. "Not Active" does NOT mean
			# "detached", and treating it that way would let an allowed request
			# rewrite _target_scene and SaveGame's pending spawn mid-load, so
			# the stored destination disagrees with the scene already loading.
			# Travel is an Active-only behaviour; refuse everywhere else.
			push_error(
				"Area access requested from a non-Active gameplay state; refusing: %s"
				% transition_id
			)
			_on_area_access_refused()
			return false
		# Not inside Playing at all: a detached gameplay scene (the interior
		# round-trip fixtures), where no chart transition can fire. travel()
		# already tolerates this, and area access must match that contract or
		# the same door behaves differently by caller. The decision still comes
		# from the AUTHORED guard resource — this asks the chart's own guard
		# rather than re-deriving the rule in GDScript, so the band logic
		# continues to live in exactly one place.
		var access_transition := (
			$StateChart/Root/Playing/Active/ToGarrisonLoading as Transition
		)
		if access_transition.evaluate_guard():
			_on_area_access_allowed()
		else:
			_on_area_access_refused()
	var accepted := _area_access_result == 1
	if accepted:
		WorldClock.advance("travel:%s" % scene_path)
	return accepted


## Looks up an authored reputation-gated transition by its .tres id.
func _area_access_transition(transition_id: StringName) -> BuildingTransitionDefinition:
	for transition: BuildingTransitionDefinition in AREA_ACCESS_TRANSITIONS:
		if transition.id == transition_id:
			return transition
	return null


func _on_area_access_allowed() -> void:
	if _pending_area_scene.is_empty():
		# A transition taken outside an in-flight request_area_access() has no
		# staged destination; applying it would blank _target_scene.
		push_error("Area access allowed with no pending destination; ignoring.")
		return
	_area_access_result = 1
	_target_scene = _pending_area_scene
	_target_spawn_id = _pending_area_spawn
	SaveGame.pending_spawn_id = _pending_area_spawn
	SaveGame.has_pending_player_position = false
	_clear_pending_area()


func _on_area_access_refused() -> void:
	_area_access_result = 0
	_clear_pending_area()


## The staged destination is consumed by whichever guarded transition is taken,
## so it is cleared there rather than by the requesting call — a queued event
## that fires after request_area_access() returns must still find it.
func _clear_pending_area() -> void:
	_pending_area_scene = ""
	_pending_area_spawn = &"default"


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
	if not destination.scene_path.is_empty():
		if not GAMEPLAY_SCENES.has(destination.scene_path):
			push_error("Refusing load of unknown gameplay scene: %s" % destination.scene_path)
			return false
		_target_scene = destination.scene_path
		_target_spawn_id = destination.spawn_id
		send_event("travel")
		return true
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


func _on_intro_narration_entered() -> void:
	_target_scene = TRIAL_SCENE
	_target_spawn_id = &"entry"
	UIManager.open(INTRO_NARRATION_SCREEN, false, true)


func _on_intro_narration_exited() -> void:
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
	for map_location: Dictionary in WorldMapRegistry.all_locations():
		if str(map_location.get("scene_path", "")) == _target_scene:
			GameState.discover_world_location(StringName(map_location["id"]))
			break
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


func _on_deployment_entered(step: int) -> void:
	get_tree().paused = true
	var screen := UIManager.open(DEPLOYMENT_SCREEN, false, true) as DeploymentScreen
	if screen != null:
		screen.configure_step(step)
		# Battle.start() has already run by the time the chart enters deployment (the
		# Enemy trigger starts the battle, then sends "enter_battle"), so the PLACE
		# step hands the screen the LIVE battlefield model — place_unit() writes real
		# spawn positions instead of refusing on deployment_context (#202).
		if step == DeploymentScreen.Step.PLACE and Battle.controller != null:
			screen.configure_placement(Battle.controller.battlefield, Battle.current_ally())


func _on_deployment_exited() -> void:
	UIManager.close_all()


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
