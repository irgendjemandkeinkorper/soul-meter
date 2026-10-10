# Dom production art batch 1 — #305

Branch: `art/305-dom-batch1`, based on local main `ecc4c61d5accfb845e56fd77c5dba06b1206e745`.
Completed against the PR #310 house-style text in `docs/art-aesthetics-bible.md`;
production recipe: `e64c0801` (#309). This directory retains the requested 2026-10-09 batch name; resumed production ran on 2026-10-10.

[Contact sheet](contact-sheet.png) — seven replacement cutouts and the existing terrain plate.
The bottom strip shows the preserved scene sizes beside the 112 px adult-height reference from `globals/unit_art.gd`.
This is a headless CPU image composite, **not a rendered gameplay screenshot**.

## Changes and retained scene contract

| Replacement in assets/generated/sprites/world/ | Replaces | Scene uses | Drawn size at zoom 1 |
| --- | --- | ---: | --- |
| `dom-gate--arched.png` | `castle-kit/gate.png` | 1 | 26×46 px |
| `dom-wall--crenellated.png` | `castle-kit/wall.png` | 74 | 64×82 px |
| `dom-banner--green.png` | `fantasy-town-kit/banner-green.png` | 1 | 18×40 px |
| `dom-banner--red.png` | `fantasy-town-kit/banner-red.png` | 2 | 18×38 px |
| `dom-lantern--street.png` | `fantasy-town-kit/lantern.png` | 10 | 12×67 px |
| `dom-cart--high.png` | `fantasy-town-kit/cart-high.png` | 2 | 62×49 px |
| `dom-stall-bench--plank.png` | `fantasy-town-kit/stall-bench.png` | 1 | 38×26 px |

The gate and wall PNGs from the previous run are preserved byte-for-byte.
The remaining five PNGs were generated with the **built-in image_gen tool**, then processed with headless Godot 4.7.1.
Each final cutout is 256×256 with real alpha and a four-pixel outer margin.
The existing source alpha is retained; very low alpha noise is removed before cropping, and any vivid green fringe is keyed/despilled.
New texture import sidecars use Godot's lossless texture settings.

`world/starting_town.tscn` changes only seven texture paths and scale/offset on their 91 Sprite2D uses.
The replacement art fits the previous alpha bounds, with the horizontal center and bottom anchor preserved.
Node positions, paths, UIDs, collision, navigation, gameplay, modulation, NPC placement and adult actor scale are unchanged.
The small existing prop sizes are intentional scope preservation; the contact sheet exposes them for review.

`assets/generated/sprites/manifest.json` adds `painted_batches.dom-batch1-2026-10-09` with outputs, SHA-256 hashes, source provenance, original alpha bounds, placements and terrain verification.
`test/unit/test_starting_town.gd` covers kit removal, scene usage, alpha/hash integrity, drawn extents/anchors and terrain usage.

## Terrain plate

Existing image: `assets/generated/backgrounds/world/dom-town-terrain-v1.png`.
It is a fully opaque **2000×1200** painted plate.
`TerrainBackdrop` uses it visibly at position `(1700, 1100)`, scale `(1.8, 1.8)`, and `z_index = -15`;
the drawn plate measures **3600×2160**.
The plate was inspected and retained without regeneration or changes to its reference.

SHA-256: `5c8ba7332496c504038417b21ac8ac24b96084b67a53c6df081c9a7d463f8cd6`.

## Verification

| Check | Observed result |
| --- | --- |
| Requested kit-reference grep | **0 hits**; grep exits 1 as expected for no matches. |
| Focused `test/unit/test_starting_town.gd` suite | **5/5 passed**, 0 errors/failures/flaky/skipped/orphans; exit 0; 787 ms suite time. |
| Full headless import, after cache initialization | Exit 0, but **not clean**: sandbox TCP-listener errors, PhantomCameraManager/Pandora editor-plugin diagnostics, duplicate UID in existing test fixtures, and shutdown leaks. No remaining missing-UID/preload errors on the warm run. |
| Supplemental recovery-mode import | Exit 0; plugin diagnostics disappear, while TCP-listener, fixture UID and shutdown diagnostics remain. This does not satisfy the requested clean normal import. |
| Headless town launch, 120 frames | Exit 0, with 30 generated-NPC interaction-area errors and shutdown leaks. Running the unchanged main scene from a temporary copy produces the **identical diagnostic list**, confirming these predate the art changes. |
| Static scope/hash audit | All node positions/paths/UIDs and non-art scene properties preserved; 8 texture hashes and 5 new generation-source hashes match; all texture sidecars exist; `git diff --check` passes. |

The final test run still prints engine teardown diagnostics: 3,989 ObjectDB instances and 15 resources remain at exit. The identical diagnostics occur in the baseline town launch. The test runner reports success, not a crash, and exits 0; these diagnostics are not represented as clean teardown.

Commands executed from the worktree root:

```bash
grep -E 'castle-kit|fantasy-town-kit|nature-kit|kenney3d' world/starting_town.tscn

XDG_DATA_HOME=/tmp/codex-305-import/data \
  XDG_CONFIG_HOME=/tmp/codex-305-art/config LP_NUM_THREADS=1 \
  godot --headless --import --path .

SOUL_METER_TEST_DATA_DIR=/tmp/codex-305-tests-final-20261010 \
  SOUL_METER_HEADLESS=1 LP_NUM_THREADS=1 \
  GODOT_BIN=/home/adamjroder/.local/bin/godot \
  XDG_CONFIG_HOME=/tmp/codex-305-art/config \
  bash scripts/test.sh -a test/unit/test_starting_town.gd

XDG_DATA_HOME=/tmp/codex-305-runtime-smoke \
  XDG_CONFIG_HOME=/tmp/codex-305-art/config LP_NUM_THREADS=1 \
  godot --headless --path . res://world/starting_town.tscn --quit-after 120
```

Local diagnostic logs are under `/tmp/codex-305-import/`: `import.log` (cold), `import-warm.log`, `import-recovery.log`, `test-starting-town-final.log`, `runtime-smoke.log`, and `runtime-baseline.log`.
The cold import initialized this worktree's missing cache and briefly reported missing preloads before completing; those messages did not recur on the warm import.
**Clean-import acceptance remains unmet in this sandbox.** The art and test changes do not alter the affected editor plugins or test fixtures.

Changed files: the seven PNGs listed above and their seven `.png.import` sidecars; `world/starting_town.tscn`; `assets/generated/sprites/manifest.json`; `test/unit/test_starting_town.gd` and its `.uid`; this README; `contact-sheet.png` and its `.import`. The terrain plate is verified but unchanged.

## Rendered checks for the reviewer

Xvfb/display access is unavailable in this sandbox. These remain unverified in gameplay:

1. Open `world/starting_town.tscn` in the pinned Godot 4.7.1 editor and inspect at the normal camera zoom: the gate, border walls, shop/garrison/town-hall banners, street lanterns, carts and item-shop bench should align with their existing anchors.
2. Pan across the town and inspect foreground/background occlusion, transparency edges and the existing green save-point lantern modulation. Check that the unchanged terrain plate covers the same scene area.
3. Walk past the shop, trial hall and market props with an adult actor: confirm small-prop readability against the 112 px actor-height contract and unchanged route/interactability visibility.

## Risks and open questions

- In-game composition, filtering and y-sort remain a rendered review gate; headless results do not prove them.
- Clean normal import remains an acceptance gap because of the diagnostics above. The baseline NPC interaction-area errors also remain outside this art-only scope.
- The recovered gate/wall original generation prompts and source-image paths were not present in the resumed worktree. Their accepted final PNGs and hashes are retained, and this provenance gap is explicit in the manifest.
- No unresolved implementation choices. No commits, pushes, GitHub actions or delegation were performed.

## Generation provenance and exact prompts

All five calls used this common prompt, followed by the asset-specific `Primary request:` below.
The returned PNGs contained alpha. No CLI/API fallback was used.

```text
Use case: stylized-concept
Asset type: a single production prop sprite for Soul Meter, a 2D isometric CRPG, final transparent 256x256 PNG.
Style/medium: gothic mythopunk. Semi-realistic painterly digital illustration — closer to dark-fantasy concept art than to flat vector/pixel art or a clean 3D-kit render. Rich surface detail (wear, rust, moss, wet sheen) rendered through paint-like shading rather than flat color fills or hard cel outlines.
Lighting: dramatic, directional key light with a darker falloff/vignette around the subject. Avoid flat, evenly-lit "asset kit" lighting — every piece should look like it was lit for atmosphere, not for orthographic clarity alone. Consistent key from upper left.
Palette:
- Base surfaces: charcoal/near-black stone, blue-black masonry, wet dark iron.
- Institutional metal: iron and tarnished bronze, reserved for ceremonial/important elements (see the brazier's warm firelight accent against cold stone).
- Magic/the Wound: restrained violet, cyan, pale bone-white — used as small local accents, never an all-over glow.
- Organic life: deep moss/algae green, damp peat brown, occasional demon-heat red-orange (see Bog Wight's corrupted growth).
- Overall: desaturated and dark by default, with a small number of deliberate saturated accents per asset (fire, magic, decay) rather than broad bright color.
Composition: single isolated subject, orthographic isometric view about 45 degrees yaw and 26.6 degrees downward elevation. Full subject visible, centered, generously fills the canvas without clipping; base contact at bottom center. True transparent background if possible; if an opaque backing is required, use perfectly flat saturated chroma green (#00ff00) with no gradient and no ground shadow, for a headless Godot chroma-key pass. No checkerboard, scene, terrain, people, text, symbols, logos, watermark, captions, UI, black outline strokes, cartoon proportions or steampunk machinery. No vignette on the background.
```

### banner-green

Output: `assets/generated/sprites/world/dom-banner--green.png`

Source: `/home/adamjroder/.codex/generated_images/01a124ee-af23-75b2-be48-7b0279998094/exec-5ad5dcd3-2476-4f92-b76d-930f1890ca2a.png`

Source SHA-256: `685fd68cfbf13339d843e0d9222e4394e19ae4c17de16f8311088ef96adc97d8`

```text
Primary request: One narrow hanging GREEN civic banner, a strip of deep desaturated moss-teal woven cloth hanging vertically from a short tarnished bronze horizontal rod and two simple rings. Same practical shape as a plain narrow wall banner: mostly rectangular, small split/notched bottom, gently folded cloth; no support post, no wall. Dark stitched repair and frayed hem, subtle warm wear on the rod. No invented heraldry, runes, trim motifs or writing. The cloth must remain recognizably muted green, never neon/chroma green. Slight three-quarter turn with rod rising gently to the right, right edge of cloth visible.
```

### banner-red

Output: `assets/generated/sprites/world/dom-banner--red.png`

Source: `/home/adamjroder/.codex/generated_images/01a124ee-af23-75b2-be48-7b0279998094/exec-d1667970-4578-4942-876a-3a0e34c33423.png`

Source SHA-256: `030d9371a74c273bb8216a72bd50fd9dfed4f1ea7ebd5f0b7902e7c1b03378b0`

```text
Primary request: One narrow hanging RED civic banner, a strip of deep desaturated oxblood-red woven cloth hanging vertically from a short tarnished bronze horizontal rod and two simple rings. Same practical shape as a plain narrow wall banner: mostly rectangular, small pointed/notched bottom, gently folded cloth; no support post, no wall. Dark stitched repair and frayed hem, subtle warm wear on the rod. No invented heraldry, runes, trim motifs or writing. The cloth must remain recognizably muted crimson. Slight three-quarter turn with rod rising gently to the right, right edge of cloth visible.
```

### lantern

Output: `assets/generated/sprites/world/dom-lantern--street.png`

Source: `/home/adamjroder/.codex/generated_images/01a124ee-af23-75b2-be48-7b0279998094/exec-42c572b0-d00e-42ee-9c45-5e7dfd2cc2c0.png`

Source SHA-256: `66a0d08e2456551b546b91b02e2957556f821c50b2639ecbed53a526deb321fb`

```text
Primary request: One tall slender FREESTANDING STREET LAMP. Simple straight dark wrought-iron shaft rising from a small tapered square stone-and-iron foot, a single compact enclosed lantern mounted directly on top. The lantern has worn iron framing, a modest pointed cap and tarnished bronze fittings, softly glowing amber glass. This is a narrow municipal lamppost, NOT a hanging wall lantern, not a bracket, no cross arm. Patch-repaired damp iron, restrained gothic vertical silhouette, no ornate wings or sprawling curls, no large halo. Height much greater than width (about 7:1).
```

### cart-high

Output: `assets/generated/sprites/world/dom-cart--high.png`

Source: `/home/adamjroder/.codex/generated_images/01a124ee-af23-75b2-be48-7b0279998094/exec-6a0992e6-d7f2-49fc-81fe-f643578bd3e0.png`

Source SHA-256: `5f61e4db78a1f4f67704c88f752bccd83487503c2fad56c7e18f022c43c9c5dc`

```text
Primary request: One small EMPTY two-wheeled high-sided wooden handcart with dark scarred plank cargo bed, iron-banded side rails, two arched exposed canopy hoops with NO cloth cover, and two short forward pulling shafts. Large plain wooden wheels with dark iron rims; far wheel partly hidden. The near side and open cargo bed are visible from elevated isometric view; shafts extend toward the lower right. Repaired timber and oxidized iron, a few restrained tarnished bronze fasteners; no cargo, no produce, no sacks, no animals or people. Keep the compact utilitarian cart footprint, readable wheels and hoops.
```

### stall-bench

Output: `assets/generated/sprites/world/dom-stall-bench--plank.png`

Source: `/home/adamjroder/.codex/generated_images/01a124ee-af23-75b2-be48-7b0279998094/exec-70771ab1-dcfa-4975-828f-1a35c4cd94a6.png`

Source SHA-256: `586c9aaef95bd4b30efef3dd4f29ce2b8c9c9da33d3f1ffbebb0c3fbc0c71a79`

```text
Primary request: One low backless market-stall BENCH: a single long thick dark wooden plank seat on two short sturdy trestle supports/four stubby legs, simple worn iron brackets. Elevated three-quarter isometric view with long seat receding upward to the right, near long edge visible. Scarred damp grain, uneven worn edges, hand repairs, modest rust. No backrest, armrests, cushions, canopy, stall, extra props or clutter. A low practical bench, not a table, length about three times the height.
```


### Godot processing recipe

The batch adapter of #309's extraction/resize recipe was run from an isolated temporary Godot project under `/tmp/codex-305-art/`, avoiding game autoloads during image processing.
For each source pixel, compute `excess = green - max(red, blue)`.
Where `alpha > 0`, `green > 0.45`, and `excess > 0.18`, multiply alpha by `1 - smoothstep(0.18, 0.38, excess)` and clamp green to `max(red, blue)`.
Clear pixels with alpha below 0.04, crop to the nontransparent bounds, fit proportionally within 248×248 using Lanczos, and place on a transparent 256×256 canvas centered horizontally with its bottom at y=252.
The lantern and cart sources had 35 and 83 chroma-fringe pixels processed respectively; the other three had none.
The final output SHA-256 and alpha bounds are in the sprite manifest.

To preserve an existing sprite's drawn size, use `new_scale = old_alpha_size / new_alpha_size`.
For each placement, retain `old_bottom = old_alpha_end_y - 128 + old_offset_y`;
set `new_offset_y = old_bottom / new_scale_y - (new_alpha_end_y - 128)`.
Set `new_offset_x = 128 - new_alpha_center_x`.
These operations alter no node position.
