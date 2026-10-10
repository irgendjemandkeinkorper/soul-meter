extends Node
## Debug-only dialogue replay sandbox, hosted by the Weftlumin dialogue panel
## (`weftlumin/panels/dialogue_panel.gd`). Inert until a host enables it with host_in_panel().

## Presentation feed for the hosting panel's replay controls.
signal replay_changed(running: bool, setup: Dictionary)

const DIALOGUE_DIRECTORIES: Array[String] = [
	"res://dialogue",
	"res://dialogue/companions",
]
## Shown by the hosting panel when it declines to replay over live production content.
const REFUSAL_WARNING := "Dialogue Lab refuses to open or replay over live production content."

var _enabled: bool = false
var _dialogue_signals_connected: bool = false
var _setup: Dictionary = {}
var _current_resource: DialogueResource = null
var _lab_balloon: Node = null
var _lab_dialogue_running: bool = false
var _production_dialogue_running: bool = false



func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(false)


func _exit_tree() -> void:
	_shutdown()


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
	_lab_dialogue_running = true
	_lab_balloon = DialogueManager.show_dialogue_balloon(resource, title)
	if _lab_balloon == null:
		_lab_dialogue_running = false
		_restore_saved_state()
		return
	_lab_balloon.tree_exited.connect(_on_lab_balloon_exited.bind(_lab_balloon), CONNECT_ONE_SHOT)


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


## Owner id this lab holds the shared sandbox under.
const SANDBOX_OWNER := &"dialogue_lab"
## The id actually used. A Weftlumin panel hands over the shell's token so the lab's own
## session arms and restores under the owner the shell already holds (§4.5.6).
var sandbox_owner: StringName = SANDBOX_OWNER


## The shared sandbox, with this game's surfaces registered. Registration replaces by id, so
## every tool calling this converges on one set rather than each contributing its own.
func _sandbox() -> WeftluminSandbox:
	var sandbox: WeftluminSandbox = WeftluminSandbox.shared()
	sandbox.add_default_surfaces(SaveGame, SkillCheck)
	return sandbox


## Arms the shared sandbox under this lab's name.
##
## The reasoning that used to live here — SaveGame owning the authoritative surface list, the
## RNG position being captured separately, seed restored before state, and autosave suppressed
## at staging rather than at flush — now lives once in `WeftluminSandbox`.
## True while THIS tool holds the shared sandbox.
##
## Distinct from `another_sandbox_is_armed()`: a restart must be allowed to replace our own
## armed session, but never someone else's.
func sandbox_is_armed() -> bool:
	var sandbox: WeftluminSandbox = _sandbox()
	return sandbox.is_armed() and sandbox.owner() == sandbox_owner


func _capture_saved_state() -> void:
	_sandbox().arm(sandbox_owner)


## Restores exactly once per session, then disarms.
func _restore_saved_state() -> void:
	if not sandbox_is_armed():
		return
	var result: Dictionary = _sandbox().disarm()
	if not bool(result["allowed"]):
		push_warning(
			"Dialogue Lab could not restore the pre-lab snapshot: %s" % str(result["message"])
		)


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


func _update_panel() -> void:
	replay_changed.emit(_lab_dialogue_running, _setup.duplicate(true))


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
## up. The shared sandbox distinguishes our own armed session — which a restart
## must still be allowed to replace — from the other lab's.
func another_sandbox_is_armed() -> bool:
	return _sandbox().held_by_other(sandbox_owner)


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


## Weftlumin panel seam (architecture §4.5.5, §4.8). The panel that owns this instance enables
## the lab under the shell's sandbox token; the shell owns activation, bindings and pause.
## Refused in release builds and outside the tree. The replay lifecycle and its containment are
## unchanged.
func host_in_panel(owner_token: StringName) -> bool:
	if owner_token.is_empty():
		return false
	if not OS.is_debug_build() or not is_inside_tree():
		return false
	sandbox_owner = owner_token
	_set_enabled(true)
	return true


func _set_enabled(should_enable: bool) -> void:
	if should_enable == _enabled:
		return
	_enabled = should_enable
	if _enabled:
		_connect_dialogue_signals()
	else:
		_shutdown()


func _shutdown() -> void:
	_end_session()
	_disconnect_dialogue_signals()
	_production_dialogue_running = false
