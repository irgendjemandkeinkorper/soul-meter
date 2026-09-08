class_name VendorRegistry
extends RefCounted
## Read-only runtime view of Pandora-generated vendor and item economy data.

const VENDORS_DATA: JSON = preload("res://data/generated/vendors.json")
const ITEMS_DATA: JSON = preload("res://data/generated/gloot_prototree.json")
const BAND_RANK := {
	"hostile": 0,
	"cold": 1,
	"neutral": 2,
	"warm": 3,
	"allied": 4,
}


static func vendor(vendor_id: String) -> Dictionary:
	var vendors: Dictionary = VENDORS_DATA.data
	var value: Variant = vendors.get(vendor_id, {})
	return value.duplicate(true) if value is Dictionary else {}


static func all_vendors() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var vendors: Dictionary = VENDORS_DATA.data
	var ids: Array = vendors.keys()
	ids.sort()
	for vendor_id: String in ids:
		result.append(vendors[vendor_id].duplicate(true))
	return result


static func item(item_id: String) -> Dictionary:
	var items: Dictionary = ITEMS_DATA.data
	var value: Variant = items.get(item_id, {})
	if not value is Dictionary:
		return {}
	var result: Dictionary = value.duplicate(true)
	result["id"] = item_id
	return result


static func current_band(vendor_id: String) -> StringName:
	var row := vendor(vendor_id)
	if row.is_empty():
		return &"neutral"
	return Reputation.band(str(row.get("faction_id", "")))


static func trade_status(vendor_id: String, band: StringName = &"") -> Dictionary:
	var row := vendor(vendor_id)
	if row.is_empty():
		return {
			"allowed": false,
			"blocked_by": &"vendor",
			"nearest_unblock": {"type": &"known_vendor"},
			"open": false,
			"reason": "UNKNOWN VENDOR",
			"message": "UNKNOWN VENDOR",
			"band": &"neutral",
			"faction_id": &"",
		}
	var resolved_band := String(band if not band.is_empty() else current_band(vendor_id))
	var minimum_band := str(row.get("minimum_band", ""))
	var maximum_band := str(row.get("maximum_band", ""))
	var faction_id := str(row.get("faction_id", ""))
	if not _band_allows(resolved_band, minimum_band, maximum_band):
		var reason := "TRADE UNAVAILABLE AT %s STANDING" % resolved_band.to_upper()
		var nearest_unblock := {
			"type": &"reputation_band",
			"faction_id": StringName(faction_id),
			"current": StringName(resolved_band),
		}
		if not minimum_band.is_empty() and _rank(resolved_band) < _rank(minimum_band):
			reason = "TRADE REQUIRES %s STANDING" % minimum_band.to_upper()
			nearest_unblock["minimum"] = StringName(minimum_band)
			nearest_unblock["delta"] = _rank(minimum_band) - _rank(resolved_band)
		elif not maximum_band.is_empty() and _rank(resolved_band) > _rank(maximum_band):
			reason = "TRADE CLOSES ABOVE %s STANDING" % maximum_band.to_upper()
			nearest_unblock["maximum"] = StringName(maximum_band)
			nearest_unblock["delta"] = _rank(resolved_band) - _rank(maximum_band)
		return {
			"allowed": false,
			"blocked_by": &"reputation_band",
			"nearest_unblock": nearest_unblock,
			"open": false,
			"reason": reason,
			"message": reason,
			"band": StringName(resolved_band),
			"faction_id": StringName(faction_id),
		}
	return {
		"allowed": true,
		"blocked_by": &"",
		"nearest_unblock": {},
		"open": true,
		"reason": "",
		"message": "",
		"band": StringName(resolved_band),
		"faction_id": StringName(faction_id),
	}


static func stock_entry(vendor_id: String, item_id: String) -> Dictionary:
	var row := vendor(vendor_id)
	for value: Variant in row.get("stock", []):
		if value is Dictionary and str(value.get("item_id", "")) == item_id:
			return value.duplicate(true)
	return {}


static func stock_for(vendor_id: String, band: StringName = &"") -> Array[Dictionary]:
	var row := vendor(vendor_id)
	if row.is_empty():
		return []
	var resolved_band := String(band if not band.is_empty() else current_band(vendor_id))
	var result: Array[Dictionary] = []
	for value: Variant in row.get("stock", []):
		if not value is Dictionary:
			continue
		var stock: Dictionary = value
		if not _band_allows(
			resolved_band,
			str(stock.get("minimum_band", "")),
			str(stock.get("maximum_band", ""))
		):
			continue
		var item_row := item(str(stock.get("item_id", "")))
		if item_row.is_empty():
			continue
		item_row["base_quantity"] = int(stock.get("quantity", 0))
		item_row["minimum_band"] = str(stock.get("minimum_band", ""))
		item_row["maximum_band"] = str(stock.get("maximum_band", ""))
		result.append(item_row)
	return result


