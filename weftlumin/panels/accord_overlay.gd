class_name WeftluminAccordOverlayPanel
extends WeftluminPanel
## E6.2 (#350, architecture §4.11): the Harmonic Accord / weather / charge overlay. It is how
## the owner *sees* hidden per-area state while playing: a per-cell accord heatmap, the effective
## weather element badge, `TileState` charge from the live battle, Blocking/walkability, and the
## §4.11 saturation warnings for the field.
##
## **Read-only.** Every number comes from `FieldMap` (`accord_base()`, `accord_at()`,
## `zone_delta()`, `element_default_at()`, `weather_default()`, `iso_grid()`, the zones it
## lists) and from the live `CombatController` (`agreement_integrity`, `weather`, the
## `tile_states` it already holds — never `tile_state_at()`, which creates tiles). Nothing here
## writes game state, and nothing here changes how accord, charge or weather are computed.
##
## **Variation is not shown.** E1.7's background variation is held at 0.0 in live combat
## (`Battle._accord_variation()`, not approved as a balance change), so the heatmap is
## `clamp(base_adjusted + zone_delta, 0, 100)` — exactly what combat samples today — and the
## caption says so. The saturation warnings are the bake's lint (`WeftluminScenesKind
## .accord_saturation`), which reasons about the ±10 band without applying it.
##
## Off by default: the overlay draws on the shell's centre viewport only once **Show overlay** is
## ticked, whichever bottom tab is showing. Colours are DS tokens; chrome uses `Editor*`
## theme variations.

const LAYER_ACCORD := &"accord"
const LAYER_WEATHER := &"weather"
const LAYER_CHARGE := &"charge"
const LAYER_WALKABILITY := &"walkability"
const LAYER_LABELS := {
	LAYER_ACCORD: "Accord heatmap",
	LAYER_WEATHER: "Weather element",
	LAYER_CHARGE: "Tile charge",
	LAYER_WALKABILITY: "Walkability",
}
## Seconds between re-reads while the overlay shows (charge and weather move during a battle).
const REFRESH_SECONDS := 0.5
const VARIATION_NOTE := "variation not applied (E1.7 held at 0.0)"
## Heatmap stops: hostile accord (0), the middle of the band (50), accord that holds (100).
const HEAT_LOW := DS.VIOLET_2
const HEAT_MID := DS.GILD_2
const HEAT_HIGH := DS.STATE_CONSTANT
const COLORS := {
	"heat_alpha": DS.FACADE_OCCLUDED_ALPHA,
	"zone_edge": DS.BRONZE_4,
	"blocked": Color(DS.CINDER_3, DS.FACADE_OCCLUDED_ALPHA),
	"blocked_edge": DS.CINDER_3,
	"hush": DS.STATE_HUSH,
	"text": DS.PARCHMENT,
	"warning": DS.CINDER_3,
	"back": DS.STONE_0,
}

var show_check: CheckBox = null
var layer_checks: Dictionary = {}
var summary_label: Label = null
var weather_label: Label = null
var warnings_label: Label = null
var hover_label: Label = null

var _host: WeftluminShell = null
var _scene_root: Node = null
var _sample: Dictionary = {}
var _hover: Variant = null
var _since_refresh: float = 0.0


func _init() -> void:
	title = "Accord overlay"
	needs_sandbox = false
	hotkey_hint = ""


func configure(host: WeftluminShell) -> void:
	if _host != null:
		return
	_host = host
	_build()
	if host != null:
		host.viewport_draw.connect(_draw_overlay)
		host.viewport_input.connect(_on_viewport_input)
		refresh({"scene_root": host.adapter.gameplay_scene_root() if host.adapter != null else null})


func refresh(payload: Dictionary) -> void:
	if payload.has("scene_root"):
		_scene_root = payload["scene_root"] as Node
	_resample()


## Show or hide the overlay (the **Show overlay** box).
func set_overlay_visible(on: bool) -> void:
	show_check.button_pressed = on


func overlay_visible() -> bool:
	return show_check != null and show_check.button_pressed


