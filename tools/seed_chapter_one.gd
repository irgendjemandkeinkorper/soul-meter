extends Node
## Idempotent Pandora migration for chapter-one authored content, including
## the combatant and encounter definitions consumed by the data generator.

const FACTION_PROPERTIES := [
	["Display Name", "string"],
	["Summary", "string"],
	["Seat", "string"],
	["Vault Id", "string"],
]
const NPC_PROPERTIES := [
	["Display Name", "string"],
	["Epithet", "string"],
	["Race", "reference"],
	["Class", "reference"],
	["Bio", "string"],
	["Vault Id", "string"],
]
const COMBATANT_PROPERTIES := [
	["Combatant Id", "string"],
	["Display Name", "string"],
	["Max HP", "int"],
	["Attack", "int"],
	["Defense", "int"],
	["Balance Affinity", "int"],
	["Balance Pressure", "int"],
	["Element Id", "string"],
	["Edge", "int"],
]
const ENCOUNTER_PROPERTIES := [
	["Encounter Id", "string"],
	["Display Name", "string"],
	["Combatant Ids", "string"],
	["Defeated Flag", "string"],
	["Win Faction", "string"],
	["Win Delta", "float"],
	["Win Cause", "string"],
	["Loss Faction", "string"],
	["Loss Delta", "float"],
	["Loss Cause", "string"],
	["Default Outcome", "string"],
	["Context Actions", "string"],
	["Outcomes", "string"],
]


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()
	var factions := _ensure_root("Factions", FACTION_PROPERTIES)
	var npcs := _ensure_root("NPCs", NPC_PROPERTIES)
	var combatants := _ensure_root("Combatants", COMBATANT_PROPERTIES)
	var encounters := _ensure_root("Encounters", ENCOUNTER_PROPERTIES)
	_seed_factions(factions)
	_seed_npcs(npcs)
	_seed_combatants(combatants)
	_seed_encounters(encounters)
	Pandora.save_data()
	print("CHAPTER-SEED: chapter-one entities present.")
	get_tree().quit()


func _ensure_root(name: String, properties: Array) -> PandoraCategory:
	for candidate in Pandora.get_all_roots():
		if candidate.get_entity_name() == name:
			_ensure_properties(candidate, properties)
			return candidate
	var created := Pandora.create_category(name)
	_ensure_properties(created, properties)
	return created


func _ensure_properties(root: PandoraCategory, properties: Array) -> void:
	for property_spec in properties:
		if not root.has_entity_property(property_spec[0]):
			Pandora.create_property(root, property_spec[0], property_spec[1])


func _seed_factions(root: PandoraCategory) -> void:
	_upsert(
		root,
		"The Iron Companies",
		{
			"Display Name": "The Iron Companies",
			"Summary": "Dom's contracted companies, guild and regiment together.",
			"Seat": "Dom",
			"Vault Id": "iron-companies",
		}
	)
	_upsert(
		root,
		"The Ironbrand Sentinels",
		{
			"Display Name": "The Ironbrand Sentinels",
			"Summary": "Branded wardens of Dom's Wound and its dead muster.",
			"Seat": "Dom",
			"Vault Id": "ironbrand-sentinels",
		}
	)
	_upsert(
		root,
		"The Lords of the Breach",
		{
			"Display Name": "The Lords of the Breach",
			"Summary": "Extraplanar demon lords of consumption.",
			"Seat": "The Breach",
			"Vault Id": "lords-of-the-breach",
		}
	)
	_upsert(
		root,
		"The Cold Consensus",
		{
			"Display Name": "The Cold Consensus",
			"Summary": "Undead sovereigns who preserve souls against release.",
			"Seat": "Wintervast",
			"Vault Id": "cold-consensus",
		}
	)


func _seed_npcs(root: PandoraCategory) -> void:
	_upsert(
		root,
		"Marshal Coiljaw",
		{
			"Display Name": "Marshal Coiljaw",
			"Epithet": "the Road-Bench",
			"Bio": "A Trial Council road marshal charged with the broken muster at Dorthkor.",
			"Vault Id": "branek-coiljaw",
		}
	)


