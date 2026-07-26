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
var inventory: Array[ItemStack] = []

var _settings := ConfigFile.new()


func _ready() -> void:
	_ensure_audio_buses()
	_load_settings()
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


# --- Inventory ----------------------------------------------------------------

func add_item(item: Item, count: int = 1) -> void:
	if item.stackable:
		for stack in inventory:
			if stack.item == item:
				stack.count += count
				inventory_changed.emit()
				return
	var new_stack := ItemStack.new()
	new_stack.item = item
	new_stack.count = count
	inventory.append(new_stack)
	inventory_changed.emit()


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

	add_item(_make_item("taubstummer_axe", "Taubstummer Axe", "weapon", false,
		"A sealed soul-weapon of the Last Great War; its edge remembers what it unmade."))
	add_item(_make_item("captured_reflection", "Captured Reflection", "relic", false,
		"An obsidian shard that shows a room lit by a sky that does not exist."))
	add_item(_make_item("soul_gauge", "Soul Gauge", "tool", false,
		"A brass-and-glass dial that reads a soul's integrity — and what magic has spent."))
	add_item(_make_item("loam_bread", "Loam Bread", "consumable", true,
		"Dense composting-city fare from Loamgate. Restores a little vigor."), 5)
	add_item(_make_item("cinder_ink", "Cinder-Ink Vial", "material", true,
		"Ash-Bound tattoo ink; names written in it resist the Waning's slow erasure."), 2)
	add_item(_make_item("quine_shard", "QUINE Shard", "relic", false,
		"A fragment of pre-Bloom machine, one cyan light still faintly alive."))


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


func _make_item(item_id: String, n: String, cat: String, stackable: bool, desc: String) -> Item:
	var i := Item.new()
	i.id = item_id
	i.display_name = n
	i.category = cat
	i.stackable = stackable
	i.description = desc
	return i
