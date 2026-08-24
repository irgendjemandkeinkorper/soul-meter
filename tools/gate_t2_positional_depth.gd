extends SceneTree

## Gate T-2 deterministic positional-depth comparison.
##
## Pre-registered before execution:
## - Encounter: originally the fixed `phase2-demon` entry. After rerun 3 (see
##   docs/gate-t2-evidence.md) the owner ratified a PRE-REGISTERED SELECTION RULE (2026-08-24,
##   #169), fixed before any per-encounter comparison was looked at: run the NAIVE arm across
##   every charge-time catalog encounter and select the one with the LOWEST naive party-HP
##   fraction (a naive defeat selects immediately; ties break lexicographically by id). The
##   selection metric never sees positional-arm results, so the rule cannot optimize for the
##   differential — it finds the encounter where survival pressure is real, which is what the
##   original fixed choice lacked. Seed 1_692_002 and the identical two-member party stay.
## - Arm A: the shared ally policy includes elevation, facing, and rear-access scoring.
## - Arm B: the same policy with those positional score terms set to zero.
## - Enemy policy: production CombatController AI in both arms; it seeks reachable height and
##   faces the party through the BattlefieldModel capability seam.
## - PASS threshold: Arm A victory AND Arm B defeat. No fallback threshold is accepted.
##
## Canonical invocation:
##   SOUL_METER_HEADLESS=1 godot --headless --path . \
##     --script res://tools/gate_t2_positional_depth.gd

const ENCOUNTER_ID := &"phase2-demon"  # rerun 1-3 fixed encounter; kept for the evidence trail
const CANDIDATE_ENCOUNTERS: Array[StringName] = [
	&"phase2-demon",
	&"phase2-mixed-whipsaw",
	&"phase2-speech-winnable",
	&"phase2-stabilizer-showcase",
	&"phase2-undead",
]
const SEED := 1_692_002
const GRID_WIDTH := 8
const GRID_HEIGHT := 5
const MAX_ALLY_DECISIONS := 300
const MOVE_ACTION_ID := &"__gate_t2_ally_move__"
const RIDGE_ELEVATION := 2
const FACING_ORDER: Array[StringName] = [
	&"e", &"se", &"s", &"sw", &"w", &"nw", &"n", &"ne"
]


func _initialize() -> void:
	var comparison: Dictionary = run_comparison()
	print(JSON.stringify(comparison))
	quit(0 if bool(comparison.get("passed", false)) else 2)


static func run_comparison() -> Dictionary:
	var selection: Dictionary = _select_encounter()
	var encounter_id: StringName = selection["selected"]
	var positional: Dictionary = _run_arm(true, encounter_id)
	var naive: Dictionary = _run_arm(false, encounter_id)
	return {
		"gate": "T-2 positional depth",
		"encounter_id": String(encounter_id),
		"selection": selection,
		"seed": SEED,
		"threshold": "positional victory AND naive defeat",
		"positional": positional,
		"naive": naive,
		"passed": (
			positional.get("outcome", "") == "victory"
			and naive.get("outcome", "") == "defeat"
		),
	}


## The pre-registered selection rule (#169, 2026-08-24). Runs ONLY the naive arm per candidate;
## positional results play no part in selection.
static func _select_encounter() -> Dictionary:
	var rows: Array[Dictionary] = []
	var best_id: StringName = CANDIDATE_ENCOUNTERS[0]
	var best_fraction := 999.0
	for candidate: StringName in CANDIDATE_ENCOUNTERS:
		var naive: Dictionary = _run_arm(false, candidate)
		var max_hp := 54.0  # 30 + 24, the fixed probe party
		var fraction := float(naive.get("party_hp", 0)) / max_hp
		if naive.get("outcome", "") == "defeat":
			fraction = 0.0
		rows.append({
			"encounter_id": String(candidate),
			"naive_outcome": naive.get("outcome", ""),
			"naive_party_hp": naive.get("party_hp", 0),
			"fraction": fraction,
		})
		if fraction < best_fraction:
			best_fraction = fraction
			best_id = candidate
	return {"rule": "lowest naive party-HP fraction; defeat wins; lexicographic tie", "rows": rows, "selected": best_id}