func set_layer_visible(layer: StringName, on: bool) -> void:
	(layer_checks[layer] as CheckBox).button_pressed = on


func layer_visible(layer: StringName) -> bool:
	return overlay_visible() and (layer_checks[layer] as CheckBox).button_pressed


## The last read of the field (see `sample()`).
func current_sample() -> Dictionary:
	return _sample


func _process(delta: float) -> void:
	if not overlay_visible():
		return
	_since_refresh += delta
	if _since_refresh >= REFRESH_SECONDS:
		_resample()


# --- reading (static, read-only) --------------------------------------------------------------


## The field under `scene_root` and the live controller for it, read into one dictionary:
## `field, location_id, base, base_source, cells {Vector2i: accord}, zone_deltas {Vector2i:
## delta}, uncovered_accord, zone_range, zones [{name, anchor, delta, element}], weather
## {element, hush, source}, charges [{cell, element, level, hush}], walk_grid, warnings`.
## Empty when there is no `FieldMap`.
static func sample(scene_root: Node, controller: CombatController = null) -> Dictionary:
	var field: FieldMap = WeftluminScenesKind.field_map_in(scene_root)
	if field == null:
		return {}
	var location: LocationDefinition = LocationRegistry.by_scene(field._scene_path())
	var live: bool = controller != null
	# A battle samples from its own (encounter-overridable) base; the field from the location.
	var base: float = controller.agreement_integrity if live else field.accord_base()
	var zone_deltas: Dictionary = WeftluminScenesKind.covered_zone_deltas(field)
	var cells: Dictionary = {}
	for cell: Vector2i in zone_deltas:
		cells[cell] = field.accord_at(cell, base)
	var zones: Array[Dictionary] = []
	for zone: AccordZone in field.accord_zones():
		zones.append({
			"name": String(zone.name), "anchor": field.zone_anchor_cell(zone),
			"delta": zone.accord_delta, "element": zone.element_default,
		})
	var span: Vector2 = WeftluminScenesKind.zone_delta_range(field)
	var location_id: String = String(location.id) if location != null else ""
	var weather: Dictionary = {"element": field.weather_default(), "hush": false, "source": "location default"}
	var charges: Array[Dictionary] = []
	if live:
		weather = {
			"element": controller.weather.element_id, "hush": controller.weather.weather_hush,
			"source": "live battle",
		}
		for tile: TileState in controller.tile_states:
			if tile.charge_level > 0 or tile.hush:
				charges.append({
					"cell": Vector2i(tile.x, tile.y), "element": tile.charge_element_id,
					"level": tile.charge_level, "hush": tile.hush,
				})
	return {
		"field": field, "location_id": location_id, "base": base,
		"base_source": "live battle" if live else ("location %s" % location_id if location != null else "no location (default)"),
		"cells": cells, "zone_deltas": zone_deltas,
		"uncovered_accord": AccordMath.accord_at(base, 0.0, 0.0),
		"zone_range": span, "zones": zones, "weather": weather, "charges": charges,
		"walk_grid": field.iso_grid(),
		"warnings": AccordMath.saturation_warnings(base, span.x, span.y, location_id) if location != null else PackedStringArray(),
	}


## The live controller when a battle runs on `scene_root`'s field, else null.
static func live_controller(scene_root: Node) -> CombatController:
	var field: FieldMap = WeftluminScenesKind.field_map_in(scene_root)
	if field == null or not Battle.session_active or Battle.ended or not is_instance_valid(Battle.controller):
		return null
	return Battle.controller if Battle._current_field_map() == field else null


## Accord at `cell` in a sample: the covered cell's value, else the uncovered (base) value.
static func accord_in(sampled: Dictionary, cell: Vector2i) -> float:
	return float((sampled.get("cells", {}) as Dictionary).get(cell, sampled.get("uncovered_accord", 0.0)))


## Heatmap colour for `accord` (0..100) between the three DS stops, at the overlay's alpha.
static func accord_color(accord: float) -> Color:
	var t: float = clampf(accord, 0.0, 100.0) / 100.0
	var color: Color = HEAT_LOW.lerp(HEAT_MID, t * 2.0) if t < 0.5 else HEAT_MID.lerp(HEAT_HIGH, (t - 0.5) * 2.0)
	return Color(color, COLORS["heat_alpha"])


