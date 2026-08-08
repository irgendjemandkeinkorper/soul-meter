extends Node
## Serialized global state: durable flags, Soul, the Vex-led party, inventory,
## and local settings. Menus are views over this singleton.

const VendorData := preload("res://globals/vendor_registry.gd")

signal soul_meter_changed(value: float)
signal husked_state_changed(husked: bool)
signal gp_changed(value: int)
signal flag_changed(flag: String, value: Variant)
signal inventory_changed
signal vendor_stock_changed(vendor_id: String, item_id: String, quantity: int)
signal party_changed
signal locale_changed(locale: String)
signal var_harmony_changed(actor_id: String, value: int, delta: int, source: StringName)
signal combat_knowledge_changed(archetype_id: String)
signal setting_changed(section: String, key: String, value: Variant)

const SETTINGS_PATH := "user://settings.cfg"
const PROTAGONIST_ID := "vex"
const PROTAGONIST_NAME := "Vex the Unbowed"
const REQUIRED_COMPANIONS := 2
const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES := ["en", "es"]
const DEFAULT_GP := 250
const MIN_VAR_HARMONY := -5
const MAX_VAR_HARMONY := 5
const SKILL_TIERS := ["Untrained", "Trained", "Expert"]
const AUDIO_BUSES: Array[StringName] = [&"Master", &"Music", &"SFX"]

## M4.3 — husking-while-alive (cosmology/souls.md, "Reaching zero", ratified
## 2026-08-07). Reaching Gauge zero does NOT end the run: it sets a husked
## flag that CastingGate refuses casting against. Stored as flags (see
## globals/game_state.gd `flags`) rather than new save fields, so this needs
## no schema bump. `soul` is a registered FLAG_DOMAINS entry (tools/quest_audit.gd).
const HUSKED_FLAG := "soul_husked"
## Set once, the first time the Gauge reaches zero, and never cleared — it is
## the permanent scar canon describes ("never reads as bright again"), kept
## even after HUSKED_FLAG clears from partial recovery.
const HUSKED_RECOVERY_CEILING_FLAG := "soul_husked_recovery_ceiling"
## Fraction of the pre-zero Gauge that recovery may ever reach again.
## **PROVISIONAL — not ratified.** Canon fixes only the SHAPE: recovery is slow,
## partial, and never complete. This ratio is the first number that satisfies
## that shape and has had no balance sweep. The tactical amendment §1.1 records
## what happens when a magnitude is treated as settled without one.
const HUSKED_CEILING_RATIO := 0.5

var flags: Dictionary = {}
var soul_meter: float = 50.0:
	set = set_soul_meter
var gp: int = DEFAULT_GP:
	set = set_gp
var party: Array[PartyMember] = []
var inventory: Inventory
## Stable vendor id -> stable item id -> current quantity.
var vendor_stock: Dictionary = {}
## Stable vendor id -> most recent world-time restock cycle applied.
var vendor_restock_cycles: Dictionary = {}
var current_locale := DEFAULT_LOCALE
## actor id -> skill id -> { percentage, tier, advancement_points_spent }
var skills: Dictionary = {}
## actor id -> integer Vär harmony in the ratified -5…+5 range.
var var_harmony: Dictionary = {}
## Stable Pandora Combatant Id -> {encounters, weaknesses}. Weakness IDs are
## stable world-fact IDs from the generated Defining Strike table.
var combat_knowledge: Dictionary = {}
var settings_path: String = SETTINGS_PATH

var _settings := ConfigFile.new()


func _ready() -> void:
	_ensure_audio_buses()
	_load_settings()
	inventory = Inventory.new()
	inventory.protoset = load("res://data/generated/gloot_prototree.json")
	add_child(inventory)
	inventory.item_added.connect(func(_item: InventoryItem) -> void: inventory_changed.emit())
	inventory.item_removed.connect(func(_item: InventoryItem) -> void: inventory_changed.emit())
	inventory.item_property_changed.connect(
		func(_item: InventoryItem, _property: String) -> void: inventory_changed.emit()
	)
	inventory.item_moved.connect(func() -> void: inventory_changed.emit())
	_seed_demo_data()


# --- Soul Meter and facts ----------------------------------------------------


