class_name ForecastPanelRegion
extends PanelContainer

signal element_selected(element_id: StringName)
var _context: Dictionary = {}
var _selected: StringName = ElementWheel.ORDER[0]
## Damage the controller quoted for the hovered action (-1 = none). The wheel's
## Resolution breakdown excludes the positional terms (cover/flank) that ride
## outside the Resolution context, so the NUMBER shown for a live action must be
## the controller's — the same calculate_damage path a commit will take. This is
## display of a controller value, not UI arithmetic.
var _payload_damage := -1
@onready var wheel: Container = %ActWheel
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
	_recompute()


func show_action_forecast(payload: Dictionary, context: Dictionary = {}) -> void:
	if not bool(payload.get("allowed", false)):
		forecast.text = str(payload.get("message", "FORECAST UNAVAILABLE"))
		return
	if not context.is_empty():
		set_forecast_context(context)
	if payload.has("damage"):
		_payload_damage = int(payload.get("damage", -1))
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
	var result := forecast_result()
	if not bool(result.get("allowed", false)):
		forecast.text = str(result.get("message", "FORECAST UNAVAILABLE"))
		return
	var chain: PackedStringArray = []
	for step: Dictionary in result.get("breakdown", []):
		chain.append("%s %s" % [str(step.get("label", "")), str(step.get("value", 0))])
	var shown := _payload_damage if _payload_damage >= 0 else int(result.get("damage", 0))
	forecast.text = "%s\nFORECAST %d · HIT 90%%" % [" × ".join(chain), shown]
