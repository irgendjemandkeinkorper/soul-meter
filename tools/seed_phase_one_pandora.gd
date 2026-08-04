extends Node
## Idempotent Pandora migration for the ratified Phase 1 casting data and the
## FR-108 encounter schema. This writes authored source data only; generators
## remain the one-way path from Pandora to runtime artifacts.

const ELEMENT_PROPERTIES := [
	["Display Name", "string"],
	["Vault Id", "string"],
	["Element Id", "string"],
	["Imposition Id", "string"],
	["Imposition Display Name", "string"],
	["Rule Bend Id", "string"],
	["Rule Bend Description", "string"],
	["Deals Damage", "bool"],
]
const TRIAD_PROPERTIES := [
	["Display Name", "string"],
	["Vault Id", "string"],
	["Triad Id", "string"],
	["Elements", "string"],
	["Center", "string"],
	["Unique Effect Id", "string"],
	["Unique Effect Display Name", "string"],
	["Unique Effect Parameters", "string"],
]
const IMPOSITION_PROPERTIES := [
	["Display Name", "string"],
	["Vault Id", "string"],
	["Imposition Id", "string"],
]
const RULE_BEND_PROPERTIES := [
	["Display Name", "string"],
	["Vault Id", "string"],
	["Rule Bend Id", "string"],
	["Description", "string"],
]
const BREADTH_PROPERTIES := [
	["Display Name", "string"],
	["Vault Id", "string"],
	["Breadth Id", "string"],
	["Element Count", "int"],
	["Fizzle Add", "float"],
]
const MAGNITUDE_PROPERTIES := [
	["Display Name", "string"],
	["Vault Id", "string"],
	["Magnitude Id", "string"],
	["Multiplier", "float"],
]
const FIZZLE_PROPERTIES := [
	["Display Name", "string"],
	["Vault Id", "string"],
	["Table Id", "string"],
	["Breadth Add", "string"],
	["Strain Add", "string"],
	["Magnitude Multiplier", "string"],
]
const ENCOUNTER_SCHEMA_PROPERTIES := [
	["Composition", "string"],
	["Zone Layout", "string"],
	["Balance Bias", "float"],
	["Speech Hooks", "string"],
]
const BALANCE_BAND_PROPERTIES := [
	["Display Name", "string"],
	["Band Id", "string"],
	["Minimum", "int"],
	["Maximum", "int"],
	["Global", "bool"],
	["Effect Parameters", "string"],
	["Tunable", "bool"],
]
const DEFINING_WEAKNESS_PROPERTIES := [
	["Display Name", "string"],
	["Archetype Id", "string"],
	["Weakness Id", "string"],
	["Check Skill", "string"],
	["Check Modifier", "float"],
	["Lore Minimum", "float"],
	["Prior Encounters", "int"],
	["Effect Id", "string"],
	["Effect Parameters", "string"],
	["Resistance Stat", "string"],
	["Resistance Threshold", "int"],
]


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()
	_seed_elements()
	_seed_triads()
	_seed_impositions()
	_seed_rule_bends()
	_seed_breadths()
	_seed_magnitudes()
	_seed_fizzle()
	_seed_encounter_schema()
	_seed_balance_bands()
	_seed_defining_weaknesses()
	Pandora.save_data()
	print("PHASE-1-SEED: casting, encounter, and combat-identity data present.")
	get_tree().quit()


func _ensure_root(root_name: String, properties: Array) -> PandoraCategory:
	var root: PandoraCategory = null
	for candidate: PandoraCategory in Pandora.get_all_roots():
		if candidate.get_entity_name() == root_name:
			root = candidate
			break
	if root == null:
		root = Pandora.create_category(root_name)
	for property_spec: Array in properties:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])
	return root


func _assign(entity: PandoraEntity, property_name: String, value: Variant) -> void:
	var property := entity.get_entity_property(property_name)
	if property != null:
		property.set_default_value(value)