func set_soul_meter(value: float) -> void:
	var pre_zero_value := soul_meter
	var ceiling := husked_recovery_ceiling() if has_been_husked() else 100.0
	soul_meter = clampf(value, 0.0, ceiling)
	soul_meter_changed.emit(soul_meter)
	if is_zero_approx(soul_meter):
		if not is_husked():
			_enter_husked_state(pre_zero_value)
	elif is_husked():
		_exit_husked_state()


## True while the Soul Gauge is husked — casting is refused (see CastingGate).
## This clears once the Gauge is raised back above zero by partial recovery;
## the permanent ceiling on that recovery does not (see has_been_husked()).
func is_husked() -> bool:
	return bool(get_flag(HUSKED_FLAG, false))


## True once a soul has ever been husked, even after recovery clears
## is_husked(). Drives the permanent recovery ceiling.
func has_been_husked() -> bool:
	return flags.has(HUSKED_RECOVERY_CEILING_FLAG)


## The most the Gauge may ever read again after a husking. Recovery is
## partial by construction: capped at half of whatever the Gauge read the
## instant before it hit zero, so it structurally cannot return to its
## pre-zero value. The mechanism that actually raises the Gauge after
## husking (a quest, dialogue, being witnessed and remembered) is authored
## later — this only models the ceiling that mechanism must respect.
func husked_recovery_ceiling() -> float:
	return float(get_flag(HUSKED_RECOVERY_CEILING_FLAG, 100.0))


## Casting-gate context describing the current husked state, in the shape
## CastingGate.query()/query_breadth() expect from caster_context.
func husked_casting_context() -> Dictionary:
	return {"husked": is_husked(), "husked_recovery_ceiling": husked_recovery_ceiling()}


func _enter_husked_state(pre_zero_value: float) -> void:
	set_flag(HUSKED_FLAG, true)
	if not has_been_husked():
		var ceiling := clampf(pre_zero_value, 0.0, 100.0) * HUSKED_CEILING_RATIO
		set_flag(HUSKED_RECOVERY_CEILING_FLAG, ceiling)
	husked_state_changed.emit(true)


func _exit_husked_state() -> void:
	set_flag(HUSKED_FLAG, false)
	husked_state_changed.emit(false)


func set_gp(value: int) -> void:
	gp = maxi(0, value)
	gp_changed.emit(gp)


func can_afford(amount: int) -> bool:
	return amount >= 0 and gp >= amount


func spend_gp(amount: int) -> bool:
	if amount < 0 or not can_afford(amount):
		return false
	set_gp(gp - amount)
	return true


func earn_gp(amount: int) -> void:
	if amount > 0:
		set_gp(gp + amount)


func set_flag(flag: String, value: Variant = true) -> void:
	if flags.get(flag) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


# --- Defining Strike knowledge ----------------------------------------------


func prior_archetype_encounters(archetype_id: StringName) -> int:
	var row: Variant = combat_knowledge.get(String(archetype_id), {})
	return int(row.get("encounters", 0)) if row is Dictionary else 0


func record_archetype_encounter(archetype_id: StringName) -> int:
	var key := String(archetype_id)
	if not StableIds.is_valid(StableIds.ACTOR, key):
		return 0
	var row: Dictionary = combat_knowledge.get(key, {}).duplicate(true)
	row["encounters"] = int(row.get("encounters", 0)) + 1
	if not row.get("weaknesses", []) is Array:
		row["weaknesses"] = []
	combat_knowledge[key] = row
	combat_knowledge_changed.emit(key)
	return int(row["encounters"])


func discover_weakness(archetype_id: StringName, weakness_id: StringName) -> bool:
	var archetype_key := String(archetype_id)
	var weakness_key := String(weakness_id)
	if (
		not StableIds.is_valid(StableIds.ACTOR, archetype_key)
		or not StableIds.is_valid(StableIds.WORLD_FACT, weakness_key)
	):
		return false
	var row: Dictionary = combat_knowledge.get(archetype_key, {}).duplicate(true)
	var weaknesses: Array = row.get("weaknesses", []).duplicate()
	if weakness_key in weaknesses:
		return false
	weaknesses.append(weakness_key)
	row["weaknesses"] = weaknesses
	row["encounters"] = int(row.get("encounters", 0))
	combat_knowledge[archetype_key] = row
	combat_knowledge_changed.emit(archetype_key)
	return true


func discovered_weaknesses(archetype_id: StringName) -> Array[StringName]:
	var result: Array[StringName] = []
	var row: Variant = combat_knowledge.get(String(archetype_id), {})
	if not row is Dictionary:
		return result
	var values: Variant = row.get("weaknesses", [])
	if values is Array:
		for weakness_id: Variant in values:
			if weakness_id is String:
				result.append(StringName(weakness_id))
	return result


