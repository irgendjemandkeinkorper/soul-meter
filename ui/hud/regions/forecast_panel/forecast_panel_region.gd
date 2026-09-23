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
@onready var aim_summary: PanelContainer = %AimSummary
@onready var aim_title: Label = %AimTitle
@onready var aim_stats: Label = %AimStats
@onready var aim_consequence: Label = %AimConsequence
@onready var aim_details: CheckButton = %AimDetails
@onready var accuracy_summary: Label = %AccuracySummary
@onready var accuracy_details: Label = %AccuracyDetails


func _ready() -> void:
	aim_details.toggled.connect(func(_pressed: bool) -> void: _update_details_visibility())
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
	aim_summary.hide()
	_context = context.duplicate(true)
	_payload_damage = -1
	_class_command_text = ""
	_recompute()


func show_action_forecast(payload: Dictionary, context: Dictionary = {}) -> void:
	aim_summary.hide()
	_clear_accuracy()
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
	_show_accuracy((payload.get("resolution", {}) as Dictionary).get("accuracy_breakdown", {}))
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
		_update_details_visibility()
		return
	var locations: Array[StringName] = [ORDINARY_AIM]
	for key: Variant in action.aim_profiles.keys():
		locations.append(StringName(str(key)))
	for location: StringName in locations:
		var button := Button.new()
		button.name = "Aim%s" % ("Ordinary" if location == ORDINARY_AIM else str(location).capitalize())
		button.text = tr("ORDINARY") if location == ORDINARY_AIM else _aim_label(target, location)
		button.set_meta("aim_label", button.text)
		button.theme_type_variation = "BronzeButton" if location == selected else "Button"
		var quote: Dictionary = quotes.get(location, {})
		if location != ORDINARY_AIM and not bool(quote.get("allowed", false)):
			button.disabled = true
			button.tooltip_text = str(quote.get("message", tr("Aim unavailable.")))
		button.set_meta("aim_location", str(location))
		button.pressed.connect(func() -> void: aim_selected.emit(location))
		aim_row.add_child(button)
	aim_row.visible = true
	mark_aim_selected(selected)
	_update_details_visibility()


## Keep focus on the existing button when keyboard/controller users change aim.
func mark_aim_selected(selected: StringName) -> void:
	for child: Node in aim_row.get_children():
		var button := child as Button
		var is_selected := str(button.get_meta("aim_location", "")) == str(selected)
		button.theme_type_variation = "BronzeButton" if is_selected else "Button"
		var label := str(button.get_meta("aim_label", ""))
		button.text = "[%s]" % label if is_selected else label


## Render only public conditional quotes, never the committed hit or injury roll.
func show_aim_forecast(payload: Dictionary, selected: StringName, use_ct: bool) -> void:
	_clear_accuracy()
	if bool(payload.get("allowed", false)):
		_show_accuracy((payload.get("resolution", {}) as Dictionary).get("accuracy_breakdown", {}))
	aim_summary.visible = aim_row.visible
	if not aim_summary.visible:
		return
	var button := aim_button(selected)
	var label := str(button.get_meta("aim_label", selected)) if button != null else str(selected).to_upper()
	aim_title.text = tr("ORDINARY ATTACK") if selected.is_empty() else tr("AIM %s") % label
	aim_consequence.theme_type_variation = "StatLabel"
	if not bool(payload.get("allowed", false)):
		aim_stats.text = tr("UNAVAILABLE")
		aim_consequence.text = str(payload.get("message", tr("Aim unavailable.")))
		return
	var resolution: Dictionary = payload.get("resolution", {})
	var accuracy: Dictionary = resolution.get("accuracy_breakdown", {})
	var hit := int(accuracy.get("effective_hit_chance", resolution.get("hit_chance", 100)))
	var damage := str(payload.get("damage_on_hit", 0))
	var landed := Resolution.preview_on_hit(_context)
	if not (landed.get("hidden_draw", {}) as Dictionary).is_empty() and not bool(resolution.get("reveal", false)):
		damage = "?"
	aim_stats.text = tr("HIT %d%% · COST %d %s\nDAMAGE %s ON HIT") % [
		hit, int(payload.get("ct_cost" if use_ct else "ap_cost", 0)), "CT" if use_ct else "AP", damage,
	]
	var injury: Dictionary = payload.get("injury_forecast", {})
	if injury.is_empty():
		aim_consequence.text = tr("NO INJURY EFFECT")
	elif not bool(injury.get("eligible", false)):
		aim_consequence.text = tr("INJURY NEEDS %d DAMAGE") % int(injury.get("min_damage", 1))
	else:
		var serious := str(injury.get("severity", "minor")) == CombatInjury.PERSISTENT_SEVERITY
		aim_consequence.theme_type_variation = "AimWarningLabel" if serious else "StatLabel"
		aim_consequence.text = tr("POSSIBLE SERIOUS INJURY") if serious else tr("POSSIBLE MINOR INJURY")
		aim_consequence.text += "\n" + tr("INJURY %d%% ON HIT · %d%% OVERALL") % [
			int(injury.get("chance_on_hit", 0)), int(injury.get("overall_chance", 0)),
		]
		if serious:
			aim_consequence.text += "\n" + tr("Persists after combat until treated.")
		elif int(injury.get("serious_min_damage", 0)) > 0:
			aim_consequence.text += "\n" + tr("SERIOUS AT %d DAMAGE") % int(injury["serious_min_damage"])