func _upsert(root: PandoraCategory, entity_name: String, values: Dictionary) -> void:
	var entity: PandoraEntity = null
	for candidate: PandoraEntity in Pandora.get_all_entities(root):
		if not candidate is PandoraCategory and candidate.get_entity_name() == entity_name:
			entity = candidate
			break
	if entity == null:
		entity = Pandora.create_entity(entity_name, root)
	for property_name: String in values:
		_assign(entity, property_name, values[property_name])


func _seed_elements() -> void:
	var root := _ensure_root("Elements", ELEMENT_PROPERTIES)
	var rows := [
		["Suul", "suul", "exposed", "Exposed", "reveals_aftertones", "Reveals Aftertones, Discord signatures, and illusions.", true],
		["Bloei", "bloei", "overgrown", "Overgrown", "extends_own_buff_duration", "Extends the duration of your own buffs.", true],
		["Aqua", "aqua", "soaked", "Soaked", "restores_breath", "The only element that restores Breath.", true],
		["Khor", "khor", "", "", "extends_durations_holds_notes", "Extends durations and holds Notes across rounds.", false],
		["Terra", "terra", "weighted", "Weighted", "creates_cover_anchors_aftertones", "Creates cover and anchors Aftertones.", true],
		["Daar", "daar", "blinded", "Blinded", "conceals_discord_signatures", "Conceals Discord signatures.", true],
		["Molm", "molm", "decaying", "Decaying", "converts_to_breath", "Converts corpses and objects into Breath.", true],
		["Scor", "scor", "burning", "Burning", "consumes_aftertone_for_burst", "Consumes an Aftertone for burst power.", true],
		["Nul", "nul", "muted", "Muted", "cancels_and_zeroes_tempo", "Cancels buffs, ends Aftertones, and zeroes Tempo.", false],
		["Strom", "strom", "shocked", "Shocked", "ignores_instability_die", "Ignores the Instability die.", true],
	]
	for row: Array in rows:
		_upsert(
			root,
			row[0],
			{
				"Display Name": row[0],
				"Vault Id": "elements-and-music",
				"Element Id": row[1],
				"Imposition Id": row[2],
				"Imposition Display Name": row[3],
				"Rule Bend Id": row[4],
				"Rule Bend Description": row[5],
				"Deals Damage": row[6],
			}
		)


func _seed_triads() -> void:
	var root := _ensure_root("Triads", TRIAD_PROPERTIES)
	var rows := [
		["Dayspring", "dayspring", "strom,suul,bloei", "suul", "first_light", "First Light", {"duration": "round", "reveals": ["aftertones", "discord_signatures", "queued_effects", "discovered_weaknesses"], "defining_strike_cost": 0}],
		["Fruiting", "fruiting", "suul,bloei,aqua", "bloei", "second_season", "Second Season", {"copy_active_friendly_buffs": true, "targets_per_new_buff": 2}],
		["Rivermouth", "rivermouth", "bloei,aqua,khor", "aqua", "the_mouth_opens", "The Mouth Opens", {"duration": "round", "zone_change_ap": 0, "aoe_ignores_zone_boundaries": true}],
		["Founding", "founding", "aqua,khor,terra", "khor", "cornerstone", "Cornerstone", {"freeze_remaining_durations": true, "until": "end_of_next_turn"}],
		["Vault", "vault", "khor,terra,daar", "terra", "sealed_ground", "Sealed Ground", {"fortify_zone": true, "encounter_scope": true, "entry_ap_add": 1, "ranged_attacks_apply_weighted": true, "anchored_aftertones_enemy_consumption": false}],
		["Barrow", "barrow", "terra,daar,molm", "daar", "unlisted", "Unlisted", {"hide_friendly_signatures": true, "hide_friendly_queued_effects": true, "hide_friendly_positions": true, "enemy_back_zone_targetable": false, "enemy_reveal_effects": false, "duration": "round"}],
		["Pyre", "pyre", "daar,molm,scor", "molm", "the_rendering", "The Rendering", {"convert_corpses": true, "convert_destroyed_objects": true, "convert_expired_aftertones": true, "split_breath_across_side": true, "shared_corpse_applies_decaying": true}],
		["Cinderfall", "cinderfall", "molm,scor,nul", "scor", "everything_burns_at_once", "Everything Burns At Once", {"consume_all_aftertones": true, "include_both_sides": true, "yield_bursts_to_caster_side": true}],
		["Stillpoint", "stillpoint", "scor,nul,strom", "nul", "the_held_silence", "The Held Silence", {"balance_gauge": "exact_center", "lock_until": "end_of_next_round", "suppress_threshold_effects": true}],
		["Thunderhead", "thunderhead", "nul,strom,suul", "strom", "nothing_is_uncertain", "Nothing Is Uncertain", {"skip_instability_die": true, "out_of_turn_allies": 1, "duration": "round"}],
	]
	for row: Array in rows:
		_upsert(root, row[0], {
			"Display Name": row[0],
			"Vault Id": "elements-and-music",
			"Triad Id": row[1],
			"Elements": row[2],
			"Center": row[3],
			"Unique Effect Id": row[4],
			"Unique Effect Display Name": row[5],
			"Unique Effect Parameters": JSON.stringify(row[6]),
		})