## `{name, color}` of a wheel element id (`""` -> calm), from `DS.WHEEL`.
static func element_style(element_id: StringName) -> Dictionary:
	for entry: Dictionary in DS.WHEEL:
		if str(entry["id"]) == String(element_id):
			return {"name": str(entry["name"]), "color": entry["color"] as Color}
	return {"name": "calm" if element_id == &"" else String(element_id), "color": DS.ASH}


## One line naming the effective weather and where it comes from.
static func weather_text(sampled: Dictionary) -> String:
	var weather: Dictionary = sampled.get("weather", {})
	var text: String = "Weather: %s (%s)" % [element_style(weather.get("element", &""))["name"], weather.get("source", "")]
	return text + (" · hushed" if bool(weather.get("hush", false)) else "")


static func summary_text(sampled: Dictionary) -> String:
	if sampled.is_empty():
		return "No FieldMap in the current scene: nothing to show."
	var span: Vector2 = sampled["zone_range"]
	return "Accord base %.1f (%s, thinning applied once) · zone delta %+.0f..%+.0f over %d zone(s) · %s" % [
		float(sampled["base"]), sampled["base_source"], span.x, span.y, (sampled["zones"] as Array).size(),
		VARIATION_NOTE,
	]


## Readout for one cell: accord, zone delta, elemental default, charge, walkability.
static func cell_text(sampled: Dictionary, cell: Vector2i) -> String:
	if sampled.is_empty():
		return ""
	var field: FieldMap = sampled["field"]
	var text: String = "Cell %s · accord %.1f · zone delta %+.0f · element default %s" % [
		cell, accord_in(sampled, cell), float((sampled["zone_deltas"] as Dictionary).get(cell, 0.0)),
		element_style(field.element_default_at(cell))["name"],
	]
	for charge: Dictionary in sampled["charges"]:
		if charge["cell"] == cell:
			text += " · charge %s %d%s" % [
				element_style(charge["element"])["name"], int(charge["level"]), " (hush)" if bool(charge["hush"]) else "",
			]
	var grid: IsoGrid = sampled["walk_grid"]
	if grid != null:
		text += " · %s" % ("blocked" if grid.is_blocked_for(cell) else "walkable")
	return text


# --- presentation -----------------------------------------------------------------------------


func _resample() -> void:
	_since_refresh = 0.0
	var root: Node = _scene_root if is_instance_valid(_scene_root) else null
	_sample = sample(root, live_controller(root))
	if summary_label == null:
		return
	summary_label.text = summary_text(_sample)
	weather_label.text = weather_text(_sample) if not _sample.is_empty() else ""
	var warnings: PackedStringArray = _sample.get("warnings", PackedStringArray())
	var lines := PackedStringArray()
	for line: String in warnings:
		lines.append("WARNING: " + line)
	warnings_label.text = "\n".join(lines)
	warnings_label.visible = not warnings.is_empty()
	hover_label.text = cell_text(_sample, _hover as Vector2i) if _hover is Vector2i else "Hover a cell for its readout."
	_redraw()


func _redraw() -> void:
	if is_instance_valid(_host) and is_instance_valid(_host.viewport_surface):
		_host.viewport_surface.queue_redraw()


func _on_viewport_input(event: InputEvent, world_position: Vector2) -> void:
	# Read-only: motion updates the readout; the event is never consumed.
	if not event is InputEventMouseMotion or not overlay_visible() or _sample.is_empty():
		return
	var ground: TileMapLayer = (_sample["field"] as FieldMap).ground()
	if ground == null:
		return
	var cell: Vector2i = ground.local_to_map(ground.to_local(world_position))
	if _hover is Vector2i and _hover == cell:
		return
	_hover = cell
	hover_label.text = cell_text(_sample, cell)
	_redraw()


func _world_to_surface() -> Transform2D:
	return _host.viewport_surface.get_global_transform_with_canvas().affine_inverse() * get_viewport().canvas_transform


