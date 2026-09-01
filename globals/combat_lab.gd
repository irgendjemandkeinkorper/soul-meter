extends Node
## Debug-only encounter sandbox. Disabled builds remain completely inert.

const COMBAT_LAB_SCENE := preload("res://ui/debug/combat_lab.tscn")
const EXPORT_ROOT := "user://combat_lab"
const AUTHORED_WEATHER := &"__authored_default__"
const CALM := &""
## PROVISIONAL owner surface: F3 may move after balance-facilitator playtesting.
const TOGGLE_HOTKEY: Key = KEY_F3
## Emitted by every entry point that declines to open — over a live production
## battle, or over another debug lab's armed sandbox. It lives here, next to the
## guard, so the tests that assert the refusal is audible match on this constant
## instead of a copied literal.
const REFUSAL_WARNING := (
	"Combat Lab refuses to open over a running battle or another lab's session."
)

var force_enabled_for_tests: bool = false:
	set(value):
		force_enabled_for_tests = value
		_refresh_activation()

var _enabled: bool = false
var _overlay_layer: CanvasLayer = null
var _panel: Control = null
var _previous_paused: bool = false
var _restore_pause_on_close: bool = false
var _lab_battle_running: bool = false
var _battle_signals_connected: bool = false
var _runtime_overrides_applied: bool = false
var _setup: Dictionary = {}
var _turn_rows: Array[Dictionary] = []
var _outcome: Dictionary = {}
var _latest_snapshot: Dictionary = {}
var _pending_forecast: Dictionary = {}
var _last_comparison: Dictionary = {}
## A finished lab battle runs the PRODUCTION end-of-battle path, which accrues
## style points into SaveGame.ng_plus, can consume persistent SkillCheck expert
## rerolls, turns in quests, and mutates the tactical roster. Battle then
## requests a checkpoint, so without a full rollback the player's next real save
## would contain progress earned in the sandbox.
var _runtime_before: Dictionary = {}
var _rng_seed_before: int = 0
var _rng_state_before: int = 0
var _has_saved_state: bool = false
var last_export_path: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process_unhandled_key_input(false)
	_refresh_activation()


func _exit_tree() -> void:
	_shutdown()


func _unhandled_key_input(event: InputEvent) -> void:
	if not _enabled or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if not key_event.pressed or key_event.echo:
		return
	if key_event.physical_keycode != TOGGLE_HOTKEY and key_event.keycode != TOGGLE_HOTKEY:
		return
	if _overlay_layer == null:
		# A finished lab session keeps _setup so it can be restarted, so this
		# branch stays reachable after the lab battle ends. Without the same
		# ownership guard open_setup() carries, F3 during a LATER production
		# battle would reopen the inspector on the stale prior session and
		# render it over a live encounter it knows nothing about.
		if _ownership_conflict_is_live():
			push_warning(REFUSAL_WARNING)
			return
		if _lab_battle_running or not _setup.is_empty():
			_open_overlay(true)
		else:
			open_setup()
	else:
		close_overlay()
	get_viewport().set_input_as_handled()


func is_enabled() -> bool:
	return _enabled


## True while a battle the lab did NOT start is live. The lab must never open
## over, or start on top of, a production encounter: Battle.start() would
## destroy the real one, and GameFlow's journey listener would then advance
## journey state from the lab's result.
func production_battle_is_live() -> bool:
	return (
		not _lab_battle_running
		and Battle.controller != null
		and not Battle.ended
	)


## Every entry point that can open the lab or start a session checks this, not
## production_battle_is_live() alone.
func _ownership_conflict_is_live() -> bool:
	return production_battle_is_live() or another_sandbox_is_armed()


## True while a DIFFERENT debug lab holds an armed rollback.
##
## Two labs holding snapshots at once is not safe even though each is internally
## correct: they restore in whatever order they happen to end, and a non-LIFO
## restore reinstates the first lab's dirty state after that lab already cleaned
## up. `_has_saved_state` distinguishes our own armed session — which a restart
## must still be allowed to replace — from the other lab's.
func another_sandbox_is_armed() -> bool:
	return SaveGame.runtime_sandbox_is_armed() and not _has_saved_state


