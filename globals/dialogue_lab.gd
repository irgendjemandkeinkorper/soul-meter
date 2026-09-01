extends Node
## Debug-only dialogue replay sandbox. Disabled builds remain completely inert.

const DIALOGUE_LAB_SCENE := preload("res://ui/debug/dialogue_lab.tscn")
const DIALOGUE_DIRECTORIES: Array[String] = [
	"res://dialogue",
	"res://dialogue/companions",
]
const TOGGLE_HOTKEY: Key = KEY_F5
const ENVIRONMENT_VARIABLE: String = "SOUL_METER_DIALOGUE_LAB"
const REFUSAL_WARNING := "Dialogue Lab refuses to open or replay over live production content."

var force_enabled_for_tests: bool = false:
	set(value):
		force_enabled_for_tests = value
		_refresh_activation()

var _enabled: bool = false
var _dialogue_signals_connected: bool = false
var _overlay_layer: CanvasLayer = null
var _panel: Control = null
var _previous_paused: bool = false
var _restore_pause_on_close: bool = false
var _setup: Dictionary = {}
var _current_resource: DialogueResource = null
var _lab_balloon: Node = null
var _lab_dialogue_running: bool = false
var _production_dialogue_running: bool = false

var _runtime_before: Dictionary = {}
var _rng_seed_before: int = 0
var _rng_state_before: int = 0
var _has_saved_state: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(false)
	_refresh_activation()


func _exit_tree() -> void:
	_shutdown()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _enabled or not event is InputEventKey:
		return
	var key_event: InputEventKey = event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != TOGGLE_HOTKEY and key_event.keycode != TOGGLE_HOTKEY:
		return
	if _overlay_layer == null:
		if _ownership_conflict_is_live():
			push_warning(REFUSAL_WARNING)
			return
		if _setup.is_empty():
			open_setup()
		else:
			_open_overlay(true)
	else:
		close_overlay()
	get_viewport().set_input_as_handled()


func is_enabled() -> bool:
	return _enabled


## True while a battle the dialogue lab did not start is live.
func production_battle_is_live() -> bool:
	return Battle.controller != null and not Battle.ended


## True while a Dialogue Manager balloon the lab does not own is live.
func production_dialogue_is_live() -> bool:
	if _production_dialogue_running:
		return true
	var current_scene: Node = null
	if DialogueManager.get_current_scene.is_valid():
		current_scene = DialogueManager.get_current_scene.call() as Node
	return current_scene != null and _contains_other_dialogue_balloon(current_scene)


func open_setup() -> void:
	if not _enabled or _overlay_layer != null or _lab_dialogue_running:
		return
	if _ownership_conflict_is_live():
		push_warning(REFUSAL_WARNING)
		return
	_previous_paused = get_tree().paused
	get_tree().paused = true
	_restore_pause_on_close = true
	_open_overlay(false)


func close_overlay() -> void:
	if not _enabled:
		return
	_close_overlay()


func dialogue_files() -> Array[String]:
	var result: Array[String] = []
	if not _enabled:
		return result
	for directory: String in DIALOGUE_DIRECTORIES:
		for file_name: String in DirAccess.get_files_at(directory):
			if file_name.get_extension() == "dialogue":
				result.append(directory.path_join(file_name))
	result.sort()
	return result


func titles_for_file(path: String) -> Array[String]:
	var result: Array[String] = []
	if not _enabled or not _is_allowed_dialogue_path(path):
		return result
	var resource := ResourceLoader.load(
		path, "", ResourceLoader.CACHE_MODE_IGNORE
	) as DialogueResource
	if resource == null:
		return result
	for cue: String in resource.get_cues():
		result.append(cue)
	result.sort()
	return result


## Production replay entry point used by the setup screen.
func start_replay(requested_setup: Dictionary) -> void:
	if not _enabled or _ownership_conflict_is_live():
		return
	_start_session(requested_setup, true, false)


## Test seam: runs the same snapshot and setup lifecycle without opening a balloon.
func start_test_session(requested_setup: Dictionary) -> void:
	if not _enabled or _ownership_conflict_is_live():
		return
	_start_session(requested_setup, false, false)


func replay_same_state() -> void:
	if not _enabled or _setup.is_empty() or _ownership_conflict_is_live():
		return
	_start_session(_setup, true, false)


func reload_and_replay() -> void:
	if not _enabled or _setup.is_empty() or _ownership_conflict_is_live():
		return
	_start_session(_setup, true, true)


func end_session() -> void:
	if not _enabled:
		return
	_end_session()


func current_setup() -> Dictionary:
	if not _enabled:
		return {}
	return _setup.duplicate(true)