func _draw_overlay(surface: Control) -> void:
	if not overlay_visible() or _sample.is_empty() or not is_instance_valid(_sample["field"]):
		return
	var field: FieldMap = _sample["field"]
	var ground: TileMapLayer = field.ground()
	if ground == null or ground.tile_set == null:
		return
	var transform: Transform2D = _world_to_surface()
	var visible_area := Rect2(Vector2.ZERO, surface.size)
	var heat: bool = layer_visible(LAYER_ACCORD)
	var grid: IsoGrid = _sample["walk_grid"] as IsoGrid if layer_visible(LAYER_WALKABILITY) else null
	if heat or grid != null:
		for cell: Vector2i in ground.get_used_cells():
			var points: PackedVector2Array = WeftluminPaintTools._diamond(ground, cell, transform)
			if not visible_area.intersects(Rect2(points[0], Vector2.ZERO).expand(points[1]).expand(points[2]).expand(points[3])):
				continue
			if heat:
				surface.draw_colored_polygon(points, accord_color(accord_in(_sample, cell)))
			if grid != null and grid.is_blocked_for(cell):
				if not heat:
					surface.draw_colored_polygon(points, COLORS["blocked"])
				WeftluminPaintTools._outline(surface, points, COLORS["blocked_edge"])
	if heat:
		_draw_zones(surface, ground, transform)
	if layer_visible(LAYER_CHARGE):
		for charge: Dictionary in _sample["charges"]:
			var points: PackedVector2Array = WeftluminPaintTools._diamond(ground, charge["cell"], transform)
			var style: Dictionary = element_style(charge["element"])
			if int(charge["level"]) > 0:
				surface.draw_colored_polygon(points, DS.charge_tint(style["color"], int(charge["level"])))
				WeftluminPaintTools._outline(surface, points, style["color"])
				_draw_text(surface, (points[0] + points[2]) * 0.5, "%s %d" % [style["name"], int(charge["level"])], style["color"], true)
			if bool(charge["hush"]):
				WeftluminPaintTools._outline(surface, points, COLORS["hush"])
	_draw_badges(surface)


## Each zone's anchor carries its delta (and elemental default, if it authors one).
func _draw_zones(surface: Control, ground: TileMapLayer, transform: Transform2D) -> void:
	var deltas: Dictionary = _sample["zone_deltas"]
	for cell: Vector2i in deltas:
		WeftluminPaintTools._outline(surface, WeftluminPaintTools._diamond(ground, cell, transform), COLORS["zone_edge"])
	for zone: Dictionary in _sample["zones"]:
		var points: PackedVector2Array = WeftluminPaintTools._diamond(ground, zone["anchor"], transform)
		var label: String = "%s %+d" % [zone["name"], int(zone["delta"])]
		if zone["element"] != &"":
			label += " · %s" % element_style(zone["element"])["name"]
		_draw_text(surface, (points[0] + points[2]) * 0.5, label, COLORS["text"], true)


