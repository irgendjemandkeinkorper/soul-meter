extends Node2D
## A brief, noninteractive impact mark. Four expanding arcs read without relying on hue.

var radius: float = DS.SPACE_5:
	set(value):
		radius = value
		queue_redraw()


static func is_damaging_hit(event: CombatEvent) -> bool:
	return did_hit(event) and int(event.data.get("damage", 0)) > 0


static func did_hit(event: CombatEvent) -> bool:
	var resolution: Dictionary = event.data.get("resolution", {})
	return bool(event.data.get("hit", resolution.get("hit", true))) and not bool(resolution.get("fizzled", false))


static func result_text(event: CombatEvent) -> String:
	var resolution: Dictionary = event.data.get("resolution", {})
	if bool(resolution.get("fizzled", false)):
		return TranslationServer.translate("FIZZLE")
	if not did_hit(event):
		return TranslationServer.translate("MISS")
	var damage := int(event.data.get("damage", 0))
	return TranslationServer.translate("%d DAMAGE") % damage if damage > 0 else TranslationServer.translate("NO DAMAGE")


static func has_result(event: CombatEvent) -> bool:
	if event.type != &"action_resolved" or event.target_id.is_empty():
		return false
	if not (event.data.get("path_cells", []) as Array).is_empty():
		return false
	var resolution: Dictionary = event.data.get("resolution", {})
	if bool(resolution.get("fizzled", false)):
		return true
	if not bool(resolution.get("direct_damage_enabled", true)) and int(event.data.get("damage", 0)) <= 0:
		return false
	return event.data.has("hit") or resolution.has("hit") or int(event.data.get("damage", 0)) > 0


static func target_snapshot(event: CombatEvent) -> Dictionary:
	var snapshot: Dictionary = event.data.get("snapshot", {})
	for side: String in ["allies", "enemies"]:
		for actor: Dictionary in snapshot.get(side, []):
			if str(actor.get("id", "")) == String(event.target_id):
				return actor
	return {}


## A committed action may refresh a minor record even when its roll proposes serious.
## Only describe the actual snapshot record with this action's provenance.
static func injury_text(event: CombatEvent) -> String:
	if not has_result(event) or not did_hit(event):
		return ""
	var resolution: Dictionary = event.data.get("resolution", {})
	var injury: Dictionary = resolution.get("injury", {})
	if not bool(injury.get("applies", false)) or not resolution.has("battle_id") or not resolution.has("tick"):
		return ""
	var target := target_snapshot(event)
	var location := str(injury.get("location_id", ""))
	var record: Dictionary = (target.get("injuries", {}) as Dictionary).get(location, {})
	var source_key := "%s|%d|%s|%s" % [
		str(resolution["battle_id"]), int(resolution["tick"]), String(event.actor_id), str(resolution.get("ability_id", "")),
	]
	if record.is_empty() or str(record.get("source_key", "")) != source_key:
		return ""
	var anatomy: Dictionary = target.get("anatomy", {})
	var part: Dictionary = anatomy.get(location, {})
	var severity := TranslationServer.translate("SERIOUS INJURY") if str(record.get("severity", "minor")) == CombatInjury.PERSISTENT_SEVERITY else TranslationServer.translate("MINOR INJURY")
	var text := TranslationServer.translate("%s · %s") % [str(part.get("display_name", location.capitalize())).to_upper(), severity]
	if int(record.get("applications", 1)) > 1:
		text += "\n" + TranslationServer.translate("REFRESHED")
	return text


func _ready() -> void:
	var pulse := create_tween().set_parallel(true)
	pulse.tween_property(self, "radius", float(DS.SPACE_7), DS.DUR_BASE)
	pulse.tween_property(self, "modulate:a", 0.0, DS.DUR_BASE)
	pulse.chain().tween_callback(queue_free)


func _draw() -> void:
	for index: int in 4:
		var start := float(index) * PI * 0.5 + PI * 0.125
		draw_arc(Vector2.ZERO, radius, start, start + PI * 0.25, 8, DS.PARCHMENT, DS.BORDER_TRIM_W, true)