func _seed_impositions() -> void:
	var root := _ensure_root("Impositions", IMPOSITION_PROPERTIES)
	var rows := [["Exposed", "exposed"], ["Overgrown", "overgrown"], ["Soaked", "soaked"], ["Weighted", "weighted"], ["Blinded", "blinded"], ["Decaying", "decaying"], ["Burning", "burning"], ["Muted", "muted"]]
	for row: Array in rows:
		_upsert(root, row[0], {"Display Name": row[0], "Vault Id": "elements-and-music", "Imposition Id": row[1]})


func _seed_rule_bends() -> void:
	var root := _ensure_root("Rule-Bends", RULE_BEND_PROPERTIES)
	var rows := [
		["Reveals Aftertones", "reveals_aftertones", "Reveals Aftertones, Discord signatures, and illusions."],
		["Extends Own Buff Duration", "extends_own_buff_duration", "Extends the duration of your own buffs."],
		["Restores Breath", "restores_breath", "The only element that restores Breath."],
		["Extends Durations and Holds Notes", "extends_durations_holds_notes", "Extends durations and holds Notes across rounds."],
		["Creates Cover and Anchors Aftertones", "creates_cover_anchors_aftertones", "Creates cover and anchors Aftertones."],
		["Conceals Discord Signatures", "conceals_discord_signatures", "Conceals Discord signatures."],
		["Converts to Breath", "converts_to_breath", "Converts corpses and objects into Breath."],
		["Consumes Aftertone for Burst", "consumes_aftertone_for_burst", "Consumes an Aftertone for burst power."],
		["Cancels and Zeroes Tempo", "cancels_and_zeroes_tempo", "Cancels buffs, ends Aftertones, and zeroes Tempo."],
		["Ignores Instability Die", "ignores_instability_die", "Ignores the Instability die."],
	]
	for row: Array in rows:
		_upsert(root, row[0], {"Display Name": row[0], "Vault Id": "elements-and-music", "Rule Bend Id": row[1], "Description": row[2]})


func _seed_breadths() -> void:
	var root := _ensure_root("Breadth", BREADTH_PROPERTIES)
	var rows := [["Tone", "tone", 1, 0.0], ["Chord", "chord", 2, 5.0], ["Triad", "triad", 3, 12.0]]
	for row: Array in rows:
		_upsert(root, row[0], {"Display Name": row[0], "Vault Id": "elements-and-music", "Breadth Id": row[1], "Element Count": row[2], "Fizzle Add": row[3]})


