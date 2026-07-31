# Soul Meter design system — IMPORTED

**Canonical source:** the "Soul Meter Design System" Claude project
(https://claude.ai/design/p/241acfb5-f8a3-4283-89c2-d5090b297c43) — synced via the
claude_design MCP on 2026-07-26. Keep it front of mind for every menu, screen, and entity.

The project-level gameplay review sheet is [`DESIGN_PILLARS.md`](DESIGN_PILLARS.md). Use it
alongside these visual tokens when deciding whether a feature belongs in Soul Meter.

**In this repo:**
- `design/tokens/*.css` — the 9 token files, vendored **verbatim**. The DS wins; re-sync
  rather than hand-edit.
- `ui/theme/ds.gd` — the tokens mirrored as GDScript constants (colors, Wheel of Ten, type
  scale, spacing, motion, font paths).
- `ui/theme/theme_builder.gd` — the runtime `Theme`: type variations only (HeroLabel,
  TitleLabel, HeadingLabel, EyebrowLabel, QuoteLabel, StatLabel, MutedLabel, DangerButton,
  BronzeButton), never per-node overrides.
- `assets/fonts/soul-meter/` — Cinzel, Cormorant Garamond (+Italic), Fira Code,
  Metamorphous (OFL; DS-documented Google-Fonts substitutions for unsupplied brand binaries).
- `ui/hud/soul_gauge.gd` — the DS's flagship component ported: bronze fill (never violet —
  "ledgered, not magical"), canon agreement states (constant/skip/feedback/hush; feedback
  pulses), the Registry audit-floor mark.

## The rules that bind Godot work

- **Identity:** "carved, ledgered, and slightly wrong." Heavy stone panels, tarnished metal
  trims, runic light leaking out of the cracks. Voice: dry, exact, administrative about
  horror. Numbers always mono, always exact, often uncomfortable ("91–93%", "-6 soul").
- **Palette bands:** Stone (surfaces) · Metal (iron = structure, bronze = importance — ONE
  bronze-trimmed element per screen) · Arcane (violet = magic/selection, cinder =
  damage/consequence, mote = energy/tempo — never two accents on one control) · Ink
  (parchment/ash). Closed sets: rarity (common/rare/mythic) and agreement states.
- **The Wheel of Ten** is canon-ordered and closed: Suul, Bloei, Aqua, Khor, Terra, Daar,
  Molm, Scor, Nul, Strom. Adjacent = Chord; diametric = Clash. Never an 11th, never reorder.
- **Type:** Cinzel for display + ALL tracked-uppercase labels/buttons; Cormorant Garamond for
  body/dialogue (italic = flavour/quotes); Fira Code for numbers ONLY. No sans in menus.
- **Corners:** radii ~0; the corner language is a 45° **notch** (6/10/16px). Nothing rounded.
- **Depth:** carved INTO stone — inset shadows for wells/slots/tracks; gradient bevels (not
  radius) for raised metal; glows only as edge-light on hover/selection/focus.
- **States:** hover = edge lights up (no fill lift, no scale); press = inset + 1px down;
  selected = violet edge; disabled = 42% opacity, still visible (locked dialogue options must
  be seen).
- **Motion:** stone settles — 80/140/220/400ms + 2.4s ambient; no bounce, no overshoot.
- **Layout:** fixed-frame 1440×900 thinking; HUD pinned bottom with 2px bronze rule;
  **SoulGauge is always the rightmost HUD element**; 64px item slots; grids use gap.
- **No emoji, ever.** Element sigils are text-presentation unicode (✷⚘≈♫▲◑⁂☲○☇).

## Not yet ported (tracked gaps)

- **45° corner notches + gradient bevels** — need `StyleBoxTexture` nine-patches generated
  from the DS (StyleBoxFlat can't notch); until then corners are sharp, fills are bevel
  mid-stops.
- **Engraved patterns** (etch/lattice/measure/resonance/brocade/weave) and the grain/vignette
  atmosphere — shader or texture pass later.
- **Remaining components:** ElementWheel, TempoTrack, AgreementReadout, MeterBar, ItemSlot/
  ItemGrid (grid inventory is confirmed), DialogueChoice, Portrait, Modal, Tooltip — port
  from `components/*/*.prompt.md` as each system lands.
- **Art:** `assets/art/` portraits (rune-knights, Suulmae, spire figures) still live in the
  DS project — bring binaries over when the dialogue/portrait UI lands.