func _start_session(
	requested_setup: Dictionary, launch_dialogue: bool, reload_from_disk: bool
) -> void:
	if requested_setup.is_empty():
		return
	_dismiss_owned_dialogue()
	# Every session begins armed. Restore and capture are an unconditional pair:
	# restore is a no-op when nothing is armed, while capture must still happen
	# for a restarted session after the previous snapshot was disarmed.
	_restore_saved_state()
	_capture_saved_state()
	_setup = _normalize_setup(requested_setup)
	var path := str(_setup.get("dialogue_path", ""))
	var title := str(_setup.get("title", ""))
	var cache_mode := (
		ResourceLoader.CACHE_MODE_IGNORE
		if reload_from_disk
		else ResourceLoader.CACHE_MODE_REUSE
	)
	var resource := ResourceLoader.load(path, "", cache_mode) as DialogueResource
	if resource == null or title.is_empty() or not resource.get_cues().has(title):
		push_warning("Dialogue Lab could not load '%s' at title '%s'." % [path, title])
		_restore_saved_state()
		return
	_current_resource = resource
	_apply_setup_state(_setup)
	if not launch_dialogue:
		return
	_close_overlay()
	_lab_dialogue_running = true
	_lab_balloon = DialogueManager.show_dialogue_balloon(resource, title)
	if _lab_balloon == null:
		_lab_dialogue_running = false
		_restore_saved_state()
		return
	_lab_balloon.tree_exited.connect(_on_lab_balloon_exited.bind(_lab_balloon), CONNECT_ONE_SHOT)
	_open_overlay(true)


func _normalize_setup(requested_setup: Dictionary) -> Dictionary:
	var normalized := requested_setup.duplicate(true)
	normalized["dialogue_path"] = str(normalized.get("dialogue_path", ""))
	normalized["title"] = str(normalized.get("title", ""))
	if not normalized.get("flags", {}) is Dictionary:
		normalized["flags"] = {}
	if not normalized.get("reputation", {}) is Dictionary:
		normalized["reputation"] = {}
	return normalized


func _apply_setup_state(setup: Dictionary) -> void:
	var flags: Dictionary = setup.get("flags", {})
	for key: Variant in flags:
		var flag_name := str(key).strip_edges()
		if not flag_name.is_empty():
			GameState.set_flag(flag_name, bool(flags[key]))
	var reputation: Dictionary = setup.get("reputation", {})
	for key: Variant in reputation:
		var faction := str(key).strip_edges()
		if faction.is_empty():
			continue
		var target := float(reputation[key])
		var delta := target - Reputation.standing(faction)
		if not is_zero_approx(delta):
			Reputation.record(
				"dialogue-lab", faction, delta, "Dialogue Lab seeded standing", "dialogue-lab"
			)
	if setup.has("renown_reputation"):
		var reputation_delta := float(setup["renown_reputation"]) - Renown.reputation()
		if not is_zero_approx(reputation_delta):
			Renown.gain_reputation(
				"dialogue-lab", reputation_delta, "Dialogue Lab seeded Renown", "dialogue-lab"
			)
	if setup.has("renown_infamy"):
		var infamy_delta := float(setup["renown_infamy"]) - Renown.infamy()
		if not is_zero_approx(infamy_delta):
			Renown.gain_infamy(
				"dialogue-lab", infamy_delta, "Dialogue Lab seeded Renown", "dialogue-lab"
			)


func _capture_saved_state() -> void:
	# SaveGame owns the authoritative list of rollback-able runtime state. An
	# earlier version of this lab enumerated five globals here and missed four,
	# so replayed dialogue could permanently raise the Zhavar and stage a real
	# autosave of sandbox state. Never re-enumerate the surfaces locally.
	_runtime_before = SaveGame.capture_runtime_state()
	# Not part of that snapshot: SkillCheck.to_dict() serializes reroll usage,
	# not the generator's position, so an uncaptured session would permanently
	# shift the randomness later campaign skill checks draw from.
	_rng_seed_before = SkillCheck.random_number_generator.seed
	_rng_state_before = SkillCheck.random_number_generator.state
	# Dialogue writes consequences, and several QuestRegistry mutators reachable
	# from a `do` line stage an autosave that flushes DEFERRED — while the next
	# dialogue line is still open, long before the session ends. Suppression, not
	# restore ordering, is what keeps sandbox state off the player's disk.
	SaveGame.begin_runtime_sandbox()
	_has_saved_state = true


## Restores exactly once per session, then disarms.
func _restore_saved_state() -> void:
	if not _has_saved_state:
		return
	_has_saved_state = false
	if not SaveGame.restore_runtime_state(_runtime_before):
		push_warning("Dialogue Lab could not restore the pre-lab GameState snapshot.")
	# Assigning seed resets state, so the order is load-bearing.
	SkillCheck.random_number_generator.seed = _rng_seed_before
	SkillCheck.random_number_generator.state = _rng_state_before
	SaveGame.end_runtime_sandbox()


func _on_dialogue_started(resource: DialogueResource) -> void:
	if not _enabled:
		return
	if _lab_dialogue_running and resource == _current_resource:
		return
	_production_dialogue_running = true