func _seed_magnitudes() -> void:
	var root := _ensure_root("Magnitude", MAGNITUDE_PROPERTIES)
	var rows := [["Note", "note", 0.5], ["Phrase", "phrase", 1.0], ["Song", "song", 1.75], ["Refrain", "refrain", 2.75]]
	for row: Array in rows:
		_upsert(root, row[0], {"Display Name": row[0], "Vault Id": "elements-and-music", "Magnitude Id": row[1], "Multiplier": row[2]})


func _seed_fizzle() -> void:
	var root := _ensure_root("Fizzle Tables", FIZZLE_PROPERTIES)
	_upsert(root, "Default Fizzle Table", {
		"Display Name": "Default Fizzle Table",
		"Vault Id": "magic-system",
		"Table Id": "default",
		"Breadth Add": JSON.stringify({"tone": 0.0, "chord": 5.0, "triad": 12.0}),
		"Strain Add": JSON.stringify({"0": 0.0, "1": 0.0, "2": 6.0, "3": 12.0, "4": 18.0}),
		"Magnitude Multiplier": JSON.stringify({"note": 0.5, "phrase": 1.0, "song": 1.75, "refrain": 2.75}),
	})


func _seed_encounter_schema() -> void:
	var root: PandoraCategory = null
	for candidate: PandoraCategory in Pandora.get_all_roots():
		if candidate.get_entity_name() == "Encounters":
			root = candidate
			break
	if root == null:
		return
	for property_spec: Array in ENCOUNTER_SCHEMA_PROPERTIES:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])
	for entity: PandoraEntity in Pandora.get_all_entities(root):
		if entity is PandoraCategory:
			continue
		_assign(entity, "Composition", "{}")
		_assign(entity, "Zone Layout", "[]")
		_assign(entity, "Balance Bias", 0.0)
		_assign(entity, "Speech Hooks", "[]")
	_seed_phase_two_encounters(root)


func _seed_balance_bands() -> void:
	var root := _ensure_root("Balance Bands", BALANCE_BAND_PROPERTIES)
	var rows := [
		["Chaos Extreme", "chaos_extreme", -100, -60, true, {"damage_bonus": 2}],
		["Chaosward", "chaosward", -59, -21, true, {}],
		["Held Centre", "center", -20, 20, false, {"defense_bonus": 2}],
		["Orderward", "orderward", 21, 59, true, {}],
		["Order Extreme", "order_extreme", 60, 100, true, {"damage_bonus": 2}],
	]
	for row: Array in rows:
		_upsert(root, row[0], {
			"Display Name": row[0],
			"Band Id": row[1],
			"Minimum": row[2],
			"Maximum": row[3],
			"Global": row[4],
			"Effect Parameters": JSON.stringify(row[5]),
			"Tunable": true,
		})