## Top-left: the weather badge, then any saturation warning. Bottom: what the heatmap is.
func _draw_badges(surface: Control) -> void:
	var font: Font = surface.get_theme_font(&"font", &"EditorLabel")
	var size: int = surface.get_theme_font_size(&"font_size", &"EditorLabel")
	var margin: float = float(size) * 0.5
	var line_height: float = font.get_height(size) + margin
	# Below the shell's own one-line viewport hint.
	var y: float = line_height + margin
	if layer_visible(LAYER_WEATHER):
		var style: Dictionary = element_style((_sample["weather"] as Dictionary).get("element", &""))
		var text: String = weather_text(_sample)
		var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
		var badge := Rect2(Vector2(margin, y), extent + Vector2(2.0 * margin + size, margin))
		surface.draw_rect(badge, COLORS["back"])
		surface.draw_rect(Rect2(badge.position + Vector2(margin * 0.5, margin * 0.5), Vector2(size, size)), style["color"])
		surface.draw_rect(badge, style["color"], false, DS.BORDER_TRIM_W)
		surface.draw_string(font, badge.position + Vector2(1.5 * margin + size, margin * 0.5 + font.get_ascent(size)), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1, size, COLORS["text"])
		y += badge.size.y + margin
	for warning: String in _sample["warnings"]:
		_draw_line_box(surface, font, size, Vector2(margin, y), "WARNING: " + warning, COLORS["warning"])
		y += line_height
	if _hover is Vector2i:
		_draw_line_box(surface, font, size, Vector2(margin, y), cell_text(_sample, _hover as Vector2i), COLORS["text"])
	var parts: Array[String] = []
	if layer_visible(LAYER_ACCORD):
		parts.append("Accord heatmap: base %.1f + zone delta, %s" % [float(_sample["base"]), VARIATION_NOTE])
	if layer_visible(LAYER_WALKABILITY):
		parts.append("Walkability: player path, clearance %d cell" % ClickMoveController.STATIC_CLEARANCE_CELLS
			if _sample["walk_grid"] != null else "Walkability: no player grid")
	if layer_visible(LAYER_CHARGE):
		parts.append("Charge: %d tile(s) from the live battle" % (_sample["charges"] as Array).size()
			if (_sample["weather"] as Dictionary).get("source", "") == "live battle" else "Charge: no live battle")
	if not parts.is_empty():
		_draw_line_box(surface, font, size, Vector2(margin, surface.size.y - line_height - margin), " · ".join(parts), COLORS["text"])


func _draw_line_box(surface: Control, font: Font, size: int, at: Vector2, text: String, color: Color) -> void:
	var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var margin: float = float(size) * 0.5
	surface.draw_rect(Rect2(at, extent + Vector2(2.0 * margin, margin)), COLORS["back"])
	surface.draw_string(font, at + Vector2(margin, margin * 0.5 + font.get_ascent(size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _draw_text(surface: Control, centre: Vector2, text: String, color: Color, backed: bool) -> void:
	var font: Font = surface.get_theme_font(&"font", &"EditorLabel")
	var size: int = surface.get_theme_font_size(&"font_size", &"EditorLabel")
	var extent: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size)
	var origin: Vector2 = centre - extent * 0.5
	if backed:
		surface.draw_rect(Rect2(origin - Vector2(2, 0), extent + Vector2(4, 0)), COLORS["back"])
	surface.draw_string(font, origin + Vector2(0, font.get_ascent(size)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _build() -> void:
	var scroll := ScrollContainer.new()
	scroll.name = "Scroll"
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var content := VBoxContainer.new()
	content.name = "Content"
	content.theme_type_variation = &"EditorColumn"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	var row := SoulMeterToolPanel._row()
	content.add_child(row)
	show_check = _check("ShowOverlay", "Show overlay", false)
	row.add_child(show_check)
	for layer: StringName in [LAYER_ACCORD, LAYER_WEATHER, LAYER_CHARGE, LAYER_WALKABILITY]:
		var check: CheckBox = _check(String(LAYER_LABELS[layer]).replace(" ", ""), LAYER_LABELS[layer], true)
		layer_checks[layer] = check
		row.add_child(check)
	row.add_child(SoulMeterToolPanel._button("Refresh", "Refresh", _resample))
	summary_label = SoulMeterToolPanel._label("", &"EditorLabel", true)
	summary_label.name = "Summary"
	content.add_child(summary_label)
	weather_label = SoulMeterToolPanel._label("", &"EditorLabel", true)
	weather_label.name = "Weather"
	content.add_child(weather_label)
	warnings_label = SoulMeterToolPanel._label("", &"EditorLabel", true)
	warnings_label.name = "SaturationWarnings"
	warnings_label.visible = false
	content.add_child(warnings_label)
	hover_label = SoulMeterToolPanel._label("", &"EditorLabel", true)
	hover_label.name = "CellReadout"
	content.add_child(hover_label)


func _check(node_name: String, text: String, pressed: bool) -> CheckBox:
	var check := CheckBox.new()
	check.name = node_name
	check.text = text
	check.theme_type_variation = &"EditorCheckBox"
	check.button_pressed = pressed
	check.toggled.connect(func(_on: bool) -> void: _resample())
	return check
