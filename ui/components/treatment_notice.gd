extends PanelContainer
## Receipt for a committed cure. Quotes and refusals never produce success feedback.

signal dismissed

@onready var heading: Label = %Heading
@onready var penalties: Label = %Penalties
@onready var payment: Label = %Payment
@onready var dismiss_button: Button = %Dismiss


func _ready() -> void:
	dismiss_button.pressed.connect(func() -> void:
		clear_notice()
		dismissed.emit())
	clear_notice()


func clear_notice() -> void:
	hide()
	dismiss_button.focus_mode = Control.FOCUS_NONE


func show_result(result: Dictionary, patient_name: String) -> void:
	clear_notice()
	# Current treatment cards clear one wound. Require the commit's paid receipt,
	# not merely an allowed forecast, and do not claim a remaining wound was cured.
	if not bool(result.get("allowed", false)) or not result.has("paid"):
		return
	var before: Dictionary = result.get("before", {})
	var after: Dictionary = result.get("after", {})
	if before.is_empty() or not after.is_empty():
		return
	var locations := {"arm": tr("Arm"), "throat": tr("Throat"), "leg": tr("Leg"), "head": tr("Head")}
	var location := str(result.get("location", ""))
	heading.text = tr("%s — %s INJURY CLEARED") % [
		patient_name.to_upper(), str(locations.get(location, location.capitalize())).to_upper(),
	]
	penalties.text = _removed_penalties(before.get("effects", {}))
	var paid: Dictionary = result["paid"]
	var supply := str(paid.get("supply_item", ""))
	if int(paid.get("supply_quantity", 0)) > 0:
		payment.text = tr("Used %d × %s") % [
			int(paid["supply_quantity"]),
			ItemLocalization.text(supply, "name", supply.get_file().capitalize()),
		]
	else:
		var silver := int(paid.get("gp", 0))
		payment.text = tr("Paid %d silver") % silver if silver > 0 else tr("No silver spent")
	show()
	dismiss_button.focus_mode = Control.FOCUS_ALL
	dismiss_button.grab_focus()


func _removed_penalties(effects: Dictionary) -> String:
	var removed: PackedStringArray = []
	var labels := {
		CombatInjury.EFFECT_ATTACK_ACCURACY: tr("attack accuracy %+d percentage points"),
		CombatInjury.EFFECT_VOCAL_ACCURACY: tr("vocal accuracy %+d percentage points"),
		CombatInjury.EFFECT_SIGHT_ACCURACY: tr("ranged / aimed accuracy %+d percentage points"),
		CombatInjury.EFFECT_MOVE_COST_PERCENT: tr("movement cost %+d%%"),
	}
	for effect: String in labels:
		if int(effects.get(effect, 0)) != 0:
			removed.append(str(labels[effect]) % int(effects[effect]))
	if bool(effects.get(CombatInjury.EFFECT_VOICE_BLOCKED, false)):
		removed.append(tr("voice block"))
	return tr("Removed from this injury: %s.") % "; ".join(removed) if not removed.is_empty() else tr("No listed combat penalty remains from this injury.")