func open_setup() -> void:
	if not _enabled or _overlay_layer != null or _lab_battle_running:
		return
	if _ownership_conflict_is_live():
		push_warning(REFUSAL_WARNING)
		return
	_previous_paused = get_tree().paused
	get_tree().paused = true
	_restore_pause_on_close = true
	_open_overlay(false)


func close_overlay() -> void:
	if _overlay_layer == null:
		return
	var layer: CanvasLayer = _overlay_layer
	var restore_pause := _restore_pause_on_close
	_overlay_layer = null
	_panel = null
	_restore_pause_on_close = false
	remove_child(layer)
	layer.free()
	if restore_pause:
		get_tree().paused = _previous_paused


func encounter_ids() -> Array[StringName]:
	return EncounterCatalog.all_ids()


func party_cap() -> int:
	return GameState.REQUIRED_COMPANIONS + 1


func authored_weather_marker() -> StringName:
	return AUTHORED_WEATHER


func party_candidates() -> Array[PartyMember]:
	var result: Array[PartyMember] = []
	var seen: Dictionary = {}
	for member: PartyMember in GameState.party:
		if member != null and not seen.has(member.id):
			seen[member.id] = true
			result.append(member)
	for member: PartyMember in GameState.recruitable_candidates():
		if member != null and not seen.has(member.id):
			seen[member.id] = true
			result.append(member)
	return result


func resolve_weather(
	encounter_id: StringName, override_enabled: bool, override_id: StringName
) -> Dictionary:
	if override_enabled:
		return {
			"element_id": override_id,
			"source": &"override",
			"label": "CALM (override)" if override_id == CALM else "%s (override)" % String(override_id).to_upper(),
		}
	var definition: Dictionary = EncounterCatalog.definition(encounter_id)
	var authored := StringName(str(definition.get("weather_default", "")))
	if authored != CALM:
		return {
			"element_id": authored,
			"source": &"authored",
			"label": "%s (authored default)" % String(authored).to_upper(),
		}
	return {"element_id": CALM, "source": &"calm", "label": "CALM (no authored default)"}


## Every mutating entry point is gated. Inertness is not just "does nothing on
## its own when disabled" — a disabled lab must not be *drivable* either, or the
## force_enabled_for_tests seam is decorative and a stray call can start a real
## Battle and connect signals in a shipped build.
func start_lab_battle(requested_setup: Dictionary) -> void:
	if not _enabled or _ownership_conflict_is_live():
		return
	_start_session(requested_setup, true)


func start_test_session(requested_setup: Dictionary) -> void:
	if not _enabled or _ownership_conflict_is_live():
		return
	_start_session(requested_setup, false)


## Ends a lab session. Safe to call when no session is running: it tears down
## only a battle the lab started, so it can never abort a production encounter
## even though it is a public autoload surface.
func stop_test_session() -> void:
	var owned_battle := _lab_battle_running
	_disconnect_battle_signals()
	_lab_battle_running = false
	_restore_saved_state()
	# Leaving session state behind made F3 open the inspector instead of the
	# setup screen for whatever ran next, and left an unfinished global Battle
	# visible to later suites.
	_setup.clear()
	_turn_rows.clear()
	_outcome.clear()
	_latest_snapshot.clear()
	_pending_forecast.clear()
	_last_comparison.clear()
	_runtime_overrides_applied = false
	_clear_lab_battle(owned_battle)


## Tears down ONLY a battle the lab itself started. There is no Battle.abandon()
## and flee() would run the production flee path, so this mirrors the field
## teardown the existing suites use (test_travel_flow._clear_test_battle) —
## including the encounter id, rosters and last_result, which a partial reset
## would leave visible to whatever runs next.
func _clear_lab_battle(owned: bool) -> void:
	if not owned or Battle.encounter_id.is_empty():
		return
	Battle._release_battlefield_ground()
	Battle.allies.clear()
	Battle.enemies.clear()
	Battle._definition.clear()
	Battle._combat_history.clear()
	Battle.controller = null
	Battle.encounter_id = &""
	Battle.last_result = null
	Battle.ended = true


## The restart controls are the LAST two entry points into Battle.start(). They
## carry the same ownership guard as the four open/start paths: the inspector
## outlives the lab battle that opened it, so a restart pressed after a real
## encounter has begun would otherwise destroy it.
func restart_same_setup() -> void:
	if not _enabled or _setup.is_empty() or _ownership_conflict_is_live():
		return
	_start_session(_setup, true)


