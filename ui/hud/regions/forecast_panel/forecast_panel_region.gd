class_name ForecastPanelRegion
extends PanelContainer

signal element_selected(element_id: StringName)
## Player picked an anatomical aim (empty = ordinary aim) from the aim row.
signal aim_selected(location: StringName)
const ORDINARY_AIM := &""
var _context: Dictionary = {}
var _selected: StringName = ElementWheel.ORDER[0]
## Landed damage quoted by the controller (-1 = none), including mitigation.
## The raw deterministic outcome remains available for replay/parity checks;
## presentation uses its conditional quote so it cannot announce a future miss.
var _payload_damage := -1
var _class_command_text := ""
@onready var wheel: Container = %ActWheel
@onready var aim_row: Container = %AimRow
@onready var target_header: Label = %TargetHeader
@onready var affinity: Label = %AffinityStrip
@onready var forecast: Label = %Forecast


func _ready() -> void:
	for element_id: StringName in ElementWheel.ORDER:
		var button := Button.new()
		button.text = String(element_id).to_upper()
		button.theme_type_variation = "BronzeButton" if element_id == _selected else "Button"
		button.pressed.connect(select_element.bind(element_id))
		wheel.add_child(button)


func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", event.data)
	var forecast_context: Variant = event.data.get("forecast_context", snapshot.get("forecast_context", {}))
	if forecast_context is Dictionary and not (forecast_context as Dictionary).is_empty():
		set_forecast_context(forecast_context)


func set_forecast_context(context: Dictionary) -> void:
	_context = context.duplicate(true)
	_payload_damage = -1
	_class_command_text = ""
	_recompute()


func show_action_forecast(payload: Dictionary, context: Dictionary = {}) -> void:
	if not bool(payload.get("allowed", false)):
		forecast.text = str(payload.get("message", "FORECAST UNAVAILABLE"))
		return
	if not context.is_empty():
		set_forecast_context(context)
	if bool(payload.get("class_command", false)):
		_class_command_text = str(payload.get("description", "Class command"))
		_recompute()
		return
	_class_command_text = ""
	if payload.has("damage"):
		_payload_damage = int(payload.get("damage_on_hit", payload.get("damage", -1)))
		_recompute()
	var positioning: Dictionary = context.get("positioning", {})
	var terms: PackedStringArray = []
	var cover := int(positioning.get("cover_bonus", 0))
	var flank := int(positioning.get("flank_bonus", 0))
	if cover != 0:
		terms.append("COVER %+d" % cover)
	if flank != 0:
		terms.append("FLANK %+d" % flank)
	if not terms.is_empty():
		forecast.text += "\n" + " · ".join(terms)


## Rebuilds the aim row from controller quotes: one button per authored location on the
## armed action plus the ordinary aim. `quotes` maps location -> forecast/refusal payload;
## a refused location stays visible but disabled, with the controller's reason as tooltip.
## Buttons are ordinary focusable controls, so keyboard/controller navigation reaches them.
func show_aim_options(
	action: CombatAction, target: BattleActor, quotes: Dictionary, selected: StringName
) -> void:
	for child: Node in aim_row.get_children():
		aim_row.remove_child(child)
		child.queue_free()
	if action == null or action.aim_profiles.is_empty():
		aim_row.visible = false
		return
	var locations: Array[StringName] = [ORDINARY_AIM]
	for key: Variant in action.aim_profiles.keys():
		locations.append(StringName(str(key)))
	for location: StringName in locations:
		var button := Button.new()
		button.name = "Aim%s" % ("Ordinary" if location == ORDINARY_AIM else str(location).capitalize())
		button.text = tr("ORDINARY") if location == ORDINARY_AIM else _aim_label(target, location)
		button.theme_type_variation = "BronzeButton" if location == selected else "Button"
		var quote: Dictionary = quotes.get(location, {})
		if location != ORDINARY_AIM and not bool(quote.get("allowed", false)):
			button.disabled = true
			button.tooltip_text = str(quote.get("message", tr("Aim unavailable.")))
		button.set_meta("aim_location", str(location))
		button.pressed.connect(func() -> void: aim_selected.emit(location))
		aim_row.add_child(button)
	aim_row.visible = true


func clear_aim_options() -> void:
	for child: Node in aim_row.get_children():
		aim_row.remove_child(child)
		child.queue_free()
	aim_row.visible = false


