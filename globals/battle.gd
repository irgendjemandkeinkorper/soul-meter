extends Node
## Party turn combat around the Balance Gauge. Encounter composition,
## contextual resolutions, and their consequences come from generated data.
##
## AP COMPATIBILITY SHIM (Gate T-10, removal ticket #176). This facade still normalizes legacy
## contextual actions that only authored `ap_cost`; all turn authority and live pricing remain
## behind `TurnScheduler`. Remove the normalization with the AP scheduler, never independently.

signal battle_started
signal turn_resolved
signal balance_changed(value: int)
signal battle_ended(result: BattleResult)
signal combat_event(event: CombatEvent)
signal speech_requested(dialogue_path: String, dialogue_start: String)

const ACTION_STRIKE := &"strike"
const ACTION_GUARD := &"guard"
const ACTION_STABILIZE := &"stabilize"
const ACTION_DEFINITION := &"definition"
const ACTION_PARADOX := &"paradox"
const ACTION_SPEECH := &"speech-seam"
const OUTCOME_DEFEAT := &"defeat"
const OUTCOME_FLED := &"fled"

var allies: Array[BattleActor] = []
var enemies: Array[BattleActor] = []
var active_ally_index := 0
var target_enemy_index := 0
var balance := 0
var enemy_rounds := 0
var last_message := ""
var ended := false
var encounter_id: StringName = &""
var last_result: BattleResult
var controller: CombatController
var last_speech_check: Dictionary = {}
var last_speech_option: StringName = &""
var last_speech_succeeded := false

var BALANCE_MIN: int:
	get:
		return CombatIdentityCatalog.balance_minimum()
var BALANCE_MAX: int:
	get:
		return CombatIdentityCatalog.balance_maximum()
var EXTREME_THRESHOLD: int:
	get:
		for band: Dictionary in CombatIdentityCatalog.balance_bands():
			var effects: Variant = band.get("effects", {})
			if effects is Dictionary and int(effects.get("damage_bonus", 0)) > 0:
				return mini(abs(int(band.get("minimum", 0))), abs(int(band.get("maximum", 0))))
		return 0
var _combat_history: Array[CombatEvent] = []

var player: BattleActor:
	get:
		return current_ally()
var enemy: BattleActor:
	get:
		return enemies[0] if not enemies.is_empty() else null

var _definition: Dictionary = {}
var _battlefield_ground: TileMapLayer


func start(encounter: Variant) -> void:
	_release_battlefield_ground()
	_combat_history.clear()
	allies.clear()
	enemies.clear()
	_definition.clear()
	encounter_id = &""
	last_speech_check.clear()
	last_speech_option = &""
	last_speech_succeeded = false
	for i in GameState.party.size():
		var member: PartyMember = GameState.party[i]
		var actor := BattleActor.new()
		actor.display_name = member.display_name
		actor.hp = member.hp
		actor.max_hp = member.max_hp
		actor.attack = member.attack
		actor.defense = member.defense
		actor.attributes = member.attributes.duplicate(true)
		actor.party_index = i
		actor.source_member = member
		allies.append(actor)
	if allies.is_empty():
		allies.append(BattleActor.new())
	if encounter is StringName or encounter is String:
		encounter_id = StringName(encounter)
		_definition = EncounterCatalog.definition(encounter_id)
		enemies = EncounterCatalog.make_actors(encounter_id)
	elif encounter is BattleActor:
		enemies.append(encounter)
	elif encounter is Array:
		for actor in encounter:
			if actor is BattleActor:
				enemies.append(actor)
	_prepare_enemy_knowledge()
	active_ally_index = _next_living_index(allies, -1)
	target_enemy_index = _next_living_index(enemies, -1)
	balance = 0
	enemy_rounds = 0
	last_message = "The field hangs in balance. Each party member acts before the enemy round."
	ended = enemies.is_empty()
	last_result = null
	if ended:
		push_error("Cannot start an empty encounter: %s" % encounter_id)
		return
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = bool(_definition.get("use_charge_time", rules.use_charge_time))
	controller = CombatController.new()
	controller.event_emitted.connect(_on_combat_event)
	controller.battle_finished.connect(_on_controller_finished)
	controller.configure(
		available_actions(true),
		_battlefield_for_definition(rules),
		rules,
		null,
		TacticalTables.shared().abilities_in_slot(AbilityDefinition.SLOT_ACTION),
	)
	var weather_default := StringName(str(_definition.get("weather_default", "")))
	if weather_default != &"":
		var weather_result := controller.configure_weather(weather_default)
		if not bool(weather_result.get("allowed", false)):
			push_warning(
				"Encounter '%s' authors unknown weather '%s'; battle starts calm."
				% [encounter_id, weather_default]
			)
	controller.start(allies, enemies, encounter_id)
	battle_started.emit()
	balance_changed.emit(balance)


