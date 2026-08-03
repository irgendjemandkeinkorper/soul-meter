extends Node
## Serialized global state: durable flags, Soul, the Vex-led party, inventory,
## and local settings. Menus are views over this singleton.

signal soul_meter_changed(value: float)
signal gp_changed(value: int)
signal flag_changed(flag: String, value: Variant)
signal inventory_changed
signal party_changed
signal locale_changed(locale: String)

const SETTINGS_PATH := "user://settings.cfg"
const PROTAGONIST_ID := "vex"
const PROTAGONIST_NAME := "Vex the Unbowed"
const REQUIRED_COMPANIONS := 2
const DEFAULT_LOCALE := "en"
const SUPPORTED_LOCALES := ["en", "es"]
const DEFAULT_GP := 250

var flags: Dictionary = {}
var soul_meter: float = 50.0:
	set = set_soul_meter
var gp: int = DEFAULT_GP:
	set = set_gp
var party: Array[PartyMember] = []
var inventory: Inventory
var current_locale := DEFAULT_LOCALE

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
	soul_meter = clampf(value, 0.0, 100.0)
	soul_meter_changed.emit(soul_meter)


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


# --- Settings ---------------------------------------------------------------


func set_setting(section: String, key: String, value: Variant) -> void:
	_settings.set_value(section, key, value)
	_settings.save(SETTINGS_PATH)


func get_setting(section: String, key: String, default: Variant) -> Variant:
	return _settings.get_value(section, key, default)


func _load_settings() -> void:
	_settings.load(SETTINGS_PATH)
	apply_fullscreen(_settings.get_value("display", "fullscreen", false))
	apply_locale(str(_settings.get_value("display", "locale", DEFAULT_LOCALE)))
	for bus in ["Master", "Music", "SFX"]:
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


func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func get_bus_volume(bus: String) -> float:
	var idx := AudioServer.get_bus_index(bus)
	return 1.0 if idx < 0 else db_to_linear(AudioServer.get_bus_volume_db(idx))


func _ensure_audio_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


# --- Prototype party and inventory ------------------------------------------


func _seed_demo_data() -> void:
	gp = DEFAULT_GP
	party = [_make_vex()]
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
	}


func from_dict(data: Dictionary) -> bool:
	var inventory_data: Variant = data.get("inventory", {})
	if not inventory_data is Dictionary or not inventory.deserialize(inventory_data):
		return false
	flags = data.get("flags", {}).duplicate(true)
	soul_meter = float(data.get("soul_meter", 50.0))
	gp = maxi(0, int(data.get("gp", DEFAULT_GP)))
	party.clear()
	for row in data.get("party", []):
		if row is Dictionary:
			party.append(PartyMember.from_dict(row))
	inventory_changed.emit()
	party_changed.emit()
	return true