static func _run_arm(use_positioning: bool, encounter_id: StringName = ENCOUNTER_ID) -> Dictionary:
	var loaded_rules := load("res://data/combat/combat_rules.tres") as CombatRules
	var rules: CombatRules = loaded_rules.duplicate(true) as CombatRules
	rules.use_grid_battlefield = true
	rules.use_charge_time = true
	var ground: TileMapLayer = _ground()
	var battlefield := GridBattlefieldModel.new()
	battlefield.configure(rules)
	battlefield.build_grid(ground)
	for x in range(1, GRID_WIDTH - 1):
		battlefield.set_elevation(Vector2i(x, 2), RIDGE_ELEVATION)

	var allies: Array[BattleActor] = _party()
	var enemies: Array[BattleActor] = EncounterCatalog.make_actors(encounter_id)
	var move_action := CombatAction.new()
	move_action.id = MOVE_ACTION_ID
	move_action.display_name = "Probe Move"
	move_action.kind = CombatAction.Kind.MOVE
	move_action.verb = CombatAction.Verb.MOVE
	move_action.target_profile = &"self"
	move_action.player_available = false
	var actions: Array[CombatAction] = CombatActionCatalog.all()
	actions.append(move_action)
	var controller := CombatController.new()
	controller.configure(actions, battlefield, rules)
	controller.start(allies, enemies, StringName("gate-t2-%d" % SEED))

	var decisions := 0
	var moves := 0
	var rear_attacks := 0
	var refused_actions := 0
	var highest_elevation := 0
	while controller.state != CombatController.State.FINISHED and decisions < MAX_ALLY_DECISIONS:
		var actor: BattleActor = controller.active_actor()
		if actor == null or actor.side != &"ally":
			break
		var target: BattleActor = _first_living(enemies)
		if target == null:
			break
		var choice: Dictionary = _choose_action(actor, target, battlefield, rules, use_positioning)
		var result: Dictionary = {}
		if choice.get("kind", &"") == &"attack":
			if use_positioning:
				_face_toward(actor, target, battlefield)
			if battlefield.flank_bonus(actor, target) > 0:
				rear_attacks += 1
			result = controller.submit_action(&"strike", target)
		elif choice.get("kind", &"") == &"move":
			var destination: StringName = choice.get("destination", &"")
			var path: Dictionary = battlefield.path_query(actor, destination)
			move_action.destination = destination
			move_action.ap_cost = 1
			move_action.ct_cost = int(path.get("ct_cost", rules.move_ct_cost))
			result = controller.submit_action(MOVE_ACTION_ID)
			if bool(result.get("allowed", false)):
				moves += 1
				var position: Dictionary = battlefield.describe_position(battlefield.position_of(actor))
				highest_elevation = maxi(
					highest_elevation, int(position.get("elevation", 0))
				)
				if use_positioning:
					_face_toward(actor, target, battlefield)
		else:
			controller.end_turn()
			decisions += 1
			continue
		if not bool(result.get("allowed", false)):
			refused_actions += 1
			controller.end_turn()
		decisions += 1

	var outcome := "timeout"
	if not _has_living(allies):
		outcome = "defeat"
	elif not _has_living(enemies):
		outcome = "victory"
	var report := {
		"arm": "positional" if use_positioning else "naive",
		"outcome": outcome,
		"ally_decisions": decisions,
		"moves": moves,
		"rear_attacks": rear_attacks,
		"highest_elevation": highest_elevation,
		"refused_actions": refused_actions,
		"party_hp": _living_hp(allies),
		"enemy_hp": _living_hp(enemies),
		"party_survivors": _living_count(allies),
		"enemy_survivors": _living_count(enemies),
	}
	ground.free()
	return report


