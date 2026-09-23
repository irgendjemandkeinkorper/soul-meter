extends PanelContainer
## Battle-local feedback from committed injury records; forecasts never enter this view.

@onready var heading: Label = %Heading
@onready var severity: Label = %Severity
@onready var details: Label = %Details
@onready var details_toggle: CheckButton = %DetailsToggle
@onready var dismiss_button: Button = %Dismiss

var _pending: Array[Dictionary] = []
var _seen: Dictionary = {}


func _ready() -> void:
	details_toggle.toggled.connect(func(expanded: bool) -> void: details.visible = expanded)
	dismiss_button.pressed.connect(_advance)
	hide()


func clear_notices() -> void:
	_pending.clear()
	_seen.clear()
	details_toggle.set_pressed_no_signal(false)
	details.hide()
	hide()


func pending_count() -> int:
	return _pending.size()


## A separate instance acts as a live-record inspector, never enters the impact queue.
func inspect_injury(unit: Dictionary, location: String) -> void:
	var injuries: Dictionary = unit.get("injuries", {})
	if not injuries.has(location):
		hide()
		return
	var anatomy: Dictionary = unit.get("anatomy", {})
	var part: Dictionary = anatomy.get(location, {})
	_pending.clear()
	_show_notice({
		"target": str(unit.get("name", unit.get("display_name", tr("Unknown combatant")))),
		"location": str(part.get("display_name", location.capitalize())),
		"record": (injuries[location] as Dictionary).duplicate(true), "refreshed": false,
	})
	details_toggle.hide()
	details.show()
	dismiss_button.text = tr("Close")


func consume_event(event: CombatEvent) -> void:
	if event.type == &"battle_started":
		clear_notices()
		return
	if event.type != &"injury_applied" or not bool(event.data.get("applied", false)):
		return
	var record: Dictionary = event.data.get("record", {})
	if record.is_empty():
		return
	var key := "%s|%s|%d" % [
		String(event.target_id), str(record.get("instance_id", record.get("source_key", event.sequence))),
		int(record.get("applications", 1)),
	]
	if _seen.has(key):
		return
	_seen[key] = true
	var target := _target_snapshot(event)
	var location := str(record.get("location_id", ""))
	var anatomy: Dictionary = target.get("anatomy", {})
	var part: Dictionary = anatomy.get(location, {})
	var notice := {
		"target": str(target.get("display_name", tr("Unknown combatant"))),
		"location": str(part.get("display_name", location.capitalize())),
		"record": record.duplicate(true),
		"refreshed": bool(event.data.get("refreshed", false)),
	}
	if visible:
		_pending.append(notice)
		_update_dismiss_label()
	else:
		_show_notice(notice)


func _target_snapshot(event: CombatEvent) -> Dictionary:
	var snapshot: Dictionary = event.data.get("snapshot", {})
	for group: String in ["allies", "enemies"]:
		for actor: Dictionary in snapshot.get(group, []):
			if str(actor.get("id", "")) == String(event.target_id):
				return actor
	return {}


func _show_notice(notice: Dictionary) -> void:
	var record: Dictionary = notice["record"]
	var serious := str(record.get("severity", "minor")) == CombatInjury.PERSISTENT_SEVERITY
	heading.text = tr("%s — %s") % [str(notice["target"]).to_upper(), str(notice["location"]).to_upper()]
	severity.text = tr("SERIOUS INJURY") if serious else tr("MINOR INJURY")
	severity.theme_type_variation = "AimWarningLabel" if serious else "StatLabel"
	if bool(notice["refreshed"]):
		severity.text += " · " + tr("REFRESHED")
	details.text = _effect_text(record.get("effects", {}))
	details.text += "\n" + (tr("Persists after combat until treated.") if serious else tr("Clears when combat ends."))
	if bool(notice["refreshed"]):
		details.text += "\n" + tr("Existing injury refreshed; penalties do not stack.")
	details_toggle.set_pressed_no_signal(false)
	details.hide()
	_update_dismiss_label()
	show()


func _effect_text(effects: Dictionary) -> String:
	var lines: PackedStringArray = []
	var labels := {
		CombatInjury.EFFECT_ATTACK_ACCURACY: tr("Attack accuracy: %+d percentage points"),
		CombatInjury.EFFECT_VOCAL_ACCURACY: tr("Vocal accuracy: %+d percentage points"),
		CombatInjury.EFFECT_SIGHT_ACCURACY: tr("Ranged / aimed accuracy: %+d percentage points"),
		CombatInjury.EFFECT_MOVE_COST_PERCENT: tr("Movement cost: %+d%%"),
	}
	for effect: String in labels:
		if int(effects.get(effect, 0)) != 0:
			lines.append(str(labels[effect]) % int(effects[effect]))
	if bool(effects.get(CombatInjury.EFFECT_VOICE_BLOCKED, false)):
		lines.append(tr("Actions requiring a voice are blocked."))
	if lines.is_empty():
		lines.append(tr("No listed combat penalty."))
	return "\n".join(lines)


func _update_dismiss_label() -> void:
	dismiss_button.text = tr("Dismiss") if _pending.is_empty() else tr("Next (%d)") % _pending.size()


func _advance() -> void:
	if _pending.is_empty():
		hide()
	else:
		_show_notice(_pending.pop_front())
