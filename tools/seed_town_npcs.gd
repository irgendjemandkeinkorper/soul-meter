extends Node
## Idempotent Pandora migration for Dom's authored townsfolk roster.
##
## The roster itself lives in `canon/dom/characters` (`kind: "npc"`); this script reads it,
## derives the fields canon deliberately does not carry, and writes the Pandora NPC category.
## Pandora remains canonical after it runs; tools/generate_gloot.gd is the one-way path to
## runtime data.

const TOWN_SCENE := "res://world/starting_town.tscn"
const SeedPandora := preload("res://tools/seed_pandora.gd")
const TOWNSFOLK_MODEL_COUNT := 26
const DEFAULT_OUTDOOR_JITTER := Vector2i(26, 20)
const OUTDOOR_JITTER_BY_PLACEMENT := {
	"town_market": Vector2i(36, 16),
	"town_shrine": Vector2i(30, 26),
	"town_north_road": Vector2i(22, 32),
	"town_wound_lip": Vector2i(34, 16),
}
const NPC_PROPERTIES := [
	["Display Name", "string"],
	["Epithet", "string"],
	["Bio", "string"],
	["Vault Id", "string"],
	["NPC Id", "string"],
	["Town Id", "string"],
	["Role", "string"],
	["Home", "string"],
	["District", "string"],
	["Faction Id", "string"],
	["Quest Hooks", "string"],
	["Portrait Id", "string"],
	["Portrait Path", "string"],
	["Dialogue Greeting", "string"],
	["Dialogue Context", "string"],
	["Dialogue Farewell", "string"],
	["Dialogue Hostile", "string"],
	["Dialogue Warm", "string"],
	["Placement Scene", "string"],
	["Placement Anchor", "string"],
	["Placement X", "float"],
	["Placement Y", "float"],
	["Facing", "string"],
	["Idle Phase", "float"],
	["Model Index", "int"],
]
const FACTION_PROPERTIES := [
	["Display Name", "string"],
	["Summary", "string"],
	["Seat", "string"],
	["Vault Id", "string"],
]
const PLACEMENT_ANCHORS := {
	"trial_hall_i": {"scene": "res://world/interiors/trial_hall.tscn", "anchor": "NpcSpot"},
	"council_i": {"scene": "res://world/interiors/council_chamber.tscn", "anchor": "NpcSpot"},
	"town_hall_i": {"scene": "res://world/interiors/town_hall.tscn", "anchor": "NpcSpot"},
	"registry_i": {"scene": "res://world/interiors/registry_archive.tscn", "anchor": "NpcSpot"},
	"bell_i": {"scene": "res://world/interiors/bell_house.tscn", "anchor": "NpcSpot"},
	"shrine_i": {"scene": "res://world/interiors/river_shrine.tscn", "anchor": "NpcSpot"},
	"companies_i": {"scene": "res://world/interiors/iron_companies.tscn", "anchor": "NpcSpot"},
	"item_i": {"scene": "res://world/interiors/item_shop.tscn", "anchor": "NpcSpot"},
	"equipment_i": {"scene": "res://world/interiors/equipment_shop.tscn", "anchor": "NpcSpot"},
	"chefs_i": {"scene": "res://world/interiors/chefs_house.tscn", "anchor": "NpcSpot"},
	"players_i": {"scene": "res://world/interiors/players_house.tscn", "anchor": "NpcSpot"},
	"town_trial": {"scene": TOWN_SCENE, "anchor": "TrialHall"},
	"town_registry": {"scene": TOWN_SCENE, "anchor": "RegistryArchive"},
	"town_bell": {"scene": TOWN_SCENE, "anchor": "BellHouse"},
	"town_shrine": {"scene": TOWN_SCENE, "anchor": "RiverShrine"},
	"town_companies": {"scene": TOWN_SCENE, "anchor": "IronCompaniesBarracks"},
	"town_market": {"scene": TOWN_SCENE, "anchor": "LowerMarket"},
	"town_equipment": {"scene": TOWN_SCENE, "anchor": "EquipmentShop"},
	"town_hall": {"scene": TOWN_SCENE, "anchor": "TownHall"},
	"town_tavern": {"scene": TOWN_SCENE, "anchor": "FourArmsTavern"},
	"town_north_road": {"scene": TOWN_SCENE, "anchor": "NorthRoad"},
	"town_wound_lip": {"scene": TOWN_SCENE, "anchor": "WoundLip"},
}


