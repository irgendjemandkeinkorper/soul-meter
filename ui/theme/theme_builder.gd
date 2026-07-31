class_name ThemeBuilder
extends RefCounted
## Builds the runtime Theme from the DS tokens (ui/theme/ds.gd).
## Per the architecture guardrails: type variations, never per-node overrides.
## Variations provided: TitleLabel, HeadingLabel, EyebrowLabel, QuoteLabel, StatLabel,
## MutedLabel, DangerButton, BronzeButton.
## Panels use a project-owned notched nine-patch. Controls that do not need the silhouette
## use token-driven StyleBoxFlat treatments so the prototype remains easy to reskin.


static func build() -> Theme:
	var t := Theme.new()

	var display: FontFile = load(DS.FONT_DISPLAY)
	var body: FontFile = load(DS.FONT_BODY)
	var quote: FontFile = load(DS.FONT_QUOTE)
	var numeric: FontFile = load(DS.FONT_NUMERIC)

	# Body serif is the default face; display serif is opt-in via variations/controls.
	t.default_font = body
	t.default_font_size = DS.FS_400

	# ---- Panels: stone slab, iron trim, sharp corners, heavy shadow ----
	var panel := StyleBoxTexture.new()
	panel.texture = load("res://assets/blockout/notched_panel.svg")
	panel.texture_margin_left = 16.0
	panel.texture_margin_top = 16.0
	panel.texture_margin_right = 16.0
	panel.texture_margin_bottom = 16.0
	panel.set_content_margin_all(DS.PANEL_PAD)
	t.set_stylebox("panel", "PanelContainer", panel)

	# ---- Buttons: iron bevel (mid-stop fill), hover = edge lights up, press = inset ----
	t.set_font("font", "Button", display)
	t.set_font_size("font_size", "Button", DS.FS_200)
	t.set_color("font_color", "Button", DS.ASH)
	t.set_color("font_hover_color", "Button", DS.PARCHMENT)
	t.set_color("font_pressed_color", "Button", DS.PARCHMENT)
	t.set_color("font_focus_color", "Button", DS.PARCHMENT)
	t.set_color("font_disabled_color", "Button", DS.ASH_FAINT)

	var btn := StyleBoxFlat.new()
	btn.bg_color = Color("#252B35")  # --bevel-iron mid stop
	btn.border_color = DS.IRON_1
	btn.set_border_width_all(1)
	btn.set_corner_radius_all(DS.RADIUS)
	btn.content_margin_left = DS.SPACE_6
	btn.content_margin_right = DS.SPACE_6
	btn.content_margin_top = DS.SPACE_4
	btn.content_margin_bottom = DS.SPACE_4
	t.set_stylebox("normal", "Button", btn)

	var btn_hover := btn.duplicate()
	btn_hover.border_color = DS.VIOLET_3  # hover: the metal edge lights up; no fill lift
	t.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := btn.duplicate()
	btn_pressed.bg_color = Color("#161A21")  # --bevel-iron-pressed top stop
	btn_pressed.border_color = DS.IRON_0
	t.set_stylebox("pressed", "Button", btn_pressed)

	var btn_focus := btn.duplicate()
	btn_focus.border_color = DS.VIOLET_3  # --glow-focus ring
	btn_focus.set_border_width_all(2)
	t.set_stylebox("focus", "Button", btn_focus)

	var btn_disabled := btn.duplicate()
	btn_disabled.bg_color = Color(btn.bg_color, 0.42)
	t.set_stylebox("disabled", "Button", btn_disabled)

	# DangerButton — cinder accent (consequence); never mixed with violet on one control.
	t.add_type("DangerButton")
	t.set_type_variation("DangerButton", "Button")
	var dbtn := btn.duplicate()
	dbtn.border_color = DS.CINDER_2
	t.set_stylebox("normal", "DangerButton", dbtn)
	var dbtn_h := dbtn.duplicate()
	dbtn_h.border_color = DS.CINDER_3
	t.set_stylebox("hover", "DangerButton", dbtn_h)
	t.set_color("font_color", "DangerButton", DS.CINDER_3)

	# BronzeButton — the one ceremonial control per screen (importance = bronze).
	t.add_type("BronzeButton")
	t.set_type_variation("BronzeButton", "Button")
	var bbtn := btn.duplicate()
	bbtn.bg_color = DS.BRONZE_1
	bbtn.border_color = DS.BRONZE_3
	t.set_stylebox("normal", "BronzeButton", bbtn)
	var bbtn_h := bbtn.duplicate()
	bbtn_h.border_color = DS.BRONZE_4
	t.set_stylebox("hover", "BronzeButton", bbtn_h)
	t.set_color("font_color", "BronzeButton", DS.TEXT_ON_METAL)
	t.set_color("font_hover_color", "BronzeButton", DS.TEXT_ON_METAL)

	# ---- Labels ----
	t.set_color("font_color", "Label", DS.PARCHMENT)

	t.add_type("HeroLabel")  # --type-hero: Cinzel black 58 — the title screen wordmark
	t.set_type_variation("HeroLabel", "Label")
	t.set_font("font", "HeroLabel", display)
	t.set_font_size("font_size", "HeroLabel", DS.FS_1000)

	t.add_type("TitleLabel")  # --type-title: Cinzel bold 32
	t.set_type_variation("TitleLabel", "Label")
	t.set_font("font", "TitleLabel", display)
	t.set_font_size("font_size", "TitleLabel", DS.FS_800)

	t.add_type("HeadingLabel")  # --type-heading: Cinzel semibold 22
	t.set_type_variation("HeadingLabel", "Label")
	t.set_font("font", "HeadingLabel", display)
	t.set_font_size("font_size", "HeadingLabel", DS.FS_600)

	t.add_type("EyebrowLabel")  # --type-eyebrow: Cinzel 12, tracked, muted
	t.set_type_variation("EyebrowLabel", "Label")
	t.set_font("font", "EyebrowLabel", display)
	t.set_font_size("font_size", "EyebrowLabel", DS.FS_100)
	t.set_color("font_color", "EyebrowLabel", DS.ASH)

	t.add_type("QuoteLabel")  # --type-quote: Cormorant italic 19 — flavour text
	t.set_type_variation("QuoteLabel", "Label")
	t.set_font("font", "QuoteLabel", quote)
	t.set_font_size("font_size", "QuoteLabel", DS.FS_500)
	t.set_color("font_color", "QuoteLabel", DS.ASH)

	t.add_type("StatLabel")  # --type-stat: Fira Code — numbers only, exact, uncomfortable
	t.set_type_variation("StatLabel", "Label")
	t.set_font("font", "StatLabel", numeric)
	t.set_font_size("font_size", "StatLabel", DS.FS_200)

	t.add_type("MutedLabel")
	t.set_type_variation("MutedLabel", "Label")
	t.set_color("font_color", "MutedLabel", DS.ASH_DIM)

	# ---- Inset wells: ItemList, ProgressBar track, LineEdit ----
	var inset := StyleBoxFlat.new()
	inset.bg_color = DS.VOID_1
	inset.border_color = DS.VOID_0
	inset.set_border_width_all(1)
	inset.set_corner_radius_all(DS.RADIUS)
	inset.set_content_margin_all(DS.SPACE_4)
	for cls in ["ItemList", "LineEdit"]:
		t.set_stylebox("panel" if cls == "ItemList" else "normal", cls, inset.duplicate())
	t.set_color("font_color", "ItemList", DS.ASH)
	t.set_color("font_selected_color", "ItemList", DS.PARCHMENT)
	var sel := StyleBoxFlat.new()
	sel.bg_color = Color(DS.VIOLET_2, 0.25)  # selected: violet, over any rarity colour
	sel.border_color = DS.VIOLET_3
	sel.set_border_width_all(1)
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel.duplicate())

	var track := inset.duplicate()
	track.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = DS.BRONZE_3
	fill.set_corner_radius_all(DS.RADIUS)
	t.set_stylebox("fill", "ProgressBar", fill)

	# ---- HSlider: carved track + iron grabber ----
	var slider_track := inset.duplicate()
	slider_track.set_content_margin_all(2)
	t.set_stylebox("slider", "HSlider", slider_track)

	# Tooltips are carved annotations, not browser-default bubbles.
	var tooltip := inset.duplicate()
	tooltip.border_color = DS.BRONZE_1
	tooltip.set_border_width_all(1)
	t.set_stylebox("panel", "TooltipPanel", tooltip)
	t.set_font("font", "TooltipLabel", body)
	t.set_font_size("font_size", "TooltipLabel", DS.FS_200)
	t.set_color("font_color", "TooltipLabel", DS.PARCHMENT)

	return t
