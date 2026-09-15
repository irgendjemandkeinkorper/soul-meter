extends Node2D
## Runtime occlusion for Dom's painted facades. Building roots retain the
## existing door, collision, and placement wiring.

const FacadeOccluderScript := preload("res://world/facade_occluder.gd")

const BUILDING_NAMES := [
	"TrialHall",
	"RegistryArchive",
	"BellHouse",
	"RiverShrine",
	"IronCompaniesBarracks",
	"LowerMarket",
	"ItemShop",
	"EquipmentShop",
	"TownHall",
	"ChefsHouse",
	"PlayersHouse",
	"FourArmsTavern",
]
# PROVISIONAL — CANON REVIEW REQUIRED (the nudge line itself; the marker must
# never reach the player-visible string).
const OPENING_COUNCIL_NUDGE := "THE COUNCIL AWAITS IN THE COUNCIL CHAMBER."
const COUNCIL_NUDGE_SHOWN_FLAG := "chapter_council_nudge_shown"


func _ready() -> void:
	for building_name: String in BUILDING_NAMES:
		var building := get_node_or_null(building_name) as Node2D
		if building == null:
			push_error("Starting town is missing building '%s'." % building_name)
			continue
		var facade := building.get_node("Facade") as Sprite2D
		building.add_child(FacadeOccluderScript.new(facade))
	_show_opening_council_nudge()


func _show_opening_council_nudge() -> void:
	if (
		not GameState.flag_is_true(GameState.OPENING_GAUNTLET_COMPLETE_FLAG)
		or GameState.flag_is_true(COUNCIL_NUDGE_SHOWN_FLAG)
		or QuestRegistry.is_active(QuestRegistry.DORTHKOR_ROAD)
		or QuestRegistry.is_done(QuestRegistry.DORTHKOR_ROAD)
	):
		return
	GameState.set_flag(COUNCIL_NUDGE_SHOWN_FLAG, true)
	var notices := get_node_or_null("FieldHUD/ConsequenceNotices") as ConsequenceNotices
	if notices == null:
		push_warning("Starting town has no consequence-notice HUD for the Council nudge.")
		return
	# Reuse the established notice queue. A dedicated marker/compass mechanism
	# would add persistent world-navigation state for a single onboarding beat.
	notices._enqueue(OPENING_COUNCIL_NUDGE)