func _on_dialogue_ended(resource: DialogueResource) -> void:
	if not _enabled:
		return
	if _lab_dialogue_running and resource == _current_resource:
		_lab_dialogue_running = false
		_restore_saved_state()
		_update_panel()
	else:
		_production_dialogue_running = false


func _on_lab_balloon_exited(balloon: Node) -> void:
	if balloon != _lab_balloon:
		return
	_lab_balloon = null
	if _lab_dialogue_running:
		_lab_dialogue_running = false
		_restore_saved_state()
	_update_panel()


func _connect_dialogue_signals() -> void:
	if not _enabled or _dialogue_signals_connected:
		return
	DialogueManager.dialogue_started.connect(_on_dialogue_started)
	DialogueManager.dialogue_ended.connect(_on_dialogue_ended)
	_dialogue_signals_connected = true


func _disconnect_dialogue_signals() -> void:
	if not _dialogue_signals_connected:
		return
	if DialogueManager.dialogue_started.is_connected(_on_dialogue_started):
		DialogueManager.dialogue_started.disconnect(_on_dialogue_started)
	if DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.disconnect(_on_dialogue_ended)
	_dialogue_signals_connected = false


func _open_overlay(replay_controls: bool) -> void:
	if not _enabled or _overlay_layer != null:
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "DialogueLabLayer"
	_overlay_layer.layer = 1150
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)
	_panel = DIALOGUE_LAB_SCENE.instantiate() as Control
	_panel.name = "DialogueLabOverlay"
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_layer.add_child(_panel)
	_panel.call("configure", self, replay_controls)
	_update_panel()


func _update_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.call("update_replay_controls", _lab_dialogue_running, _setup)


func _close_overlay() -> void:
	if _overlay_layer == null:
		return
	var layer: CanvasLayer = _overlay_layer
	var restore_pause := _restore_pause_on_close
	_overlay_layer = null
	_panel = null
	_restore_pause_on_close = false
	# Detached synchronously so the lab's own state is consistent the instant
	# this returns, but freed deferred: every caller is a button `pressed`
	# handler on a node this layer owns, so an immediate free would destroy the
	# emitting button while its own emission is still unwinding.
	remove_child(layer)
	layer.queue_free()
	if restore_pause:
		get_tree().paused = _previous_paused


func _dismiss_owned_dialogue() -> void:
	if _lab_balloon == null or not is_instance_valid(_lab_balloon):
		_lab_balloon = null
		return
	var balloon: Node = _lab_balloon
	_lab_balloon = null
	_lab_dialogue_running = false
	if balloon.is_inside_tree():
		var parent := balloon.get_parent()
		if parent != null:
			parent.remove_child(balloon)
	balloon.free()


func _end_session() -> void:
	_dismiss_owned_dialogue()
	_restore_saved_state()
	_setup.clear()
	_current_resource = null
	_lab_dialogue_running = false
	_close_overlay()


func _ownership_conflict_is_live() -> bool:
	return (
		production_battle_is_live()
		or production_dialogue_is_live()
		or another_sandbox_is_armed()
	)


## True while a DIFFERENT debug lab holds an armed rollback.
##
## Two labs holding snapshots at once is not safe even though each is internally
## correct: they restore in whatever order they happen to end, and a non-LIFO
## restore reinstates the first lab's dirty state after that lab already cleaned
## up. `_has_saved_state` distinguishes our own armed session — which a restart
## must still be allowed to replace — from the other lab's.
func another_sandbox_is_armed() -> bool:
	return SaveGame.runtime_sandbox_is_armed() and not _has_saved_state


func _contains_other_dialogue_balloon(node: Node) -> bool:
	for child: Node in node.get_children():
		if child != _lab_balloon and _has_dialogue_resource_property(child):
			var value: Variant = child.get("dialogue_resource")
			if value is DialogueResource:
				return true
		if _contains_other_dialogue_balloon(child):
			return true
	return false


static func _has_dialogue_resource_property(node: Node) -> bool:
	for property: Dictionary in node.get_property_list():
		if StringName(property.get("name", &"")) == &"dialogue_resource":
			return true
	return false


static func _is_allowed_dialogue_path(path: String) -> bool:
	if path.get_extension() != "dialogue":
		return false
	for directory: String in DIALOGUE_DIRECTORIES:
		if path.get_base_dir() == directory:
			return true
	return false


func _refresh_activation() -> void:
	if not is_inside_tree():
		return
	var should_enable: bool = OS.is_debug_build() and (
		OS.get_environment(ENVIRONMENT_VARIABLE) == "1" or force_enabled_for_tests
	)
	if should_enable == _enabled:
		return
	_enabled = should_enable
	set_process_unhandled_key_input(_enabled)
	if _enabled:
		_connect_dialogue_signals()
	else:
		_shutdown()


func _shutdown() -> void:
	_end_session()
	_disconnect_dialogue_signals()
	_production_dialogue_running = false
