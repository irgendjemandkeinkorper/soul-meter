extends Node
## GameState — the serialized game-state singleton the design doc (§9) calls for: the global
## flag store, the Soul Meter, the party, and the inventory. Every menu is a *view* of this.
## Autoloaded, so it survives scene changes. Save/load and richer systems build on top of it.

signal soul_meter_changed(value: float)
signal flag_changed(flag: String, value: Variant)
signal inventory_changed()
signal party_changed()

const SETTINGS_PATH := "user://settings.cfg"

## Global reactivity spine — every location reads/writes this.
var flags: Dictionary = {}
## The Soul Meter (0–100). Magic spends it; it mostly only goes down (see the vault: souls).
var soul_meter: float = 50.0: set = set_soul_meter
var party: Array[PartyMember] = []
var inventory: Inventory

var _settings := ConfigFile.new()


func _ready() -> void:
	_ensure_audio_buses()
	_load_settings()

	inventory = Inventory.new()
	inventory.protoset = load("res://data/generated/gloot_prototree.json")
	add_child(inventory)

	# Proxy GLoot signals to the unified inventory_changed signal
	inventory.item_added.connect(func(_item): inventory_changed.emit())
	inventory.item_removed.connect(func(_item): inventory_changed.emit())
	inventory.item_property_changed.connect(func(_item, _property): inventory_changed.emit())
	inventory.item_moved.connect(func(): inventory_changed.emit())

	_seed_demo_data()


# --- Soul Meter & flags -------------------------------------------------------

func set_soul_meter(value: float) -> void:
	soul_meter = clampf(value, 0.0, 100.0)
	soul_meter_changed.emit(soul_meter)


func set_flag(flag: String, value: Variant = true) -> void:
	flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: String, default: Variant = false) -> Variant:
	return flags.get(flag, default)


# --- Inventory queries & transactions ----------------------------------------

func item_count(item_id: String) -> int:
	var total := 0
	for item in inventory.get_items_with_prototype_id(item_id):
		total += item.get_stack_size()
	return total


## Removes up to `amount` items across every matching stack. Returns false and
## changes nothing when the full amount is not available.
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


# --- Settings (persisted to user://settings.cfg) ------------------------------

func set_setting(section: String, key: String, value: Variant) -> void:
	_settings.set_value(section, key, value)
	_settings.save(SETTINGS_PATH)


func get_setting(section: String, key: String, default: Variant) -> Variant:
	return _settings.get_value(section, key, default)


func _load_settings() -> void:
	_settings.load(SETTINGS_PATH)  # missing file is fine; values just fall back to defaults
	apply_fullscreen(_settings.get_value("display", "fullscreen", false))
	for bus in ["Master", "Music", "SFX"]:
		set_bus_volume(bus, _settings.get_value("audio", bus, 1.0))


func apply_fullscreen(on: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if on else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


func set_bus_volume(bus: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))


func get_bus_volume(bus: String) -> float:
	var idx := AudioServer.get_bus_index(bus)
	if idx < 0:
		return 1.0
	return db_to_linear(AudioServer.get_bus_volume_db(idx))


func _ensure_audio_buses() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, bus)
			AudioServer.set_bus_send(idx, "Master")


# --- Demo content (until real data/saves exist) -------------------------------

