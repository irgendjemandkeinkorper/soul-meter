class_name BattleHUD
extends PanelContainer
## FR-603 presentation model. Every rendered value is reconstructed from
## CombatEvent payloads; this component has no resolver or battle-state reads.

@onready var _initiative_label: Label = $Margin/Columns/PrimaryRow/InitiativeColumn/Initiative
@onready var _balance_label: Label = $Margin/Columns/PrimaryRow/BalanceColumn/BalanceValue
@onready var _balance_arcs: BalanceArcs = $Margin/Columns/PrimaryRow/BalanceColumn/BalanceArcs
@onready var _ap_pips: EclipsePips = $Margin/Columns/PrimaryRow/APColumn/APPips
@onready var _ap_label: Label = $Margin/Columns/PrimaryRow/APColumn/APValue
@onready var _zones_label: Label = $Margin/Columns/SecondaryRow/ZonesColumn/Zones
@onready var _check_toggle: Button = $Margin/Columns/SecondaryRow/CheckColumn/CheckMathToggle
@onready var _check_label: Label = $Margin/Columns/SecondaryRow/CheckColumn/CheckMath
@onready var _weaknesses_label: Label = $Margin/Columns/SecondaryRow/WeaknessesColumn/Weaknesses

var _snapshot: Dictionary = {}
var _initiative: Array = []
var _weaknesses: Array[Dictionary] = []
var _last_check_math: Dictionary = {}
var _check_math_enabled := true


func _ready() -> void:
	_check_toggle.toggled.connect(set_check_math_enabled)
	_check_toggle.set_pressed_no_signal(true)
	_render()


func consume_event(event: CombatEvent) -> void:
	if event == null:
		return
	if event.type == &"battle_started":
		_initiative.clear()
		_weaknesses.clear()
		_last_check_math.clear()
	var snapshot_value: Variant = event.data.get("snapshot", {})
	if snapshot_value is Dictionary:
		_snapshot = snapshot_value.duplicate(true)
	if event.data.get("initiative") is Array:
		_initiative = event.data.get("initiative", []).duplicate(true)
	_consume_weaknesses(event)
	_consume_check_math(event)
	_render()


func set_check_math_enabled(enabled: bool) -> void:
	_check_math_enabled = enabled
	if _check_toggle.button_pressed != enabled:
		_check_toggle.set_pressed_no_signal(enabled)
	_render_check_math()


func is_check_math_enabled() -> bool:
	return _check_math_enabled


func check_math_text() -> String:
	return format_check_math(_last_check_math)


static func format_check_math(check_math: Dictionary) -> String:
	if check_math.is_empty():
		return ""
	var skill_value: Variant = check_math.get(
		"skill_percent", check_math.get("effective_percent", check_math.get("skill", 0))
	)
	var roll := int(check_math.get("roll", 0))
	return "Skill %s%%  ·  Roll %d\nModifiers %s" % [
		_number_text(float(skill_value)),
		roll,
		_format_modifiers(check_math.get("modifiers", [])),
	]


func _render() -> void:
	if not is_node_ready():
		return
	_render_initiative()
	var balance := int(_snapshot.get("balance", 0))
	_balance_label.text = "BALANCE  %s" % _signed_int(balance)
	_balance_arcs.set_balance(balance)
	_render_ap()
	_render_zones()
	_render_weaknesses()
	_render_check_math()


func _render_initiative() -> void:
	var names: Array[String] = []
	if not _initiative.is_empty():
		for row: Variant in _initiative:
			if row is Dictionary:
				names.append(str(row.get("display_name", row.get("id", "?"))))
			else:
				names.append(str(row))
	else:
		for row: Dictionary in _combatant_rows():
			names.append(str(row.get("display_name", row.get("id", "?"))))
	var active_id := StringName(_snapshot.get("active_actor_id", ""))
	var active_name := _display_name_for(active_id)
	_initiative_label.text = "ACTIVE  %s\n%s" % [
		active_name.to_upper() if not active_name.is_empty() else "—",
		"  ·  ".join(names) if not names.is_empty() else "Awaiting event",
	]


func _render_ap() -> void:
	var active_id := StringName(_snapshot.get("active_actor_id", ""))
	var row := _row_for(active_id)
	var current := int(row.get("ap", 0))
	var maximum := int(row.get("max_ap", 0))
	_ap_pips.set_ap(current, maximum)
	_ap_label.text = "AP  %d / %d" % [current, maximum]