func restart_new_seed() -> void:
	if not _enabled or _setup.is_empty() or _ownership_conflict_is_live():
		return
	var next_setup := _setup.duplicate(true)
	next_setup["seed"] = Time.get_ticks_usec()
	_start_session(next_setup, true)


func export_session() -> String:
	if not _enabled or _setup.is_empty():
		return ""
	var absolute_root := ProjectSettings.globalize_path(EXPORT_ROOT)
	var error := DirAccess.make_dir_recursive_absolute(absolute_root)
	if error != OK:
		push_warning("Combat Lab could not create export directory: %s" % error_string(error))
		return ""
	var timestamp := Time.get_datetime_string_from_system(false, true).replace(":", "-")
	var path := EXPORT_ROOT.path_join("%s.md" % timestamp)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("Combat Lab could not export %s." % path)
		return ""
	file.store_string(build_session_markdown(_setup, _turn_rows, _outcome))
	file.flush()
	file.close()
	last_export_path = path
	_update_panel()
	return path


func build_session_markdown(
	setup: Dictionary, turns: Array[Dictionary], outcome: Dictionary
) -> String:
	var weather: Dictionary = setup.get("weather", {})
	if weather.is_empty():
		weather = resolve_weather(
			StringName(setup.get("encounter_id", &"")),
			bool(setup.get("weather_override_enabled", false)),
			StringName(setup.get("weather_override", &"")),
		)
	var tile_seed: Dictionary = setup.get("tile_seed", {})
	var party_names: Array[String] = []
	for party_id: Variant in setup.get("party_ids", []):
		party_names.append(str(party_id))
	var lines: Array[String] = [
		"# Combat Lab Session",
		"",
		"## Setup",
		"",
		"- Encounter: `%s`" % str(setup.get("encounter_id", "")),
		"- Party: `%s`" % "`, `".join(party_names),
		"- Seed: `%s`" % str(setup.get("seed", 0)),
		"- Weather: `%s` (%s)" % [
			"CALM" if StringName(weather.get("element_id", &"")) == CALM else str(weather.get("element_id", "")),
			str(weather.get("source", "calm")),
		],
		"- Tile seed: `%s` / `%s` charge `%d`" % [
			str(tile_seed.get("cell", Vector2i.ZERO)),
			"UNCHARGED" if StringName(tile_seed.get("element_id", &"")) == CALM else str(tile_seed.get("element_id", "")),
			int(tile_seed.get("charge", 0)),
		],
		"",
	]
	if str(weather.get("source", "")) == "override":
		lines.append("Authoring candidate (manual only): `EncounterCatalog._WEATHER_DEFAULTS[\"%s\"] = \"%s\"`" % [
			str(setup.get("encounter_id", "")), str(weather.get("element_id", "")),
		])
		lines.append("")
	lines.append_array([
		"## Turns",
		"",
		"| Turn | Actor | Action | Forecast | Resolution | Parity |",
		"| ---: | --- | --- | ---: | ---: | --- |",
	])
	for row: Dictionary in turns:
		lines.append("| %d | %s | %s | %s | %s | %s |" % [
			int(row.get("turn", 0)),
			str(row.get("actor", "")),
			str(row.get("action", "")),
			_value_or_dash(row.get("forecast", null)),
			_value_or_dash(row.get("resolution", null)),
			(
				"DIVERGED" if bool(row.get("diverged", false)) else "MATCH"
			) if bool(row.get("compared", false)) else "—",
		])
	lines.append_array([
		"",
		"## Outcome",
		"",
		"- State: `%s`" % str(outcome.get("state", "in_progress")),
		"- Outcome: `%s`" % str(outcome.get("outcome_id", "")),
		"- Message: %s" % str(outcome.get("message", "")),
		"",
		"> Combat Lab observes and configures runtime state. It never rewrites authored balance data.",
	])
	return "\n".join(lines) + "\n"


func compare_forecast_resolution(forecast: Dictionary, resolution: Dictionary) -> Dictionary:
	var differences: Array[String] = []
	if forecast.has("damage") and resolution.has("damage"):
		var forecast_damage := int(forecast.get("damage", 0))
		var resolved_damage := int(resolution.get("damage", 0))
		if forecast_damage != resolved_damage:
			differences.append("damage forecast %d != resolution %d" % [forecast_damage, resolved_damage])
	return {"diverged": not differences.is_empty(), "differences": differences}