func has_discovered_weakness(archetype_id: StringName, weakness_id: StringName) -> bool:
	return weakness_id in discovered_weaknesses(archetype_id)


# --- Vär (personal harmony) --------------------------------------------------


## Return one actor's Vär. Unknown actors begin at the neutral midpoint.
func get_var_harmony(actor_id: String) -> int:
	return clampi(int(var_harmony.get(actor_id, 0)), MIN_VAR_HARMONY, MAX_VAR_HARMONY)


func var_harmony_for(actor_id: String) -> int:
	return get_var_harmony(actor_id)


## Set Vär through the bounded store and report the actual clamped value.
func set_var_harmony(actor_id: String, value: int, source: StringName = &"manual") -> int:
	if actor_id.is_empty():
		return 0
	var previous := get_var_harmony(actor_id)
	var next := clampi(value, MIN_VAR_HARMONY, MAX_VAR_HARMONY)
	var_harmony[actor_id] = next
	if next != previous:
		var_harmony_changed.emit(actor_id, next, next - previous, source)
	return next


## Story and system effects may move Vär in either direction.
func adjust_var_harmony(actor_id: String, delta: int, source: StringName = &"adjust") -> int:
	return set_var_harmony(actor_id, get_var_harmony(actor_id) + delta, source)


## Combat and field actions use a positive-only recovery seam. Keeping this
## separate from adjust_var_harmony makes recovery-through-play structural.
func raise_var_harmony_from_play(
	actor_id: String, amount: int = 1, action_id: StringName = &"play"
) -> int:
	if amount <= 0:
		return get_var_harmony(actor_id)
	return adjust_var_harmony(actor_id, amount, action_id)


# --- Inventory ---------------------------------------------------------------


func item_count(item_id: String) -> int:
	var total := 0
	for item in inventory.get_items_with_prototype_id(item_id):
		total += item.get_stack_size()
	return total


