class_name ThemeBuilder
extends RefCounted
## Builds the runtime Theme from the DS tokens (ui/theme/ds.gd).
## Per the architecture guardrails: type variations, never per-node overrides.
## Variations provided: TitleLabel, HeadingLabel, EyebrowLabel, QuoteLabel, StatLabel,
## MutedLabel, NPC portrait variations, DangerButton, BronzeButton, DialogueChoice,
## DialogueLinePanel, and BattleHud layouts. Every framed control uses a project-owned,
## 16px-margined notched nine-patch; nodes never carry stylebox overrides.

const NOTCHED_ATLAS := preload("res://assets/ui/notched_nine_patch_atlas.svg")
const NOTCHED_TILE_SIZE := 64.0


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
		var portrait_frame := _notched_style(index, DS.SPACE_2)
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

	var btn := _notched_style(10)
	btn.content_margin_left = DS.SPACE_6
	btn.content_margin_right = DS.SPACE_6
	btn.content_margin_top = DS.SPACE_4
	btn.content_margin_bottom = DS.SPACE_4
	t.set_stylebox("normal", "Button", btn)

	var btn_hover := _notched_style(11, DS.SPACE_4, DS.SPACE_6)
	t.set_stylebox("hover", "Button", btn_hover)

	var btn_pressed := _notched_style(12, DS.SPACE_4, DS.SPACE_6)
	t.set_stylebox("pressed", "Button", btn_pressed)

	var btn_focus := _notched_style(13, DS.SPACE_4, DS.SPACE_6)
	t.set_stylebox("focus", "Button", btn_focus)

	var btn_disabled := _notched_style(14, DS.SPACE_4, DS.SPACE_6)
	t.set_stylebox("disabled", "Button", btn_disabled)

	# DangerButton — cinder accent (consequence); never mixed with violet on one control.
	t.add_type("DangerButton")
	t.set_type_variation("DangerButton", "Button")
	var dbtn := _notched_style(15, DS.SPACE_4, DS.SPACE_6)
	t.set_stylebox("normal", "DangerButton", dbtn)
	var dbtn_h := _notched_style(16, DS.SPACE_4, DS.SPACE_6)
	t.set_stylebox("hover", "DangerButton", dbtn_h)
	t.set_color("font_color", "DangerButton", DS.CINDER_3)

	# BronzeButton — the one ceremonial control per screen (importance = bronze).
	t.add_type("BronzeButton")
	t.set_type_variation("BronzeButton", "Button")
	var bbtn := _notched_style(17, DS.SPACE_4, DS.SPACE_6)
	t.set_stylebox("normal", "BronzeButton", bbtn)
	var bbtn_h := _notched_style(18, DS.SPACE_4, DS.SPACE_6)
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
	t.add_type("DangerLabel")
	t.set_type_variation("DangerLabel", "Label")
	t.set_color("font_color", "DangerLabel", DS.CINDER_3)

	# Compact composed-component typography.
	t.add_type("BadgeLabel")
	t.set_type_variation("BadgeLabel", "Label")
	t.set_font("font", "BadgeLabel", display)
	t.set_font_size("font_size", "BadgeLabel", DS.FS_100)
	t.set_color("font_color", "BadgeLabel", DS.PARCHMENT)
	t.add_type("ItemSlotCaption")
	t.set_type_variation("ItemSlotCaption", "Label")
	t.set_font("font", "ItemSlotCaption", numeric)
	t.set_font_size("font_size", "ItemSlotCaption", DS.FS_100)
	t.set_color("font_color", "ItemSlotCaption", DS.PARCHMENT)
	t.add_type("InventoryColumns")
	t.set_type_variation("InventoryColumns", "HBoxContainer")
	t.set_constant("separation", "InventoryColumns", DS.CONTROL_GAP)

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
	var inset := _notched_style(19, DS.SPACE_4)
	for cls in ["ItemList", "LineEdit"]:
		t.set_stylebox("panel" if cls == "ItemList" else "normal", cls, inset.duplicate())
	t.set_color("font_color", "ItemList", DS.ASH)
	t.set_color("font_selected_color", "ItemList", DS.PARCHMENT)
	var sel := _notched_style(20)
	t.set_stylebox("selected", "ItemList", sel)
	t.set_stylebox("selected_focus", "ItemList", sel.duplicate())

	# ItemSlot — 64px inventory cells: inset stone, violet selection edge.
	t.add_type("ItemSlot")
	t.set_type_variation("ItemSlot", "Button")
	var item_slot := _notched_style(21, 2)
	t.set_stylebox("normal", "ItemSlot", item_slot)
	var item_slot_hover := _notched_style(22, 2)
	t.set_stylebox("hover", "ItemSlot", item_slot_hover)
	var item_slot_pressed := _notched_style(23, 2)
	t.set_stylebox("pressed", "ItemSlot", item_slot_pressed)
	t.set_stylebox("focus", "ItemSlot", item_slot_pressed.duplicate())
	t.set_color("font_color", "ItemSlot", DS.ASH)
	t.set_color("font_hover_color", "ItemSlot", DS.PARCHMENT)
	t.set_color("font_pressed_color", "ItemSlot", DS.PARCHMENT)

	# Reusable Badge and GLoot ItemSlot scenes choose only these semantic type
	# variations; their nodes never carry local StyleBox overrides.
	for badge_type: String in ["Badge", "BadgeZone", "BadgeWeak", "BadgeResist"]:
		t.add_type(badge_type)
		t.set_type_variation(badge_type, "PanelContainer")
	t.set_stylebox("panel", "Badge", _notched_style(19, DS.SPACE_2, DS.SPACE_4))
	t.set_stylebox("panel", "BadgeZone", _notched_style(20, DS.SPACE_2, DS.SPACE_4))
	t.set_stylebox("panel", "BadgeWeak", _notched_style(25, DS.SPACE_2, DS.SPACE_4))
	t.set_stylebox("panel", "BadgeResist", _notched_style(24, DS.SPACE_2, DS.SPACE_4))
	for rarity_type: String in ["ItemSlotCommon", "ItemSlotRare", "ItemSlotMythic"]:
		t.add_type(rarity_type)
		t.set_type_variation(rarity_type, "PanelContainer")
	t.set_stylebox("panel", "ItemSlotCommon", _notched_style(21, DS.SPACE_1))
	t.set_stylebox("panel", "ItemSlotRare", _notched_style(22, DS.SPACE_1))
	t.set_stylebox("panel", "ItemSlotMythic", _notched_style(24, DS.SPACE_1))

	var track := inset.duplicate()
	track.set_content_margin_all(0)
	t.set_stylebox("background", "ProgressBar", track)
	var fill := _notched_style(24)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.add_type("HealthProgressBar")
	t.set_type_variation("HealthProgressBar", "ProgressBar")
	var health_fill := _notched_style(25)
	t.set_stylebox("fill", "HealthProgressBar", health_fill)

	# ---- HSlider: carved track + iron grabber ----
	var slider_track := inset.duplicate()
	slider_track.set_content_margin_all(2)
	t.set_stylebox("slider", "HSlider", slider_track)

	# Tooltips are carved annotations, not browser-default bubbles.
	var tooltip := _notched_style(26, DS.SPACE_4)
	t.set_stylebox("panel", "TooltipPanel", tooltip)
	t.set_font("font", "TooltipLabel", body)
	t.set_font_size("font_size", "TooltipLabel", DS.FS_200)
	t.set_color("font_color", "TooltipLabel", DS.PARCHMENT)

	# Dialogue surfaces are named variations so dynamically-created controls only
	# select a semantic role; every state remains centralized in this theme.
	t.add_type("DialogueLinePanel")
	t.set_type_variation("DialogueLinePanel", "PanelContainer")
	t.set_stylebox("panel", "DialogueLinePanel", _notched_style(27, DS.PANEL_PAD))

	t.add_type("DialogueChoice")
	t.set_type_variation("DialogueChoice", "Button")
	t.set_stylebox("normal", "DialogueChoice", _notched_style(28))
	t.set_stylebox("hover", "DialogueChoice", _notched_style(29))
	t.set_stylebox("pressed", "DialogueChoice", _notched_style(29))
	t.set_stylebox("focus", "DialogueChoice", _notched_style(29))
	t.set_stylebox("disabled", "DialogueChoice", _notched_style(30))

	return t


static func _notched_style(
	atlas_index: int, vertical_margin: float = 0.0, horizontal_margin: float = -1.0
) -> StyleBoxTexture:
	var region := AtlasTexture.new()
	region.atlas = NOTCHED_ATLAS
	region.region = Rect2(atlas_index * NOTCHED_TILE_SIZE, 0.0, NOTCHED_TILE_SIZE, NOTCHED_TILE_SIZE)
	var style := StyleBoxTexture.new()
	style.texture = region
	style.texture_margin_left = 16.0
	style.texture_margin_top = 16.0
	style.texture_margin_right = 16.0
	style.texture_margin_bottom = 16.0
	var resolved_horizontal := vertical_margin if horizontal_margin < 0.0 else horizontal_margin
	style.content_margin_left = resolved_horizontal
	style.content_margin_right = resolved_horizontal
	style.content_margin_top = vertical_margin
	style.content_margin_bottom = vertical_margin
	return style