func _start_session(requested_setup: Dictionary, enter_game_flow: bool) -> void:
	if requested_setup.is_empty():
		return
	# Rewind any prior session, THEN re-arm. Restoring without re-capturing left
	# a restarted session with no armed snapshot — the original containment leak,
	# reintroduced by the restore-once rule that was meant to close it. Every
	# session must begin armed on genuinely pre-lab state, so these two always
	# run as a pair. _restore_saved_state() is a no-op when nothing is armed.
	_restore_saved_state()
	_capture_saved_state()
	_setup = _normalize_setup(requested_setup)
	_turn_rows.clear()
	_outcome.clear()
	_latest_snapshot.clear()
	_pending_forecast.clear()
	_last_comparison.clear()
	_runtime_overrides_applied = false
	_apply_party(_setup.get("party_ids", []))
	# Seed the ONE stochastic source a lab session can actually control.
	# Calling global seed() here was misleading in both directions: combat damage
	# derives its seed deterministically from the controller's own _sequence, so
	# "new seed" never varied it, while skill checks roll on SkillCheck's own
	# RandomNumberGenerator, so "same seed" never reproduced them. Global seed()
	# also perturbed unrelated engine randomness for the rest of the process.
	SkillCheck.random_number_generator.seed = int(_setup.get("seed", 0))
	_lab_battle_running = true
	_connect_battle_signals()
	close_overlay()
	Battle.start(StringName(_setup["encounter_id"]))
	if Battle.ended or Battle.controller == null:
		_lab_battle_running = false
		_restore_saved_state()
		return
	if not _runtime_overrides_applied:
		_apply_runtime_overrides(Battle.controller, _setup)
		_runtime_overrides_applied = true
	_latest_snapshot = Battle.controller.snapshot()
	_capture_pending_forecast()
	_record_playtest_usage()
	_open_overlay(true)
	if enter_game_flow:
		GameFlow.send_event("enter_battle")
	_update_panel()


func _normalize_setup(requested_setup: Dictionary) -> Dictionary:
	var normalized := requested_setup.duplicate(true)
	var encounter_id := StringName(normalized.get("encounter_id", &""))
	normalized["encounter_id"] = encounter_id
	var override_enabled := bool(normalized.get("weather_override_enabled", false))
	var override_id := StringName(normalized.get("weather_override", &""))
	normalized["weather"] = resolve_weather(encounter_id, override_enabled, override_id)
	if not normalized.has("seed"):
		normalized["seed"] = Time.get_ticks_usec()
	if not normalized.has("tile_seed"):
		normalized["tile_seed"] = {
			"cell": Vector2i.ZERO, "element_id": CALM, "charge": 0,
		}
	return normalized


func _apply_runtime_overrides(controller: CombatController, setup: Dictionary) -> void:
	var weather: Dictionary = setup.get("weather", {})
	var weather_result := controller.configure_weather(
		StringName(weather.get("element_id", CALM))
	)
	if not bool(weather_result.get("allowed", false)):
		push_warning("Combat Lab weather override refused: %s" % weather_result)
	var tile_seed: Dictionary = setup.get("tile_seed", {})
	var cell: Vector2i = tile_seed.get("cell", Vector2i.ZERO)
	var tile := controller.tile_state_at(cell)
	if tile == null:
		return
	tile.clear_charge()
	var element_id := StringName(tile_seed.get("element_id", CALM))
	var charge := clampi(int(tile_seed.get("charge", 0)), 0, TileState.MAX_CHARGE_LEVEL)
	if element_id == CALM:
		return
	for _level: int in charge:
		var residue_result := tile.apply_residue(element_id)
		if not bool(residue_result.get("allowed", false)):
			push_warning("Combat Lab tile seed refused: %s" % residue_result)
			break


