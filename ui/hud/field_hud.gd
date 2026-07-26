extends CanvasLayer
## Field HUD — the bottom bar. Per the DS layout rules: pinned to the bottom edge with a
## 2px bronze top rule; the SoulGauge is always the rightmost element in it.

func _ready() -> void:
	var bar: Control = $Bar
	bar.theme = UIManager.ui_theme  # CanvasLayer children don't inherit the root Window theme
	bar.draw.connect(func() -> void:
		# the 2px bronze top rule
		bar.draw_rect(Rect2(0, 0, bar.size.x, DS.BORDER_TRIM_W), DS.BRONZE_1)
		# stone fill under the bar, slightly scrimmed so the field reads through
		bar.draw_rect(Rect2(0, DS.BORDER_TRIM_W, bar.size.x, bar.size.y), Color(DS.STONE_0, 0.82))
	)
	bar.queue_redraw()
