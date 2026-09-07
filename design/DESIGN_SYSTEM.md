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
- `ui/hud/battle_hud.tscn` — the event-stream HUD: initiative and zones/weaknesses are
  mirror-paired around the centre Balance arcs, and check math is an explicit toggle. It
  composes existing tokens and type variations only. ⚠ Built against FR-603, which
  `docs/prd-amendment-tactical-layer.md` **supersedes** (region model); its AP pips become CT —
  see [The Balance UI language](#the-balance-ui-language-fr-601--fr-602--fr-606) below.

## The rules that bind Godot work

- **Identity:** "carved, ledgered, and slightly wrong." Heavy stone panels, tarnished metal
  trims, runic light leaking out of the cracks. Voice: dry, exact, administrative about
  horror. Numbers always mono, always exact, often uncomfortable ("91–93%", "-6 soul").
- **Palette bands:** Stone (surfaces) · Metal (iron = structure, bronze = importance — ONE
  bronze-trimmed element per screen) · Arcane (violet = magic/selection, cinder =
  damage/consequence, mote = energy/tempo — never two accents on one control) · Ink
  (parchment/ash). Closed sets: rarity (common/rare/mythic) and agreement states.
- **The Wheel of Ten** is canon-ordered and closed: Sul, Vel, Luth, Khor, Tham, Vekh,
  Mozh, Khash, Zhem, Zhur. Adjacent = Chord; diametric = Clash. Never an 11th, never reorder.
- **Type:** Cinzel for display + ALL tracked-uppercase labels/buttons; Cormorant Garamond for
  body/dialogue (italic = flavour/quotes); Fira Code for numbers ONLY. No sans in menus.
- **Corners:** radii ~0; the corner language is a 45° **notch** (6/10/16px). Nothing rounded.
- **Depth:** carved INTO stone — inset shadows for wells/slots/tracks; gradient bevels (not
  radius) for raised metal; glows only as edge-light on hover/selection/focus.
- **States:** hover = edge lights up (no fill lift, no scale); press = inset + 1px down;
  selected = violet edge; disabled = 42% opacity, still visible (locked dialogue options must
  be seen).
- **Motion:** stone settles — 80/140/220/400ms + 2.4s ambient; no bounce, no overshoot.
- **Layout:** fixed-frame **1920×1080** — the canonical design frame, matching every authored
  mockup. Spec pixel values map **1:1** to `ds.gd` constants and scene layout; never hand-divide
  a spec value. `project.godot` uses `canvas_items` + aspect `keep`, so Godot applies one uniform
  scale `s = min(window_w / 1920, window_h / 1080)`; the 1280×720 window override is a launch
  size, not a design frame. (Was "1440×900 thinking" — stale, and 16:10 against the mockups'
  16:9; corrected 2026-08-05, see `docs/prd-amendment-tactical-layer.md` §7.)
  HUD pinned bottom with 2px bronze rule;
  **SoulGauge is always the rightmost HUD element**; 64px item slots; grids use gap.
- **No emoji, ever.** Element sigils are text-presentation unicode (✷⚘≈♫▲◑⁂☲○☇).

## The Balance UI language (FR-601 / FR-602 / FR-606)

Repo-side extension, authored here rather than synced — **closes #99**. FR-601 requires this
document to be extended *before* the code changes: the doc is the spec, code follows it.
Cross-check: `design/ui-shell-conventions.md` (#125) owns the screen shell; this section owns
what goes *inside* the gauges.

> ⚠ **Read the amendment first.** `docs/prd-amendment-tactical-layer.md` **amends FR-601**
> (pips are no longer AP), **supersedes FR-603**, and **extends FR-606**'s blocking list. The
> ratified FR text in `docs/prd-chapter-one.md` is retained there as historical record and is
> *not* current. Anything below that contradicts the original FR prose does so deliberately.

### The compositional rule: bilateral mirror symmetry

HUD elements pair left/right around a fixed centre axis. The axis is the Balance Gauge, because
Balance is the thing that is literally two-sided. Everything else arranges around it as a matched
pair — never a lone element floating off-centre, never three-across.

This is not decoration. Mirror symmetry means *the player reads deviation as meaning*: when the
composition is symmetric, the fight is even; asymmetry is the signal.

### The motif: eclipse — occlusion, corona, phase

One motif carries every state display. A disc is occluded to some degree; the corona is what
remains visible.

- **Occlusion** = the resource is spent / unavailable.
- **Corona** = what is left, and it is always *visible* — never a dark hole. A fully spent gauge
  still reads as a ring, so "empty" and "broken" never look alike.
- **Phase** = progress through a cycle.

### The three gauges are one grammar at three zooms

FR-602's requirement is that a player should *see* that the game is one thesis at three scales.
Same family, different scale — and each owns exactly one decision, so they never become
interchangeable soup:

| Gauge | Scale | The decision it owns | Form |
|---|---|---|---|
| **Soul Meter** | self / story | what a permanent spend is worth | progressively occluded disc, bronze fill |
| **Vär (Harmony)** | personal / casting | whether a cast is legal | mirrored disc, −5 kesh ↔ +5 sēl about a centre |
| **Balance Gauge** | battle / tactical | which side the fight is tilting to | twin mirrored arcs meeting at centre |

Shared: the disc/arc family, the centre axis, corona-not-hole, mono numerals, and occlusion as
the spend language. Distinct: **scale and silhouette** — full disc (self), mirrored disc
(harmony), twin arcs (battle). Distinguishable at a glance by shape alone, at any size.

Bronze stays reserved for the Soul Meter: it is *ledgered, not magical*. Vär and Balance never
take bronze — that is what keeps the title mechanic the most valuable pixel on screen.

### Charge time takes the eclipse phase — not AP

**AP is retired** (amendment §6). The eclipse phase now encodes **CT progress toward 100** —
"how close am I to acting" — which the motif fits far better than discrete AP ever did, and which
therefore *strengthens* FR-602 rather than straining it.

`ui/hud/eclipse_pips.gd` is a pure view over two ints with no AP-specific logic, so it survives
the change — but **not as a rename**. CT is continuous and the current `_draw()` renders N
discrete discs. Two legitimate readings, and this is the open call for implementation:

1. a single **filling disc** (a true percentage), or
2. **discrete pips as a deliberate stylisation** of continuous CT (e.g. 10 pips × 10 CT).

Budget a `_draw()` rewrite either way. Option 2 keeps the existing silhouette and reads faster at
small sizes; option 1 is more honest about a continuous quantity. **Not resolved here** — it
wants a screenshot review against the mockups, which is the FR-601 acceptance gate.

### FR-606 — a refusal must name its system and its remedy

Any greyed-out or failed-to-start action states **inline** which system blocked it and the
nearest condition that would unblock it. This is the single mechanism the PRD promises for
answering *"why did that cast fail?"* — one of the comprehension questions the gate tests.

**The amended blocking list** (AP removed, grid axes added):

> **Vär · Breath · CT · span cap · elevation · facing · occupancy · range · weather/Balance bias**

These must stay **distinguishable**. Collapsing them into a generic "invalid move" destroys the
property, and the axes are precisely what a player needs to learn a tactical grid.

The typed taxonomy already exists in code and the UI's job is to surface it, not re-derive it:

- `globals/combat/zone_battlefield_model.gd` → `{allowed, blocked_by, nearest_unblock, message}`
- `globals/elements/casting_gate.gd` → `{blocked_by, nearest_unblock, …}`

**Presentation:** the refusal reads as one line in the game's administrative voice — the system
named, then the remedy, with the number exact and mono.

> *Vär too low — Chord needs +0, you are at −3.*
> *Not charged — 62 / 100.*

Never a bare "Can't do that." Never colour alone to mark the disabled control: per the DS's
own state rules, disabled is 42% opacity and **still visible**, because a locked option the
player cannot see is an option they cannot learn from.

### Colour-independent encoding (FR-607)

State is encoded by **shape and position**, never hue alone. The eclipse and mirror motifs give
this natively and it must not regress:

- Occlusion **fraction** carries the value; the tint only reinforces it.
- Balance uses **which side** the arc fills and **how far** — a monochrome screenshot still reads.
- CT uses fill, not colour temperature.
- Chaos/Order are distinguished by side-of-centre first, colour second.

The existing `balance_arcs.gd` and `eclipse_pips.gd` already state this property in their headers
("without relying on the Chaos/Order colours", "availability is encoded by fill as well as
colour"). Any rewrite keeps it.

### Binding rules

All of the above ships via `ds.gd` tokens + theme type variations. **Zero per-node overrides** —
the standing DS rule, no exception for gauges.

### Acceptance (Phase 3 gate)

All three gauges in one visual grammar, confirmed by design-doc screenshot review. Open call
carried into implementation: the CT disc-vs-pips question above.

## Not yet ported (tracked gaps)

- **Gradient bevel depth** — 45° corner notches are complete across the runtime theme and
  dialogue UI through 16px-margined `StyleBoxTexture` nine-patches and semantic theme type
  variations. A later texture pass may add full gradient bevel depth without changing nodes.
- **Engraved patterns** (etch/lattice/measure/resonance/brocade/weave) and the grain/vignette
  atmosphere — shader or texture pass later.
- **Remaining components:** ElementWheel, TempoTrack, AgreementReadout, MeterBar, ItemSlot/
  ItemGrid (grid inventory is confirmed), DialogueChoice, Portrait, Modal, Tooltip — port
  from `components/*/*.prompt.md` as each system lands.
- **Art:** `assets/art/` portraits (rune-knights, Sulmae, spire figures) still live in the
  DS project — bring binaries over when the dialogue/portrait UI lands.
