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