func remove_items(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if item_count(item_id) < amount:
		return false
	var remaining := amount
	for item in inventory.get_items_with_prototype_id(item_id):
		var stack_size: int = item.get_stack_size()
		var taken := mini(stack_size, remaining)
		if taken == stack_size:
			inventory.remove_item(item)
		else:
			item.set_stack_size(stack_size - taken)
		remaining -= taken
		if remaining == 0:
			break
	return true


# --- Vendor economy ----------------------------------------------------------


func vendor_trade_status(vendor_id: String) -> Dictionary:
	return VendorData.trade_status(vendor_id)


func available_vendor_stock(vendor_id: String) -> Array[Dictionary]:
	var status := vendor_trade_status(vendor_id)
	if not bool(status.get("allowed", false)):
		return []
	_ensure_vendor_stock(vendor_id)
	var result: Array[Dictionary] = []
	for row: Dictionary in VendorData.stock_for(vendor_id):
		var item_id := str(row.get("id", ""))
		row["quantity"] = vendor_item_quantity(vendor_id, item_id)
		row["buy_price"] = VendorData.price_for(vendor_id, item_id, true)
		row["sell_price"] = VendorData.price_for(vendor_id, item_id, false)
		result.append(row)
	return result


func vendor_item_quantity(vendor_id: String, item_id: String) -> int:
	_ensure_vendor_stock(vendor_id)
	var stock: Dictionary = vendor_stock.get(vendor_id, {})
	return int(stock.get(item_id, 0))


func buy_from_vendor(vendor_id: String, item_id: String) -> Dictionary:
	if (
		not StableIds.is_valid(StableIds.VENDOR, vendor_id)
		or not StableIds.is_valid(StableIds.ITEM, item_id)
	):
		return _trade_failure("invalid_id")
	var status := vendor_trade_status(vendor_id)
	if not bool(status.get("allowed", false)):
		return _trade_failure("trade_refused", str(status.get("reason", "")), 0, status)
	if not _vendor_stock_is_available(vendor_id, item_id):
		return _trade_failure("stock_unavailable")
	if vendor_item_quantity(vendor_id, item_id) <= 0:
		return _trade_failure("sold_out")
	var price := VendorData.price_for(vendor_id, item_id, true)
	if price <= 0:
		return _trade_failure("invalid_price")
	if not can_afford(price):
		return _trade_failure("insufficient_gp", "NEED %d  ·  HAVE %d" % [price, gp], price)

	# Add first: a full GLoot grid must leave GP and vendor stock untouched.
	var added_item: InventoryItem = inventory.create_and_add_item(item_id)
	if added_item == null:
		return _trade_failure("inventory_full", "THE INVENTORY CANNOT HOLD THIS ITEM", price)
	if not spend_gp(price):
		inventory.remove_item(added_item)
		return _trade_failure("insufficient_gp", "GP LEDGER UNCHANGED", price)
	_set_vendor_item_quantity(vendor_id, item_id, vendor_item_quantity(vendor_id, item_id) - 1)
	return _trade_success(price)


func sell_to_vendor(vendor_id: String, item_id: String) -> Dictionary:
	if (
		not StableIds.is_valid(StableIds.VENDOR, vendor_id)
		or not StableIds.is_valid(StableIds.ITEM, item_id)
	):
		return _trade_failure("invalid_id")
	var status := vendor_trade_status(vendor_id)
	if not bool(status.get("allowed", false)):
		return _trade_failure("trade_refused", str(status.get("reason", "")), 0, status)
	if not _vendor_stock_is_available(vendor_id, item_id):
		return _trade_failure("stock_unavailable")
	if not VendorData.accepts_sales(vendor_id, item_id):
		return _trade_failure("sales_not_accepted")
	if item_count(item_id) <= 0:
		return _trade_failure("item_missing")
	var price := VendorData.price_for(vendor_id, item_id, false)
	if price <= 0:
		return _trade_failure("invalid_price")
	if not remove_items(item_id, 1):
		return _trade_failure("item_missing")
	earn_gp(price)
	_set_vendor_item_quantity(vendor_id, item_id, vendor_item_quantity(vendor_id, item_id) + 1)
	return _trade_success(price)


func restock_vendor(vendor_id: String, restock_cycle: int) -> bool:
	var policy := VendorData.restock_policy(vendor_id)
	if policy.is_empty() or str(policy.get("mode", "")) == "never":
		return false
	var interval := maxi(1, int(policy.get("interval", 1)))
	var previous_cycle := int(vendor_restock_cycles.get(vendor_id, 0))
	if restock_cycle <= previous_cycle or restock_cycle - previous_cycle < interval:
		return false
	_ensure_vendor_stock(vendor_id)
	var target := VendorData.base_stock(vendor_id)
	for item_id: String in target:
		_set_vendor_item_quantity(vendor_id, item_id, int(target[item_id]))
	vendor_restock_cycles[vendor_id] = restock_cycle
	return true


func _ensure_vendor_stock(vendor_id: String) -> void:
	if vendor_stock.has(vendor_id):
		return
	var initial := VendorData.base_stock(vendor_id)
	if not initial.is_empty():
		vendor_stock[vendor_id] = initial


func _vendor_stock_is_available(vendor_id: String, item_id: String) -> bool:
	for row: Dictionary in VendorData.stock_for(vendor_id):
		if str(row.get("id", "")) == item_id:
			return true
	return false


func _set_vendor_item_quantity(vendor_id: String, item_id: String, quantity: int) -> void:
	_ensure_vendor_stock(vendor_id)
	if not vendor_stock.has(vendor_id):
		return
	var stock: Dictionary = vendor_stock[vendor_id]
	stock[item_id] = maxi(0, quantity)
	vendor_stock[vendor_id] = stock
	vendor_stock_changed.emit(vendor_id, item_id, int(stock[item_id]))


func _trade_success(price: int) -> Dictionary:
	return {
		"ok": true,
		"allowed": true,
		"blocked_by": &"",
		"nearest_unblock": {},
		"reason": "",
		"message": "",
		"price": price,
	}


func _trade_failure(
	reason: String, message: String = "", price: int = 0, gate: Dictionary = {}
) -> Dictionary:
	var blocked_by := StringName(reason)
	var nearest_unblock: Dictionary = {}
	if not gate.is_empty():
		blocked_by = StringName(gate.get("blocked_by", blocked_by))
		var nearest_value: Variant = gate.get("nearest_unblock", {})
		if nearest_value is Dictionary:
			nearest_unblock = nearest_value.duplicate(true)
	return {
		"ok": false,
		"allowed": false,
		"blocked_by": blocked_by,
		"nearest_unblock": nearest_unblock,
		"reason": reason,
		"message": message,
		"price": price,
	}


# --- Settings ---------------------------------------------------------------


func set_setting(section: String, key: String, value: Variant) -> void:
	_settings.set_value(section, key, value)
	_settings.save(settings_path)
	setting_changed.emit(section, key, value)


func get_setting(section: String, key: String, default: Variant) -> Variant:
	return _settings.get_value(section, key, default)


func _load_settings() -> void:
	_settings.load(settings_path)
	apply_fullscreen(_settings.get_value("display", "fullscreen", false))
	apply_locale(str(_settings.get_value("display", "locale", DEFAULT_LOCALE)))
	for bus: StringName in AUDIO_BUSES:
		set_bus_volume(bus, _settings.get_value("audio", bus, 1.0))


func apply_fullscreen(on: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func apply_locale(locale: String) -> void:
	var resolved := locale if locale in SUPPORTED_LOCALES else DEFAULT_LOCALE
	if current_locale == resolved and TranslationServer.get_locale() == resolved:
		return
	current_locale = resolved
	TranslationServer.set_locale(current_locale)
	locale_changed.emit(current_locale)


func set_locale(locale: String) -> void:
	apply_locale(locale)
	set_setting("display", "locale", current_locale)


func get_locale() -> String:
	return current_locale


func set_bus_volume(bus: StringName, linear: float, persist: bool = false) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		var clamped := clampf(linear, 0.0, 1.0)
		AudioServer.set_bus_mute(idx, is_zero_approx(clamped))
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(clamped, 0.0001)))
		if persist:
			set_setting("audio", String(bus), clamped)


