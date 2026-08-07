class_name ThemeBuilder
extends RefCounted
## Builds the runtime Theme from the DS tokens (ui/theme/ds.gd).
## Per the architecture guardrails: type variations, never per-node overrides.
## Variations provided: TitleLabel, HeadingLabel, EyebrowLabel, QuoteLabel, StatLabel,
## MutedLabel, NPC portrait variations, DangerButton, BronzeButton, and BattleHud layouts.
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

	# NPC placeholder portraits. The generated roster picks one of the ten
	# Wheel-backed variants from the stable portrait id; controls only select a
	# type variation and never carry task-local theme overrides.
	t.add_type("NpcPortraitColumn")
	t.set_type_variation("NpcPortraitColumn", "VBoxContainer")
	t.set_constant("separation", "NpcPortraitColumn", DS.SPACE_2)
	for index: int in DS.WHEEL.size():
		var accent: Color = DS.WHEEL[index]["color"]
		var frame_type := "NpcPortraitFrame%d" % index
		t.add_type(frame_type)
		t.set_type_variation(frame_type, "PanelContainer")
		var portrait_frame := StyleBoxFlat.new()
		portrait_frame.bg_color = DS.VOID_1
		portrait_frame.border_color = accent
		portrait_frame.set_border_width_all(DS.BORDER_TRIM_W)
		portrait_frame.set_corner_radius_all(DS.RADIUS)
		portrait_frame.set_content_margin_all(DS.SPACE_2)
		t.set_stylebox("panel", frame_type, portrait_frame)

		var monogram_type := "NpcPortraitMonogram%d" % index
		t.add_type(monogram_type)
		t.set_type_variation(monogram_type, "Label")
		t.set_font("font", monogram_type, display)
		t.set_font_size("font_size", monogram_type, DS.FS_700)
		t.set_color("font_color", monogram_type, accent)

	t.add_type("NpcPortraitMark")
	t.set_type_variation("NpcPortraitMark", "Label")
	t.set_font("font", "NpcPortraitMark", numeric)
	t.set_font_size("font_size", "NpcPortraitMark", DS.FS_100)
	t.set_color("font_color", "NpcPortraitMark", DS.ASH_DIM)

	# Battle HUD layout — mirror-paired columns around a fixed centre axis.
	t.add_type("BattleHudPanel")
	t.set_type_variation("BattleHudPanel", "PanelContainer")
	t.add_type("BattleHudMargin")
	t.set_type_variation("BattleHudMargin", "MarginContainer")
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		t.set_constant(margin_name, "BattleHudMargin", DS.PANEL_PAD)
	t.add_type("BattleHudColumn")
	t.set_type_variation("BattleHudColumn", "VBoxContainer")
	t.set_constant("separation", "BattleHudColumn", DS.SPACE_4)
	t.add_type("BattleHudRow")
	t.set_type_variation("BattleHudRow", "HBoxContainer")
	t.set_constant("separation", "BattleHudRow", DS.SPACE_6)

	# Battle screen layout. These replace legacy per-node overrides with the
	# nearest existing spacing tokens; no task-local dimensions are introduced.
	t.add_type("BattleSafeFrame")
	t.set_type_variation("BattleSafeFrame", "MarginContainer")
	t.set_constant("margin_left", "BattleSafeFrame", DS.SPACE_9)
	t.set_constant("margin_right", "BattleSafeFrame", DS.SPACE_9)
	t.set_constant("margin_top", "BattleSafeFrame", DS.SPACE_8)
	t.set_constant("margin_bottom", "BattleSafeFrame", DS.SPACE_8)
	t.add_type("BattleLayout")
	t.set_type_variation("BattleLayout", "VBoxContainer")
	t.set_constant("separation", "BattleLayout", DS.CONTROL_GAP)
	t.add_type("BattleHeader")
	t.set_type_variation("BattleHeader", "HBoxContainer")
	t.set_constant("separation", "BattleHeader", DS.SPACE_7)
	t.add_type("BattleHeaderMargin")
	t.set_type_variation("BattleHeaderMargin", "MarginContainer")
	t.set_constant("margin_left", "BattleHeaderMargin", DS.SPACE_5)
	t.set_constant("margin_right", "BattleHeaderMargin", DS.SPACE_5)
	t.set_constant("margin_top", "BattleHeaderMargin", DS.SPACE_4)
	t.set_constant("margin_bottom", "BattleHeaderMargin", DS.SPACE_4)
	t.add_type("BattleRail")
	t.set_type_variation("BattleRail", "HBoxContainer")
	t.set_constant("separation", "BattleRail", DS.CONTROL_GAP)
	t.add_type("BattleColumn")
	t.set_type_variation("BattleColumn", "VBoxContainer")
	t.set_constant("separation", "BattleColumn", DS.SPACE_4)
	t.add_type("BattleTightColumn")
	t.set_type_variation("BattleTightColumn", "VBoxContainer")
	t.set_constant("separation", "BattleTightColumn", DS.SPACE_3)
	t.add_type("BattleActionGrid")
	t.set_type_variation("BattleActionGrid", "GridContainer")
	t.set_constant("h_separation", "BattleActionGrid", DS.SPACE_4)
	t.set_constant("v_separation", "BattleActionGrid", DS.SPACE_4)
	t.add_type("BattlePanelMargin")
	t.set_type_variation("BattlePanelMargin", "MarginContainer")
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		t.set_constant(margin_name, "BattlePanelMargin", DS.SPACE_5)
	t.add_type("BattlePartyMargin")
	t.set_type_variation("BattlePartyMargin", "MarginContainer")
	t.set_constant("margin_left", "BattlePartyMargin", DS.SPACE_5)
	t.set_constant("margin_right", "BattlePartyMargin", DS.SPACE_5)
	t.set_constant("margin_top", "BattlePartyMargin", DS.SPACE_3)
	t.set_constant("margin_bottom", "BattlePartyMargin", DS.SPACE_3)
	t.add_type("BattlePartyRow")
	t.set_type_variation("BattlePartyRow", "HBoxContainer")
	t.set_constant("separation", "BattlePartyRow", DS.SPACE_5)

	# Shared screen and ledger layouts. Screen scripts select these variations;
	# all visual values remain centralized here and come from DS tokens.
	t.add_type("ScreenWindowMargin")
	t.set_type_variation("ScreenWindowMargin", "MarginContainer")
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		t.set_constant(margin_name, "ScreenWindowMargin", DS.PANEL_PAD)
	t.add_type("ScreenContentColumn")
	t.set_type_variation("ScreenContentColumn", "VBoxContainer")
	t.set_constant("separation", "ScreenContentColumn", DS.CONTROL_GAP)

	# M2 full-screen shell — Screen > MarginContainer(20) > VBox(16) with exactly
	# Header / Body / HudBar. See design/ui-shell-conventions.md. Separate from the
	# ScreenWindow* variations above, which style the older centred-panel window.
	t.add_type("ScreenShellMargin")
	t.set_type_variation("ScreenShellMargin", "MarginContainer")
	for margin_name in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		t.set_constant(margin_name, "ScreenShellMargin", DS.PANEL_PAD)
	t.add_type("ScreenShellColumn")
	t.set_type_variation("ScreenShellColumn", "VBoxContainer")
	t.set_constant("separation", "ScreenShellColumn", DS.SPACE_6)
	t.add_type("ScreenHeader")
	t.set_type_variation("ScreenHeader", "HBoxContainer")
	t.set_constant("separation", "ScreenHeader", DS.SPACE_6)
	t.add_type("ScreenHudBar")
	t.set_type_variation("ScreenHudBar", "HBoxContainer")
	t.set_constant("separation", "ScreenHudBar", DS.SPACE_6)
	t.add_type("MirrorPairRow")
	t.set_type_variation("MirrorPairRow", "HBoxContainer")
	t.set_constant("separation", "MirrorPairRow", DS.SPACE_6)
	t.add_type("LedgerColumn")
	t.set_type_variation("LedgerColumn", "VBoxContainer")
	t.set_constant("separation", "LedgerColumn", DS.SPACE_4)
	t.add_type("LedgerHistory")
	t.set_type_variation("LedgerHistory", "VBoxContainer")
	t.set_constant("separation", "LedgerHistory", DS.SPACE_5)

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

	# Journal and Standing use semantic label variations so state remains
	# color-independent in text while accents still follow the shared palette.
	t.add_type("PositiveLabel")
	t.set_type_variation("PositiveLabel", "Label")
	t.set_color("font_color", "PositiveLabel", DS.STATE_CONSTANT)
	t.add_type("NegativeLabel")
	t.set_type_variation("NegativeLabel", "Label")
	t.set_color("font_color", "NegativeLabel", DS.CINDER_3)
	t.add_type("RenownHeadingLabel")
	t.set_type_variation("RenownHeadingLabel", "Label")
	t.set_font("font", "RenownHeadingLabel", display)
	t.set_font_size("font_size", "RenownHeadingLabel", DS.FS_600)
	t.set_color("font_color", "RenownHeadingLabel", DS.GILD_2)
	t.add_type("InfamyHeadingLabel")
	t.set_type_variation("InfamyHeadingLabel", "Label")
	t.set_font("font", "InfamyHeadingLabel", display)
	t.set_font_size("font_size", "InfamyHeadingLabel", DS.FS_600)
	t.set_color("font_color", "InfamyHeadingLabel", DS.CINDER_3)
	for band_name: String in ["Hostile", "Cold", "Neutral", "Warm", "Allied"]:
		var type_name := "Standing%sLabel" % band_name
		t.add_type(type_name)
		t.set_type_variation(type_name, "Label")
	t.set_color("font_color", "StandingHostileLabel", DS.CINDER_3)
	t.set_color("font_color", "StandingColdLabel", DS.ASH)
	t.set_color("font_color", "StandingNeutralLabel", DS.PARCHMENT)
	t.set_color("font_color", "StandingWarmLabel", DS.STATE_CONSTANT)
	t.set_color("font_color", "StandingAlliedLabel", DS.GILD_2)

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

	# ItemSlot — 64px inventory cells: inset stone, violet selection edge.
	t.add_type("ItemSlot")
	t.set_type_variation("ItemSlot", "Button")
	var item_slot := btn.duplicate()
	item_slot.bg_color = DS.VOID_1
	item_slot.border_color = DS.IRON_1
	item_slot.content_margin_left = 2
	item_slot.content_margin_right = 2
	item_slot.content_margin_top = 2
	item_slot.content_margin_bottom = 2
	t.set_stylebox("normal", "ItemSlot", item_slot)
	var item_slot_hover := item_slot.duplicate()
	item_slot_hover.border_color = DS.VIOLET_3
	t.set_stylebox("hover", "ItemSlot", item_slot_hover)
	var item_slot_pressed := item_slot.duplicate()
	item_slot_pressed.bg_color = Color(DS.VIOLET_2, 0.25)
	item_slot_pressed.border_color = DS.VIOLET_3
	t.set_stylebox("pressed", "ItemSlot", item_slot_pressed)
	t.set_stylebox("focus", "ItemSlot", item_slot_pressed.duplicate())
	t.set_color("font_color", "ItemSlot", DS.ASH)
	t.set_color("font_hover_color", "ItemSlot", DS.PARCHMENT)
	t.set_color("font_pressed_color", "ItemSlot", DS.PARCHMENT)

	var track := inset.duplicate()
	track.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", track)
	var fill := StyleBoxFlat.new()
	fill.bg_color = DS.BRONZE_3
	fill.set_corner_radius_all(DS.RADIUS)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.add_type("HealthProgressBar")
	t.set_type_variation("HealthProgressBar", "ProgressBar")
	var health_fill := fill.duplicate()
	health_fill.bg_color = DS.METER_HEALTH_B
	t.set_stylebox("fill", "HealthProgressBar", health_fill)

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