## Builds the authored encounter grid, or a provisional default grid when a catalog
## definition authors none — every catalog encounter is tactical (owner ruling,
## 2026-08-29: the stage renders only grid battles, so zone defaults left the
## screen blank in real play). Two zone paths stay live as the FR-105 fallback:
## authors can select zones explicitly with `"battlefield": "zones"`, and ad-hoc
## `start(BattleActor)` scaffold battles (no definition — a test/debug surface,
## never reachable from authored content) keep their legacy zone behavior.
func _battlefield_for_definition(rules: CombatRules) -> BattlefieldModel:
	if _definition.is_empty() or str(_definition.get("battlefield", "")) == "zones":
		return BattlefieldModel.create_default(rules)

	var required_rows: int = maxi(allies.size(), enemies.size())
	# PROVISIONAL balance dimensions until the later per-encounter content pass.
	var default_dimensions := Vector2i(7, maxi(5, required_rows))
	var grid: Variant = _definition.get("grid", {})
	if not grid is Dictionary or grid.is_empty():
		return _grid_battlefield(default_dimensions, rules)

	var authored_dimensions: Variant = grid.get("dimensions", Vector2i.ZERO)
	if not authored_dimensions is Vector2i:
		push_warning("Encounter '%s' has invalid grid dimensions; using default grid." % encounter_id)
		return _grid_battlefield(default_dimensions, rules)
	var dimensions: Vector2i = authored_dimensions
	if dimensions.x < 2 or dimensions.y < required_rows:
		push_warning("Encounter '%s' grid cannot fit its combatants; using default grid." % encounter_id)
		return _grid_battlefield(default_dimensions, rules)
	var model: GridBattlefieldModel = _grid_battlefield(dimensions, rules)
	_apply_authored_terrain(model, dimensions, grid)
	return model


func _grid_battlefield(dimensions: Vector2i, rules: CombatRules) -> GridBattlefieldModel:
	_battlefield_ground = TileMapLayer.new()
	_battlefield_ground.name = "EncounterBattlefieldGround"
	_battlefield_ground.tile_set = _encounter_grid_tile_set()
	for y in dimensions.y:
		for x in dimensions.x:
			_battlefield_ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var ground_parent: Node = self
	var main_loop: MainLoop = Engine.get_main_loop()
	if not is_inside_tree() and main_loop is SceneTree:
		ground_parent = (main_loop as SceneTree).root
	ground_parent.add_child(_battlefield_ground)

	var model: GridBattlefieldModel = GridBattlefieldModel.new()
	model.configure(rules)
	model.build_grid(_battlefield_ground)
	return model


