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


func _make_member(n: String, race: String, cls: String, lvl: int, hp: int, maxhp: int, bio: String) -> PartyMember:
	var m := PartyMember.new()
	m.display_name = n
	m.race = race
	m.char_class = cls
	m.level = lvl
	m.hp = hp
	m.max_hp = maxhp
	m.bio = bio
	return m