static func _choose_action(
	actor: BattleActor,
	target: BattleActor,
	battlefield: GridBattlefieldModel,
	rules: CombatRules,
	use_positioning: bool
) -> Dictionary:
	var options: Array[Dictionary] = []
	var targeting: Dictionary = battlefield.target_query(actor, target, &"melee")
	if bool(targeting.get("allowed", false)):
		var attack_score := 10_000
		if use_positioning and battlefield.flank_bonus(actor, target) > 0:
			attack_score += 30_000
		options.append({"kind": &"attack", "score": attack_score, "tie": "attack"})

	var budget := rules.maximum_action_ct_cost
	for destination in battlefield.reachable_positions(actor, budget):
		var described: Dictionary = battlefield.describe_position(destination)
		var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
		if not described.has("cell") or not target_position.has("cell"):
			continue
		var candidate_cell: Vector2i = described.get("cell", Vector2i.ZERO)
		var target_cell: Vector2i = target_position.get("cell", Vector2i.ZERO)
		var delta := candidate_cell - target_cell
		var distance := maxi(absi(delta.x), absi(delta.y))
		var score := -distance * 100
		if distance <= 1:
			score += 1000
		if use_positioning:
			score += int(described.get("elevation", 0)) * 2000
			if actor.party_index == 1:
				var attack_direction := _facing_for_delta(delta)
				if attack_direction == _opposite_facing(battlefield.facing_of(target)):
					score += 20_000
		options.append({
			"kind": &"move", "destination": destination, "score": score, "tie": String(destination)
		})
	if options.is_empty():
		return {"kind": &"pass"}
	options.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a.get("score", 0)) != int(b.get("score", 0)):
			return int(a.get("score", 0)) > int(b.get("score", 0))
		return str(a.get("tie", "")) < str(b.get("tie", ""))
	)
	return options[0]

static func _face_toward(
	actor: BattleActor, target: BattleActor, battlefield: GridBattlefieldModel
) -> void:
	var actor_position: Dictionary = battlefield.describe_position(battlefield.position_of(actor))
	var target_position: Dictionary = battlefield.describe_position(battlefield.position_of(target))
	var actor_cell: Vector2i = actor_position.get("cell", Vector2i.ZERO)
	var target_cell: Vector2i = target_position.get("cell", Vector2i.ZERO)
	var facing := _facing_for_delta(target_cell - actor_cell)
	if facing != &"":
		battlefield.set_facing(actor, facing)


static func _facing_for_delta(delta: Vector2i) -> StringName:
	if delta == Vector2i.ZERO:
		return &""
	var index := int(round(atan2(delta.y, delta.x) / (PI / 4.0)))
	index = ((index % FACING_ORDER.size()) + FACING_ORDER.size()) % FACING_ORDER.size()
	return FACING_ORDER[index]


static func _opposite_facing(facing: StringName) -> StringName:
	var index := FACING_ORDER.find(facing)
	return &"" if index == -1 else FACING_ORDER[(index + 4) % FACING_ORDER.size()]


static func _party() -> Array[BattleActor]:
	var anchor := _actor("Gate Anchor", 30, 7, 2, 8)
	anchor.party_index = 0
	var flanker := _actor("Gate Flanker", 24, 6, 1, 8)
	flanker.party_index = 1
	return [anchor, flanker]


static func _actor(name: String, hp: int, attack: int, defense: int, edge: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = name
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	actor.attributes = {&"edge": edge}
	return actor


static func _ground() -> TileMapLayer:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var texture := ImageTexture.create_from_image(image)
	var source := TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	var layer := TileMapLayer.new()
	layer.tile_set = tile_set
	for y in GRID_HEIGHT:
		for x in GRID_WIDTH:
			layer.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	return layer


static func _first_living(group: Array[BattleActor]) -> BattleActor:
	for actor in group:
		if actor.is_alive():
			return actor
	return null


static func _has_living(group: Array[BattleActor]) -> bool:
	return _living_count(group) > 0


static func _living_count(group: Array[BattleActor]) -> int:
	var count := 0
	for actor in group:
		if actor.is_alive():
			count += 1
	return count


static func _living_hp(group: Array[BattleActor]) -> int:
	var total := 0
	for actor in group:
		total += maxi(actor.hp, 0)
	return total