func _seed_combatants(root: PandoraCategory) -> void:
	# Element Id is a Wheel id (see globals/elements/element_wheel.gd's ORDER) read as this
	# combatant's TARGET-side attunement — the "target relation" gamble curve (vault:
	# systems/magic-system.md, ratified 2026-08-05) prices any elemental attack against it by
	# Wheel distance. Bog Wight (a grave-rotted bog creature) is Molm (decay/the grave);
	# Loam-Maddened Boar (a beast maddened by corrupted soil) is Terra (stone/the earthwork).
	# Left blank for combatants with no authored attunement yet — they keep resolving at the
	# ElementMatrix neutral IDENTITY_ROW, unchanged from before this column existed.
	# Edge (9th column): PROVISIONAL accuracy/evasion — keep in lockstep with
	# tools/seed_pandora.gd (see that file's rationale comment).
	var rows := [
		["Bog Wight", "bog-wight", 20, 4, 1, 1, 18, "molm", 2],
		["Loam-Maddened Boar", "loam-maddened-boar", 14, 6, 0, -1, 18, "terra", 3],
		["Gnaal Breach-Hound", "gnaal-breach-hound", 28, 7, 1, -1, 22, "", 4],
		["Gnaal Rift-Scavenger", "gnaal-rift-scavenger", 16, 5, 0, -1, 16, "", 4],
		["Mustered Bloodbellow", "mustered-bloodbellow", 32, 6, 3, 1, 22, "", 2],
		["Cleaned Jawbrace Guard", "cleaned-jawbrace-guard", 36, 7, 4, 1, 24, "", 3],
	]
	for row in rows:
		_upsert(
			root,
			row[0],
			{
				"Combatant Id": row[1],
				"Display Name": row[0],
				"Max HP": row[2],
				"Attack": row[3],
				"Defense": row[4],
				"Balance Affinity": row[5],
				"Balance Pressure": row[6],
				"Element Id": row[7],
				"Edge": row[8] if row.size() > 8 else 0,
			}
		)


func _seed_encounters(root: PandoraCategory) -> void:
	for row in _encounter_rows():
		_upsert(root, row[0], row[1])


func _encounter_rows() -> Array:
	return [
		[
			"Bog Wight",
			_encounter(
				"bog-wight",
				"Bog Wight",
				"bog-wight",
				"defeated_bog_wight",
				"ssae-seeders",
				6.0,
				"Cleared the Bog Wight from the grove margins",
				"ssae-seeders",
				-3.0,
				"The Bog Wight still haunts the grove's edge"
			),
		],
		[
			"Loam-Maddened Boar",
			_encounter(
				"loam-boar",
				"Loam-Maddened Boar",
				"loam-maddened-boar",
				"defeated_loam_boar",
				"ssae-seeders",
				5.0,
				"Culled a Loam-maddened boar before it reached the grove",
				"ssae-seeders",
				-3.0,
				"A Loam-maddened boar broke loose near the grove"
			),
		],
		[
			"Dorthkor Demon Vanguard",
			_encounter(
				"dorthkor-vanguard",
				"Dorthkor Demon Vanguard",
				"gnaal-breach-hound,gnaal-rift-scavenger",
				"defeated_breach_hound",
				"iron-companies",
				5.0,
				"Broke the demon vanguard at Dorthkor"
			),
		],
		[
			"Dorthkor Dead Muster",
			_muster_encounter(),
		],
		[
			"The Empty Post",
			_encounter(
				"jawbrace-empty-post",
				"The Empty Post",
				"cleaned-jawbrace-guard",
				"defeated_cleaned_jawbrace_guard",
				"ironbrand-sentinels",
				6.0,
				"Stopped the cleaned armor standing watch at the Jawbrace",
				"ironbrand-sentinels",
				-3.0,
				"The empty guard still holds the first gate"
			),
		],
	]


