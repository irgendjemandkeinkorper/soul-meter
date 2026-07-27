extends Screen
## Standing Screen: A view of Reputation.all_standings() and Reputation.why(faction)

var _name_lbl: Label
var _band_lbl: Label
var _history_lbl: Label
var _history_vbox: VBoxContainer
var _factions: Array[String] = []

func _build() -> void:
	var vbox := _make_window("Standing", Vector2(720, 480))

	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", 16)
	vbox.add_child(row)

	var list := ItemList.new()
	list.custom_minimum_size = Vector2(260, 0)
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_child(list)

	var sheet := VBoxContainer.new()
	sheet.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sheet.add_theme_constant_override("separation", 8)
	row.add_child(sheet)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 24)
	sheet.add_child(_name_lbl)

	_band_lbl = Label.new()
	sheet.add_child(_band_lbl)

	sheet.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sheet.add_child(scroll)

	_history_vbox = VBoxContainer.new()
	_history_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_history_vbox.add_theme_constant_override("separation", 12)
	scroll.add_child(_history_vbox)

	var standings: Dictionary = Reputation.all_standings()
	_factions = []
	for f in standings.keys():
		_factions.append(f)
	_factions.sort()

	for faction in _factions:
		var display_name := faction.capitalize().replace("-", " ")
		var band_str: String = Reputation.band(faction)
		list.add_item("%s (%s)" % [display_name, band_str.capitalize()])

	list.item_selected.connect(_on_selected)
	if _factions.size() > 0:
		list.select(0)
		_on_selected(0)
	else:
		_name_lbl.text = "(No reputation changes yet)"

	_add_back_button(vbox)

func _on_selected(idx: int) -> void:
	var faction: String = _factions[idx]
	var display_name := faction.capitalize().replace("-", " ")
	_name_lbl.text = display_name

	var band: StringName = Reputation.band(faction)
	var band_str := String(band).capitalize()
	_band_lbl.text = "Standing: %s" % band_str

	# Apply color based on the design system band tokens
	if band == &"hostile":
		_band_lbl.modulate = DS.CINDER_3
	elif band == &"cold":
		_band_lbl.modulate = DS.ASH
	elif band == &"allied":
		_band_lbl.modulate = DS.GILD_2
	elif band == &"warm":
		_band_lbl.modulate = DS.STATE_CONSTANT
	else:
		_band_lbl.modulate = DS.PARCHMENT

	for child in _history_vbox.get_children():
		child.queue_free()

	var events: Array[ReputationEvent] = Reputation.why(faction)
	for event in events:
		var event_lbl := Label.new()
		event_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		event_lbl.text = format_event(event)

		# Color coding the delta
		if event.delta > 0:
			event_lbl.modulate = DS.STATE_CONSTANT
		elif event.delta < 0:
			event_lbl.modulate = DS.CINDER_3
		else:
			event_lbl.modulate = DS.ASH

		_history_vbox.add_child(event_lbl)

static func format_event(e: ReputationEvent) -> String:
	var sign_str := "+" if e.delta > 0 else ""
	return "%s%s: %s" % [sign_str, str(e.delta), e.cause]