func _ready() -> void:
	await get_tree().process_frame
	if not Pandora.is_loaded():
		Pandora.load_data()
	if not _seed_factions():
		get_tree().quit(1)
		return
	var documents: Array[Dictionary] = SeedPandora.CanonReader.load("characters")
	if documents.is_empty() or not _placement_anchors_exist(documents):
		get_tree().quit(1)
		return
	_seed_npcs()
	Pandora.save_data()
	print("DOM-NPC-SEED: 60 authored townsfolk present.")
	get_tree().quit()


func _seed_factions() -> bool:
	var seeder: Node = SeedPandora.new()
	var seeded: bool = seeder._seed_factions()
	seeder.free()
	return seeded


func _seed_npcs() -> void:
	var root := _ensure_root("NPCs", NPC_PROPERTIES)
	for row: Dictionary in _townsfolk_rows():
		var entity := _find_npc(root, row["NPC Id"])
		if entity == null:
			entity = Pandora.create_entity(row["Display Name"], root)
		for property_name: String in row:
			_assign(entity, property_name, row[property_name])


## Reads the authored roster from `canon/dom/characters`, `kind: "npc"`. Everything the
## seeder writes beyond these fields — greetings, facing, idle phase, model index, the
## organic outdoor scatter — is derived below and deliberately stays out of canon.
func _townsfolk_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for document: Dictionary in SeedPandora.CanonReader.load("characters"):
		if String(document.get("kind", "")) != "npc":
			continue
		result.append(_npc(document))
	return result


## An anchor this seeder does not know would be a null placement, so it is caught before
## anything is written rather than as a crash midway through the roster.
func _placement_anchors_exist(documents: Array[Dictionary]) -> bool:
	for document: Dictionary in documents:
		if String(document.get("kind", "")) != "npc":
			continue
		if not PLACEMENT_ANCHORS.has(document["placement_anchor"]):
			push_error(
				"DOM-NPC-SEED: character '%s' names unknown placement anchor '%s'."
				% [document["id"], document["placement_anchor"]]
			)
			return false
	return true


func _npc(document: Dictionary) -> Dictionary:
	var npc_id: String = document["id"]
	var role: String = document["role"]
	var district: String = document["district"]
	var faction_id: String = document["faction_id"]
	var involvement: String = document["involvement"]
	var offset_pair: Array = document["placement_offset"]
	var offset := Vector2(float(offset_pair[0]), float(offset_pair[1]))
	var placement_key: String = document["placement_anchor"]
	var placement: Dictionary = PLACEMENT_ANCHORS[placement_key]
	var placement_offset := offset
	if placement["scene"] == TOWN_SCENE:
		placement_offset = _organic_outdoor_offset(npc_id, district, placement_key, offset)
	var hooks: Array[Dictionary] = []
	if not involvement.is_empty():
		var hook := {
			"quest_id": "dom/%s/%s" % [npc_id, involvement.replace("_", "-")],
			"involvement": involvement,
			"summary": document["hook_summary"],
			"state_source": "QuestRegistry",
		}
		if involvement in ["gate", "state_change"]:
			hook["state_source"] = "GameState"
			hook["world_fact_id"] = "dom/%s/%s-state" % [npc_id, involvement.replace("_", "-")]
		elif involvement == "reputation_reaction":
			hook["state_source"] = "Reputation.band"
			hook["faction_id"] = faction_id
			hook["band"] = "warm"
		hooks.append(hook)
	# An empty authored bio falls back to the generated one; canon records what was written,
	# not what the seeder can work out for itself.
	var bio: String = document["bio"]
	if bio.is_empty():
		bio = "%s of Dom's %s." % [role, district]
	return {
		"Display Name": document["display_name"],
		"Epithet": document["epithet"],
		"Bio": bio,
		"Vault Id": document["vault_id"],
		"NPC Id": npc_id,
		"Town Id": "dom",
		"Role": role,
		"Home": document["home"],
		"District": district,
		"Faction Id": faction_id,
		"Quest Hooks": JSON.stringify(hooks),
		"Portrait Id": npc_id,
		"Portrait Path": document["portrait_path"],
		"Dialogue Greeting": _greeting(district),
		"Dialogue Context": document["context_line"],
		"Dialogue Farewell": _farewell(district),
		"Dialogue Hostile": document["dialogue_hostile"],
		"Dialogue Warm": document["dialogue_warm"],
		"Placement Scene": placement["scene"],
		"Placement Anchor": placement["anchor"],
		"Placement X": placement_offset.x,
		"Placement Y": placement_offset.y,
		"Facing": _plausible_facing(npc_id, placement_key, offset),
		"Idle Phase": _idle_phase(npc_id),
		"Model Index": (int(document["order"]) * 11) % TOWNSFOLK_MODEL_COUNT,
	}


