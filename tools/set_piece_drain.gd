extends RefCounted
## P2.2 (#595): set-piece Breath drain. Plays the approved set-pieces (R14) with KitAI on both
## sides and reports, per class, the round a caster's Breath first cannot pay its cheapest kit
## spell against how long the fight lasts. R2's target: dry by PROVISIONAL round 3-4.
##
## Run through `tools/casting_economy_sweep.gd` (it loads this file once the autoloads exist):
##   godot --headless --path . --script res://tools/casting_economy_sweep.gd -- --set-pieces-only
## Read-only: it builds members and fights in memory and restores GameState afterwards.

## R14 (owner, 2026-10-31): the approved set-pieces. The Hollowmere entry is not authored yet.
const SET_PIECES: Array[StringName] = [&"dorthkor-muster", &"jawbrace-empty-post"]
## R3: Soul starts at 50. Overreach needs Soul to spend, so every fight starts there.
const START_SOUL := 50.0
const RULES_PATH := "res://data/combat/combat_rules.tres"
## Autoplay steps past this are a stall, not a fight.
const MAX_STEPS := 3000


## One row per (set-piece, party, class): the class's Breath, its cheapest kit spell, how long
## the fights ran and the round its Breath first could not pay that spell ("dry"). Solo rows
## put the class alone against the set-piece: the longest fight it can give. The five row is
## the class demo's player side, one row per member.
func print_report(seeds: int) -> void:
	_print_steady_table()
	var saved := GameState.to_dict().duplicate(true)
	print("")
	print("Set-piece Breath drain under KitAI (P2.2, R2 target: dry by PROVISIONAL round 3-4), %d fights per row" % seeds)
	print("KitAI prices damage, not Breath or Soul: it opens with its biggest spell and overreaches freely.")
	print("set_piece,party,class,breath_max,cheapest_spell,spells_cast_per_fight,wins,median_rounds,max_rounds,dry_fights,median_dry_round,overreach_casts")
	for encounter_id: StringName in SET_PIECES:
		for row: Dictionary in ClassCatalog.ALL:
			var class_id := str(row["id"])
			_print_rows(encounter_id, "solo", [class_id], seeds)
		_print_rows(encounter_id, "five", ClassDemo.PLAYER_SIDE, seeds)
	GameState.from_dict(saved)


## The turn a caster who casts one tier as often as its AP allows first meets a cast its Breath
## cannot pay (the overreach decision), by Intuition. Pure arithmetic on the live numbers:
## `DramgidDerived.breath_max`, the catalog's spell cards (cost, and the least AP any card of
## that cost needs) and the shipped rules' AP per turn. No dice, so no seeds.
func _print_steady_table() -> void:
	var rules := load(RULES_PATH) as CombatRules
	var ap := rules.base_action_points
	var least_ap := {}
	for action: CombatAction in CombatActionCatalog.all():
		if action.spell and action.breath_cost > 0:
			var key := action.breath_cost
			least_ap[key] = mini(int(least_ap.get(key, action.ap_cost)), action.ap_cost)
	print("")
	print("Steady casting: the turn the overreach decision first appears (%d AP per turn)" % ap)
	print("magnitude,breath_cost,least_ap,casts_per_turn,int2,int3,int4,int5")
	for magnitude: StringName in AbilityDefinition.BREATH_COST_BY_MAGNITUDE:
		var cost := AbilityDefinition.breath_cost_for_magnitude(magnitude)
		var card_ap := int(least_ap.get(cost, 0))
		if card_ap <= 0:
			print("%s,%d,-,-,no card,no card,no card,no card" % [magnitude, cost])
			continue
		var per_turn := maxi(ap / card_ap, 1)
		var turns: Array[String] = []
		for intuition: int in range(2, 6):
			turns.append(str(decision_turn(DramgidDerived.breath_max(intuition), cost, per_turn)))
		print("%s,%d,%d,%d,%s" % [magnitude, cost, card_ap, per_turn, ",".join(turns)])


## Turn (1-based) of the first cast `pool` cannot pay at `cost` Breath, `per_turn` casts a turn.
static func decision_turn(pool: int, cost: int, per_turn: int) -> int:
	var breath := pool
	var turn := 1
	while true:
		for _cast: int in per_turn:
			if breath < cost:
				return turn
			breath -= cost
		turn += 1
	return turn


func _print_rows(encounter_id: StringName, party: String, class_ids: Array[String], seeds: int) -> void:
	var fights: Array[Dictionary] = []
	for fight: int in seeds:
		fights.append(_set_piece_fight(encounter_id, class_ids, (fight + 1) * 104729))
	var wins := 0
	var rounds: Array[int] = []
	for result: Dictionary in fights:
		if int(result["result"]) == CombatController.ResultState.VICTORY:
			wins += 1
		rounds.append(int(result["rounds"]))
	for class_id: String in class_ids:
		var dry_rounds: Array[int] = []
		var overreach := 0
		var casts := 0
		for result: Dictionary in fights:
			var member: Dictionary = result["members"][class_id]
			if int(member["dry_round"]) > 0:
				dry_rounds.append(int(member["dry_round"]))
			overreach += int(member["overreach_casts"])
			casts += int(member["casts"])
		var first: Dictionary = fights[0]["members"][class_id]
		var cheapest := int(first["cheapest_spell"])
		print("%s,%s,%s,%d,%s,%.1f,%d/%d,%s,%d,%d/%d,%s,%d" % [
			encounter_id, party, class_id, int(first["breath_max"]),
			str(cheapest) if cheapest > 0 else "none",
			float(casts) / float(fights.size()),
			wins, fights.size(), _median(rounds), _max(rounds),
			dry_rounds.size(), fights.size(),
			_median(dry_rounds) if not dry_rounds.is_empty() else "-",
			overreach,
		])