func get_bus_volume(bus: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return 1.0
	return 0.0 if AudioServer.is_bus_mute(idx) else db_to_linear(AudioServer.get_bus_volume_db(idx))


func _ensure_audio_buses() -> void:
	for bus: StringName in AUDIO_BUSES:
		if bus == &"Master":
			continue
		if AudioServer.get_bus_index(bus) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, &"Master")


# --- Prototype party and inventory ------------------------------------------


func _seed_demo_data() -> void:
	gp = DEFAULT_GP
	vendor_stock.clear()
	vendor_restock_cycles.clear()
	party = [_make_vex()]
	skills = {}
	var_harmony = {}
	combat_knowledge = {}
	party_changed.emit()
	inventory.clear()
	inventory.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	inventory.create_and_add_item(ItemIds.RELICS_CAPTURED_REFLECTION)
	inventory.create_and_add_item(ItemIds.TOOLS_SOUL_GAUGE)
	var bread := inventory.create_and_add_item(ItemIds.CONSUMABLES_LOAM_BREAD)
	if bread:
		bread.set_stack_size(5)
	var ink := inventory.create_and_add_item(ItemIds.MATERIALS_CINDER_INK_VIAL)
	if ink:
		ink.set_stack_size(2)
	inventory.create_and_add_item(ItemIds.RELICS_QUINE_SHARD)


func _make_member(
	member_id: String,
	display_name: String,
	race: String,
	char_class: String,
	stats: Vector4i,
	bio: String,
	min_reputation: float = 0.0,
	min_infamy: float = 0.0
) -> PartyMember:
	var member := PartyMember.new()
	member.id = member_id
	member.display_name = display_name
	member.race = race
	member.char_class = char_class
	member.level = stats.x
	member.hp = stats.y
	member.max_hp = stats.y
	member.attack = stats.z
	member.defense = stats.w
	member.bio = bio
	member.min_reputation = min_reputation
	member.min_infamy = min_infamy
	return member


func _make_vex() -> PartyMember:
	return _make_member(
		PROTAGONIST_ID,
		PROTAGONIST_NAME,
		"Ash-Bound Kes'reth",
		"Ironbrand (Kero)",
		Vector4i(4, 44, 9, 5),
		"A horned reaver of Karrn-Vash; her soul is a held line, sealed in cinder-ink."
	)


