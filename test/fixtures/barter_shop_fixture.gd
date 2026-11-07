extends RefCounted
## Shared isolated basket for the P1.3 accounting tests and rendered acceptance capture.

const VENDOR_ID := VendorIds.IRON_AND_THREAD
const BASKET: Array[String] = [
	ItemIds.WEAPONS_ROADWARDEN_SPEAR,
	ItemIds.WEAPONS_FORGE_HAMMER,
	ItemIds.MATERIALS_IRON_RIVETS,
]

var leader: PartyMember
var _state_before: Dictionary
var _reputation_before: Dictionary
var _renown_before: Dictionary
var _quest_listener_connected := false


func set_up() -> void:
	_state_before = GameState.to_dict().duplicate(true)
	_reputation_before = Reputation.to_dict().duplicate(true)
	_renown_before = Renown.to_dict().duplicate(true)
	var listener := Callable(QuestRegistry, "_on_inventory_changed")
	_quest_listener_connected = GameState.inventory_changed.is_connected(listener)
	if _quest_listener_connected:
		GameState.inventory_changed.disconnect(listener)
	Reputation.from_dict({})
	Renown.from_dict({})
	GameState.flags.clear()
	GameState.skills.clear()
	GameState.vendor_stock.clear()
	GameState.vendor_restock_cycles.clear()
	GameState.inventory.clear()
	GameState.set_gp(5000)
	GameState.set_locale("en")
	leader = PartyMember.new()
	leader.id = GameState.PROTAGONIST_ID
	leader.display_name = "Vex"
	leader.attributes = {"decorum": 0, "doctrine": DramgidSchema.ATTRIBUTE_CAP}
	leader.advancement_points = 1000
	GameState.set_party([leader])


func restore() -> void:
	GameState.from_dict(_state_before)
	Reputation.from_dict(_reputation_before)
	Renown.from_dict(_renown_before)
	if _quest_listener_connected:
		GameState.inventory_changed.connect(Callable(QuestRegistry, "_on_inventory_changed"))


## Buy real +5% steps; no generated data or direct skill-dictionary edits.
func advance_to(percent: float) -> bool:
	while SkillCheck.effective_percent("sway", leader) < percent:
		if not bool(Advancement.buy(leader, "sway").get("allowed", false)):
			return false
	return is_equal_approx(SkillCheck.effective_percent("sway", leader), percent)


static func trade_button(shop: ShopScreen, item_id: String, buys: bool) -> Button:
	var prefix := "Buy_" if buys else "Sell_"
	return shop.find_child(prefix + item_id.replace("/", "_"), true, false) as Button


## Read the number the player sees, not metadata or a second pricing formula.
static func displayed_price(button: Button) -> int:
	return button.text.get_slice("  ·  ", 1).to_int()


static func readout(shop: ShopScreen) -> Label:
	return shop.find_child("BarterReadout", true, false) as Label
