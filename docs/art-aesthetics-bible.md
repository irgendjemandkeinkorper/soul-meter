# Soul Meter — Art Aesthetics Bible

**Status: ratified 2026-08-09.** Canonized from the approved calibration batch produced
by the standing Codex art fleet: `art/units-lane` commit `33b3375` (Vex the Unbowed, Bog
Wight) and `art/world-lane` commit `4ac3118` (Dom 7-piece calibration micro-set). Those
renders are the reference standard — when in doubt, compare a new asset against them
directly, not against this document's prose.

This supersedes the flat Kenney-derived look as the **target aesthetic** for new units,
props, and terrain. It does not retroactively invalidate the existing Kenney-sourced
tileset (`assets/generated/sprites/ground/ground_tileset.tres`) or the deterministic
3D-render pipeline (`tools/render_isometric_sprites.gd`) — those remain in place and in
use until a follow-up batch restyles them to match (see "Known gap" below). `art-request.md`
remains the authoritative brief for *what* to produce; this document governs *how it
should look*.

Everything above the Part II rule governs **world art** — units, props, terrain. **Part II**
(added 2026-09-07, #296) governs **UI chrome** and holds the per-asset-class prompt templates the
generated-art pipeline calls. A chrome asset takes its rules from Part II and its house style from
Part I; it does not take Part I's painterly rendering, which is why icons are flat.

## Technique

These assets were produced with OpenAI's `image_gen` (text-to-image), **not** the
project's deterministic GLB→PNG isometric renderer. That is a deliberate, approved
departure for this style tier: the painterly result is what got approved, and
`render_isometric_sprites.gd`'s flat-lit 3D-kit look was not. Future UNIT and
WORLD/TERRAIN batches should default to `image_gen` for this style unless a specific
asset genuinely needs the deterministic renderer's guarantees (e.g. an asset that must
be procedurally regenerated from a parametrized 3D source).

Standing constraints carried over from the render pipeline (do not relax these just
because the technique changed):
- Isometric single-subject framing: one subject/tile per image, camera reads as
  top-down/isometric, not a flat side-on illustration.
- 256×256 output, transparent background.
- Bottom-center/feet (or base-of-object) ground contact point for correct y-sorting.
- 64×32 world-tile seam convention for ground pieces.

## Visual language

