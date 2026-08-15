class_name WeatherChipRegion
extends PanelContainer

@onready var value: Label = %Value


func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", event.data)
	var weather: Dictionary = snapshot.get("weather", {})
	if weather.is_empty():
		return
	value.text = "%s · MEASURE %d/16\n+%s  −%s" % [str(weather.get("element_id", weather.get("attunement", "CALM"))).to_upper(), int(weather.get("tick", weather.get("ticks_elapsed", 0))) % 16, str(weather.get("gains", "—")).to_upper(), str(weather.get("drains", "—")).to_upper()]