func _capture_pending_forecast() -> void:
	_pending_forecast.clear()
	var controller: CombatController = Battle.controller
	if controller == null or controller.state != CombatController.State.ALLY_TURN:
		return
	var actor := controller.active_actor()
	var target := _first_living_enemy(controller)
	var action := controller.action_by_id(&"strike")
	if actor == null or target == null or action == null:
		return
	var context := controller.forecast_context(actor, target, action)
	var forecast := controller.forecast_action(action, target)
	if not bool(forecast.get("allowed", false)):
		return
	_pending_forecast = {
		"actor_id": actor.combat_id,
		"actor": actor.display_name,
		"target_id": target.combat_id,
		"action_id": action.id,
		"damage": int(forecast.get("damage", 0)),
		"context": context.duplicate(true),
	}


func _on_combat_event(event: CombatEvent) -> void:
	if not _lab_battle_running or event == null:
		return
	if event.type == &"battle_started" and Battle.controller != null:
		# CombatController emits this synchronously before it starts driving the scheduler.
		# Applying here ensures even a CT enemy that acts first sees the lab weather/tile state.
		_apply_runtime_overrides(Battle.controller, _setup)
		_runtime_overrides_applied = true
		_latest_snapshot = Battle.controller.snapshot()
	else:
		var snapshot_value: Variant = event.data.get("snapshot", {})
		if snapshot_value is Dictionary:
			_latest_snapshot = (snapshot_value as Dictionary).duplicate(true)
	if event.type == &"turn_started":
		_capture_pending_forecast()
	elif event.type == &"action_resolved":
		_record_resolution(event)
	_update_panel()


## The resolved action's target. CombatEvent carries it as a field; some events
## carry it only in `data`, so fall back rather than silently reading &"" and
## comparing a forecast against the wrong target.
func _resolution_target(event: CombatEvent) -> StringName:
	if not event.target_id.is_empty():
		return event.target_id
	return StringName(event.data.get("target_id", &""))


func _record_resolution(event: CombatEvent) -> void:
	var action_id := StringName(event.data.get("action_id", &""))
	var resolved_damage: Variant = event.data.get("damage", null)
	var forecast_damage: Variant = null
	var comparison := {"diverged": false, "differences": []}
	# The TARGET is part of the identity of a forecast, not incidental to it:
	# damage depends on the target's defence, so a forecast made against enemy A
	# tells you nothing about a strike resolved against enemy B. Comparing them
	# would report MATCH on coincidentally equal damage and, worse, a FALSE
	# DIVERGENCE when defences differ — turning the one signal this lab exists
	# to surface into noise. A target mismatch is "not compared", never a pass.
	if (
		action_id == StringName(_pending_forecast.get("action_id", &""))
		and event.actor_id == StringName(_pending_forecast.get("actor_id", &""))
		and _resolution_target(event) == StringName(_pending_forecast.get("target_id", &""))
		and resolved_damage != null
	):
		forecast_damage = int(_pending_forecast.get("damage", 0))
		comparison = compare_forecast_resolution(
			{"damage": forecast_damage}, {"damage": int(resolved_damage)}
		)
		if bool(comparison.get("diverged", false)) or _last_comparison.is_empty():
			# A divergence stays loud for the rest of the session; a later matching action
			# must not erase the evidence the lab exists to surface.
			_last_comparison = comparison.duplicate(true)
	_turn_rows.append({
		"turn": _turn_rows.size() + 1,
		"actor": _actor_name(event.actor_id),
		"action": String(action_id),
		"forecast": forecast_damage,
		"resolution": resolved_damage,
		"compared": forecast_damage != null and resolved_damage != null,
		"diverged": bool(comparison.get("diverged", false)),
	})
	_pending_forecast.clear()


func _on_turn_resolved() -> void:
	_update_panel()


func _on_balance_changed(_value: int) -> void:
	_update_panel()


func _on_battle_ended(result: BattleResult) -> void:
	if not _lab_battle_running:
		return
	_lab_battle_running = false
	_outcome = {
		"state": _result_state_name(result.state),
		"outcome_id": String(result.outcome_id),
		"message": result.message,
	}
	_disconnect_battle_signals()
	_restore_saved_state()
	_update_panel()


func _connect_battle_signals() -> void:
	if _battle_signals_connected:
		return
	Battle.combat_event.connect(_on_combat_event)
	Battle.turn_resolved.connect(_on_turn_resolved)
	Battle.balance_changed.connect(_on_balance_changed)
	Battle.battle_ended.connect(_on_battle_ended)
	_battle_signals_connected = true