func aim_button(location: StringName) -> Button:
	for child: Node in aim_row.get_children():
		if child is Button and child.has_meta("aim_location") and str(child.get_meta("aim_location")) == str(location):
			return child as Button
	return null


static func _aim_label(target: BattleActor, location: StringName) -> String:
	if target != null and target.anatomy.get(location) is Dictionary:
		return str((target.anatomy[location] as Dictionary).get("display_name", location)).to_upper()
	return str(location).capitalize().to_upper()


func pulse_refusal(message: String) -> void:
	forecast.text = message
	var pulse := create_tween()
	forecast.modulate = Color("#E06C5A")
	pulse.tween_property(forecast, "modulate", Color.WHITE, 0.22)


func select_element(element_id: StringName) -> void:
	if not ElementWheel.ORDER.has(element_id):
		return
	_selected = element_id
	# Wheel exploration is hypothetical (a different element than the quoted
	# action) — drop the controller quote and let Resolution speak alone.
	_payload_damage = -1
	var ability: Dictionary = _context.get("ability", {}).duplicate(true)
	ability["element_id"] = String(_selected)
	ability["elements"] = [_selected]
	_context["ability"] = ability
	for child: Node in wheel.get_children():
		if child is Button:
			(child as Button).theme_type_variation = "BronzeButton" if (child as Button).text == String(_selected).to_upper() else "Button"
	_recompute()
	element_selected.emit(_selected)


func forecast_result() -> Dictionary:
	return Resolution.resolve(_context)


func _recompute() -> void:
	var target: Dictionary = _context.get("target", {})
	target_header.text = "ATTUNED — %s · H%d" % [str(target.get("element_id", "—")).to_upper(), int(target.get("height", 0))]
	var values: Dictionary = target.get("attunements", {})
	var parts: PackedStringArray = []
	for element_id: StringName in ElementWheel.ORDER:
		parts.append("%s %+d" % [String(element_id).to_upper(), int(values.get(element_id, values.get(String(element_id), 0)))])
	affinity.text = "  ".join(parts)
	if not _class_command_text.is_empty():
		forecast.text = _class_command_text
		return
	var result := forecast_result()
	if not bool(result.get("allowed", false)):
		forecast.text = str(result.get("message", "FORECAST UNAVAILABLE"))
		return
	var chain: PackedStringArray = []
	var landed := Resolution.preview_on_hit(_context)
	var revealed := bool(result.get("reveal", false))
	for step: Dictionary in landed.get("breakdown", []):
		# Committed rolls belong in the combat log, never in the aiming preview.
		if str(step.get("id", "")) == "to_hit":
			continue
		if str(step.get("id", "")) == "hidden_draw" and not revealed:
			continue
		chain.append("%s %s" % [str(step.get("label", "")), str(step.get("value", 0))])
	var shown := _payload_damage if _payload_damage >= 0 else int(landed.get("damage", 0))
	var ability: Dictionary = _context.get("ability", {})
	var accuracy: Dictionary = result.get("accuracy_breakdown", {})
	var chance := "HIT %d%%" % int(accuracy.get("effective_hit_chance", result.get("hit_chance", 100)))
	if bool(ability.get("is_spell", false)):
		chance += " · FIZZLE %.0f%%" % float(result.get("fizzle_percent", 0.0))
	# Hidden draws remain masked even when the upcoming committed action will miss.
	var hidden: Dictionary = landed.get("hidden_draw", {})
	var shown_text := str(shown)
	if not hidden.is_empty() and not revealed:
		shown_text = "?"
	if revealed:
		chance += " · TRUE"
	forecast.text = "%s\nFORECAST %s ON HIT · %s" % [" × ".join(chain), shown_text, chance]
	if bool(accuracy.get("enabled", false)):
		var terms: PackedStringArray = ["Base %d%%" % int(accuracy["base"])]
		for modifier: Dictionary in accuracy.get("modifiers", []):
			terms.append("%s %+d pp" % [str(modifier["label"]), int(modifier["percentage_points"])])
		if int(accuracy.get("clamp_adjustment", 0)) != 0:
			terms.append("Clamp %+d pp" % int(accuracy["clamp_adjustment"]))
		if bool(accuracy.get("guaranteed", false)):
			terms.append("Guaranteed hit")
		forecast.text += "\n" + " · ".join(terms)