func _seed_demo_data() -> void:
	party.clear()
	party.append(_make_member("Vex the Unbowed", "Ash-Bound Kes'reth", "Ironbrand (Kero)", 4, 38, 44,
		"A horned reaver of Karrn-Vash; her soul is a held line, sealed against the Loam and tattooed in cinder-ink."))
	party.append(_make_member("Serai-Lun", "Mirror-Veil Kes'reth", "Mirrorblade (Maiiam)", 3, 26, 30,
		"A mirror-dancer of Vervulling who fights in paired, reflected forms and speaks in balanced halves."))
	party.append(_make_member("Old Grumbrand", "Kaan Deepkin", "Lensbearer (Stuid)", 3, 31, 34,
		"A soot-stained salvager who reads Age-of-Stars machines for a price and trusts nothing that hums."))
	party_changed.emit()

	inventory.clear()

	var axe := inventory.create_and_add_item(ItemIds.WEAPONS_TAUBSTUMMER_AXE)
	var reflection := inventory.create_and_add_item(ItemIds.RELICS_CAPTURED_REFLECTION)
	var gauge := inventory.create_and_add_item(ItemIds.TOOLS_SOUL_GAUGE)

	var bread := inventory.create_and_add_item(ItemIds.CONSUMABLES_LOAM_BREAD)
	if bread:
		bread.set_stack_size(5)

	var ink := inventory.create_and_add_item(ItemIds.MATERIALS_CINDER_INK_VIAL)
	if ink:
		ink.set_stack_size(2)

	var shard := inventory.create_and_add_item(ItemIds.RELICS_QUINE_SHARD)


func _make_member(n: String, race: String, cls: String, lvl: int, hp: int, maxhp: int, bio: String,
		min_rep: float = 0.0, min_infamy: float = 0.0) -> PartyMember:
	var m := PartyMember.new()
	m.display_name = n
	m.race = race
	m.char_class = cls
	m.level = lvl
	m.hp = hp
	m.max_hp = maxhp
	m.bio = bio
	m.min_reputation = min_rep
	m.min_infamy = min_infamy
	return m


# --- Party assembly (the tavern screen; see ui/screens/tavern.gd) ------------

