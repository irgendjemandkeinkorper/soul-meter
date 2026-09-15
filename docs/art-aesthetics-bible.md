# Soul Meter — Art Aesthetics Bible

**Status: ratified 2026-08-09.** Canonized from the approved calibration batch produced
by the standing Codex art fleet: `art/units-lane` commit `33b3375` (Vex the Unbowed, Bog
Wight) and `art/world-lane` commit `4ac3118` (Dom 7-piece calibration micro-set). Those
renders are the reference standard — when in doubt, compare a new asset against them
directly, not against this document's prose.

**Author update, 2026-09-10:** [Part III](#part-iii--seed-race-design-guidelines)
now governs race identity and appearance, taking precedence over older race descriptions
and character references where they conflict. This is a text guideline for the author's
3D modeling and Blender captures. The existing calibration art remains a reference for
surface treatment, palette, and lighting; its anatomy does not override the new race direction.

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
**Part III** collects the seed races' physical, tactile, and acoustic identities for
designing models. Seed races come first; the larger historical peoples inventory is
not the design roster for this pass.

## Technique

The original calibration assets were produced with OpenAI's `image_gen`. Their approval
established the painterly appearance, material weight, and atmosphere described below.

**Current race workflow, author-confirmed 2026-09-10:** the author designs and makes
3D models, then captures them in **Blender** for isometric art tokens and related uses.
This Bible supplies a coherent text reference for that work. It does not commission
image generation, model creation, renders, or an automated asset pipeline. Read
"painterly" as the desired finish of the captured art, achievable through modeling,
materials, textures, and lighting, rather than as a requirement to use text-to-image.

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

When preparing a model/design brief or an independently requested world-art batch, carry forward:
1. Subject/tile identity (canonical ID from Pandora/encounter data or the location brief).
2. Style/medium: author-made 3D race models captured in Blender, with a semi-realistic,
   painterly finish, isometric single-subject composition, and transparent background.
   Follow Part III for race anatomy; use this part for the shared material and lighting language.
3. Lighting: one consistent directional key light + dark falloff, matching the family's
   established light direction.
4. Palette: pull the relevant lines from the Palette section above — never leave palette
   unconstrained.
5. Avoid-list: pure-black outlines, flat/even lighting, cartoon/chibi proportions, bright
   generic high fantasy, steampunk-dominant material language, baked text/UI.
6. Reference: use the approved commits above for finish and atmosphere. For race identity,
   the author's Part III corrections take precedence over older images and briefs.

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

---

# Part III — Seed-race design guidelines

**Direction supplied by the author, 2026-09-10.** This section coalesces the author's
*The Races of Dramgid: Seed and Elder Lineages* text and accompanying appearance
corrections into a reference for designing 3D characters. The purpose is to keep each
race's shape, material, movement, and cultural expression coherent while the author
models it and later captures it in Blender.

The explicit appearance decisions and lineage facts below come from the author.
**Design reading** identifies an interpretation to guide exploration, not newly fixed
anatomy. **Open** identifies decisions the source does not yet supply. Fantasy labels
such as elf, orc, smallfolk, genasi, tiefling, and dragonborn are orientation aids;
the author intends these peoples to look substantially different from stock fantasy races.

## Scope and precedence

**Seed races first: nine in total, author-confirmed 2026-09-10.** The complete roster
is **Vael (Solan), Kes'reth, Orthos, Vaerin, Kaan, Shimari, Weftkin, Fiel, and Ghorr**.
Vael and Solan name the same people and count as one lineage. These nine lineages
form the nine-part harmonic cycle and the Great Chord.

**Mirror-Veil is dropped.** Do not develop mirror-bodied Kes'reth, a reflective branch,
paired mirror scars, or a Mirror-Veil variant. Older Serai-Lun art and the former
two-branch scheme do not establish current race appearance. The supplied Kes'reth
entry is the starting point; dropping Mirror-Veil does not itself decide a character's
replacement identity or require a game-data migration.

This author direction overrides conflicting race facts in the
[earlier source survey](briefs/race-appearance-source-survey.md), the sibling vault,
and older game art briefs for this design work. In particular, **Orthos are Puer's
Witnesses/Dragonborn**, **Shimari carry Iris's mycorrhizal inheritance**, **Weftkin
carry Osse Vaal's biological/signal inheritance**, and **Fiel carry Yungmi's
envy-to-generosity inheritance**. Do not fall back to the earlier assignments.
**Solan are Vael**, explicitly confirmed by the author. This shared identity carries
the Kalyi/Certainty-Bearer foundation below; the older vault's different Vael founding
assignment does not override it.

## The shared foundation: the Forge Principle

Balance is not peace. In the supplied account, the Bloom at Year 0 was an acoustic
cataclysm ending the QUINE epistemic framework: 80% of humanity was unmade through
the de-resolution of biological frequencies, while the surviving 20% were rewritten
through the Founding Seeds. Baes Kuchnik anchors the Acoustic Understanding and
holds the memory of that toll; the seeds' virtues and sins become tactile and tonal
inheritances in the new peoples. Preserve the stated **Spindle-VI** origin of Osse
Vaal even though the broader account centers the **Spindle-VII** crew.

For design, a race's inheritance should inform a consistent relationship between its
body, its characteristic rhythm, and what the Waning takes from it. A sound is not
automatically a visible aura, musical notation, or ornament. It can inform how weight
settles, hands move, surfaces feel, garments hang, and tools are used. These are
design readings to explore, not requirements to give every individual the same
occupation, temperament, costume, or stage of illness.

## The named seed lineages

### Vael (Solan) — The Certainty-Bearers

**Author foundation:** Kalyi's cold leadership, formal logic, and synthesis-bridge
architecture. Their acoustic signature is a persistent high-frequency **B-flat**,
the resonance of QUINE's crystal substrate. As the Weft thins, tactile rigidity
fails; structures soften into tonal instability and star-tech memories become static.

**Design reading:** explore controlled, deliberate construction and the tactile
difference between something that holds its form and something losing that certainty.
The material story is rigidity becoming unstable. This does not yet prescribe a
crystal body, a machine body, or ordinary human anatomy.

**Open:** silhouette, bodily substrate, facial structure, proportions, surface palette,
and how loss of rigidity reads on a living person. The acoustic B-flat has no assigned
color. Solmarch's association with Hard Certainty can inform culture without settling biology.

### Kes'reth — The Ashborn

**Author foundation:** Nole's physician-like detachment, the "armor of apathy," and
the clinical tally of the dead. Their sound is the measured count of **169 names**
in a low monotone. Their **Clinical Heat** becomes slow, ashen combustion as the
Waning consumes their forms. The supplied tiefling/Ashborn identity retains the
horned point of reference; the Mirror-Veil branch is removed.

**Design reading:** let the contrast between bodily heat and controlled bearing guide
the design. Heat, ash, and endurance can be conveyed through material and posture
without making every healthy Kes'reth an actively burning body. The count of names
is an acoustic inheritance, not a requirement to engrave 169 marks onto every model.

**Open:** horn arrangement, face, build, skin and ash palette, tail/feet anatomy, and
the healthy-to-combusting transition. The older ash-to-red skin range is historical
reference, not a newly confirmed restriction.

### Orthos — The Witnesses / Dragonborn

**Author foundation:** **Puer**, the pilot; spatial awareness and rhythmic navigation
of darkness. The **Left-Right double-tap heartbeat** synchronizes with Dramgid's
orbit. Waning-induced temporal drift traps them in **six-minute** ancestral trauma loops.
Their supplied bodily reference is **Dragonborn**.

**Design reading:** develop a distinctly Dramgid draconic humanoid whose bearing can
suggest orientation, balance, and a repeated left/right cadence. A designed pose or
gesture may carry that rhythm; it need not become visible clockwork. The older
Kalyi/synthesis-frame account is not the basis for their anatomy in this pass.

**Open:** head and muzzle, scales or other surface, horns, tail, limb proportions,
and how strongly draconic the body reads. Wings and flight are not established by
the label. Temporal drift is a condition, not a requirement for a permanently distorted mesh.

### Vaerin — The Archivists

**Author foundation:** **Reth's greed for truth**, archiving at the biological self's
expense. Their acoustic identity is the tactile rustle of vellum and the Silver
Scriptorium's absolute archive silence. Losing or destroying an archived record
audibly removes **one year of life** into silence. The supplied orientation is elven.

**Design reading:** explore the tension between preservation and bodily expenditure:
careful handling, protected surfaces, and a material language that values records.
Vellum can inform texture or clothing studies without making their skin literally paper.
The absence of sound is part of their identity; a glowing archive effect is unnecessary.

**Open:** the distinctive anatomy that takes them beyond conventional elves, including
ears, facial proportions, build, palette, and any visible consequence of lost lifespan.
Age loss does not by itself establish transparency, spectral bodies, or a fixed wrinkle pattern.

### Kaan — The Deepkin

**Author foundation:** **Dieters's geological patience**, finding settled truth in
wreckage. Their signature is tectonic grinding and geothermic resonance. Without
the Weft's binding, they revert to **inert, non-sentient rock**. The supplied dwarf
orientation and compatible older stone-fused description provide starting context.

**Design reading:** material weight and settled structure should matter when exploring
their bodies. Consider how their chosen anatomy bears loads and how a living surface
differs from the inert rock it can become. Fungal symbiosis from the historical
Deepkin account should not replace this stone-centered identity.

**Open:** body proportions, mineral coverage and type, exposed flesh, hair/beard
structure, joint behavior, and the progression from healthy body to inert stone.
Specific minerals and an almost entirely stone body remain design choices.

### Shimari — The Sporeborn

**Author foundation:** **Iris's mycorrhizal communion** and search for the erased bond.
Their sound is a warm, haptic growth-cycle drone, the **Melody of the Spore**. As the
Loom's filter fails, they are prematurely reabsorbed and composted by the fungal mass.
The supplied labels are Sporeborn/Genasi.

**Design reading:** give communion, living fungal material, and the boundary between
individual and surrounding growth a coherent expression. This is the roster's explicit
mycorrhizal inheritance. “Genasi” does not require a standard fire/water/earth/air palette.

**Open:** face and limbs, cap or capless body, fungal structures, texture and color,
and how reabsorption differs visibly from a healthy person. A mushroom head, exposed
bone frame, or permanent attachment to terrain has not been selected.

### Weftkin — The Signal-Seekers

**Author foundation:** **Osse Vaal of Spindle-VI**, caught between biological life and
signal. Their acoustic vocabulary is Morse-code flicker and a leading note that
never resolves. Severance from the Underweave leaves hollow **shadow puppets** without
voice or signal.

**Design reading:** explore the coexistence of a biological person and an interrupted
signal. The incompletion can inform rhythm, gesture, or a restrained surface treatment;
it does not require holograms or an electronic screen for a face. Keep their design
distinct from Shimari's mycorrhizal communion rather than reusing the old all-fungal
Weftkin template automatically.

**Open:** healthy anatomy and material, how signal is sensed or expressed, and the
literal versus figurative appearance of the severed shadow-puppet state. Healthy
Weftkin are not defined as already hollow or voiceless.

### Fiel — The Liberated

**Author-fixed appearance:** **monkey–turtle hybrid humanoid folk**. This replaces
generic smallfolk as the useful visual starting point. The source still supplies
Smallfolk as a label, but no exact height is fixed.

**Author foundation:** **Yungmi's envy transformed into generosity**. Their sound is
the **Whistlebox trill** and a mother's Zindari death-lullaby. As reality hardens,
they become physically shackled by their own skin.

**Design reading:** both monkey and turtle ancestry should be legible in the body
design, beyond clothing or a carried prop. Explore the relationship between mobile,
expressive anatomy and a protective or resistant surface. Loss of flexibility gives
the Waning a direct tactile contrast with healthy movement.

**Open:** distribution of primate and chelonian features, shell presence and shape,
fur/scales/skin, tail, hands and feet, facial structure, and relative size. Do not
silently select a full carapace, prehensile tail, or a fixed locomotion pattern.

### Ghorr — The Bloodbellows

**Author-fixed appearance:** **four arms**, an **almost ursine** body, and warthog-like
facial character, using the author's remembered Star Wars cantina/bounty-hunter image
as loose visual context. The exact screen species is not identified; the useful
direction is the bear-like mass and warthog-like character, not a copied costume.
The “orc” label must not pull the design back to a conventional two-armed orc.

**Author foundation:** **Strauss's martial discipline and wrath survived**. Their
signature is the **Bloodbellows roar** and rhythmic storm-forged shield beating.
The Waning makes their bodies **heavy and brittle**, unable to bear the burdens
they were made to hold.

**Design reading:** resolve a credible four-arm torso, shoulder organization, and
space for all four arms to move. Preserve readable arm separation in isometric
views; bear-like mass should not turn the lower pair into unreadable stubs. Clothes,
harnesses, and tools need to fit this anatomy. Explore breath, chest, and stance
as part of the Bloodbellows identity without prescribing every Ghorr as a soldier.

**Open:** placement and relative size of the two arm pairs, hand anatomy, fur coverage,
snout and tusks, leg posture, relative scale, and surface palette. The warthog reference
does not yet fix a particular tusk pattern. Brittle decline is a separate state from
the healthy body's capacity to carry weight.

## Acoustic relationships to keep in mind

These relationships are supplied world context. Their translation into pose, material,
or composition remains a design reading; they are not a new combat-system specification.

| Relationship | Supplied effect | Use in visual thinking |
|---|---|---|
| Ghorr → Orthos | Bloodbellows disrupts the double-tap synchronization and causes temporal disorientation. | Contrast Ghorr's forceful rhythm with Orthos's ordered cadence; avoid making their rhythmic identities interchangeable. |
| Vael (Solan) → Fiel | Rigid B-flat conflicts with the Whistlebox and physically shackles Fiel. | Keep Vael's rigidity and Fiel's threatened mobility distinct in form and movement. |
| Shimari + Vaerin | Haptic drone harmonizes with archive silence. | Compatible tactile restraint can connect them without erasing fungal versus archival identity. |
| Kaan + Kes'reth | Geothermic hum stabilizes the measured 169-name count. | Explore complementary weight, heat, and controlled pacing without assigning shared anatomy. |
| The Great Chord | All nine seed-race signatures align to resolve the “M” of Maiiam and briefly stabilize the Waning. | Treat the nine lineages as a complete harmonic ensemble while preserving each one's distinct identity. |

## Elder peoples and other context — later design work

**Giants and Goliaths** are the Verspch builders: elder peoples outside the seed logic,
storm-callers and drum-namers following Ofshütje, the Thunder-Bearer. **Dragons** are
will-fed, distinct from the belief-fed Ten and function-fed örlaganna; the supplied
account places them in older hierarchies and alongside Vael (Solan) in Solmarch's Hard
Certainty architecture. Giants, Goliaths, and Dragons are outside the nine seed lineages.

**Baes Kuchnik** is the Forge catalyst and the sole remaining truly biological human
in the supplied account. Formerly Rhea and the origin point for Maiiam, she maintains
LOG-OB and Auntie-Synth and holds the memory of the 80% toll. She is an individual,
not a generic human population template or a seed race.

Other peoples in the historical survey remain outside this initial seed-race design
pass. Their absence from this pass does not establish their deletion from the world.

## Applying the guideline while modeling

1. **Establish the body first.** Keep fixed anatomy distinct from exploration: four arms
   for Ghorr and the monkey–turtle hybrid for Fiel are author decisions; unresolved
   tails, horns, shells, scale bands, and palettes are still design work.
2. **Separate identity layers.** Race supplies anatomy and inheritance. Culture,
   occupation, age, personal history, equipment, and Waning condition add variation.
   A biological horn, shell, or fungal feature is not inherently corruption.
3. **Check the intended view.** Examine the model's silhouette from the eventual
   Blender isometric capture angle. Keep identifying forms and limb separation visible
   as the image shrinks. Existing export dimensions are integration context, not a
   reason to flatten meaningful differences in body size or proportion.
4. **Keep a common material world.** Use Part I's wear, weight, restrained accents,
   and lighting across very different bodies. The palette describes the shared scene;
   it does not settle every race's skin color or require every person to wear armor.
5. **Record decisions as they are made.** Add chosen proportions, surfaces, palette,
   body variation, and garment accommodations to the relevant entry, with the author
   decision distinguished from an exploratory interpretation. The deliverable remains
   a coalescing text guideline for the author's modeling work.
