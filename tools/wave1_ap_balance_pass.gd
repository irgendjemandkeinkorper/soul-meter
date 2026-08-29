extends SceneTree
## Wave 1 AP balance pass (ratified `docs/fallout2-adoption-spec.md`, Wave 1 item 6).
##
## Simulates each formerly-CT Phase-2 encounter deterministically under both schedulers
## and reports rounds-to-outcome, total damage dealt/taken, and ally KOs, so removing the
## five `_CHARGE_TIME_ENCOUNTERS` overrides ships with evidence instead of assertion.
## The scripted policy is deliberately plain — reference allies strike the first living
## enemy until out of AP (or once per CT ready) — because the comparison target is the
## SCHEDULER cadence, not build strategy.
##
## Run:  godot --headless --path . --script res://tools/wave1_ap_balance_pass.gd
## Judge the printed report, never the exit code (teardown aborts ~20-30%, see CLAUDE.md).

const ENCOUNTERS := [
	"phase2-demon",
	"phase2-undead",
	"phase2-mixed-whipsaw",
	"phase2-speech-winnable",
	"phase2-stabilizer-showcase",
]
const MAX_ROUNDS := 60


func _init() -> void:
	print("=== WAVE 1 AP BALANCE PASS — five ex-CT encounters, AP vs CT ===")
	for encounter_id: String in ENCOUNTERS:
		for use_ct: bool in [false, true]:
			var report := _simulate(StringName(encounter_id), use_ct)
			print(
				"%-28s %-3s rounds=%2d outcome=%-8s enemy_hp_left=%3d ally_hp_left=%3d ally_kos=%d"
				% [
					encounter_id,
					"CT" if use_ct else "AP",
					report["rounds"],
					report["outcome"],
					report["enemy_hp"],
					report["ally_hp"],
					report["ally_kos"],
				]
			)
	print("=== END WAVE 1 AP BALANCE PASS ===")
	quit(0)


func _simulate(encounter_id: StringName, use_ct: bool) -> Dictionary:
	var rules := (load("res://data/combat/combat_rules.tres") as CombatRules).duplicate(true)
	rules.use_charge_time = use_ct
	var battlefield := BattlefieldModel.create_default(rules)
	var allies: Array[BattleActor] = [
		_reference_ally("Ref Vanguard", 34, 8, 3, 4),
		_reference_ally("Ref Second", 30, 7, 2, 3),
	]
	var enemies := EncounterCatalog.make_actors(encounter_id)
	var controller := CombatController.new()
	controller.configure(CombatActionCatalog.all(), battlefield, rules)
	var final_result := {"state": -1}
	controller.battle_finished.connect(
		func(result_state: CombatController.ResultState, _outcome_id: StringName) -> void:
			final_result["state"] = result_state
	)
	controller.start(allies, enemies)

	var guard := 0
	while controller.state != CombatController.State.FINISHED \
			and controller.round_number <= MAX_ROUNDS and guard < 4000:
		guard += 1
		if controller.state == CombatController.State.ALLY_TURN:
			var target := _first_living(enemies)
			if target == null:
				break
			var acted := controller.submit_action(&"strike", target)
			if not bool(acted.get("allowed", false)) and not controller.end_turn():
				break
		elif controller.state == CombatController.State.ENEMY_TURN:
			controller.advance()
		else:
			controller.advance()

	return {
		"rounds": controller.round_number,
		"outcome": _outcome_name(int(final_result["state"])),
		"enemy_hp": _total_hp(enemies),
		"ally_hp": _total_hp(allies),
		"ally_kos": _ko_count(allies),
	}


func _reference_ally(display_name: String, hp: int, attack: int, defense: int, edge: int) -> BattleActor:
	var actor := BattleActor.new()
	actor.display_name = display_name
	actor.combat_id = StringName(display_name.to_snake_case())
	actor.hp = hp
	actor.max_hp = hp
	actor.attack = attack
	actor.defense = defense
	actor.attributes = {"edge": edge}
	actor.side = &"ally"
	return actor


func _first_living(group: Array[BattleActor]) -> BattleActor:
	for actor: BattleActor in group:
		if actor.is_alive():
			return actor
	return null


func _total_hp(group: Array[BattleActor]) -> int:
	var total := 0
	for actor: BattleActor in group:
		total += maxi(0, actor.hp)
	return total


func _ko_count(group: Array[BattleActor]) -> int:
	var count := 0
	for actor: BattleActor in group:
		if not actor.is_alive():
			count += 1
	return count


func _outcome_name(result_state: int) -> String:
	match result_state:
		CombatController.ResultState.VICTORY:
			return "VICTORY"
		CombatController.ResultState.DEFEAT:
			return "DEFEAT"
		CombatController.ResultState.FLED:
			return "FLED"
	return "TIMEOUT"