func _encounter(
	id: String,
	display_name: String,
	combatant_ids: String,
	defeated_flag: String,
	win_faction: String,
	win_delta: float,
	win_cause: String,
	loss_faction: String = "",
	loss_delta: float = 0.0,
	loss_cause: String = ""
) -> Dictionary:
	return {
		"Encounter Id": id,
		"Display Name": display_name,
		"Combatant Ids": combatant_ids,
		"Defeated Flag": defeated_flag,
		"Win Faction": win_faction,
		"Win Delta": win_delta,
		"Win Cause": win_cause,
		"Loss Faction": loss_faction,
		"Loss Delta": loss_delta,
		"Loss Cause": loss_cause,
		"Default Outcome": "slain",
		"Context Actions": "[]",
		"Outcomes": JSON.stringify(
			{
				"slain": {
					"message": "The opposition is defeated.",
					"cause": win_cause,
					"faction": win_faction,
					"delta": win_delta,
				}
			}
		),
	}


func _muster_encounter() -> Dictionary:
	var row := _encounter(
		"dorthkor-muster",
		"Dorthkor Dead Muster",
		"mustered-bloodbellow",
		"defeated_mustered_dead",
		"ironbrand-sentinels",
		5.0,
		"Stopped a dead soldier answering Dom's muster"
	)
	row["Context Actions"] = (
		JSON
		. stringify(
			[
				{
					"id": "speak-muster-name",
					"display_name": "Speak Its Muster-Name",
					"outcome_id": "named",
					"soul_cost": 3.0,
					"minimum_enemy_rounds": 0,
					"minimum_balance": 50,
					"maximum_balance": 100,
					"lock_reason": "Requires Order +50 and 3 Soul to break the binding.",
				},
				{
					"id": "release-bound-soldier",
					"display_name": "Release the Bound Soldier",
					"outcome_id": "released",
					"soul_cost": 0.0,
					"minimum_enemy_rounds": 1,
					"minimum_balance": -20,
					"maximum_balance": 20,
					"lock_reason":
					"Survive one enemy round, then hold Balance between -20 and +20.",
				},
			]
		)
	)
	row["Outcomes"] = (
		JSON
		. stringify(
			{
				"slain":
				{
					"message": "The Bloodbellow falls, its borrowed cadence cut short.",
					"cause": "Destroyed the Mustered Bloodbellow by force",
					"faction": "ironbrand-sentinels",
					"delta": 5.0,
					"flags": {
						"dorthkor_muster_outcome": "$outcome_id",
						"dorthkor_muster_cause": "$cause",
					},
				},
				"named":
				{
					"message": "Its muster-name answers. The binding splits and the armor empties.",
					"cause": "Broke the Bloodbellow binding by speaking its muster-name",
					"faction": "ironbrand-sentinels",
					"delta": 5.0,
					"flags": {
						"dorthkor_muster_outcome": "$outcome_id",
						"dorthkor_muster_cause": "$cause",
					},
				},
				"released":
				{
					"message":
					"The held center opens a way out. The soldier's soul leaves the armor.",
					"cause": "Released the soldier bound inside the Bloodbellow muster",
					"faction": "ironbrand-sentinels",
					"delta": 5.0,
					"flags": {
						"dorthkor_muster_outcome": "$outcome_id",
						"dorthkor_muster_cause": "$cause",
					},
				},
			}
		)
	)
	return row


func _upsert(root: PandoraCategory, entity_name: String, values: Dictionary) -> void:
	var entity: PandoraEntity = null
	for candidate in Pandora.get_all_entities(root):
		if not candidate is PandoraCategory and candidate.get_entity_name() == entity_name:
			entity = candidate
			break
	if entity == null:
		entity = Pandora.create_entity(entity_name, root)
	for property_name in values:
		var property := entity.get_entity_property(property_name)
		if property:
			property.set_default_value(values[property_name])
