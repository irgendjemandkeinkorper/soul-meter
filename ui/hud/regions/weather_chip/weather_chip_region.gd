class_name WeatherChipRegion
extends PanelContainer

@onready var value: Label = %Value


func consume_event(event: CombatEvent) -> void:
	var snapshot: Dictionary = event.data.get("snapshot", event.data)
	var weather: Dictionary = snapshot.get("weather", {})
	if weather.is_empty():
		return
	# An empty element id is the "no weather authored" sentinel (Weather.UNCHARGED) —
	# render it as the calm state rather than a blank label.
	var element := str(weather.get("element_id", weather.get("attunement", "")))
	if element.is_empty():
		element = "CALM"
	value.text = "%s · MEASURE %d/16\n+%s  −%s" % [element.to_upper(), int(weather.get("tick", weather.get("ticks_elapsed", 0))) % 16, str(weather.get("gains", "—")).to_upper(), str(weather.get("drains", "—")).to_upper()]