func _render_zones() -> void:
	var lines: Array[String] = []
	for side in ["ally", "enemy"]:
		lines.append(side.to_upper())
		for zone in ["front", "back", "flank"]:
			var occupants: Array[String] = []
			for row: Dictionary in _combatant_rows():
				if str(row.get("side", "")) == side and str(row.get("position", "")) == zone:
					occupants.append(str(row.get("display_name", row.get("id", "?"))))
			if not occupants.is_empty():
				lines.append("%s  %s" % [zone.to_upper(), ", ".join(occupants)])
	_zones_label.text = "\n".join(lines) if lines.size() > 2 else "Awaiting zone event"


func _render_weaknesses() -> void:
	if _weaknesses.is_empty():
		_weaknesses_label.text = "None discovered"
		return
	var lines: Array[String] = []
	for weakness: Dictionary in _weaknesses:
		var name := str(weakness.get("display_name", weakness.get("name", weakness.get("id", "Unknown"))))
		var target := str(weakness.get("target_name", weakness.get("target_id", "")))
		lines.append("%s%s" % [name, "  ·  " + target if not target.is_empty() else ""])
	_weaknesses_label.text = "\n".join(lines)


func _render_check_math() -> void:
	if not is_node_ready():
		return
	var text := check_math_text()
	_check_toggle.text = "CHECK MATH  %s" % ("ON" if _check_math_enabled else "OFF")
	_check_label.visible = _check_math_enabled and not text.is_empty()
	_check_label.text = text if _check_math_enabled else ""
	_check_label.tooltip_text = text if _check_math_enabled else ""
	_check_toggle.tooltip_text = text if _check_math_enabled else "Check math is hidden."


func _consume_weaknesses(event: CombatEvent) -> void:
	var rows: Variant = event.data.get(
		"discovered_weaknesses", event.data.get("weaknesses", null)
	)
	if rows is Array:
		_weaknesses.clear()
		for row: Variant in rows:
			_append_weakness(row, event.target_id)
	elif event.type == &"weakness_discovered":
		_append_weakness(event.data.get("weakness", event.data), event.target_id)
	for enemy: Variant in _snapshot.get("enemies", []):
		if enemy is Dictionary and enemy.get("weaknesses") is Array:
			for weakness: Variant in enemy.get("weaknesses", []):
				_append_weakness(weakness, StringName(enemy.get("id", "")))


func _append_weakness(value: Variant, target_id: StringName) -> void:
	var row: Dictionary
	if value is Dictionary:
		row = value.duplicate(true)
	else:
		row = {"id": str(value), "display_name": str(value)}
	if not target_id.is_empty() and str(row.get("target_id", "")).is_empty():
		row["target_id"] = target_id
	var key := str(row.get("id", row.get("display_name", row.get("name", ""))))
	for existing: Dictionary in _weaknesses:
		if str(existing.get("id", existing.get("display_name", existing.get("name", "")))) == key:
			return
	_weaknesses.append(row)


func _consume_check_math(event: CombatEvent) -> void:
	var check_value: Variant = event.data.get("check_math", null)
	if check_value is Dictionary:
		_last_check_math = check_value.duplicate(true)
	elif event.data.has("skill_percent") and event.data.has("roll"):
		_last_check_math = {
			"skill_percent": event.data.get("skill_percent", 0),
			"roll": event.data.get("roll", 0),
			"modifiers": event.data.get("modifiers", []),
		}


func _combatant_rows() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group_name in ["allies", "enemies"]:
		for row: Variant in _snapshot.get(group_name, []):
			if row is Dictionary:
				result.append(row)
	return result


func _row_for(actor_id: StringName) -> Dictionary:
	for row: Dictionary in _combatant_rows():
		if StringName(row.get("id", "")) == actor_id:
			return row
	return {}


func _display_name_for(actor_id: StringName) -> String:
	var row := _row_for(actor_id)
	return str(row.get("display_name", row.get("id", "")))


static func _format_modifiers(raw: Variant) -> String:
	var parts: Array[String] = []
	if raw is Array:
		for value: Variant in raw:
			if value is Dictionary:
				parts.append("%s %s" % [
					_signed_number(float(value.get("value", value.get("amount", 0)))),
					str(value.get("label", value.get("id", "modifier"))).capitalize(),
				])
			else:
				parts.append(str(value))
	elif raw is Dictionary:
		var keys: Array = raw.keys()
		keys.sort()
		for key: Variant in keys:
			parts.append("%s %s" % [_signed_number(float(raw[key])), str(key).capitalize()])
	elif raw != null and str(raw) != "":
		parts.append(str(raw))
	return ", ".join(parts) if not parts.is_empty() else "none"


static func _number_text(value: float) -> String:
	return str(int(value)) if is_equal_approx(value, roundf(value)) else "%.1f" % value


static func _signed_number(value: float) -> String:
	var text := _number_text(value)
	return "+" + text if value > 0.0 else text


static func _signed_int(value: int) -> String:
	return "+%d" % value if value > 0 else str(value)