## One whole set-piece with KitAI playing the party (autoplay) and the encounter. Rules are
## the live game's: the shipped CombatRules with the encounter's own charge-time setting, as
## `Battle.start()` builds them. The board is an open 12x6 grid, not the field map.
func _set_piece_fight(encounter_id: StringName, class_ids: Array[String], fight_seed: int) -> Dictionary:
	GameState.soul_meter = START_SOUL
	var definition := EncounterCatalog.definition(encounter_id)
	var rules := (load(RULES_PATH) as CombatRules).duplicate(true) as CombatRules
	rules.use_charge_time = bool(definition.get("use_charge_time", rules.use_charge_time))
	var actions := CombatActionCatalog.all()
	for row: Dictionary in EncounterCatalog.context_actions(encounter_id):
		actions.append(CombatAction.from_context_row(row))
	var ground := TileMapLayer.new()
	var controller := CombatController.new()
	controller.configure(actions, _open_grid(ground, rules, 12, 6), rules)
	controller.fight_seed = fight_seed
	controller.autoplay_allies = true

	var spell_costs := {}
	for action: CombatAction in actions:
		if action.spell:
			spell_costs[String(action.id)] = action.breath_cost
	# Parallel arrays: combat ids are assigned inside `start()`, so rows follow the actor.
	var allies: Array[BattleActor] = []
	var rows: Array[Dictionary] = []
	for class_id: String in class_ids:
		var member := ClassDemo.member(class_id)
		# Per-scene refill (R2): every scene, and so every set-piece, opens on a full pool.
		member.breath = member.breath_max
		var actor := BattleActor.from_party_member(member, allies.size())
		allies.append(actor)
		rows.append({
			"class_id": class_id, "breath_max": member.breath_max, "cheapest_spell": _cheapest_spell(actor),
			"dry_round": 0, "overreach_casts": 0, "casts": 0, "breath_seen": member.breath_max,
		})
	var outcome := {"result": -1}
	controller.battle_finished.connect(
		func(state: CombatController.ResultState, _outcome_id: StringName) -> void:
			outcome["result"] = state
	)
	controller.event_emitted.connect(func(event: CombatEvent) -> void:
		var index := -1
		for i: int in allies.size():
			if allies[i].combat_id == event.actor_id:
				index = i
				break
		if index >= 0:
			_note_event(controller, event, allies[index], rows[index], spell_costs)
		# Every ally's Breath as of the last turn start or resolved action, so a restore between
		# two casts is not read as one. Events inside a cast (Aftertones, Tempo...) fire before
		# its `action_resolved` and must not move the mark.
		if event.type in [&"turn_started", &"action_resolved"]:
			for i: int in allies.size():
				rows[i]["breath_seen"] = allies[i].breath
	)
	controller.start(allies, EncounterCatalog.make_actors(encounter_id), encounter_id)
	var steps := 0
	while controller.state != CombatController.State.FINISHED and steps < MAX_STEPS:
		steps += 1
		if not controller.autoplay_step():
			break
	var by_class := {}
	for row: Dictionary in rows:
		by_class[row["class_id"]] = row
	var result := {"result": outcome["result"], "rounds": controller.round_number, "members": by_class}
	for actor: BattleActor in controller.allies + controller.enemies:
		if actor.class_resource != null:
			actor.class_resource.host = null
	ground.free()
	return result


## Dry: the first of this ally's turns that opens with less Breath than its cheapest spell.
## Overreach: a spell whose Breath paid (the drop since the last turn start or resolved action)
## is short of its cost, so Resolution paid the rest in Soul.
func _note_event(
	controller: CombatController, event: CombatEvent, actor: BattleActor, row: Dictionary, spell_costs: Dictionary
) -> void:
	if event.type == &"turn_started":
		var cheapest := int(row["cheapest_spell"])
		if cheapest > 0 and int(row["dry_round"]) == 0 and actor.breath < cheapest:
			row["dry_round"] = controller.round_number
	elif event.type == &"action_resolved":
		var cost := int(spell_costs.get(str(event.data.get("action_id", "")), 0))
		if cost > 0:
			row["casts"] = int(row["casts"]) + 1
			if int(row["breath_seen"]) - actor.breath < cost:
				row["overreach_casts"] = int(row["overreach_casts"]) + 1


## The cheapest Breath-costing spell this member's kit (KitAI's own list) can cast; 0 for none.
func _cheapest_spell(actor: BattleActor) -> int:
	var cheapest := 0
	for action: CombatAction in KitAI.kit_actions(actor):
		if action.spell and action.breath_cost > 0 and (cheapest == 0 or action.breath_cost < cheapest):
			cheapest = action.breath_cost
	return cheapest


func _open_grid(ground: TileMapLayer, rules: CombatRules, width: int, height: int) -> GridBattlefieldModel:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(64, 32)
	var image := Image.create(64, 32, false, Image.FORMAT_RGBA8)
	var source := TileSetAtlasSource.new()
	source.texture = ImageTexture.create_from_image(image)
	source.texture_region_size = Vector2i(64, 32)
	source.create_tile(Vector2i.ZERO)
	tile_set.add_source(source, 0)
	ground.tile_set = tile_set
	for y: int in height:
		for x: int in width:
			ground.set_cell(Vector2i(x, y), 0, Vector2i.ZERO)
	var model := GridBattlefieldModel.new()
	model.configure(rules)
	model.build_grid(ground)
	return model


static func _median(values: Array[int]) -> String:
	if values.is_empty():
		return "-"
	var sorted := values.duplicate()
	sorted.sort()
	return str(sorted[sorted.size() / 2])


static func _max(values: Array[int]) -> int:
	var top := 0
	for value: int in values:
		top = maxi(top, value)
	return top