func _apply_authored_terrain(
	model: GridBattlefieldModel,
	dimensions: Vector2i,
	grid: Dictionary,
) -> void:
	var cover_data: Variant = grid.get("cover", [])
	if not cover_data is Array:
		push_warning("Encounter '%s' grid cover must be an Array; skipping cover." % encounter_id)
	else:
		for authored_cell: Variant in cover_data:
			if not authored_cell is Vector2i:
				push_warning(
					"Encounter '%s' has malformed cover cell '%s'; skipping."
					% [encounter_id, authored_cell]
				)
				continue
			var cell: Vector2i = authored_cell
			if not _authored_cell_is_inside(cell, dimensions):
				push_warning(
					"Encounter '%s' cover cell %s is outside its %dx%d grid; skipping."
					% [encounter_id, cell, dimensions.x, dimensions.y]
				)
				continue
			model.set_cover(cell)

	var elevation_data: Variant = grid.get("elevation", {})
	if not elevation_data is Dictionary:
		push_warning(
			"Encounter '%s' grid elevation must be a Dictionary; skipping elevation."
			% encounter_id
		)
		return
	for authored_cell: Variant in elevation_data:
		if not authored_cell is Vector2i:
			push_warning(
				"Encounter '%s' has malformed elevation cell '%s'; skipping."
				% [encounter_id, authored_cell]
			)
			continue
		var cell: Vector2i = authored_cell
		var authored_height: Variant = elevation_data.get(authored_cell)
		if not authored_height is int:
			push_warning(
				"Encounter '%s' elevation at %s must be an int; skipping."
				% [encounter_id, cell]
			)
			continue
		if not _authored_cell_is_inside(cell, dimensions):
			push_warning(
				"Encounter '%s' elevation cell %s is outside its %dx%d grid; skipping."
				% [encounter_id, cell, dimensions.x, dimensions.y]
			)
			continue
		model.set_elevation(cell, clampi(int(authored_height), 0, DS.ELEVATION_MAX))

	# Authored cliffs await a stage visual; invisible impassable cells are intentionally unsupported.


