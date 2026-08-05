class_name DS
extends RefCounted
## Soul Meter Design System — Godot-side tokens.
## Source of truth: the "Soul Meter Design System" Claude project, vendored under
## design/tokens/*.css. This class mirrors those values 1:1 for GDScript/Theme use.
## "Carved, ledgered, and slightly wrong" — stone panels, tarnished metal, runic light.
## Do not invent values here; change the DS first, then mirror it.

# ---- base surfaces: carved stone, obsidian, the inset slot ----
const VOID_0 := Color("#07080B")
const VOID_1 := Color("#0C0E12")
const STONE_0 := Color("#12151B")
const STONE_1 := Color("#1B1F27")
const STONE_2 := Color("#232833")
const STONE_3 := Color("#2C323F")

# ---- metal trims ----
const IRON_0 := Color("#2A303A")
const IRON_1 := Color("#3A414D")
const IRON_2 := Color("#4E5665")
const IRON_3 := Color("#6B7484")
const BRONZE_0 := Color("#5E4415")
const BRONZE_1 := Color("#946B2D")
const BRONZE_2 := Color("#B8860B")
const BRONZE_3 := Color("#D9AB45")
const BRONZE_4 := Color("#F0D089")

# ---- runic / arcane accents ----
const VIOLET_1 := Color("#6B1FB0")
const VIOLET_2 := Color("#8A2BE2")
const VIOLET_3 := Color("#A855F7")
const VIOLET_4 := Color("#C99BFF")
const CINDER_1 := Color("#7A1414")
const CINDER_2 := Color("#991B1B")
const CINDER_3 := Color("#EF4444")
const MOTE_2 := Color("#06B6D4")
const MOTE_3 := Color("#22D3EE")
const GILD_2 := Color("#F59E0B")

# ---- ink (foreground) ----
const PARCHMENT := Color("#E2E8F0")
const ASH := Color("#94A3B8")
const ASH_DIM := Color("#64748B")
const ASH_FAINT := Color("#475569")
const TEXT_ON_METAL := Color("#100D07")

# ---- meters ----
const METER_SOUL_A := Color("#7C6A2E")
const METER_SOUL_B := BRONZE_4  # bronze fill, never violet: the Gauge is ledgered, not magical
const METER_TRACK := VOID_1
const METER_HEALTH_A := CINDER_1
const METER_HEALTH_B := CINDER_3
const METER_MANA_A := VIOLET_1
const METER_MANA_B := VIOLET_3

# ---- item rarity (closed set) ----
const RARITY_COMMON := Color("#64748B")
const RARITY_RARE := Color("#8B5CF6")
const RARITY_MYTHIC := Color("#F59E0B")

# ---- agreement integrity states (Module 8 canon; closed set) ----
const STATE_CONSTANT := Color("#4FA96A")
const STATE_SKIP := GILD_2
const STATE_FEEDBACK := CINDER_3
const STATE_HUSH := Color("#B8C0CC")

# ---- the Wheel of Ten (canon order; adjacency = Chord, diametric = Clash) ----
# Clashes: Suul/Daar, Bloei/Molm, Aqua/Scor, Khor/Nul, Terra/Strom. Never reorder.
#
# Sigils carry U+FE0E (VARIATION SELECTOR-15) where the DS marks them, forcing TEXT
# presentation. Without it these codepoints render as colour emoji on some platforms, which
# would break the DS's "no emoji, ever" rule at runtime rather than at authoring time.
# The five marked here are exactly the five the DS marks — do not add or remove selectors
# without changing the DS first.
const VS_TEXT := "︎"
const WHEEL: Array[Dictionary] = [
	{"id": "suul",  "name": "Suul",  "sigil": "✷", "color": Color("#E8C46A"), "glow": Color("#FFE7A8")},
	{"id": "bloei", "name": "Bloei", "sigil": "⚘︎", "color": Color("#4FA96A"), "glow": Color("#8FE0A4")},
	{"id": "aqua",  "name": "Aqua",  "sigil": "≈", "color": Color("#2E8FB8"), "glow": Color("#7FCDE8")},
	{"id": "khor",  "name": "Khor",  "sigil": "♫︎", "color": Color("#A855F7"), "glow": Color("#D6B4FF")},
	{"id": "terra", "name": "Terra", "sigil": "▲", "color": Color("#8C7A5B"), "glow": Color("#C4AE85")},
	{"id": "daar",  "name": "Daar",  "sigil": "◑︎", "color": Color("#4B3F72"), "glow": Color("#8577C4")},
	{"id": "molm",  "name": "Molm",  "sigil": "⁂", "color": Color("#7A8B3C"), "glow": Color("#B4C46B")},
	{"id": "scor",  "name": "Scor",  "sigil": "☲︎", "color": Color("#E0522F"), "glow": Color("#FF9A6E")},
	{"id": "nul",   "name": "Nul",   "sigil": "○︎", "color": Color("#B8C0CC"), "glow": Color("#EDF2F8")},
	{"id": "strom", "name": "Strom", "sigil": "☇", "color": Color("#22D3EE"), "glow": Color("#A6F0FA")},
]