static func _organic_outdoor_offset(
	npc_id: String,
	district: String,
	placement_key: String,
	authored_offset: Vector2,
) -> Vector2:
	var spread: Vector2i = OUTDOOR_JITTER_BY_PLACEMENT.get(
		placement_key, DEFAULT_OUTDOOR_JITTER
	)
	var x_seed := (npc_id + ":placement-x").hash() & 0x7fffffff
	var y_seed := (npc_id + ":placement-y").hash() & 0x7fffffff
	var jitter := Vector2(
		float(x_seed % (spread.x * 2 + 1) - spread.x),
		float(y_seed % (spread.y * 2 + 1) - spread.y),
	)
	# Bias the local scatter toward each Arm's street without moving anyone
	# away from their authored building, stall, shrine, road, or watch post.
	match district:
		"East Arm":
			jitter.x += 6.0
		"West Arm":
			jitter.x -= 6.0
		"North Arm":
			jitter.y -= 4.0
		"South Arm":
			jitter.y += 4.0
	return authored_offset + jitter


static func _plausible_facing(
	npc_id: String, placement_key: String, authored_offset: Vector2
) -> String:
	# The paired Wound-Lip posts watch outward; groups around buildings and
	# stalls look inward, so outer NPCs face one another instead of the camera.
	if placement_key == "town_wound_lip":
		return "west" if authored_offset.x < 0.0 else "east"
	if authored_offset.x < -8.0:
		return "east"
	if authored_offset.x > 8.0:
		return "west"
	return "east" if ((npc_id + ":facing").hash() & 1) == 0 else "west"


static func _idle_phase(npc_id: String) -> float:
	var phase_seed := (npc_id + ":idle").hash() & 0x7fffffff
	return float(phase_seed % 6283) / 1000.0


func _greeting(district: String) -> String:
	match district:
		"East Arm":
			return "Mind the sparks, traveler."
		"West Arm":
			return "Keep above the harbor spray."
		"South Arm":
			return "Yield is an honest word here."
		"Jawbrace":
			return "Hold at the brace and state your business."
		_:
			return "Keep your footing, traveler."


func _farewell(district: String) -> String:
	match district:
		"East Arm":
			return "Go before the next hammer fall."
		"West Arm":
			return "Watch the chain on your way out."
		"South Arm":
			return "Stand straight when the drum sounds."
		"Jawbrace":
			return "Cross unarmed or do not cross."
		_:
			return "Leave me a true count when you return."


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


func _find_npc(root: PandoraCategory, npc_id: String) -> PandoraEntity:
	for candidate: PandoraEntity in Pandora.get_all_entities(root):
		if candidate is PandoraCategory:
			continue
		if candidate.has_entity_property("NPC Id") and candidate.get_string("NPC Id") == npc_id:
			return candidate
		if candidate.has_entity_property("Vault Id") and candidate.get_string("Vault Id") == npc_id:
			return candidate
		if _slug(candidate.get_entity_name()) == npc_id:
			return candidate
	return null


func _find_by_vault_id(root: PandoraCategory, vault_id: String) -> PandoraEntity:
	for candidate: PandoraEntity in Pandora.get_all_entities(root):
		if not candidate is PandoraCategory and candidate.get_string("Vault Id") == vault_id:
			return candidate
	return null


func _assign(entity: PandoraEntity, property_name: String, value: Variant) -> void:
	var property := entity.get_entity_property(property_name)
	if property != null:
		property.set_default_value(value)


func _slug(value: String) -> String:
	var result := value.to_lower()
	for pair in [["'", ""], ["’", ""], [" ", "-"], ["_", "-"]]:
		result = result.replace(pair[0], pair[1])
	return result