## Fresh PartyMember instances every call — same convention as _seed_demo_data(),
## so picking a party twice in one session never hands out aliased Resources.
## Two per patron class (see systems/ten-patron-classes.md), varied races and
## genders — races beyond the original five are pulled from the vault's
## character-creation.md "expansion point" roster (Dragons, Dwermo, Giants,
## Khurnathi, Lunari, Naolune, Nkhalu, Orthos, Snarlin, Thysari, Velbrass,
## Zindari, Weftkin, Vaerin, Fiel), grounded in Dom flavor (Steel Day dueling
## honor, Trial Council bench culture, the Deep Salvage rings' corpse-armor
## trade as the city's one real underworld — see cities/dom.md).
func recruitable_candidates() -> Array[PartyMember]:
	var out: Array[PartyMember] = []

	# Ironbrand (Kero)
	out.append(_make_member("Vex the Unbowed", "Ash-Bound Kes'reth", "Ironbrand (Kero)", 4, 38, 44,
		"A horned reaver of Karrn-Vash; her soul is a held line, sealed against the Loam and tattooed in cinder-ink."))
	out.append(_make_member("Korrath Ninefold", "Orthos", "Ironbrand (Kero)", 4, 36, 40,
		"An Orthos brawler who's fought every Steel Day since his branding; won't fall in beside anyone the Trial Council hasn't at least heard of.",
		10.0))

	# Mirrorblade (Maiiam)
	out.append(_make_member("Serai-Lun", "Mirror-Veil Kes'reth", "Mirrorblade (Maiiam)", 3, 26, 30,
		"A mirror-dancer of Vervulling who fights in paired, reflected forms and speaks in balanced halves."))
	out.append(_make_member("Vey Ashinel", "Weftkin", "Mirrorblade (Maiiam)", 3, 26, 30,
		"A Weftkin whose Weft-sense reads a duel's outcome half a breath before it lands; fights already knowing which reflection wins."))

	# Lensbearer (Stuid)
	out.append(_make_member("Old Grumbrand", "Kaan Deepkin", "Lensbearer (Stuid)", 3, 31, 34,
		"A soot-stained salvager who reads Age-of-Stars machines for a price and trusts nothing that hums."))
	out.append(_make_member("Mirela Osk", "Naolune", "Lensbearer (Stuid)", 3, 24, 28,
		"A Naolune archivist who catalogs Dom's Age-of-Stars wreckage for the Trial Council, and reads a stranger's tells the way she reads a machine's wiring."))

	# River-Mother (Haeren)
	out.append(_make_member("Wyneth Hallow-Tide", "Ghorr", "River-Mother (Haeren)", 3, 28, 32,
		"A storm-stranded Haeren pilgrim, still in Dom three sailings later, tending Iron Company wounds for coin she calls tribute."))
	out.append(_make_member("Bram Kettlewell", "Dwermo", "River-Mother (Haeren)", 3, 30, 34,
		"A Dwermo field-medic who followed the Iron Companies home from three campaigns and never once put down the bandage roll."))

	# Locksmirk (Fickah)
	out.append(_make_member("Ressa Quickfingers", "Vael", "Locksmirk (Fickah)", 3, 24, 28,
		"Runs card games two tables from the Trial Council's own bench-holders and has never once been caught counting."))
	out.append(_make_member("Vesh Cutlow", "Zindari", "Locksmirk (Fickah)", 3, 22, 26,
		"A forger of Trial Council seals who's never met a brand she couldn't fake, or a debt she couldn't misplace."))

	# Husk-bearer (Vhorr)
	out.append(_make_member("Maura Greyfen", "Snarlin", "Husk-bearer (Vhorr)", 3, 27, 30,
		"Runs a Deep Salvage ring under the chasm rim, stripping armor off the called dead — she won't work with anyone the honest half of Dom hasn't already written off.",
		0.0, 8.0))
	out.append(_make_member("Dobrusk", "Thysari", "Husk-bearer (Vhorr)", 3, 29, 32,
		"A mortuary-rite keeper who tends what the Deep Salvage rings bring up, and insists every stripped corpse still gets a name spoken over it."))

	# Flamebinder (Vicoar)
	out.append(_make_member("Cinderjaw", "Dragon", "Flamebinder (Vicoar)", 4, 32, 36,
		"A young dragon apprenticed to Dom's forge-guild out of sheer boredom with hoarding; builds engines that breathe better than he does."))
	out.append(_make_member("Yorna Deephammer", "Giant", "Flamebinder (Vicoar)", 3, 34, 38,
		"A Giant artificer who rebuilt half the Trial Hall's furnace grates and charges the other half in favors, not coin."))

	# Stormbearer (Ofshütje)
	out.append(_make_member("Ilse Moonshear", "Lunari", "Stormbearer (Ofshütje)", 3, 24, 28,
		"A skirmisher who reads Dom's storm-fronts better than the harbor pilots, and times every raid to the lull before landfall."))
	out.append(_make_member("Kaddo Farrow", "Khurnathi", "Stormbearer (Ofshütje)", 3, 26, 30,
		"An outrunner who scouts ahead of the Iron Companies and has never once been caught by the same storm twice."))

	# Oathclock (Pazzah)
	out.append(_make_member("Sohvi Lastbell", "Vaerin", "Oathclock (Pazzah)", 3, 23, 26,
		"An oath-broker whose own Fading is nearly spent; won't stake a bargain-clock on someone whose name means nothing yet.",
		8.0))
	out.append(_make_member("Perrin Tallowdue", "Velbrass", "Oathclock (Pazzah)", 3, 25, 28,
		"A debt-clerk for the Trial Council who collects promises the way other men collect coin, and never once forgets a due date."))

	# Threadwalker (Izhakel)
	out.append(_make_member("Aeyin Farsdottir", "Fiel", "Threadwalker (Izhakel)", 3, 22, 25,
		"A relic-binder who keeps three borrowed spirits on a leash of her own hair, and swears all three behave better than she does."))
	out.append(_make_member("Duskhollow", "Nkhalu", "Threadwalker (Izhakel)", 3, 24, 27,
		"A summoner who inherited his threadbound court from a dead uncle, and still isn't sure which of them is in charge."))

	return out


## Replace the party wholesale — the tavern's "confirm" action. Anything else
## mutating GameState.party directly must emit party_changed itself; this is
## the one place that does it for you.
func set_party(members: Array[PartyMember]) -> void:
	party = members
	party_changed.emit()
