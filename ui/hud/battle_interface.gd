class_name BattleInterface
extends Control

## Six-region battle overlay contract:
## - consume_event(CombatEvent) fans immutable presentation snapshots to A-E.
## - bind_scheduler(TurnScheduler) gives region E the scheduler's own peek_order arithmetic.
## - forecast_context is passed to region D, whose only calculator is Resolution.resolve().
## - region B receives tile/weather state only through CombatEvent payloads.
@onready var active_unit_plate: UnitPlateRegion = %ActiveUnitPlate
@onready var stage: BattleStageRegion = %Stage
@onready var weather_chip: WeatherChipRegion = %WeatherChip
@onready var act_target_panel: ForecastPanelRegion = %ActTargetPanel
@onready var turn_timeline: CTTimelineRegion = %TurnTimeline
@onready var cursor_readout: Label = %CursorReadout


func _ready() -> void:
	stage.tile_selected.connect(_on_tile_selected)


func consume_event(event: CombatEvent) -> void:
	active_unit_plate.consume_event(event)
	stage.consume_event(event)
	weather_chip.consume_event(event)
	act_target_panel.consume_event(event)
	turn_timeline.consume_event(event)


func bind_scheduler(scheduler: TurnScheduler) -> void:
	turn_timeline.bind_scheduler(scheduler)


func set_forecast_context(context: Dictionary) -> void:
	act_target_panel.set_forecast_context(context)


func _on_tile_selected(tile: Dictionary) -> void:
	cursor_readout.text = "(%d,%d) · HEIGHT %d · %s %d · %s" % [int(tile.get("x", 0)), int(tile.get("y", 0)), int(tile.get("height_delta", tile.get("height", 0))), str(tile.get("charge_element_id", "UNCHARGED")).to_upper(), int(tile.get("charge_level", 0)), str(tile.get("note", ""))]