func _disconnect_battle_signals() -> void:
	if not _battle_signals_connected:
		return
	if Battle.combat_event.is_connected(_on_combat_event):
		Battle.combat_event.disconnect(_on_combat_event)
	if Battle.turn_resolved.is_connected(_on_turn_resolved):
		Battle.turn_resolved.disconnect(_on_turn_resolved)
	if Battle.balance_changed.is_connected(_on_balance_changed):
		Battle.balance_changed.disconnect(_on_balance_changed)
	if Battle.battle_ended.is_connected(_on_battle_ended):
		Battle.battle_ended.disconnect(_on_battle_ended)
	_battle_signals_connected = false


func _open_overlay(inspector: bool) -> void:
	if not _enabled or _overlay_layer != null:
		return
	_overlay_layer = CanvasLayer.new()
	_overlay_layer.name = "CombatLabLayer"
	_overlay_layer.layer = 1200
	_overlay_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_overlay_layer)
	_panel = COMBAT_LAB_SCENE.instantiate() as Control
	_panel.name = "CombatLabOverlay"
	_panel.process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay_layer.add_child(_panel)
	_panel.call("configure", self, inspector)
	_update_panel()


func _update_panel() -> void:
	if _panel != null and is_instance_valid(_panel):
		_panel.call("update_inspector", _inspector_payload())


func _inspector_payload() -> Dictionary:
	return {
		"running": _lab_battle_running,
		"setup": _setup.duplicate(true),
		"snapshot": _latest_snapshot.duplicate(true),
		"timeline": _scheduler_timeline(),
		"pending_forecast": _pending_forecast.duplicate(true),
		"comparison": _last_comparison.duplicate(true),
		"turns": _turn_rows.duplicate(true),
		"outcome": _outcome.duplicate(true),
		"style": CombatStylePoints.score_breakdown(),
		"combatant_tiles": _combatant_tiles(),
		"last_export_path": last_export_path,
	}


func _scheduler_timeline() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var controller: CombatController = Battle.controller
	if controller == null or controller.scheduler == null:
		return result
	var rows_value: Variant = _latest_snapshot.get("turn_order", [])
	if not rows_value is Array:
		return result
	# ChargeTimeScheduler caches the exact speed values it advances with. The base
	# scheduler does not expose them in peek_order(), so the lab reads that stored
	# diagnostic state instead of calculating a second speed table.
	var speeds: Dictionary = {}
	var has_speed_state := false
	for property: Dictionary in controller.scheduler.get_property_list():
		if str(property.get("name", "")) == "_speed":
			has_speed_state = true
			break
	if has_speed_state:
		var speeds_value: Variant = controller.scheduler.get("_speed")
		if speeds_value is Dictionary:
			speeds = speeds_value
	for row_value: Variant in rows_value:
		if not row_value is Dictionary:
			continue
		var row := (row_value as Dictionary).duplicate(true)
		var actor_id := StringName(row.get("actor_id", &""))
		row["ready_at"] = TurnScheduler.READY_AT if has_speed_state else "AP"
		row["speed"] = speeds.get(actor_id, "—")
		result.append(row)
	return result


func _combatant_tiles() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var controller: CombatController = Battle.controller
	if controller == null or controller.battlefield == null:
		return result
	for actor: BattleActor in controller.allies + controller.enemies:
		var described: Dictionary = controller.battlefield.describe_position(
			controller.battlefield.position_of(actor)
		)
		var tile_data: Dictionary = {}
		if described.has("cell"):
			var tile := controller.tile_state_at(described["cell"] as Vector2i)
			if tile != null:
				tile_data = tile.to_dict()
		result.append({
			"actor": actor.display_name,
			"actor_id": actor.combat_id,
			"position": described,
			"tile": tile_data,
		})
	return result


func _apply_party(selected_ids_value: Variant) -> void:
	var selected_ids: Array = selected_ids_value if selected_ids_value is Array else []
	var by_id: Dictionary = {}
	for member: PartyMember in party_candidates():
		by_id[member.id] = member
	var selected: Array[PartyMember] = []
	for selected_id: Variant in selected_ids:
		var member: PartyMember = by_id.get(str(selected_id)) as PartyMember
		if member != null and not selected.has(member):
			selected.append(member)
		if selected.size() >= party_cap():
			break
	if selected.is_empty():
		for member: PartyMember in GameState.party:
			selected.append(member)
			if selected.size() >= party_cap():
				break
	GameState.party.clear()
	GameState.party.assign(selected)


