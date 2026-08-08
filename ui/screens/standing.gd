extends Screen
## Standing Screen: the full faction-band view and the in-fiction read-back of
## Reputation.why() and Renown.why(). Journal links here for the complete ledger.

var _name_lbl: Label
var _band_lbl: Label
var _history_vbox: VBoxContainer
var _factions: Array[String] = []


func _build() -> void:
	var vbox := _make_shell_window("Standing")

	var global_row := HBoxContainer.new()
	global_row.theme_type_variation = "MirrorPairRow"
	global_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(global_row)

	var renown_vbox := VBoxContainer.new()
	renown_vbox.theme_type_variation = "LedgerColumn"
	renown_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	renown_vbox.size_flags_stretch_ratio = 1.0
	global_row.add_child(renown_vbox)
	_add_renown_readback(renown_vbox, &"reputation", 2)

	var infamy_vbox := VBoxContainer.new()
	infamy_vbox.theme_type_variation = "LedgerColumn"
	infamy_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	infamy_vbox.size_flags_stretch_ratio = 1.0
	global_row.add_child(infamy_vbox)
	_add_renown_readback(infamy_vbox, &"infamy", 2)

	vbox.add_child(HSeparator.new())

	var row := HBoxContainer.new()
	row.theme_type_variation = "MirrorPairRow"
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_child(row)

	var list := ItemList.new()
	list.name = "FactionList"
	list.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.size_flags_stretch_ratio = 1.0
	row.add_child(list)

	var sheet := VBoxContainer.new()
	sheet.theme_type_variation = "LedgerColumn"
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.size_flags_stretch_ratio = 1.0
	row.add_child(sheet)

	_name_lbl = Label.new()
	_name_lbl.theme_type_variation = "HeadingLabel"
	sheet.add_child(_name_lbl)

	_band_lbl = Label.new()
	sheet.add_child(_band_lbl)

	sheet.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(scroll)

	_history_vbox = VBoxContainer.new()
	_history_vbox.name = "FactionHistory"
	_history_vbox.theme_type_variation = "LedgerHistory"
	_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_history_vbox)

	var standings: Dictionary = Reputation.all_standings()
	_factions = []
	for faction_value: Variant in standings.keys():
		_factions.append(str(faction_value))
	_factions.sort()

	for faction: String in _factions:
		var display_name := format_faction_name(faction)
		var band_str: String = String(Reputation.band(faction)).capitalize()
		list.add_item("%s (%s)" % [display_name, band_str])

	list.item_selected.connect(_on_selected)
	if not _factions.is_empty():
		list.select(0)
		_on_selected(0)
	else:
		_name_lbl.text = "No faction has entered your name"
		_band_lbl.text = "Standing: Unrecorded"
		_band_lbl.theme_type_variation = "MutedLabel"
		_add_empty_label(_history_vbox, "No faction causes have been recorded yet.")

	_add_back_button(vbox)


func _on_selected(idx: int) -> void:
	if idx < 0 or idx >= _factions.size():
		return
	var faction := _factions[idx]
	_name_lbl.text = "%s remembers" % format_faction_name(faction)

	var band: StringName = Reputation.band(faction)
	_band_lbl.text = "Standing: %s (%s)" % [
		String(band).capitalize(), str(Reputation.standing(faction))
	]
	_band_lbl.theme_type_variation = band_theme_type(band)

	for child: Node in _history_vbox.get_children():
		child.queue_free()
	add_faction_readback(_history_vbox, faction)


static func add_faction_readback(
	container: VBoxContainer, faction: String, limit: int = 5
) -> void:
	var events: Array[ReputationEvent] = Reputation.why(faction, limit)
	if events.is_empty():
		_add_empty_label(container, "No faction causes have been recorded yet.")
		return
	for event: ReputationEvent in events:
		var event_lbl := Label.new()
		event_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_lbl.text = format_event(event)
		event_lbl.theme_type_variation = delta_theme_type(event.delta)
		container.add_child(event_lbl)


func _add_renown_readback(
	container: VBoxContainer, kind: StringName, limit: int
) -> void:
	var is_infamy := kind == &"infamy"
	var total := Renown.infamy() if is_infamy else Renown.reputation()
	var title := Label.new()
	title.text = "Global %s: %s" % ["Infamy" if is_infamy else "Renown", str(total)]
	title.theme_type_variation = "InfamyHeadingLabel" if is_infamy else "RenownHeadingLabel"
	container.add_child(title)

	var events: Array[RenownEvent] = Renown.why(kind, limit)
	if events.is_empty():
		_add_empty_label(
			container,
			"No Infamy has followed you yet." if is_infamy else "No Renown has followed you yet."
		)
		return
	for event: RenownEvent in events:
		var event_lbl := Label.new()
		event_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_lbl.text = format_renown_event(event)
		event_lbl.theme_type_variation = delta_theme_type(event.delta)
		container.add_child(event_lbl)


static func _add_empty_label(container: Container, text: String) -> void:
	var empty_lbl := Label.new()
	empty_lbl.text = text
	empty_lbl.theme_type_variation = "MutedLabel"
	empty_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	container.add_child(empty_lbl)


static func format_event(event: ReputationEvent) -> String:
	return "%s remembers: %s. Standing %s. Entered at %s." % [
		format_faction_name(event.faction),
		_trim_terminal_punctuation(event.cause),
		format_delta(event.delta),
		format_scene(event.scene),
	]


static func format_renown_event(event: RenownEvent) -> String:
	var kind_name := "Infamy" if event.kind == &"infamy" else "Renown"
	var lead := "Your name darkened because" if event.kind == &"infamy" else "Your name carried farther because"
	return "%s %s. %s %s. Entered at %s." % [
		lead,
		_trim_terminal_punctuation(event.cause),
		kind_name,
		format_delta(event.delta),
		format_scene(event.scene),
	]


static func format_delta(delta: float) -> String:
	return ("+" if delta > 0.0 else "") + str(delta)


static func format_faction_name(faction: String) -> String:
	return faction.replace("-", " ").replace("_", " ").capitalize()


static func format_scene(scene: String) -> String:
	var place := scene.strip_edges()
	if place.begins_with("res://"):
		place = place.get_file().get_basename()
	place = place.replace("-", " ").replace("_", " ").strip_edges()
	return "an unentered place" if place.is_empty() else place.capitalize()


static func delta_theme_type(delta: float) -> StringName:
	if delta > 0.0:
		return &"PositiveLabel"
	if delta < 0.0:
		return &"NegativeLabel"
	return &"MutedLabel"


static func band_theme_type(band: StringName) -> StringName:
	match band:
		&"hostile":
			return &"StandingHostileLabel"
		&"cold":
			return &"StandingColdLabel"
		&"warm":
			return &"StandingWarmLabel"
		&"allied":
			return &"StandingAlliedLabel"
		_:
			return &"StandingNeutralLabel"


static func _trim_terminal_punctuation(text: String) -> String:
	var trimmed := text.strip_edges()
	while trimmed.ends_with(".") or trimmed.ends_with("!") or trimmed.ends_with("?"):
		trimmed = trimmed.substr(0, trimmed.length() - 1).strip_edges()
	return trimmed
