extends Node
## Idempotent Pandora migration for Dom's authored townsfolk roster.
##
## The rows below are migration input only. Pandora remains canonical after this
## script runs; tools/generate_gloot.gd is the one-way path to runtime data.

const TOWN_SCENE := "res://world/starting_town.tscn"
const TOWNSFOLK_MODEL_COUNT := 26
const DEFAULT_OUTDOOR_JITTER := Vector2i(26, 20)
const OUTDOOR_JITTER_BY_PLACEMENT := {
	"town_market": Vector2i(36, 16),
	"town_shrine": Vector2i(30, 26),
	"town_north_road": Vector2i(22, 32),
	"town_wound_lip": Vector2i(34, 16),
}
const PORTRAIT_PATHS := {
	"branek-coiljaw": (
		"res://assets/generated/portraits/marshal_coiljaw_portrait_neutral.png"
	),
	"hadrik-vale": "res://assets/generated/portraits/hadrik_vale_portrait_neutral.png",
	"sella-varn": "res://assets/generated/portraits/sella_varn_portrait_neutral.png",
	"toma-reedhand": "res://assets/generated/portraits/toma_reedhand_portrait_neutral.png",
}
## Optional band-gated greeting variants (Wave 4 reputation reactivity).
## Keyed by npc id; empty/no entry keeps the plain generated greeting.
## The reaction faction is the NPC's own "Faction Id".
const REACTIVE_DIALOGUE := {
	"droma-flintjaw": {
		"hostile": "The Sentinels have you marked cold. State your business from there.",
		"warm": "The Sentinels speak warmly of you. Cross at the near brace.",
	},
	"edda-broadmark": {
		"hostile": "The Companies give your name no weight. Edda does the same.",
		"warm": "The Companies give your name weight. Edda will hear you first.",
	},
	"ressa-ironmouth": {
		"hostile": "The Sentinels distrust your name. Ressa keeps the hot tongs between you and the rack.",
		"warm": "The Sentinels trust your name. Ressa clears the sparks when you step to the rack.",
	},
}
const NPC_BIOS := {
	"branek-coiljaw": (
		"A Trial Council road marshal charged with the broken muster at Dorthkor."
	),
}
const NPC_EPITHETS := {
	"branek-coiljaw": "the Road-Bench",
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
	_seed_factions()
	_seed_npcs()
	Pandora.save_data()
	print("DOM-NPC-SEED: 60 authored townsfolk present.")
	get_tree().quit()


func _seed_factions() -> void:
	var root := _ensure_root("Factions", FACTION_PROPERTIES)
	var rows := [
		["The Trial Council", "Dom's four Arm benches, earned through the graded trials.", "Dom", "trial-council"],
		["The Kord Rite", "Dom's tolerated old-believers at the chasm-lip shrines.", "Dom", "kord-rite"],
		["The Shattersteel Concord", "The East Arm's joint shattersteel charter with Tweede.", "Dom", "shattersteel-concord"],
		["The Hospice Chain", "Haeren's protected chain of hospices and keepers.", "Dom", "hospice-chain"],
		["The Wayfare-Menders", "Road and harbor lodges serving travelers under Ofshutje.", "Dom", "wayfare-menders"],
		["The Grain Factors' Table", "The factors who provision Dom through Deivel's grain trade.", "Deivel Zeit", "grain-factors-table"],
		["The Restoration", "Deivel's Restoration, recruiting among Dom's Company halls.", "Deivel Zeit", "the-restoration"],
	]
	for row: Array in rows:
		var entity := _find_by_vault_id(root, row[3])
		if entity == null:
			entity = Pandora.create_entity(row[0], root)
		_assign(entity, "Display Name", row[0])
		_assign(entity, "Summary", row[1])
		_assign(entity, "Seat", row[2])
		_assign(entity, "Vault Id", row[3])


func _seed_npcs() -> void:
	var root := _ensure_root("NPCs", NPC_PROPERTIES)
	for row: Dictionary in _townsfolk_rows():
		var entity := _find_npc(root, row["NPC Id"])
		if entity == null:
			entity = Pandora.create_entity(row["Display Name"], root)
		for property_name: String in row:
			_assign(entity, property_name, row[property_name])


func _townsfolk_rows() -> Array[Dictionary]:
	# id, name, role, home, district, faction, contextual line,
	# placement key, offset, quest involvement, hook summary, optional vault id.
	var authored: Array = [
		["branek-coiljaw", "Marshal Coiljaw", "East Arm bench-holder and road marshal", "Trial Hall", "East Arm", "trial-council", "The Road-Bench keeps Dorthkor's broken drumbeat beside every open commission.", "trial_hall_i", Vector2(-64, 0), "giver", "Commissions a witness to audit the broken Dorthkor muster.", "branek-coiljaw"],
		["themka-gaath", "Themka Gaath", "Council of Four Arms elder and Bridgeholder", "Council Chamber", "North Arm", "trial-council", "PROVISIONAL — CANON REVIEW REQUIRED: The Council elder waits to send a proven traveler beyond Dom.", "council_i", Vector2(0, 0), "giver", "PROVISIONAL — CANON REVIEW REQUIRED: Gives the opening charge to travel to Dorthkor Road.", "themka-gaath"],
		["sella-varn", "Sella Varn", "Bell warden", "Bell House", "South Arm", "trial-council", "The district bell is warm, the rope is sound, and Sella refuses to call its silence a simple break.", "trial_hall_i", Vector2(64, 0), "giver", "Opens the silent bell-house investigation."],
		["hadrik-vale", "Hadrik Vale", "Archive clerk", "Registry Archive", "North Arm", "rennen", "Hadrik can account for every road ledger except the one that returned with rain inside its seals.", "town_hall_i", Vector2(-64, 0), "giver", "Requests recovery of a storm-damaged road register."],
		["toma-reedhand", "Toma Reedhand", "Dockhand and shrine-keeper", "River Shrine", "West Arm", "wayfare-menders", "Toma tends the river shrine between harbor shifts and knows which tide-chain offerings have gone missing.", "town_hall_i", Vector2(0, 0), "giver", "Asks for the missing offerings from the Drownedmouth tide-chain."],
		["droma-flintjaw", "Droma Flintjaw", "Wound-Watch quartermaster", "Town Hall", "Jawbrace", "ironbrand-sentinels", "Droma's armor tags include one clean plate whose owner still answers morning roll.", "town_hall_i", Vector2(64, 0), "giver", "Seeks proof of how a living guard's tag reached cleaned armor."],
		["veska-ruun", "Veska Ruun", "Trial examiner", "Trial Hall", "South Arm", "trial-council", "Veska found three Pillar weights filed smooth where a candidate's name should be cut.", "registry_i", Vector2(-64, 0), "giver", "Commissions an inquiry into altered Trial Pillar weights."],
		["orren-chainwake", "Orren Chainwake", "Drownedmouth pilot", "Pilot Lodge", "West Arm", "wayfare-menders", "Orren has a storm-stranded crew below the sea-mouth and one safe course left unmarked.", "registry_i", Vector2(0, 0), "giver", "Needs a route marker carried to a storm-stranded crew."],
		["maela-drumscar", "Maela Drumscar", "Company muster drummer", "Iron Companies Barracks", "East Arm", "iron-companies", "Maela heard a dead Company's cadence answer between two beats of the spring muster.", "registry_i", Vector2(64, 0), "giver", "Asks the player to compare an impossible cadence against old muster notation."],
		["keth-varr", "Keth Varr", "Shattersteel assay clerk", "Equipment Shop", "East Arm", "shattersteel-concord", "Keth says the newest cooling-water seals are honest bronze wrapped around dishonest water.", "bell_i", Vector2(-64, 0), "giver", "Requests samples from a suspect storm-water delivery."],
		["irka-stonebreath", "Irka Stonebreath", "Hospice scar keeper", "River Shrine Hospice", "West Arm", "hospice-chain", "Irka keeps the trial-broken names and has one patient no hall admits sending.", "bell_i", Vector2(0, 0), "giver", "Seeks the hall that abandoned an unidentified trial-broken veteran."],
		["pell-hammersong", "Pell Hammersong", "Jaw-drum tuner", "Bell House", "North Arm", "trial-council", "Pell hears a fifth echo under a four-beat Jawbrace signal whenever the western storm turns.", "bell_i", Vector2(64, 0), "giver", "Needs the brace drums tested from both sides of the chasm."],
		["vaara-cisternhand", "Vaara Cisternhand", "Storm-cistern warden", "Cistern Wardens Hall", "South Arm", "trial-council", "Vaara has sealed a cistern whose rain tastes of forge ash before it reaches the East Arm.", "shrine_i", Vector2(-64, 0), "giver", "Requests a source trace for ash entering a storm cistern."],
		["jorun-ashmantle", "Jorun Ashmantle", "Charfire hall steward", "Chef's House", "East Arm", "iron-companies", "Jorun keeps the charfire table open, but one veteran's bowl has gone cold for six nights.", "shrine_i", Vector2(0, 0), "giver", "Asks someone to find a missing Company veteran without shaming them."],
		["senn-brinehook", "Senn Brinehook", "Deep-cold net mender", "River Shrine", "West Arm", "wayfare-menders", "Senn's newest net came back cut from below, with every knot retied in marching order.", "shrine_i", Vector2(64, 0), "giver", "Offers the cut net for investigation at the sea-mouth."],
		["daska-threeknots", "Daska Threeknots", "Deep Salvage broker", "Howlpath Lodging", "North Arm", "kord-rite", "Daska prices cleaned armor by the grief of the family asking and calls that brutal honesty.", "companies_i", Vector2(-64, 0), "target", "Must be confronted about a suit taken from a forbidden ledge."],
		["hennik-coalvein", "Hennik Coalvein", "Chasm-wall miner", "East Arm Scarred Hall", "East Arm", "shattersteel-concord", "Hennik missed shift after chalking a name that no foreman remembers onto the lift cage.", "companies_i", Vector2(0, 0), "target", "Is the missing miner sought by the lift crew."],
		["ressa-ironmouth", "Ressa Ironmouth", "Brand artist", "Equipment Shop", "East Arm", "ironbrand-sentinels", "Ressa can spot a false Ironbrand by the way its scar fails to pull when the bearer speaks.", "companies_i", Vector2(64, 0), "target", "Must inspect a suspect veteran's counterfeit brand."],
		["kaelra-pikehand", "Kaelra Pikehand", "Three-legged war-dog trainer", "Iron Companies Barracks", "South Arm", "iron-companies", "Kaelra's oldest hound tracks one absent Bloodbellow and refuses every other scent.", "item_i", Vector2(-64, 0), "target", "Holds the hound needed to follow an absent Company soldier."],
		["umber-dhor", "Umber Dhor", "Grain porter", "Lower Market Loft", "West Arm", "grain-factors-table", "Umber carries a manifest for grain that reached Dom twice on paper and not once by sack.", "item_i", Vector2(0, 0), "target", "Carries the disputed manifest needed by the market factors."],
		["nalla-gatebeat", "Nalla Gatebeat", "Jawbrace signaler", "Jawbrace Watchroom", "North Arm", "trial-council", "Nalla stopped the third gate's drum after it answered with a signal no living watch uses.", "item_i", Vector2(64, 0), "target", "Is the signaler who can reproduce the unknown gate reply."],
		["torv-bellowskin", "Torv Bellowskin", "Forge bellows master", "Equipment Shop", "East Arm", "shattersteel-concord", "Torv locked away a hammer that rings after the forge around it has fallen silent.", "equipment_i", Vector2(-64, 0), "target", "Keeps the resonant hammer required for a forge-silence inquiry."],
		["yssra-coldnet", "Yssra Coldnet", "Deep-cold fisher", "Drownedmouth Berthhouse", "West Arm", "wayfare-menders", "Yssra saw lights climbing the harbor wall against the rain and will speak only beside calm water.", "equipment_i", Vector2(0, 0), "target", "Is the harbor witness another quest must locate."],
		["brek-saltjaw", "Brek Saltjaw", "Sea-mouth chain hand", "Drownedmouth Chainhouse", "West Arm", "trial-council", "Brek did not report after the outer harbor chain tightened itself during the night watch.", "equipment_i", Vector2(64, 0), "target", "Is the missing chain hand named in the harbor watch report."],
		["orenna-caskbrand", "Orenna Caskbrand", "Charfire brewer", "Chef's House", "East Arm", "hospice-chain", "Orenna holds the only kitchen key to the scarred hall where an unnamed bowl remains set.", "chefs_i", Vector2(-64, 0), "target", "Holds access needed to inspect an abandoned charfire place."],
		["marn-veld", "Marn Veld", "Council runner", "Town Hall", "North Arm", "trial-council", "Marn carried the sealed vote between the four benches and knows which seal arrived warm.", "chefs_i", Vector2(0, 0), "information", "Provides required information about a compromised Council message."],
		["thessa-drumline", "Thessa Drumline", "Muster copyist", "Bell House", "South Arm", "iron-companies", "Thessa can point to the exact beat where a living roll enters the cadence of the unremembered.", "chefs_i", Vector2(64, 0), "information", "Decodes the break between dead and living muster rolls."],
		["korrin-blackrail", "Korrin Blackrail", "Jawbrace rail inspector", "Jawbrace Watchroom", "North Arm", "ironbrand-sentinels", "Korrin saw the cleaned guard face outward before the first gate opened.", "players_i", Vector2(-64, 0), "information", "Provides the guard's original posture and direction."],
		["veyra-sootlace", "Veyra Sootlace", "Salvage-cloth merchant", "Lower Market Loft", "East Arm", "shattersteel-concord", "Veyra knows whether ash came from forge coal, charfire, or a suit scoured below the ledges.", "players_i", Vector2(0, 0), "information", "Identifies the ash on recovered salvage cloth."],
		["drel-gaunt", "Drel Gaunt", "Gauntlet scorekeeper", "Trial Hall", "South Arm", "trial-council", "Drel's slate proves the yielded duelist was struck three times after the surrender beat.", "players_i", Vector2(64, 0), "information", "Supplies the official score from the broken-yield duel."],
		["arvek-stormcup", "Arvek Stormcup", "Storm-water cooper", "Lower Market", "West Arm", "grain-factors-table", "Arvek recognizes the cooper's mark that was burned off Keth Varr's suspect casks.", "town_trial", Vector2(-100, 70), "information", "Identifies the source warehouse for tampered cooling water."],
		["istra-hearthscar", "Istra Hearthscar", "Scarred Hall matron", "Iron Companies Barracks", "East Arm", "hospice-chain", "Istra remembers which missing veteran stopped eating when the Wound began using Company voices.", "town_trial", Vector2(0, 78), "information", "Names the veteran connected to a cold place at the charfire table."],
		["kelm-rook", "Kelm Rook", "Company contract reader", "Iron Companies Barracks", "East Arm", "iron-companies", "Kelm found a Restoration clause that hires a Company by the dead names on its old roll.", "town_trial", Vector2(100, 70), "information", "Explains the hidden condition in a Restoration contract."],
		["brinna-fourbells", "Brinna Fourbells", "Crossing census keeper", "Town Hall", "North Arm", "trial-council", "Brinna's midwinter census contains one crossed-out name that still answers at each gate.", "town_registry", Vector2(-100, 70), "information", "Provides the missing name from the Crossing census."],
		["sorek-hushward", "Sorek Hushward", "Lip-shrine sweeper", "Howlpath Lodge", "North Arm", "kord-rite", "Sorek hears the calls before dawn and knows which ones come in a living voice.", "town_registry", Vector2(0, 78), "information", "Distinguishes a living caller from the dead muster echoes."],
		["enna-grayscar", "Enna Grayscar", "Archive seal clerk", "Registry Archive", "North Arm", "rennen", "Enna opens sealed road records only for someone carrying proof from the matching watch.", "town_registry", Vector2(100, 70), "gate", "Gates access to the sealed road archive behind verified watch proof."],
		["varrik-deepchalk", "Varrik Deepchalk", "Mining-lift chalker", "Equipment Shop", "East Arm", "shattersteel-concord", "Varrik will not mark a descent cage until the lift crew's safety tally is complete.", "town_bell", Vector2(-100, 70), "gate", "Gates use of a chasm-wall lift behind the completed safety tally."],
		["loa-flintthread", "Loa Flintthread", "Hospice intake keeper", "River Shrine Hospice", "West Arm", "hospice-chain", "Loa keeps patient names private until a scarred-hall token proves honest concern.", "town_bell", Vector2(0, 78), "gate", "Gates access to an unidentified hospice patient behind a hall token."],
		["kessa-nightrail", "Kessa Nightrail", "North-road sentry", "North Arm Gatehouse", "North Arm", "iron-companies", "Kessa opens the night road only when the Dorthkor warning and the Council seal agree.", "town_bell", Vector2(100, 70), "gate", "Gates the night road behind matching warning and Council clearance."],
		["orm-redtongs", "Orm Redtongs", "Forge safety master", "Equipment Shop", "East Arm", "shattersteel-concord", "Orm permits a forge shutdown only after a replacement hammer cadence is proven.", "town_shrine", Vector2(-100, 70), "gate", "Gates a controlled forge-silence behind a replacement cadence."],
		["yara-chainstep", "Yara Chainstep", "Harbor-chain inspector", "Drownedmouth Chainhouse", "West Arm", "ironbrand-sentinels", "Yara will return to the outer chain when the missing watch hand is accounted for.", "town_shrine", Vector2(0, 78), "state_change", "Moves from the shrine to the outer chain after the watch-hand search resolves."],
		["tern-hollowbeat", "Tern Hollowbeat", "Dorthkor memorial drummer", "Trial Hall", "North Arm", "trial-council", "Tern holds a deliberate silence where the lost road roll should have sounded.", "town_shrine", Vector2(100, 70), "state_change", "Restores the memorial cadence after the missing roll is recovered."],
		["mera-voss", "Mera Voss", "Hospice cook", "Chef's House", "West Arm", "hospice-chain", "Mera has banked the charfire until medicine reaches the trial-broken ward.", "town_companies", Vector2(-100, 70), "state_change", "Reopens the hospice charfire table after the medicine delivery."],
		["kadrin-stoneyield", "Kadrin Stoneyield", "Trial Pillar porter", "Trial Hall", "South Arm", "trial-council", "Kadrin keeps the damaged ascent roped off and counts every candidate turned away.", "town_companies", Vector2(0, 78), "state_change", "Removes the Pillar barricade after its burden pins are repaired."],
		["sava-mor", "Sava Mor", "Salvager's widow", "Lower Market Loft", "East Arm", "iron-companies", "Sava leaves an empty armor stand in her window until the ledge suit is returned or condemned.", "town_companies", Vector2(100, 70), "state_change", "Changes the market display when the recovered suit's fate is decided."],
		["drann-wetiron", "Drann Wetiron", "Shattersteel smith", "Equipment Shop", "East Arm", "shattersteel-concord", "Drann reserves the honest forge for names the Concord already speaks warmly.", "town_market", Vector2(-100, 70), "reputation_reaction", "Offers forge access at a warm Shattersteel Concord reputation band."],
		["edda-broadmark", "Edda Broadmark", "Company recruiter", "Iron Companies Barracks", "South Arm", "iron-companies", "Edda reads the Company's standing before she reads a volunteer's scars.", "town_market", Vector2(0, 78), "reputation_reaction", "Offers a veteran escort at a warm Iron Companies reputation band."],
		["holst-brinevein", "Holst Brinevein", "Harbor pilot", "Pilot Lodge", "West Arm", "wayfare-menders", "Holst saves his storm-proof route for travelers the Mender lodges trust.", "town_market", Vector2(100, 70), "reputation_reaction", "Shares a safe sea-mouth route at a warm Wayfare-Mender reputation band."],
		["raika-toll", "Raika Toll", "Sentinel toll keeper", "Jawbrace Watchroom", "North Arm", "ironbrand-sentinels", "Raika answers respect for the Sentinels with one more true entry from the Wound ledger.", "town_equipment", Vector2(-100, 70), "reputation_reaction", "Reveals a Wound-Watch ledger entry at a warm Sentinel reputation band."],
		["venn-ashcord", "Venn Ashcord", "Registry tallyman", "Registry Archive", "North Arm", "rennen", "Venn waives no line, but a warm Registry record earns the useful drawer first.", "town_equipment", Vector2(0, 78), "reputation_reaction", "Prioritizes a needed archive drawer at a warm Registry reputation band."],
		["jessa-longbrace", "Jessa Longbrace", "Bridge rope-splicer", "Jawbrace Watchroom", "North Arm", "trial-council", "Jessa splices every brace rope with four turns and cuts any sailor who adds a fifth.", "town_equipment", Vector2(100, 70), "", ""],
		["brannic-lowdrum", "Brannic Lowdrum", "Tavern drummer", "Four Arms Tavern", "South Arm", "iron-companies", "Brannic plays beneath the Hammer Roar by feeling the mugs walk across the table.", "town_hall", Vector2(-100, 70), "", ""],
		["saela-windscar", "Saela Windscar", "Roof-flag mender", "Town Hall", "North Arm", "trial-council", "Saela reads tomorrow's western wall by which roof flag tears first.", "town_hall", Vector2(0, 78), "", ""],
		["orrik-cinderjaw", "Orrik Cinderjaw", "Charfire barber", "Lower Market Loft", "East Arm", "shattersteel-concord", "Orrik trims hair with forge shears and never lets their hinge lose the hammer rhythm.", "town_hall", Vector2(100, 70), "", ""],
		["nym-vara", "Nym Vara", "Storm-cup seller", "Lower Market", "West Arm", "grain-factors-table", "Nym sells cups broad enough to catch rain and narrow enough not to lose it to the wind.", "town_tavern", Vector2(-100, 70), "", ""],
		["thora-bellmark", "Thora Bellmark", "Scar tattooist", "Bell House", "South Arm", "ironbrand-sentinels", "Thora inks no promise until the speaker can say its price without lowering their voice.", "town_tavern", Vector2(0, 78), "", ""],
		["gerren-pike", "Gerren Pike", "Company pike polisher", "Iron Companies Barracks", "East Arm", "iron-companies", "Gerren judges a pike by whether the bearer can see their scar in its edge.", "town_tavern", Vector2(100, 70), "", ""],
		["kiva-saltbrand", "Kiva Saltbrand", "Harbor salt seller", "Drownedmouth Berthhouse", "West Arm", "grain-factors-table", "Kiva keeps storm salt dry in retired drumskins and labels every skin by cadence.", "town_north_road", Vector2(-90, 90), "", ""],
		["dorran-rask", "Dorran Rask", "Road cobbler", "North Arm Gatehouse", "North Arm", "wayfare-menders", "Dorran soles road boots differently for the Trial Roads, where every climb leans the same way.", "town_wound_lip", Vector2(-100, 90), "", ""],
		["aela-quietforge", "Aela Quietforge", "Household tool-mender", "Player's House", "East Arm", "shattersteel-concord", "Aela works only hand tools at home, quiet enough that the East Arm hammers remain the loudest truth.", "town_wound_lip", Vector2(100, 90), "", ""],
	]
	var result: Array[Dictionary] = []
	for authored_index: int in authored.size():
		var row: Array = authored[authored_index]
		result.append(
			_npc(
				str(row[0]),
				str(row[1]),
				str(row[2]),
				str(row[3]),
				str(row[4]),
				str(row[5]),
				str(row[6]),
				str(row[7]),
				row[8] as Vector2,
				str(row[9]),
				str(row[10]),
				str(row[11]) if row.size() > 11 else "",
				authored_index,
			)
		)
	return result


func _npc(
	npc_id: String,
	display_name: String,
	role: String,
	home: String,
	district: String,
	faction_id: String,
	context_line: String,
	placement_key: String,
	offset: Vector2,
	involvement: String,
	hook_summary: String,
	vault_id: String,
	authored_index: int,
) -> Dictionary:
	var placement: Dictionary = PLACEMENT_ANCHORS[placement_key]
	var placement_offset := offset
	if placement["scene"] == TOWN_SCENE:
		placement_offset = _organic_outdoor_offset(npc_id, district, placement_key, offset)
	var hooks: Array[Dictionary] = []
	if not involvement.is_empty():
		var hook := {
			"quest_id": "dom/%s/%s" % [npc_id, involvement.replace("_", "-")],
			"involvement": involvement,
			"summary": hook_summary,
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
	return {
		"Display Name": display_name,
		"Epithet": str(NPC_EPITHETS.get(npc_id, "")),
		"Bio": str(NPC_BIOS.get(npc_id, "%s of Dom's %s." % [role, district])),
		"Vault Id": vault_id,
		"NPC Id": npc_id,
		"Town Id": "dom",
		"Role": role,
		"Home": home,
		"District": district,
		"Faction Id": faction_id,
		"Quest Hooks": JSON.stringify(hooks),
		"Portrait Id": npc_id,
		"Portrait Path": str(PORTRAIT_PATHS.get(npc_id, "")),
		"Dialogue Greeting": _greeting(district),
		"Dialogue Context": context_line,
		"Dialogue Farewell": _farewell(district),
		"Dialogue Hostile": str(REACTIVE_DIALOGUE.get(npc_id, {}).get("hostile", "")),
		"Dialogue Warm": str(REACTIVE_DIALOGUE.get(npc_id, {}).get("warm", "")),
		"Placement Scene": placement["scene"],
		"Placement Anchor": placement["anchor"],
		"Placement X": placement_offset.x,
		"Placement Y": placement_offset.y,
		"Facing": _plausible_facing(npc_id, placement_key, offset),
		"Idle Phase": _idle_phase(npc_id),
		"Model Index": (authored_index * 11) % TOWNSFOLK_MODEL_COUNT,
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
