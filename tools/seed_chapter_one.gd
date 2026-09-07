extends Node
## Idempotent Pandora migration for chapter-one authored content, including
## the combatant and encounter definitions consumed by the data generator.
##
## Combatant stats and the base encounter fields are READ FROM CANON
## (`canon/<hub>/characters/*.json` with `kind: "archetype"`, and
## `canon/<hub>/encounters/*.json`) rather than restated here. They used to be a second
## copy of `tools/seed_pandora.gd`'s tables, kept honest only by a comment asking two
## files to stay in lockstep; E1.4g (#325) removed the second copy.
##
## What stays authored here is `Default Outcome`, `Context Actions` and `Outcomes` — the
## chapter-one battle script. Those are stringified JSON blobs inside Pandora string
## properties, and JSON has one number type, so round-tripping them through canon would
## rewrite `"minimum_balance":50` as `50.0` and show up as data drift for no gain. The
## post-#281 encounter shape that would own them properly is E5.2's call, not this
## migration's.

const SeedPandora := preload("res://tools/seed_pandora.gd")

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
	for row: Dictionary in _archetypes():
		var stats: Dictionary = row["stats"]
		_upsert(
			root,
			row["display_name"],
			{
				"Combatant Id": row["id"],
				"Display Name": row["display_name"],
				"Max HP": int(stats["max_hp"]),
				"Attack": int(stats["attack"]),
				"Defense": int(stats["defense"]),
				"Balance Affinity": int(stats["balance_affinity"]),
				"Balance Pressure": int(stats["balance_pressure"]),
				"Element Id": row["element_id"],
				"Edge": int(stats["edge"]),
			}
		)


func _archetypes() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for document: Dictionary in SeedPandora.CanonReader.load("characters"):
		if String(document.get("kind", "")) == "archetype":
			result.append(document)
	return result


func _seed_encounters(root: PandoraCategory) -> void:
	for row in _encounter_rows():
		_upsert(root, row[0], row[1])


## Canon owns who fights, which flag records it and what each side writes to the ledger.
## This file layers the chapter-one battle script on top, by encounter id.
func _encounter_rows() -> Array:
	var rows: Array = []
	for document: Dictionary in SeedPandora.CanonReader.load("encounters"):
		var win: Dictionary = document["win"] if document["win"] != null else {}
		var loss: Dictionary = document["loss"] if document["loss"] != null else {}
		var row: Dictionary = _encounter(
			document["id"],
			document["display_name"],
			",".join(PackedStringArray(document["archetype_ids"])),
			document["defeated_flag"],
			String(win.get("faction", "")),
			float(win.get("delta", 0.0)),
			String(win.get("cause", "")),
			String(loss.get("faction", "")),
			float(loss.get("delta", 0.0)),
			String(loss.get("cause", ""))
		)
		if document["id"] == "dorthkor-muster":
			_apply_muster_script(row)
		rows.append([document["display_name"], row])
	return rows


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


## The one encounter with a script beyond "kill it": two context actions and three
## outcomes. Canon says who is in the fight; this says what else can be done in it.
func _apply_muster_script(row: Dictionary) -> void:
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