# ---- type scale (px) ----
const FS_100 := 12; const FS_200 := 13; const FS_300 := 15; const FS_400 := 17
const FS_500 := 19; const FS_600 := 22; const FS_700 := 26; const FS_800 := 32
const FS_900 := 42; const FS_1000 := 58

# ---- spacing / dimensions ----
const SPACE_1 := 2; const SPACE_2 := 4; const SPACE_3 := 6
const SPACE_4 := 8; const SPACE_5 := 12; const SPACE_6 := 16
const SPACE_7 := 20; const SPACE_8 := 24; const SPACE_9 := 32
const PANEL_PAD := SPACE_7          # panel padding 20
const CONTROL_GAP := SPACE_5        # control gaps 12
const ITEM_GRID_GAP := SPACE_2      # item-grid gap 4
const SLOT_SIZE := 64; const SLOT_SIZE_SM := 48; const SLOT_SIZE_LG := 80
const METER_H := 14; const METER_H_LG := 20; const METER_H_SM := 8
const CONTROL_H := 36; const CONTROL_H_SM := 28; const CONTROL_H_LG := 44
const RAIL_W := 320
const BORDER_TRIM_W := 2

# ---- corners: near-zero radii; the notch is the corner language (StyleBoxTexture later) ----
const RADIUS := 0
const NOTCH_SM := 6; const NOTCH_MD := 10; const NOTCH_LG := 16

# ---- motion (seconds; stone settles, nothing springs) ----
const DUR_INSTANT := 0.08; const DUR_FAST := 0.14; const DUR_BASE := 0.22
const DUR_SLOW := 0.4; const DUR_AMBIENT := 2.4

# ---- tactical layer: isometric board geometry ----
# Ported from the DS "Elemental Architecture" Developer Annex (rev 0.2, 2026-08-04); ratified
# by docs/prd-amendment-tactical-layer.md. 2:1 dimetric.
#   screenX = originX + (x - y) * TILE_W/2
#   screenY = originY + (x + y) * TILE_H/2 - h * ELEV_PX
#   zIndex  = (x + y) * 2 + 1        # painter's order; a unit stands at tile.z + 1
# Use iso_project()/iso_z() rather than re-deriving these — Battle Map v2 was authored at a
# different scale (a ~141x71 diamond) and hand-rolled maths will silently disagree with it.
const TILE_W := 56
const TILE_H := 28
const ELEV_PX := 12
const ELEVATION_MAX := 3

# Per-tile element charge (0-3). Tint alpha is 0.20 + 0.14 x level; charge 0 draws nothing.
const CHARGE_MAX := 3
const CHARGE_ALPHA_BASE := 0.20
const CHARGE_ALPHA_STEP := 0.14
const TILE_SELECT_RIM := Color("#D6B4FF")  # = the khor glow; the DS reuses it as the cursor rim

# RESOLVED 2026-08-05 — the Annex's `linear-gradient(180deg,#1B202A,#12151B)` fill is a STALE
# SNAPSHOT, not a missing token. The token file is the single source of truth; use
# `--bevel-stone: linear-gradient(180deg,#20242D,#171A21)` for that surface. #1B202A is
# superseded and must not be reintroduced.
# Revisit only if a side-by-side render shows two genuinely distinct surfaces are wanted — and
# then mint `--bevel-stone-deep` in the DS first, never a literal here.


## Projects grid coordinates to screen space. `origin` is the board's screen anchor.
static func iso_project(x: int, y: int, height: int, origin: Vector2 = Vector2.ZERO) -> Vector2:
	return Vector2(
		origin.x + float(x - y) * float(TILE_W) * 0.5,
		origin.y + float(x + y) * float(TILE_H) * 0.5 - float(height) * float(ELEV_PX),
	)


## Painter's-order z-index for a tile. A unit standing on it uses this + 1.
static func iso_z(x: int, y: int) -> int:
	return (x + y) * 2 + 1


## Tint for a tile carrying `level` charge of `element_color`. Level 0 is fully transparent.
static func charge_tint(element_color: Color, level: int) -> Color:
	if level <= 0:
		return Color(element_color.r, element_color.g, element_color.b, 0.0)
	var clamped := mini(level, CHARGE_MAX)
	var alpha := CHARGE_ALPHA_BASE + CHARGE_ALPHA_STEP * float(clamped)
	return Color(element_color.r, element_color.g, element_color.b, alpha)


# ---- fonts (local OFL files; DS-specified substitutions) ----
const FONT_DISPLAY := "res://assets/fonts/soul-meter/Cinzel.ttf"            # titles, labels, buttons (UPPERCASE, tracked)
const FONT_BODY := "res://assets/fonts/soul-meter/CormorantGaramond.ttf"    # body, hints, dialogue
const FONT_QUOTE := "res://assets/fonts/soul-meter/CormorantGaramond-Italic.ttf"  # flavour, in-world quotes
const FONT_NUMERIC := "res://assets/fonts/soul-meter/FiraCode.ttf"          # numbers ONLY — the ledger, not the interface