func _update_details_visibility() -> void:
	var has_accuracy := not accuracy_details.text.is_empty()
	aim_details.visible = aim_row.visible or has_accuracy
	accuracy_summary.visible = has_accuracy and not aim_details.button_pressed
	accuracy_details.visible = has_accuracy and aim_details.button_pressed
	var show_details := not aim_row.visible or aim_details.button_pressed
	for control: Control in [target_header, wheel, affinity, forecast]:
		control.visible = show_details


func clear_aim_options() -> void:
	for child: Node in aim_row.get_children():
		aim_row.remove_child(child)
		child.queue_free()
	aim_row.visible = false
	aim_summary.hide()
	_clear_accuracy()
	_update_details_visibility()


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
	_clear_accuracy()
	forecast.text = message
	if aim_summary.visible:
		aim_stats.text = tr("UNAVAILABLE")
		aim_consequence.theme_type_variation = "StatLabel"
		aim_consequence.text = message
	var pulse := create_tween()
	forecast.modulate = Color("#E06C5A")
	pulse.tween_property(forecast, "modulate", Color.WHITE, 0.22)


func select_element(element_id: StringName) -> void:
	if not ElementWheel.ORDER.has(element_id):
		return
	_selected = element_id
	aim_summary.hide()
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
	_clear_accuracy()
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
	_show_accuracy(accuracy)


## Present the resolver's public arithmetic; never infer extra penalties or expose rolls.
func _show_accuracy(accuracy: Dictionary) -> void:
	if accuracy.is_empty():
		_clear_accuracy()
		return
	var effects: Array[Dictionary] = []
	var terms: PackedStringArray = [tr("Base %d%%") % int(accuracy.get("base", 100))]
	for modifier: Dictionary in accuracy.get("modifiers", []):
		var points := int(modifier.get("percentage_points", 0))
		if points != 0:
			terms.append(tr("%s %+d pp") % [tr(str(modifier.get("label", ""))), points])
			effects.append(modifier)
	# Penalties first (largest loss first), then bonuses (largest gain first).
	# Sorting a new array leaves the controller's explanation and replay data untouched.
	effects.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var left := int(a["percentage_points"])
		var right := int(b["percentage_points"])
		return left < right if left < 0 or right < 0 else left > right
	)
	var highlights: PackedStringArray = []
	for index: int in mini(effects.size(), 2):
		var effect: Dictionary = effects[index]
		highlights.append(tr("%s %+d pp") % [tr(str(effect["label"])), int(effect["percentage_points"])])
	if effects.size() > 2:
		highlights.append(tr("%d more in details") % (effects.size() - 2))
	var guaranteed := bool(accuracy.get("guaranteed", false))
	if guaranteed:
		accuracy_summary.text = tr("Guaranteed hit")
	elif highlights.is_empty():
		accuracy_summary.text = tr("No accuracy modifiers")
	else:
		accuracy_summary.text = tr("Accuracy: %s") % " · ".join(highlights)
	var adjustment := int(accuracy.get("clamp_adjustment", 0))
	if adjustment != 0:
		terms.append(tr("Chance limits (%d–%d%%) %+d pp") % [
			int(accuracy.get("minimum", 0)), int(accuracy.get("maximum", 100)), adjustment,
		])
		if not guaranteed:
			accuracy_summary.text += "\n" + tr("Chance limited to %d%%") % int(accuracy["hit_chance"])
	if guaranteed:
		terms.append(tr("Guaranteed hit overrides accuracy modifiers"))
	terms.append(tr("Final hit chance %d%%") % int(accuracy.get("effective_hit_chance", 100)))
	accuracy_details.text = tr("HIT CHANCE (pp = percentage points)") + "\n" + " · ".join(terms)
	_update_details_visibility()


func _clear_accuracy() -> void:
	accuracy_summary.text = ""
	accuracy_details.text = ""
	accuracy_summary.hide()
	accuracy_details.hide()
	_update_details_visibility()