func _authored_cell_is_inside(cell: Vector2i, dimensions: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < dimensions.x and cell.y < dimensions.y


func _encounter_grid_tile_set() -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = tile_set.tile_size
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	return tile_set


func _release_battlefield_ground() -> void:
	if is_instance_valid(_battlefield_ground):
		_battlefield_ground.free()
	_battlefield_ground = null


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_release_battlefield_ground()


func replay_combat_events(receiver: Callable) -> void:
	## Late-created presentation receives the same immutable event stream without
	## querying resolver state or causing global observers to process events twice.
	if not receiver.is_valid():
		return
	for event: CombatEvent in _combat_history:
		receiver.call(event)


func available_actions(include_enemy_actions: bool = false) -> Array[CombatAction]:
	var result: Array[CombatAction] = (
		CombatActionCatalog.all() if include_enemy_actions else CombatActionCatalog.player_actions()
	)
	var rules := load("res://data/combat/combat_rules.tres") as CombatRules
	for row in EncounterCatalog.context_actions(encounter_id):
		var action := CombatAction.from_context_row(row)
		if action.ap_cost <= 0:
			action.ap_cost = rules.context_resolution_ap_cost
		result.append(action)
	if not include_enemy_actions and not _speech_hook().is_empty():
		var speech := CombatActionCatalog.by_id(ACTION_SPEECH)
		if speech != null:
			speech.player_available = true
			result.append(speech)
	return result


func can_use(action: CombatAction) -> bool:
	return bool(action_refusal(action, null, _availability_options(action)).get("allowed", false))


func action_lock_reason(action: CombatAction) -> String:
	var refusal := action_refusal(action, null, _availability_options(action))
	return "" if bool(refusal.get("allowed", false)) else str(refusal.get("message", "Action unavailable."))


func _availability_options(action: CombatAction) -> Dictionary:
	if action == null or action.kind != CombatAction.Kind.DEFINING_STRIKE:
		return {}
	var target := current_target()
	if target == null or target.discovered_weakness_ids.is_empty():
		return {}
	# Availability may query one discovered weakness, but execution never receives
	# this value. The presentation must still ask the player to choose and confirm.
	return {"weakness_id": target.discovered_weakness_ids[0]}


func action_refusal(
	action: CombatAction, target: BattleActor = null, options: Dictionary = {}
) -> Dictionary:
	if ended or current_ally() == null:
		return _blocked_reason(&"battle_state", "Battle has ended.", {})
	if action == null:
		return _blocked_reason(&"action", "Unknown combat action.", {"type": &"known_action"})
	if GameState.soul_meter < action.soul_cost:
		return _blocked_reason(
			&"soul",
			"Requires %d Soul." % int(action.soul_cost),
			{"type": &"soul", "minimum": action.soul_cost, "delta": action.soul_cost - GameState.soul_meter},
		)
	if action.kind == CombatAction.Kind.RESOLUTION:
		if enemy_rounds < action.minimum_enemy_rounds:
			return _blocked_reason(&"enemy_rounds", action.lock_reason, {
				"type": &"enemy_rounds",
				"minimum": action.minimum_enemy_rounds,
				"delta": action.minimum_enemy_rounds - enemy_rounds,
			})
		if balance < action.minimum_balance or balance > action.maximum_balance:
			return _blocked_reason(&"balance", action.lock_reason, {
				"type": &"balance_range",
				"minimum": action.minimum_balance,
				"maximum": action.maximum_balance,
			})
	if action.id == ACTION_SPEECH:
		var hook := _speech_hook()
		if hook.is_empty():
			return _blocked_reason(
				&"speech_context",
				"This encounter has no authored combat speech hook.",
				{"type": &"speech_hook"},
			)
		if str(hook.get("dialogue_path", "")).is_empty():
			return _blocked_reason(
				&"speech_dialogue",
				"The combat speech hook has no dialogue resource.",
				{"type": &"dialogue_path"},
			)
	if controller == null:
		return {"allowed": true, "blocked_by": &"", "nearest_unblock": {}, "message": ""}
	if target == null and action.requires_enemy_target():
		target = current_target()
	return controller.query_action(action, target, _resolved_action_options(action, target, options))


func use_action(
	action_id: StringName, target_index: int = -1, options: Dictionary = {}
) -> bool:
	var action := _action_by_id(action_id)
	var actor := current_ally()
	var target: BattleActor = null
	if action != null and action.requires_enemy_target():
		target = _living_enemy(target_enemy_index if target_index < 0 else target_index)
	var resolved_options := _resolved_action_options(action, target, options)
	if (
		action == null
		or actor == null
		or not bool(action_refusal(action, target, resolved_options).get("allowed", false))
	):
		return false
	if action.id == ACTION_SPEECH:
		var hook := _speech_hook()
		last_message = "%s opens a parley without leaving the field." % actor.display_name
		speech_requested.emit(
			str(hook.get("dialogue_path", "")), str(hook.get("dialogue_start", "start"))
		)
		turn_resolved.emit()
		return true
	# CAST resource writes come from Resolution so forecast and commit cannot diverge.
	if action.verb != CombatAction.Verb.CAST and action.soul_cost > 0.0:
		GameState.set_soul_meter(GameState.soul_meter - action.soul_cost)
	var outcome := controller.submit_action(action_id, target, resolved_options)
	return bool(outcome.get("allowed", false))


func use_defining_strike(
	weakness_id: StringName, target_index: int = -1, forced_rolls: Array[int] = []
) -> bool:
	return use_action(
		ACTION_DEFINITION,
		target_index,
		{"weakness_id": weakness_id, "forced_rolls": forced_rolls.duplicate()},
	)


func defining_strike_forecast(
	weakness_id: StringName, target_index: int = -1
) -> Dictionary:
	if controller == null:
		return {}
	var target := _living_enemy(target_enemy_index if target_index < 0 else target_index)
	return controller.forecast_defining_strike(target, weakness_id)


func action_forecast(
	action: CombatAction, target: BattleActor = null, options: Dictionary = {}
) -> Dictionary:
	if controller == null or action == null:
		return {}
	var resolved_target := current_target() if target == null and action.requires_enemy_target() else target
	return controller.forecast_action(
		action, resolved_target, _resolved_action_options(action, resolved_target, options)
	)


func available_weaknesses(target_index: int = -1) -> Array[Dictionary]:
	var target := _living_enemy(target_enemy_index if target_index < 0 else target_index)
	var result: Array[Dictionary] = []
	if target == null:
		return result
	for weakness_id: StringName in target.discovered_weakness_ids:
		var row := CombatIdentityCatalog.weakness(target.archetype_id, weakness_id)
		if not row.is_empty():
			result.append(row)
	return result


func apply_balance_effect(parameters: Dictionary) -> Dictionary:
	if controller == null:
		return _blocked_reason(&"battle_state", "Battle has not started.", {})
	return controller.apply_balance_effect(parameters, current_ally())


func commit_speech(
	option_id: StringName, forced_rolls: Array = []
) -> Dictionary:
	var action := _action_by_id(ACTION_SPEECH)
	var refusal := action_refusal(action)
	if not bool(refusal.get("allowed", false)):
		return refusal
	var option := _speech_option(option_id)
	var option_refusal := option.validation_refusal() if option != null else _blocked_reason(
		&"speech_option", "Unknown combat speech option.", {"type": &"known_speech_option"}
	)
	if not bool(option_refusal.get("allowed", false)):
		return option_refusal
	var actor := current_ally()
	if actor.party_index < 0 or actor.party_index >= GameState.party.size():
		return _blocked_reason(
			&"speaker",
			"Only a party member can commit a combat speech check.",
			{"type": &"party_member"},
		)
	var member: PartyMember = GameState.party[actor.party_index]
	var typed_rolls: Array[int] = []
	for roll: Variant in forced_rolls:
		typed_rolls.append(int(roll))
	var check: Dictionary = SkillCheck.resolve(
		String(option.skill),
		member,
		option.situational_modifier,
		String(encounter_id),
		typed_rolls,
	)
	var result := controller.submit_speech(ACTION_SPEECH, check, option)
	if bool(result.get("allowed", false)):
		last_speech_check = check.duplicate(true)
		last_speech_option = option.id
		last_speech_succeeded = bool(check.get("success", false))
	return result


func player_attack() -> void:
	use_action(ACTION_STRIKE)


func player_defend() -> void:
	use_action(ACTION_GUARD)


func flee() -> void:
	if not ended:
		last_message = "The party disengages. Current wounds are preserved."
		if controller != null:
			controller.force_finish(CombatController.ResultState.FLED, OUTCOME_FLED)
		else:
			_finish(BattleResult.State.FLED, OUTCOME_FLED)


func end_turn() -> void:
	if controller != null:
		controller.end_turn()


func current_ally() -> BattleActor:
	if active_ally_index < 0 or active_ally_index >= allies.size():
		return null
	return allies[active_ally_index]


func living_enemies() -> Array[BattleActor]:
	var result: Array[BattleActor] = []
	for actor in enemies:
		if actor.is_alive():
			result.append(actor)
	return result


func current_target() -> BattleActor:
	return _living_enemy(target_enemy_index)


## #209: the ACT/TARGET panel's forecast context — the active ally striking the
## current target, built by the controller with the exact terms live resolution
## will use. Empty when no battle (or no valid pair) is live.
func forecast_context() -> Dictionary:
	if controller == null:
		return {}
	return controller.forecast_context(
		current_ally(), current_target(), controller.action_by_id(&"strike")
	)


func select_next_enemy() -> void:
	if enemies.is_empty():
		return
	for offset in range(1, enemies.size() + 1):
		var index := (target_enemy_index + offset) % enemies.size()
		if enemies[index].is_alive():
			target_enemy_index = index
			turn_resolved.emit()
			return


func shift_balance(amount: int) -> void:
	if controller != null:
		controller.shift_balance(amount)
	else:
		balance = clampi(
			balance + amount,
			CombatIdentityCatalog.balance_minimum(),
			CombatIdentityCatalog.balance_maximum(),
		)
		balance_changed.emit(balance)


static func calculate_damage(
	attacker: BattleActor,
	target: BattleActor,
	power_bonus: int,
	alignment_shift: int,
	current_balance: int
) -> int:
	return CombatController.calculate_damage(
		attacker, target, power_bonus, alignment_shift, current_balance
	)


func _advance_party_turn() -> void:
	var next := _next_living_index(allies, active_ally_index)
	if next > active_ally_index:
		active_ally_index = next
		return
	_resolve_enemy_round()
	if _has_living(allies):
		active_ally_index = _next_living_index(allies, -1)
	else:
		_finish(BattleResult.State.DEFEAT, &"defeat")


func _resolve_enemy_round() -> void:
	enemy_rounds += 1
	for foe in enemies:
		if not foe.is_alive():
			continue
		var index := _next_living_index(allies, -1)
		if index < 0:
			return
		var target := allies[index]
		var damage := maxi(1, foe.attack - target.defense)
		if target.guarding:
			damage = maxi(1, damage / 2)
			target.guarding = false
		target.hp = maxi(0, target.hp - damage)
		shift_balance(foe.balance_affinity * foe.balance_pressure)
		last_message += " %s strikes %s for %d." % [foe.display_name, target.display_name, damage]


func _finish(state: BattleResult.State, outcome_id: StringName) -> void:
	if ended:
		return
	ended = true
	_sync_party_hp()
	if state == BattleResult.State.DEFEAT:
		for member in GameState.party:
			member.hp = maxi(1, ceili(member.max_hp * 0.5))
		GameState.party_changed.emit()
	var result := BattleResult.new()
	result.state = state
	result.encounter_id = encounter_id
	result.outcome_id = outcome_id
	_record_last_outcome(result)
	if state == BattleResult.State.VICTORY:
		_apply_victory(result)
	elif state == BattleResult.State.DEFEAT:
		result.message = "The company falls back and recovers to half strength."
		result.cause = _loss_cause()
		_apply_loss_consequence(result)
	else:
		var flee_outcome := EncounterCatalog.outcome(encounter_id, OUTCOME_FLED)
		result.message = str(
			flee_outcome.get("message", "The company disengages without reward or resolution.")
		)
		result.cause = _flee_cause()
		_apply_flee_consequence(result, flee_outcome)
	last_result = result
	battle_ended.emit(result)


func _apply_victory(result: BattleResult) -> void:
	result.spoils = EncounterCatalog.roll_spoils(encounter_id)
	var outcome := EncounterCatalog.outcome(encounter_id, result.outcome_id)
	result.message = str(outcome.get("message", "The opposition is defeated."))
	result.cause = str(outcome.get("cause", _definition.get("win_cause", "Won a field encounter")))
	_apply_authored_flags(outcome.get("flags", {}), result)
	var defeated_flag := str(_definition.get("defeated_flag", ""))
	if defeated_flag.is_empty() and not enemies.is_empty():
		defeated_flag = enemies[0].defeated_flag
	var consequence_flag := _consequence_flag(result.outcome_id)
	var already_resolved := (
		(not defeated_flag.is_empty() and GameState.flag_is_true(defeated_flag))
		or (not consequence_flag.is_empty() and GameState.flag_is_true(consequence_flag))
	)
	if not defeated_flag.is_empty():
		GameState.set_flag(defeated_flag, true)
	if not consequence_flag.is_empty():
		GameState.set_flag(consequence_flag, true)
	if already_resolved:
		return
	var faction := str(outcome.get("faction", _definition.get("win_faction", "")))
	var delta := float(outcome.get("delta", _definition.get("win_delta", 0.0)))
	if faction.is_empty() and not enemies.is_empty():
		faction = enemies[0].win_faction
		delta = enemies[0].win_delta
	var scene := _outcome_scene(outcome)
	if not faction.is_empty():
		Reputation.record("player", faction, delta, result.cause, scene)
	_record_renown(outcome, &"reputation", 3.0, result.cause, scene)
	var checkpoint := SaveGame.Checkpoint.RULING if result.outcome_id != &"slain" else SaveGame.Checkpoint.ENCOUNTER_RESOLUTION
	SaveGame.request_checkpoint(checkpoint, String(encounter_id) + "-" + String(result.outcome_id))


func _apply_flee_consequence(result: BattleResult, outcome: Dictionary) -> void:
	_apply_authored_flags(outcome.get("flags", {}), result)
	var consequence_flag := _consequence_flag(result.outcome_id)
	var already_recorded := (
		not consequence_flag.is_empty() and GameState.flag_is_true(consequence_flag)
	)
	if not consequence_flag.is_empty():
		GameState.set_flag(consequence_flag, true)
	if already_recorded:
		return

	var faction := str(outcome.get("faction", _definition.get("loss_faction", "")))
	var delta := float(outcome.get("delta", _definition.get("loss_delta", 0.0)))
	if faction.is_empty() and not enemies.is_empty():
		faction = enemies[0].loss_faction
		delta = enemies[0].loss_delta
	var scene := _outcome_scene(outcome)
	if not faction.is_empty():
		Reputation.record("player", faction, delta, result.cause, scene)
	_record_renown(outcome, &"infamy", absf(delta), result.cause, scene)
	SaveGame.request_checkpoint(
		SaveGame.Checkpoint.ENCOUNTER_RESOLUTION, String(encounter_id) + "-fled"
	)


func _record_renown(
	outcome: Dictionary,
	fallback_kind: StringName,
	fallback_delta: float,
	fallback_cause: String,
	scene: String,
) -> void:
	var delta := float(outcome.get("renown", fallback_delta))
	if is_zero_approx(delta):
		return
	var kind := StringName(outcome.get("renown_kind", fallback_kind))
	var cause := str(outcome.get("renown_cause", fallback_cause))
	if kind == &"infamy":
		Renown.gain_infamy("player", delta, cause, scene)
	else:
		Renown.gain_reputation("player", delta, cause, scene)


func _outcome_scene(outcome: Dictionary) -> String:
	return str(outcome.get("scene", _definition.get("scene", "field")))


func _apply_loss_consequence(result: BattleResult) -> void:
	var authored_loss := EncounterCatalog.loss(encounter_id)
	_apply_authored_flags(authored_loss.get("flags", {}), result)
	var consequence_flag := _consequence_flag(result.outcome_id)
	if not consequence_flag.is_empty() and GameState.flag_is_true(consequence_flag):
		return
	if not consequence_flag.is_empty():
		GameState.set_flag(consequence_flag, true)

	var faction := str(authored_loss.get("faction", ""))
	var delta := float(authored_loss.get("delta", 0.0))
	var cause := str(authored_loss.get("cause", result.cause))
	if not enemies.is_empty():
		faction = faction if not faction.is_empty() else enemies[0].loss_faction
		delta = delta if delta != 0.0 else enemies[0].loss_delta
		cause = cause if not cause.is_empty() else enemies[0].loss_cause
	if not faction.is_empty():
		Reputation.record("player", faction, delta, cause, "field")
		SaveGame.request_checkpoint(
			SaveGame.Checkpoint.ENCOUNTER_RESOLUTION, String(encounter_id) + "-defeat"
		)


func _apply_authored_flags(raw_flags: Variant, result: BattleResult) -> void:
	if not raw_flags is Dictionary:
		return
	for flag_key: Variant in raw_flags:
		var value: Variant = raw_flags[flag_key]
		if value is String:
			match value:
				"$outcome_id":
					value = String(result.outcome_id)
				"$cause":
					value = result.cause
				"$message":
					value = result.message
		GameState.set_flag(str(flag_key), value)


func _record_last_outcome(result: BattleResult) -> void:
	var outcome_flag := _outcome_flag()
	if not outcome_flag.is_empty():
		GameState.set_flag(outcome_flag, String(result.outcome_id))


func _loss_cause() -> String:
	var configured := str(_definition.get("loss_cause", ""))
	if not configured.is_empty():
		return configured
	if not enemies.is_empty() and not enemies[0].loss_cause.is_empty():
		return enemies[0].loss_cause
	return "The company was driven back by the opposition."


func _flee_cause() -> String:
	var outcome := EncounterCatalog.outcome(encounter_id, OUTCOME_FLED)
	var configured := str(outcome.get("cause", ""))
	if not configured.is_empty():
		return configured
	return "The company chose to preserve its strength and withdraw."


func _outcome_flag() -> String:
	if encounter_id.is_empty():
		return ""
	return "encounter_" + String(encounter_id).replace("-", "_") + "_outcome"


func _consequence_flag(outcome_id: StringName) -> String:
	if encounter_id.is_empty():
		return ""
	return (
		"encounter_" + String(encounter_id).replace("-", "_") + "_"
		+ String(outcome_id) + "_consequence"
	)


func _sync_party_hp() -> void:
	for actor in allies:
		if actor.party_index >= 0 and actor.party_index < GameState.party.size():
			GameState.party[actor.party_index].hp = actor.hp
	GameState.party_changed.emit()


func _prepare_enemy_knowledge() -> void:
	var lore_percent := 0.0
	for member: PartyMember in GameState.party:
		lore_percent = maxf(lore_percent, SkillCheck.preview("lore", member))
	var recorded_archetypes := {}
	for target: BattleActor in enemies:
		if target.archetype_id.is_empty():
			continue
		var archetype_key := String(target.archetype_id)
		if not recorded_archetypes.has(archetype_key):
			var prior_encounters := GameState.prior_archetype_encounters(target.archetype_id)
			for weakness: Dictionary in CombatIdentityCatalog.discovery_candidates(
				target.archetype_id, lore_percent, prior_encounters
			):
				GameState.discover_weakness(
					target.archetype_id, StringName(weakness.get("id", ""))
				)
			GameState.record_archetype_encounter(target.archetype_id)
			recorded_archetypes[archetype_key] = true
		target.discovered_weakness_ids = GameState.discovered_weaknesses(target.archetype_id)


func _resolved_action_options(
	_action: CombatAction, _target: BattleActor, options: Dictionary
) -> Dictionary:
	return options.duplicate(true)


func _speech_hook() -> Dictionary:
	var raw_hooks: Variant = _definition.get("speech_hooks", [])
	if raw_hooks is Dictionary:
		return raw_hooks.duplicate(true)
	if raw_hooks is Array:
		for raw_hook: Variant in raw_hooks:
			if raw_hook is Dictionary:
				return raw_hook.duplicate(true)
	return {}


func _speech_option(option_id: StringName) -> CombatSpeechOption:
	var raw_options: Variant = _speech_hook().get("options", [])
	if not raw_options is Array:
		return null
	for raw_option: Variant in raw_options:
		if raw_option is Dictionary and StringName(raw_option.get("id", "")) == option_id:
			return CombatSpeechOption.from_dict(raw_option)
	return null


func _action_by_id(action_id: StringName) -> CombatAction:
	for action in available_actions():
		if action.id == action_id:
			return action
	return null


func _living_enemy(preferred: int) -> BattleActor:
	if preferred >= 0 and preferred < enemies.size() and enemies[preferred].is_alive():
		return enemies[preferred]
	for actor in enemies:
		if actor.is_alive():
			return actor
	return null


func _shift_toward_center(amount: int) -> void:
	if balance > 0:
		shift_balance(-mini(balance, amount))
	elif balance < 0:
		shift_balance(mini(-balance, amount))


func _has_living(group: Array[BattleActor]) -> bool:
	return _next_living_index(group, -1) >= 0


func _next_living_index(group: Array[BattleActor], after: int) -> int:
	for i in range(after + 1, group.size()):
		if group[i].is_alive():
			return i
	return -1


func _default_outcome() -> StringName:
	if encounter_id.is_empty():
		return &"slain"
	return EncounterCatalog.default_outcome(encounter_id)


func _on_combat_event(event: CombatEvent) -> void:
	_combat_history.append(event)
	combat_event.emit(event)
	var snapshot: Dictionary = event.data.get("snapshot", {})
	balance = int(snapshot.get("balance", balance))
	if event.type == &"balance_changed":
		balance_changed.emit(balance)
	if event.type == &"enemy_turn_started":
		enemy_rounds += 1
	if event.data.has("message"):
		last_message = str(event.data["message"])
	if controller != null:
		var active := controller.active_actor()
		active_ally_index = allies.find(active) if active != null else -1
	if current_target() == null or not current_target().is_alive():
		target_enemy_index = _next_living_index(enemies, -1)
	if event.type in [
		&"action_resolved", &"action_refused", &"turn_started", &"turn_ended",
		&"round_started", &"round_ended", &"ap_refreshed",
	]:
		turn_resolved.emit()


func _on_controller_finished(
	state: CombatController.ResultState, outcome_id: StringName
) -> void:
	match state:
		CombatController.ResultState.VICTORY:
			_finish(
				BattleResult.State.VICTORY,
				_default_outcome() if outcome_id == &"slain" else outcome_id,
			)
		CombatController.ResultState.DEFEAT:
			_finish(BattleResult.State.DEFEAT, OUTCOME_DEFEAT)
		CombatController.ResultState.FLED:
			_finish(BattleResult.State.FLED, OUTCOME_FLED)


static func _blocked_reason(
	blocked_by: StringName, message: String, nearest_unblock: Dictionary
) -> Dictionary:
	return {
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": nearest_unblock.duplicate(true),
		"message": message,
	}