func _seed_defining_weaknesses() -> void:
	var root := _ensure_root("Defining Weaknesses", DEFINING_WEAKNESS_PROPERTIES)
	var rows: Array[Dictionary] = [
		_weakness_row("Bog Wight — Hidden Shape", "bog-wight", "bog-wight/reveal", "what it conceals", "insight", 0.0, 0, "reveal", {"revealed": true}),
		_weakness_row("Bog Wight — Knee", "bog-wight", "bog-wight/knee", "the knee", "lore", 40.0, 1, "cripple", {"crippled": true, "max_ap_delta": -1}),
		_weakness_row("Loam Boar — Knee", "loam-maddened-boar", "loam-maddened-boar/knee", "the knee", "lore", 0.0, 0, "cripple", {"crippled": true, "max_ap_delta": -1}),
		_weakness_row("Loam Boar — Buried Rage", "loam-maddened-boar", "loam-maddened-boar/reveal", "what it conceals", "insight", 40.0, 1, "reveal", {"revealed": true}),
		_weakness_row("Gnaal Breach-Hound — Knee", "gnaal-breach-hound", "gnaal-breach-hound/knee", "the knee", "lore", 0.0, 0, "cripple", {"crippled": true, "max_ap_delta": -1}),
		_weakness_row("Gnaal Breach-Hound — Breach Name", "gnaal-breach-hound", "gnaal-breach-hound/reveal", "what it conceals", "insight", 40.0, 1, "reveal", {"revealed": true}),
		_weakness_row("Gnaal Rift-Scavenger — Grasp", "gnaal-rift-scavenger", "gnaal-rift-scavenger/disarm", "the hand that holds it", "lore", 0.0, 0, "disarm", {"attack_delta": -2, "disarmed": true}),
		_weakness_row("Gnaal Rift-Scavenger — Rift Path", "gnaal-rift-scavenger", "gnaal-rift-scavenger/reveal", "what it conceals", "insight", 40.0, 1, "reveal", {"revealed": true}),
		_weakness_row("Mustered Bloodbellow — Binding Oath", "mustered-bloodbellow", "mustered-bloodbellow/binding-oath", "the oath that binds it", "lore", 0.0, 0, "bind_break", {"binding_broken": true, "defense_delta": -2}),
		_weakness_row("Mustered Bloodbellow — Mustered Weapon", "mustered-bloodbellow", "mustered-bloodbellow/disarm", "the hand that holds it", "insight", 40.0, 1, "disarm", {"attack_delta": -2, "disarmed": true}),
		_weakness_row("Cleaned Guard — Binding Oath", "cleaned-jawbrace-guard", "cleaned-jawbrace-guard/binding-oath", "the oath that binds it", "lore", 0.0, 0, "bind_break", {"binding_broken": true, "defense_delta": -2}),
		_weakness_row("Cleaned Guard — Gripping Hand", "cleaned-jawbrace-guard", "cleaned-jawbrace-guard/disarm", "the hand that holds it", "insight", 40.0, 1, "disarm", {"attack_delta": -2, "disarmed": true}),
	]
	for row: Dictionary in rows:
		var entity_name := str(row.get("Entity Name", ""))
		row.erase("Entity Name")
		_upsert(root, entity_name, row)


func _weakness_row(
	entity_name: String,
	archetype_id: String,
	weakness_id: String,
	display_name: String,
	check_skill: String,
	lore_minimum: float,
	prior_encounters: int,
	effect_id: String,
	effect_parameters: Dictionary
) -> Dictionary:
	return {
		"Entity Name": entity_name,
		"Display Name": display_name,
		"Archetype Id": archetype_id,
		"Weakness Id": weakness_id,
		"Check Skill": check_skill,
		"Check Modifier": 0.0,
		"Lore Minimum": lore_minimum,
		"Prior Encounters": prior_encounters,
		"Effect Id": effect_id,
		"Effect Parameters": JSON.stringify(effect_parameters),
		"Resistance Stat": "defense",
		"Resistance Threshold": 6,
	}


func _seed_phase_two_encounters(root: PandoraCategory) -> void:
	var fixtures: Array[Dictionary] = [
		_encounter_fixture(
			"Phase 2 Gate - Demon",
			"phase2-demon",
			["demon"],
			["gnaal-breach-hound", "gnaal-rift-scavenger"],
			[
				{
					"side": "enemy",
					"zone": "front",
					"combatant_ids": ["gnaal-breach-hound"],
				},
				{
					"side": "enemy",
					"zone": "flank",
					"combatant_ids": ["gnaal-rift-scavenger"],
				},
			],
			-1.0,
		),
		_encounter_fixture(
			"Phase 2 Gate - Undead",
			"phase2-undead",
			["undead"],
			["cleaned-jawbrace-guard", "mustered-bloodbellow"],
			[
				{
					"side": "enemy",
					"zone": "front",
					"combatant_ids": ["cleaned-jawbrace-guard"],
				},
				{
					"side": "enemy",
					"zone": "back",
					"combatant_ids": ["mustered-bloodbellow"],
				},
			],
			1.0,
		),
		_encounter_fixture(
			"Phase 2 Gate - Mixed Whipsaw",
			"phase2-mixed-whipsaw",
			["demon", "undead"],
			["mustered-bloodbellow", "gnaal-breach-hound"],
			[
				{
					"side": "enemy",
					"zone": "front",
					"combatant_ids": ["mustered-bloodbellow"],
				},
				{
					"side": "enemy",
					"zone": "flank",
					"combatant_ids": ["gnaal-breach-hound"],
				},
			],
			0.0,
		),
		_speech_fixture(),
		_encounter_fixture(
			"Phase 2 Gate - Stabilizer Showcase",
			"phase2-stabilizer-showcase",
			["demon", "undead"],
			["cleaned-jawbrace-guard", "gnaal-rift-scavenger"],
			[
				{
					"side": "enemy",
					"zone": "front",
					"combatant_ids": ["cleaned-jawbrace-guard"],
				},
				{
					"side": "enemy",
					"zone": "flank",
					"combatant_ids": ["gnaal-rift-scavenger"],
				},
			],
			0.0,
		),
	]
	for fixture: Dictionary in fixtures:
		var entity_name := str(fixture.get("entity_name", ""))
		fixture.erase("entity_name")
		_upsert(root, entity_name, fixture)