**House style, in two words: gothic mythopunk.** Gothic for the forms — verticality,
carved stone, tarnished ceremonial metal, wear and weight on everything. Mythopunk for
the attitude — a mythic world that has been lived in, patched, and repurposed; sacred
objects put to daily use, myth-tech seams showing. When a Kenney or 3D-kit source asset
is retooled (batches #305, #309), keep its subject and footprint and re-read it through
this lens rather than cleaning it up. Every prompt should name the style with these two
words before the Palette and Lighting text below.

**Rendering style:** semi-realistic painterly digital illustration — closer to dark-
fantasy concept art than to flat vector/pixel art or a clean 3D-kit render. Rich surface
detail (wear, rust, moss, wet sheen) rendered through paint-like shading rather than flat
color fills or hard cel outlines.

**Lighting:** dramatic, directional key light with a darker falloff/vignette around the
subject. Avoid flat, evenly-lit "asset kit" lighting — every piece should look like it
was lit for atmosphere, not for orthographic clarity alone.

**Palette** (consistent with `art-request.md`'s existing palette section — this batch is
the visual proof of it, not a departure):
- Base surfaces: charcoal/near-black stone, blue-black masonry, wet dark iron.
- Institutional metal: iron and tarnished bronze, reserved for ceremonial/important
  elements (see the brazier's warm firelight accent against cold stone).
- Magic/the Wound: restrained violet, cyan, pale bone-white — used as small local
  accents, never an all-over glow.
- Organic life: deep moss/algae green, damp peat brown, occasional demon-heat red-orange
  (see Bog Wight's corrupted growth).
- Overall: desaturated and dark by default, with a small number of deliberate saturated
  accents per asset (fire, magic, decay) rather than broad bright color.

**Character design language** (from Vex, Bog Wight):
- Semi-realistic proportions, not cartoon/chibi. Weight and presence over cuteness.
- Corruption/wrongness communicated through texture and silhouette breaks (horns, claws,
  moss/root growth breaking through form) rather than bright VFX.
- Readable silhouette even with heavy surface detail — the outer shape stays legible at
  a glance; detail lives inside it.
- No pure-black sticker outlines; edges are defined by lighting contrast instead.

**Environment/prop design language** (from the Dom set):
- Individual hero-quality objects (crate, brazier, wall facade) rendered with the same
  painterly material richness as characters — props are not lower-effort than units.
- Ground tiles (paving, wet road, mud edge, puddle) keep the same palette and lighting
  logic as props, so a scene built from both reads as one world, not two art styles
  stitched together.

## Applying this to town/terrain layouts

- When batching a new location (Dorthkor Road, Loamroot Grove, Jawbrace, etc.), generate
  ground tiles and props from the *same* lighting/palette brief so a composed scene reads
  as one continuous lit environment, not a patchwork. Reissue this document's palette and
  lighting section verbatim with every new batch rather than relying on agent memory.
- Adjacent ground tiles must still satisfy the 64×32 seam contract — painterly detail
  cannot be an excuse for shimmering or misaligned edges. Validate seams with a real
  edge-to-edge contact sheet (as the Dom batch did) before accepting a terrain family.
- Prefer a small, consistent light direction across an entire location's asset family
  (do not let each tile pick its own key-light angle) so nothing looks pasted in.

### Field-scene dressing contract

Sparse field scenes use the same restrained three-layer composition established by
Wound Lip and Dorthkor Road: flat `GroundDetails` below actors, non-colliding
`SoftDetails`, and small-footprint colliders in `SolidProps`. The scene root, soft
layer, and solid layer y-sort actors against standing art; ground decals remain
unsorted at `z_index = -2`. Keep primary routes, spawn points, interactions, and
travel triggers visually readable rather than filling every empty patch.

Before placing an existing texture, verify that it contains meaningful alpha instead
of an opaque white plate. Scale large painted sprites independently; collision shapes
represent only the prop's contact footprint, never its full illustration frame.

## Known gap — CLOSED 2026-08-31

The Dom contact sheet (`assets/generated/sprites/world/dom-calibration-contact-sheet.png`)
originally showed the new painterly props sitting above the **flat Kenney-derived ground
tileset** (grass/dirt/stone/road), and the style break between the two rows was visible
and real. That mismatch is resolved: commit `d4b87e2` replaced the atlas backing
`assets/generated/sprites/ground/ground_tileset.tres` with painterly ground tiles in this
direction. New ground work extends that atlas; there is no longer a second style to
avoid blending with.

## Brief scaffold for future agents

When tasking a new UNIT or WORLD batch, carry forward:
1. Subject/tile identity (canonical ID from Pandora/encounter data or the location brief).
2. Style/medium: "semi-realistic painterly digital illustration, isometric single-subject
   composition, transparent background" (not "pixel art," not "flat vector," not "3D
   render kit").
3. Lighting: one consistent directional key light + dark falloff, matching the family's
   established light direction.
4. Palette: pull the relevant lines from the Palette section above — never leave palette
   unconstrained.
5. Avoid-list: pure-black outlines, flat/even lighting, cartoon/chibi proportions, bright
   generic high fantasy, steampunk-dominant material language, baked text/UI.
6. Ground-truth reference: point the agent at the two approved commits above as the
   literal visual target, not just this prose description.

---

# Part II — UI chrome and the image-prompt bible

**Added 2026-09-07 (#296, ship milestone).** Part I above governs *world* art — units, props,
terrain. Part II governs *chrome* — the frames, plates, icons, and marketing art the interface is
made of — and gives the per-asset-class prompt templates the generated-art pipeline (#298) calls.

The reference is `design/reference/tactical-ui-style-board.png`, approved by the owner 2026-09-04
as the ship-milestone visual target. **It is a style reference, not a layout spec.** Take its
material language, palette, and type treatment; do not take its screen layout — layout is owned by
`design/ui-shell-conventions.md` and the six-region `BattleInterface` contract, which is frozen.

## Read the board correctly

Three things on the board are already out of date or out of scope. A worker who copies it
literally will introduce all three.

1. **`SCOR` is a dead element id.** The board predates the wheel rename (`f5d7e24`, #371). Its
   ember-labelled ability and its `SCOR` tags are today's **Khash**. The full map lives in
   `SaveMigrations.ELEMENT_RENAMES_V8`; the three that matter for colour work are
   `scor → khash`, `aqua → luth`, `strom → zhur`. **`VICOAR` is current** — Vicoar is a live
   patron (`design/god-aesthetic-style-guide.md` §6), not a renamed element.
2. **The board is gamepad-native.** Its `A` / `Y` / `B` / `RB` / `L` / `R` badges are not our
   input model: the ship plan is keyboard + mouse. Generated chrome must not bake controller
   glyphs. Where the board shows a badge, we show a key cap or nothing.
3. **The board bakes text into the image.** Generated assets never do — every string on screen is
   a real, translatable `Label` going through the PO pipeline. Baked lettering in a generated
   plate is a defect, not a style choice.

## The chrome palette, in existing DS tokens

**No new tokens.** Every colour the board uses maps onto something `ui/theme/ds.gd` already ships.
Prompts cite the hex; code cites the token.

| Board element | DS token | Hex |
|---|---|---|
| Panel ground, deepest | `VOID_1` | `#0C0E12` |
| Panel ground, raised plate | `STONE_0` / `STONE_1` | `#12151B` / `#1B1F27` |
| Carved bevel, inner shadow | `VOID_0` | `#07080B` |
| Hairline rule, unemphasised | `IRON_2` / `IRON_3` | `#4E5665` / `#6B7484` |
| Hairline rule, emphasised; selection | `BRONZE_1` → `BRONZE_3` | `#946B2D` → `#D9AB45` |
| Header caps | `PARCHMENT` | `#E2E8F0` |
| Subtitle / secondary caps | `ASH` / `ASH_DIM` | `#94A3B8` / `#64748B` |
| Ember accent (the board's "SCOR") | `DS.WHEEL` **khash** | `#E0522F` |
| Cold accent, ally / move range | `DS.WHEEL` **luth** | `#2E8FB8` |
| Cold accent, bright / charge | `DS.WHEEL` **zhur** = `MOTE_3` | `#22D3EE` |
| Threat / enemy tint | `CINDER_2` | `#991B1B` |

Type is unchanged and not negotiable: `FONT_DISPLAY` (Cinzel) for tracked uppercase headers and
buttons, `FONT_BODY` (Cormorant) for prose, `FONT_NUMERIC` (Fira) for **numbers only** — the board
is right that every readout is tabular and right-aligned, and the DS already says numerals are the
ledger, not the interface.

## The five chrome elements

Everything on the board is one of five things. Generated art produces the *materials* for these;
`#297` assembles them as 9-patch `StyleBoxTexture`s and theme type variations.

1. **The plate.** A dark slab of carved stone or blued iron, matte, with a shallow bevel and a
   45° corner notch — the notch is already the runtime theme's corner treatment, so the generated
   plate must respect it rather than round the corner. Interior is nearly flat so text stays
   legible; all the interest is at the edge.
2. **The rule.** A hairline separating a header from its body, or a plate from the ground. One
   pixel of warm metal, not a gradient bar. It is the single most repeated mark in the interface
   and the cheapest thing to get wrong: too bright and the screen turns to graph paper.
3. **The seal.** A circular or diamond relief medallion — the board's top-right emblem and its
   `FORGED` plinth. This is the only chrome element allowed real dimensional rendering, and it is
   reserved for *moments* (a mastery award, a chapter stamp), never for routine controls.
4. **The glyph.** A flat, solid-fill icon in `PARCHMENT` on a dark plate, readable at 24 px. Icons
   are **not** painterly — they are the one asset class that deliberately does not follow Part I's
   rendering style, because a painterly 24 px icon is mud. Silhouette first; no internal shading;
   no outline.
5. **The tint.** A tile or cell overlay: a flat wash plus a one-pixel rim, at low alpha. `DS`
   already ships the helper (`element_tint`) and the cursor rim.

## Where the board and the shipped design system disagree

Two collisions. Both are named here rather than resolved, because both are the owner's call and a
worker guessing either way produces work that has to be redone.

**1. Bronze.** `design/DESIGN_SYSTEM.md` reserves bronze for the Soul Meter — *"it is ledgered,
not magical … Vär and Balance never take bronze"*, the rule that keeps the title mechanic the most
valuable pixel on screen. The runtime theme honours this almost absolutely: `BRONZE_3` appears
exactly once in `ui/theme/theme_builder.gd`, on one header colour. The board instead makes bronze
the **primary chrome accent** — every rule, every selected card, every button edge.

Both cannot be true. The recommendation is to **split the ramp rather than the rule**: chrome
takes the dim end (`BRONZE_0`/`BRONZE_1`, `#5E4415`/`#946B2D`, reading as tarnish) and the Soul
Meter keeps the lit end (`BRONZE_3`/`BRONZE_4`) alone. That preserves the board's warmth and the
DS's reservation, and it costs no new token. **It is not ratified** — `#297` should not ship a
full-bronze chrome pass until it is.

**2. Selection colour.** `DS.TILE_SELECT_RIM` is `#D6B4FF`, the khor glow, and its comment says
the DS reuses it as the cursor rim. The board's selection rim is gold. The narrow reading, and the
one this document assumes until ruled otherwise, is that they are different jobs: violet is the
*grid cursor* (a world-space object, elemental), gold is the *UI selection* (a chrome-space state,
metallic). If they are meant to be one thing, the DS token wins and the board loses.

## Image-prompt bible

For the Gemini image API pipeline (`#298`). Every call passes
`design/reference/tactical-ui-style-board.png` as a reference image **for chrome classes**, and
the Part I approved commits as reference for world classes. Never both — mixing a painterly unit
reference into an icon prompt is what produces muddy icons.

### The shared preamble

Prepend verbatim to every chrome prompt:

> Gothic mythopunk game interface art. Dark carved stone and tarnished bronze; matte, worn,
> weighty. Desaturated near-black ground (#0C0E12) with warm metal edges. One directional key
> light from upper left, deep falloff. No text, no lettering, no numbers, no logos, no watermark.
> No controller button glyphs. Transparent background. Match the material language of the
> reference image; do not copy its layout.

The avoid-list is as load-bearing as the description. Append verbatim:

> Avoid: bright saturated colour, neon, glossy plastic, chrome sheen, clean modern UI, flat
> vector, pixel art, steampunk gears, rivets as decoration, cartoon proportions, drop shadows,
> rounded corners, gradients across a whole panel, baked text.

### Per-asset-class templates

`{…}` are the only fields a worker fills. Everything else is fixed.

**Panel plate** (→ 9-patch, `#297`)

> {preamble} A single rectangular interface plate, {WIDTH}×{HEIGHT}, seen straight on with no
> perspective. Carved dark stone face, nearly flat and unornamented in the centre so text can sit
> on it. Shallow bevelled edge catching a thin warm highlight; 45-degree chamfered corners. A
> one-pixel tarnished bronze hairline inset from the edge. Uniform border thickness on all four
> sides so the image can be sliced as a nine-patch.

Nine-patch is the constraint that kills most generations: the border must be *uniform* and the
centre *empty*. Reject anything with a feature in the middle of the plate.

**Icon / glyph** (→ ability, item, status; 24–64 px use)

> {preamble} A single flat interface icon of {SUBJECT}, solid warm off-white (#E2E8F0) on
> transparent. Bold simplified silhouette readable at 24 pixels. No internal shading, no gradient,
> no outline, no perspective, no background plate. One clear shape, centred, with generous margin.

Icons are the class most likely to arrive painterly because Part I's house style pulls that way.
The preamble alone does not stop it; the "flat, solid, no shading" clause must stay.

**Seal / medallion** (→ mastery stamps, chapter marks, achievement art)

> {preamble} A circular relief medallion of {SUBJECT}, cast in tarnished bronze over blued iron,
> seen straight on. Deep carved relief with real dimensional shadow. A ring of plain raised metal
> at the rim — no runes, no lettering. Ember light (#E0522F) pooling in the recesses only.
> Centred, symmetrical, transparent background.

The seal is the one chrome class allowed to be dimensional. Keep it rare or it stops meaning
anything.

**Element tint plate** (→ tile and cell overlays)

> {preamble} A seamless 64×32 isometric diamond tile overlay, flat translucent wash of {HEX} at
> low opacity with a one-pixel brighter rim of the same hue. No texture, no noise, no gradient —
> it sits over painted ground art and must not compete with it.

`{HEX}` comes from `DS.WHEEL` by element id — post-rename ids only (`khash`, not `scor`).

**Portrait** (→ `assets/generated/portraits/`, extends Part I)

Part I already governs these and 88 exist. The only chrome addition: the frame is separate art.
Generate the bust on transparent, never with its frame attached, so the frame can be re-themed
without regenerating 88 portraits.

> {Part I unit preamble} Bust portrait of {SUBJECT}, head and shoulders, three-quarter view,
> looking slightly off-camera. Semi-realistic painterly digital illustration. Transparent
> background, no frame, no border, no vignette, no text.

**Steam capsule** (→ `#303`, store page)

The one class that breaks every rule above, deliberately: it is marketing art, not chrome, and it
is the only place baked text is correct — but the wordmark is composited in a layout tool
afterwards, not generated.

> {Part I unit preamble} Key art for a dark tactical fantasy RPG. {SCENE}. Semi-realistic
> painterly digital illustration, cinematic composition, dramatic directional light with deep
> shadow. Desaturated charcoal and blue-black palette with a single warm ember light source.
> Clear negative space in the {upper third | left third} for a title treatment. No text, no logo,
> no watermark, no border.

Steam's capsule set needs several aspect ratios from one scene; generate the widest first and let
the layout crop, rather than re-prompting per size and getting four different paintings.

### Acceptance

A generated chrome asset is accepted when all four hold:

1. It sits against a real screenshot of the shipped theme without a visible style seam.
2. Its palette resolves to the token table above — no colour that is not already in `ds.gd`.
3. It carries no baked text, no controller glyph, and no dead element id.
4. For plates: it slices as a nine-patch with a uniform border and an empty centre.

Failing 2 is the common one, and it is not a matter of taste: a colour that is not a token cannot
be themed, so it will drift the first time anything else changes.