## `barter_ratio` is the caller's already-resolved Sway standing, 0.0 (no barter)
## to 1.0 (mastered), and it is a PARAMETER so this function stays pure and
## static — reading `SkillCheck` from here would make every price depend on an
## autoload and on who happens to be leading the party.
##
## #284 / game-identity ruling 7. Barter is deliberately NOT a roll. A price the
## player is shown must be the price they are charged, so it is a standing
## modifier off the skill's effective percentage, not a per-transaction dice
## throw. (Sway also carries a `karma_direction`, so a Virtuous ledger already
## bargains better through `SkillCheck.karma_bonus` — RFC-0007 §6.)
##
## 0.0 leaves the price exactly as it was before barter existed, which is what
## every caller that does not pass it still gets.
static func price_for(
	vendor_id: String,
	item_id: String,
	player_buys: bool,
	band: StringName = &"",
	barter_ratio: float = 0.0
) -> int:
	var row := vendor(vendor_id)
	var item_row := item(item_id)
	if row.is_empty() or item_row.is_empty() or stock_entry(vendor_id, item_id).is_empty():
		return 0
	var resolved_band := String(band if not band.is_empty() else current_band(vendor_id))
	var band_prices: Dictionary = row.get("band_price_modifiers", {})
	var band_row: Dictionary = band_prices.get(resolved_band, {})
	var transaction_key := "buy" if player_buys else "sell"
	var vendor_key := "buy_modifier" if player_buys else "sell_modifier"
	var raw_price := (
		float(item_row.get("base_price", 0))
		* float(row.get(vendor_key, 0.0))
		* float(band_row.get(transaction_key, 1.0))
		* barter_multiplier(player_buys, barter_ratio)
	)
	return maxi(1, roundi(raw_price)) if raw_price > 0.0 else 0


## PROVISIONAL — the swing magnitude is DeepSeek's per #284's "do not decide"
## boundary. Mastered Sway buys this much cheaper and sells this much dearer.
const BARTER_SWING := 0.20


## Monotone in `barter_ratio` and symmetric between the two directions, so a
## better negotiator is never charged more. At ratio 0 this returns exactly 1.0,
## which is why adding barter did not move any shipped price on its own.
static func barter_multiplier(player_buys: bool, barter_ratio: float) -> float:
	var ratio := clampf(barter_ratio, 0.0, 1.0)
	return 1.0 - BARTER_SWING * ratio if player_buys else 1.0 + BARTER_SWING * ratio


static func accepts_sales(vendor_id: String, item_id: String) -> bool:
	var row := vendor(vendor_id)
	return (
		str(row.get("trade_mode", "commerce")) == "commerce"
		and not stock_entry(vendor_id, item_id).is_empty()
		and price_for(vendor_id, item_id, false) > 0
	)


static func base_stock(vendor_id: String) -> Dictionary:
	var result := {}
	var row := vendor(vendor_id)
	for value: Variant in row.get("stock", []):
		if value is Dictionary:
			result[str(value.get("item_id", ""))] = int(value.get("quantity", 0))
	return result


static func restock_policy(vendor_id: String) -> Dictionary:
	var row := vendor(vendor_id)
	var value: Variant = row.get("restock", {})
	return value.duplicate(true) if value is Dictionary else {}


static func band_gated_reactions() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for row: Dictionary in all_vendors():
		for value: Variant in row.get("band_reactions", []):
			if value is Dictionary:
				var reaction: Dictionary = value.duplicate(true)
				reaction["vendor_id"] = row["id"]
				result.append(reaction)
	return result


static func _band_allows(band: String, minimum_band: String, maximum_band: String) -> bool:
	if not BAND_RANK.has(band):
		return false
	if not minimum_band.is_empty() and _rank(band) < _rank(minimum_band):
		return false
	if not maximum_band.is_empty() and _rank(band) > _rank(maximum_band):
		return false
	return true


static func _rank(band: String) -> int:
	return int(BAND_RANK.get(band, BAND_RANK["neutral"]))