func recruitable_candidates() -> Array[PartyMember]:
	var result: Array[PartyMember] = []
	result.append(
		_make_member(
			"serai-lun",
			"Serai-Lun",
			"Mirror-Veil Kes'reth",
			"Mirrorblade (Maiiam)",
			Vector4i(3, 30, 8, 2),
			"A precise duelist who turns Balance into a weapon."
		)
	)
	result.append(
		_make_member(
			"old-grumbrand",
			"Old Grumbrand",
			"Kaan Deepkin",
			"Lensbearer (Stuid)",
			Vector4i(3, 38, 5, 6),
			"A soot-stained salvager built to hold a dangerous line."
		)
	)
	result.append(
		_make_member(
			"wyneth-hallow-tide",
			"Wyneth Hallow-Tide",
			"Ghorr",
			"River-Mother (Haeren)",
			Vector4i(3, 34, 4, 5),
			"A field-medic whose steady presence makes mistakes survivable."
		)
	)
	result.append(
		_make_member(
			"ressa-quickfingers",
			"Ressa Quickfingers",
			"Vael",
			"Locksmirk (Fickah)",
			Vector4i(3, 28, 9, 1),
			"A fast, fragile opportunist with an eye for a weak flank."
		)
	)
	result.append(
		_make_member(
			"korrath-ninefold",
			"Korrath Ninefold",
			"Orthos",
			"Ironbrand (Kero)",
			Vector4i(4, 42, 7, 6),
			"A renowned Steel Day bruiser who demands a proven leader.",
			10.0
		)
	)
	result.append(
		_make_member(
			"maura-greyfen",
			"Maura Greyfen",
			"Snarlin",
			"Husk-bearer (Vhorr)",
			Vector4i(3, 34, 6, 5),
			"A Deep Salvage veteran who only trusts a notorious name.",
			0.0,
			8.0
		)
	)
	return result


func protagonist() -> PartyMember:
	for member in party:
		if member.id == PROTAGONIST_ID or member.display_name == PROTAGONIST_NAME:
			return member
	return null


func companions() -> Array[PartyMember]:
	var result: Array[PartyMember] = []
	var lead := protagonist()
	for member in party:
		if member != lead:
			result.append(member)
	return result


func has_selected_companions() -> bool:
	return protagonist() != null and companions().size() == REQUIRED_COMPANIONS


func set_companions(members: Array[PartyMember]) -> bool:
	if members.size() != REQUIRED_COMPANIONS:
		return false
	var allowed_ids := {}
	for candidate in recruitable_candidates():
		allowed_ids[candidate.id] = true
	var seen := {}
	for member in members:
		if (
			member == null
			or not allowed_ids.has(member.id)
			or member.id == PROTAGONIST_ID
			or seen.has(member.id)
			or member.min_reputation > Renown.reputation()
			or member.min_infamy > Renown.infamy()
		):
			return false
		seen[member.id] = true
	var lead := protagonist()
	if lead == null:
		lead = _make_vex()
	party = [lead, members[0], members[1]]
	set_flag("chapter_party_formed", true)
	party_changed.emit()
	SaveGame.request_checkpoint(SaveGame.Checkpoint.PARTY_FORMED)
	return true


## Compatibility seam for tests/tools; gameplay party assembly uses set_companions().
func set_party(members: Array[PartyMember]) -> void:
	party = members.duplicate()
	party_changed.emit()


func has_party_member(display_name: String) -> bool:
	for member in party:
		if member.display_name == display_name:
			return true
	return false


# --- Save data ---------------------------------------------------------------


func to_dict() -> Dictionary:
	var party_rows: Array[Dictionary] = []
	for member in party:
		party_rows.append(member.to_dict())
	return {
		"flags": flags.duplicate(true),
		"soul_meter": soul_meter,
		"gp": gp,
		"party": party_rows,
		"inventory": inventory.serialize(),
		"vendor_stock": vendor_stock.duplicate(true),
		"vendor_restock_cycles": vendor_restock_cycles.duplicate(true),
		"skills": skills.duplicate(true),
		"var_harmony": var_harmony.duplicate(true),
		"combat_knowledge": combat_knowledge.duplicate(true),
	}


func from_dict(data: Dictionary) -> bool:
	if not _validate_save_data(data):
		return false
	var inventory_data: Variant = data.get("inventory", {})
	if not inventory_data is Dictionary or not inventory.deserialize(inventory_data):
		return false
	flags.clear()
	var raw_flags: Variant = data.get("flags", {})
	if raw_flags is Dictionary:
		for k in raw_flags:
			if k is String and k.length() <= 128:
				flags[k] = raw_flags[k]
	soul_meter = float(data.get("soul_meter", 50.0))
	gp = maxi(0, int(data.get("gp", DEFAULT_GP)))
	vendor_stock = data.get("vendor_stock", {}).duplicate(true)
	vendor_restock_cycles = data.get("vendor_restock_cycles", {}).duplicate(true)
	skills = data.get("skills", {}).duplicate(true)
	var_harmony = data.get("var_harmony", {}).duplicate(true)
	combat_knowledge = data.get("combat_knowledge", {}).duplicate(true)
	party.clear()
	for row in data.get("party", []):
		party.append(PartyMember.from_dict(row))
	inventory_changed.emit()
	party_changed.emit()
	return true