func _capture_saved_state() -> void:
	# SaveGame owns the authoritative list of rollback-able runtime state. This
	# lab used to enumerate five surfaces here and missed four — including the
	# quest pools a battle victory turns in and the tactical roster combat
	# itself mutates. Never re-enumerate the surfaces locally.
	_runtime_before = SaveGame.capture_runtime_state()
	# SkillCheck.to_dict() serializes reroll usage, not RNG position, so the
	# generator's state must be captured separately or every lab session would
	# permanently shift the randomness later campaign skill checks draw from.
	# seed and state are captured together and restored in that order, because
	# assigning seed RESETS state. Restoring state alone left the generator's
	# observable seed reading as the lab's, which would misreport where the
	# campaign's randomness came from.
	_rng_seed_before = SkillCheck.random_number_generator.seed
	_rng_state_before = SkillCheck.random_number_generator.state
	# A finished lab battle requests a checkpoint that flushes DEFERRED. The old
	# code tried to win that race by restoring first; suppression removes the
	# race instead, so no ordering assumption has to hold.
	SaveGame.begin_runtime_sandbox()
	_has_saved_state = true


## Restores exactly ONCE per session, then disarms.
##
## An armed snapshot that survives the session is worse than the leak it was
## added to stop: the inspector and restart controls stay available after a lab
## battle ends, so a later restart or shutdown would roll back progression the
## player legitimately earned after returning to normal play. Containment must
## be scoped to the session, not left standing.
func _restore_saved_state() -> void:
	if not _has_saved_state:
		return
	_has_saved_state = false
	if not SaveGame.restore_runtime_state(_runtime_before):
		push_warning("Combat Lab could not restore the pre-lab GameState snapshot.")
	# seed first: assigning it resets state, so the reverse order would
	# discard the restored position.
	SkillCheck.random_number_generator.seed = _rng_seed_before
	SkillCheck.random_number_generator.state = _rng_state_before
	SaveGame.end_runtime_sandbox()


func _record_playtest_usage() -> void:
	if not is_inside_tree():
		return
	var recorder: Node = get_node_or_null("/root/PlaytestRecorder")
	if recorder == null or not recorder.has_method("append_event"):
		return
	recorder.call("append_event", &"combat_lab_battle_started", {
		"encounter_id": String(_setup.get("encounter_id", "")),
		"seed": int(_setup.get("seed", 0)),
	})


func _refresh_activation() -> void:
	if not is_inside_tree():
		return
	var should_enable: bool = OS.is_debug_build() and (
		OS.get_environment("SOUL_METER_COMBAT_LAB") == "1" or force_enabled_for_tests
	)
	if should_enable == _enabled:
		return
	_enabled = should_enable
	set_process_unhandled_key_input(_enabled)
	if not _enabled:
		_shutdown()


func _shutdown() -> void:
	# Tear the owned battle down too. Leaving it live meant a lab battle
	# abandoned by disabling the lab stayed in Battle, and re-enabling would then
	# read it as a PRODUCTION encounter (the lab no longer claims it) and refuse
	# to open over the very battle it had started.
	var owned_battle := _lab_battle_running
	close_overlay()
	_disconnect_battle_signals()
	_lab_battle_running = false
	_restore_saved_state()
	_has_saved_state = false
	_clear_lab_battle(owned_battle)


func _first_living_enemy(controller: CombatController) -> BattleActor:
	for enemy: BattleActor in controller.enemies:
		if enemy.is_alive():
			return enemy
	return null


func _actor_name(actor_id: StringName) -> String:
	var controller: CombatController = Battle.controller
	if controller != null:
		for actor: BattleActor in controller.allies + controller.enemies:
			if actor.combat_id == actor_id:
				return actor.display_name
	return String(actor_id)


static func _result_state_name(state: BattleResult.State) -> String:
	match state:
		BattleResult.State.VICTORY:
			return "victory"
		BattleResult.State.FLED:
			return "fled"
		_:
			return "defeat"


static func _value_or_dash(value: Variant) -> String:
	return "—" if value == null else str(value)