func _encounter_fixture(
	entity_name: String,
	encounter_id: String,
	archetypes: Array[String],
	combatant_ids: Array[String],
	zone_layout: Array[Dictionary],
	balance_bias: float,
	speech_hooks: Array[Dictionary] = [],
	context_actions: Array[Dictionary] = [],
	outcomes: Dictionary = {},
) -> Dictionary:
	var members: Array[Dictionary] = []
	for combatant_id: String in combatant_ids:
		members.append({"combatant_id": combatant_id, "count": 1})
	var resolved_outcomes := outcomes.duplicate(true)
	if resolved_outcomes.is_empty():
		resolved_outcomes = {
			"slain": {
				"message": "The gate fixture is resolved.",
				"cause": "",
				"faction": "",
				"delta": 0.0,
			}
		}
	return {
		"entity_name": entity_name,
		"Encounter Id": encounter_id,
		"Display Name": entity_name,
		"Combatant Ids": ",".join(combatant_ids),
		"Composition": JSON.stringify({"archetypes": archetypes, "members": members}),
		"Zone Layout": JSON.stringify(zone_layout),
		"Balance Bias": balance_bias,
		"Speech Hooks": JSON.stringify(speech_hooks),
		"Defeated Flag": "",
		"Win Faction": "",
		"Win Delta": 0.0,
		"Win Cause": "",
		"Loss Faction": "",
		"Loss Delta": 0.0,
		"Loss Cause": "",
		"Default Outcome": "slain",
		"Context Actions": JSON.stringify(context_actions),
		"Outcomes": JSON.stringify(resolved_outcomes),
	}


func _speech_fixture() -> Dictionary:
	return _encounter_fixture(
		"Phase 2 Gate - Speech Winnable",
		"phase2-speech-winnable",
		["undead"],
		["mustered-bloodbellow"],
		[
			{
				"side": "enemy",
				"zone": "front",
				"combatant_ids": ["mustered-bloodbellow"],
			}
		],
		1.0,
		[
			{
				"id": "phase2-release-binding-hook",
				"trigger": "combat_action",
				"action_id": "phase2-release-binding",
				"outcome_id": "released",
			}
		],
		[
			{
				"id": "phase2-release-binding",
				"display_name": "Release the Binding",
				"outcome_id": "released",
				"ap_cost": 1,
				"soul_cost": 0.0,
				"minimum_enemy_rounds": 0,
				"minimum_balance": -20,
				"maximum_balance": 20,
				"lock_reason": "Hold Balance between -20 and +20 to release the binding.",
			}
		],
		{
			"slain": {
				"message": "The gate fixture is resolved by force.",
				"cause": "",
				"faction": "",
				"delta": 0.0,
			},
			"released": {
				"message": "The binding releases.",
				"cause": "",
				"faction": "",
				"delta": 0.0,
			},
		},
	)