func _validate_save_data(data: Dictionary) -> bool:
	for key in [
		"flags",
		"skills",
		"var_harmony",
		"combat_knowledge",
		"inventory",
		"vendor_stock",
		"vendor_restock_cycles",
	]:
		if data.has(key) and not data[key] is Dictionary:
			return false
	var saved_vendor_stock: Dictionary = data.get("vendor_stock", {})
	for vendor_id: Variant in saved_vendor_stock:
		if (
			not vendor_id is String
			or not StableIds.is_valid(StableIds.VENDOR, str(vendor_id))
			or not saved_vendor_stock[vendor_id] is Dictionary
		):
			return false
		for item_id: Variant in saved_vendor_stock[vendor_id]:
			var quantity: Variant = saved_vendor_stock[vendor_id][item_id]
			if (
				not item_id is String
				or not StableIds.is_valid(StableIds.ITEM, str(item_id))
				or typeof(quantity) != TYPE_INT
				or int(quantity) < 0
			):
				return false
	var saved_restock_cycles: Dictionary = data.get("vendor_restock_cycles", {})
	for vendor_id: Variant in saved_restock_cycles:
		if (
			not vendor_id is String
			or not StableIds.is_valid(StableIds.VENDOR, str(vendor_id))
			or typeof(saved_restock_cycles[vendor_id]) != TYPE_INT
			or int(saved_restock_cycles[vendor_id]) < 0
		):
			return false
	if data.has("party") and not data["party"] is Array:
		return false
	for row: Variant in data.get("party", []):
		if not row is Dictionary:
			return false
	var harmony: Dictionary = data.get("var_harmony", {})
	for actor_id: Variant in harmony:
		# SECURITY ENHANCEMENT: Validate actor_id format/length using StableIds
		if not actor_id is String or (actor_id as String).length() > 64 or not StableIds.is_valid(StableIds.ACTOR, str(actor_id)):
			return false
		var value: Variant = harmony[actor_id]
		if typeof(value) != TYPE_INT or int(value) < -5 or int(value) > 5:
			return false
	var knowledge: Dictionary = data.get("combat_knowledge", {})
	for archetype_id: Variant in knowledge:
		var knowledge_row: Variant = knowledge[archetype_id]
		if (
			not archetype_id is String
			or not StableIds.is_valid(StableIds.ACTOR, str(archetype_id))
			or not knowledge_row is Dictionary
			or typeof(knowledge_row.get("encounters", 0)) != TYPE_INT
			or int(knowledge_row.get("encounters", 0)) < 0
			or not knowledge_row.get("weaknesses", []) is Array
		):
			return false
		for weakness_id: Variant in knowledge_row.get("weaknesses", []):
			if (
				not weakness_id is String
				or not StableIds.is_valid(StableIds.WORLD_FACT, str(weakness_id))
			):
				return false
	var skill_map: Dictionary = data.get("skills", {})
	for actor_id: Variant in skill_map:
		if (
			not actor_id is String
			or not StableIds.is_valid(StableIds.ACTOR, actor_id)
			or not skill_map[actor_id] is Dictionary
		):
			return false
		for skill_id: Variant in skill_map[actor_id]:
			var skill_data: Variant = skill_map[actor_id][skill_id]
			if (
				not skill_id is String
				or not StableIds.is_valid(StableIds.SKILL, skill_id)
				or not skill_data is Dictionary
			):
				return false
			if skill_data.has("percentage"):
				if typeof(skill_data["percentage"]) not in [TYPE_INT, TYPE_FLOAT] or float(skill_data["percentage"]) < 0.0 or float(skill_data["percentage"]) > 100.0:
					return false
			if skill_data.has("tier"):
				if not skill_data["tier"] is String or skill_data["tier"] not in SKILL_TIERS:
					return false
			if skill_data.has("advancement_points_spent"):
				if typeof(skill_data["advancement_points_spent"]) != TYPE_INT or int(skill_data["advancement_points_spent"]) < 0:
					return false
	return true


func validate_save_data(data: Dictionary) -> bool:
	return _validate_save_data(data)
