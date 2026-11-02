# Lived-in maps — plan (2026-11-02)

Owner request, 2026-11-02: "overhaul the look and assets of the map to make it match up WAY
more with fallout style maps. We will need a ton of small little details assets, little
greeble style filler assets to make the world start feeling lived in and real."

Rulings (asked in session; all the recommended options):

| Question | Ruling |
|---|---|
| How the greebles are made | `painterly batch via Codex`: the Dom props pipeline (built-in image_gen → alpha cleanup → 256 px sprites). The owner approves the asset list first and the finished sprites after (art bible Part III: batch approval and asset approval are separate). |
| First map | `Kesselford, then roll out`: the 5v5 demo's arena sets the look; other exteriors, then interiors, follow with the same kit and tool. |
| Density | `dense; small decor walkable`: Fallout-level clutter. Small greebles are walk-through decor; bigger pieces (crates, carts, barrels) are solid and give cover. Paths, doors, spawns and interactables stay clear. This replaces the art bible's "restrained" field-dressing rule. |
| Palette | `keep our gothic palette`: borrow Fallout's density, ground variety and lived-in clutter; keep the ratified colours, light and finish (art bible Part I). |

What we borrow from Fallout is a way of composing a map, not its art: every wall has
something leaning on it, the ground changes underfoot, paths read as worn, and small objects
tell you who lives there. Nothing here copies a Fallout asset, layout or setting.

## What is wrong today (Kesselford, `docs/qa/combat-polish-2026-11-02/01-…`)

1. **One ground for the whole town.** The visible ground is a single painted backdrop,
   `dom-town-terrain-v1.png`, reused from Dom and scaled 1.6×. The tile layers are invisible
   and only feed navigation. Every stretch looks the same.
2. **Nothing at the wall bases.** About 38 dressing sprites on a 105×105-cell map; long empty
   stretches between buildings.
3. **Stamped paving.** The ford road is eight identical cobble diamonds in a row, not a road.
4. **Props float.** No contact shadows, so nothing sits on the ground.
5. **Scale drifts.** Props are not sized against the 112 px adult (owner playtest, 2026-11-02;
   interiors already ruled `all interiors`).

## Slices

Each slice is its own commit with tests and rendered captures. M1–M3 need no new art and
start now. M4 waits for the asset-list approval, and its sprites for the finished-asset
review.

| # | Slice | What it does |
|---|---|---|
| M1 | **Contact shadows** | Every standing dressing sprite gets a soft ground shadow sized to its footprint (one shared procedural texture, no per-node theme). Existing props included. |
| M2 | **Scale table** | Each dressing texture gets a height class (small 0.3 m, knee 0.6 m, waist 1 m, head 1.8 m, building) in one table; placement scales it against the 112 px adult. Fixes existing exterior props; interiors follow in the roll-out. |
| M3 | **Dressing tool** | Cluster recipes in the existing pattern format (`globals/layout_patterns.gd`, schema 1, promoted to `res://weftlumin/patterns/`). A seeded scatter tool stamps them by rule: wall bases, doorsteps, yards, path edges, open ground. It keeps clear zones around doors, spawns, interactables, travel exits and the main routes. It writes a **generated dressing scene** per location (`world/dressing/<location>_lived_in.tscn`), and the canonical scene instances it once. The legacy bake is never run over a canonical map (`docs/layout-mode.md`). Solid pieces mark Blocking cells, and waist-high ones Terrain cover, so walking, pathfinding and combat agree. |
| M4 | **Greeble batch** | The ~84 assets below, in four Codex image_gen batches, through `tools/extract_generated_alpha.gd` and `tools/prepare_prop_assets.gd`, each with a `batch.json` provenance file like `dom-props-2026-10-02`. Ground first (largest visual win), then wall bases, yard and street, growth and small stories. |
| M5 | **Kesselford dressed** | The tool dresses Kesselford with the new kit: route-aware ground patches and a continuous ford road, then clusters. Target about 300–400 dressing nodes, up from 38. Hand-tuned after. The 5v5 demo must still seat both lines and path cleanly. |
| M6 | **Roll-out** | Other exteriors, then interiors with the 112 px rescale. Each location is its own PR. |

## Built for Kesselford (2026-11-02, PR #565)

M1–M5 are built for Kesselford. Evidence: `docs/qa/lived-in-2026-11-02/` (before/after
captures, four contact sheets, the scale sheet).

| # | As built | Differs from the plan |
|---|---|---|
| M1 | `world/dressing/dressing_shadows.gd` draws one soft contact shadow per visible standing sprite in a dressing layer, generated and old props alike. Sprites taller than 220 px (building facades) are skipped. | — |
| M2 | `world/dressing/prop_scale.gd`: small 24, knee 42, waist 64, head 108, tall 150 px against the 112 px adult; ground decals by width. The three oversized old props are rescaled: the flood-bell sign ×0.52, the mender stone ×0.71, the chandlery bench ×0.4. | Adds a `tall` class (2.5 m) for landmarks. |
| M3 | `tools/dress_location.gd` reads the map (walls, building colliders, markers, doors, exits, A* routes from the default spawn), runs the seeded `world/dressing/lived_in_dresser.gd`, and writes `world/dressing/kesselford_lived_in.tscn` (seed 1102). `kesselford.tscn` instances it once. At load `LivedIn` paints its solid cells into Blocking and the waist-high ones into Terrain cover. | Cluster recipes live as constants in the dresser for now. They move into the pattern format when the M6 roll-out needs a second map's recipes. |
| M4 | 84 sprites, four parallel Codex lanes (`gpt-6-astra`), prepared by the new `tools/prepare_greeble_assets.gd`. Provenance and masters: `assets/generated/sources/kesselford-greebles-2026-11-02/` (`batch.json`; 117 MB of masters, as Dom kept). | A new prepare tool: ground decals need 512×256 canvases and noisy feathered edges, which the prop tool does not do. |
| M5 | 211 ground decals, 272 standing pieces (79 solid, 11 give cover), 284 contact shadows. A cobble band replaces the eight paving stamps. A wet-bank pass (puddles, mud, reeds) replaces the ten ford-puddle and five mud-edge stamps. | About 480 generated nodes, above the 300–400 target. The 5v5 demo check runs where the demo lives (PR #564 / the playtest merge). |

Ground calmed (owner item 32, `calm the ground first`): `world/dressing/ground_calm.gdshader`
on Kesselford's `TerrainBackdrop` compresses the bright wet streaks (luminance above 0.2, by
55%) and keeps 72% of the fine detail over a 2-texel low-pass. No hue shift, and the darks stay deep.
Other maps that share the Dom backdrop get it in M6.

Known and not changed here: the two brown door placeholders (`WayhouseDoor`,
`ChandleryDoor`) come from the shared door scene.

## Asset list for approval (~84)

All painterly, gothic mythopunk, upper-left key light, 256×256 transparent, base-of-object
ground contact (art bible Part I). Nothing carries a symbol, glyph or writing; no object
implies canon. Notes on paper are blank scraps. **S** = solid (blocks, may give cover),
**w** = walkable decor, **g** = flat ground decal (z −2).

**Ground (24)**: Kesselford's base and route pieces
1. Cobble road strip, straight, 2 tiles wide, tiles end to end (g)
2. Cobble road, corner (g)
3. Cobble road, frayed end into mud (g)
4. Cobble road, edge stones sinking into mud (g)
5–7. Large soft-edged patches: packed dark earth, wet mud, trampled grass (g)
8–10. Puddles: shallow, long, rain-ringed (g)
11. Wheel-rut strip, straight (g)
12. Wheel-rut strip, curving (g)
13. Footprint and hoof trail (g)
14. Scattered straw (g)
15–16. Leaf litter, two variants (g)
17. Broken cobble patch (g)
18. Cracked paving (g)
19. Damp dark stain (g)
20. Ash and soot patch, for braziers and the smithy (g)
21. Gravel scatter (g)
22. Grass tufts patch (g)
23. Moss creeping over flagstones (g)
24. Spilled grain (g)

**Wall bases and doorsteps (20)**
25. Barrel, upright (S)
26. Barrel on its side (S)
27. Two barrels with a plank across (S)
28. Rain barrel under a downspout stub (S)
29. Small crate (S)
30. Crate broken open, straw spilling (w)
31. Three grain sacks, piled (S)
32. One slumped sack (w)
33. Low firewood heap (S)
34. Wooden bucket (w)
35. Washtub with washboard (S)
36. Broom and rake leaning (w)
37. Ladder leaning (w)
38. Plank stack (S)
39. Rope coil (w)
40. Stacked woven baskets (w)
41. Three clay jars (w)
42. Empty bottles, a cluster (w)
43. Boot scraper and mat (w)
44. Herbs in a cracked pot (w)

**Yard and street (20)**
45. Cart wheel leaning (w)
46. Loose hay pile (w)
47. Hay bale (S)
48. Hitching post with ring (S)
49. Chopping block with an axe (S)
50. Grindstone on a frame (S)
51. Stone water trough (S)
52. Laundry line: two posts, hanging cloths, 2 tiles wide (w)
53. Drying rack with cloth (S)
54. Notice post with blank paper scraps (S)
55. Broken fence segment (S)
56. Single leaning fence post (w)
57. Stone bollard (S)
58. Stone rubble pile (S)
59. Loose cobbles (w)
60. Plank walkway over mud (g)
61. Sawhorse with a plank (S)
62. Wooden barrow, tipped (S)
63. Anvil on a stump (S)
64. Crate of turnips (S)

**Growth (12)**
65–67. Weed tufts, three variants (w)
68. Nettle clump (w)
69. Fern (w)
70. Reed clump, for river edges (w)
71. Mushroom cluster (w)
72. Dead branch (w)
73. Old stump with roots (S)
74. Creeper mound over stone (w)
75. Fallen-leaf heap (w)
76. Mossy stone (S)

**Small stories (8)**
77. Animal bones (w)
78. Broken pottery shards (w)
79. Dropped rag (w)
80. Spilled basket of apples (w)
81. Candle stubs on a flat stone (w)
82. Tarnished bronze scrap, unmarked (w)
83. Broken lantern on the ground (w)
84. Fishing net and floats in a heap (w)

## Acceptance

- Kesselford at camera zoom 1, 1920×1080: no stretch of ground more than about 6 tiles
  without a change underfoot; every building wall base has dressing; the ford road reads as
  one continuous road; every standing prop has a contact shadow.
- Every prop sits at its height class against the 112 px adult (rendered scale sheet).
- Doors, spawns, interactables, travel exits and the main routes stay clear (test).
- Solid pieces block walking, pathfinding and combat cells alike; walkable decor blocks
  nothing (test).
- The 5v5 class demo still opens with both lines seated (existing test).
- Frame time: the dressed map is profiled headless for node and draw-call counts; the real
  60 fps check stays with FR-904 (owner item 14).

## Open for the owner

1. ~~Approve the asset list above~~ — approved 2026-11-02 (`approve all ~84`).
2. ~~Approve the finished sprites~~ — approved 2026-11-02 (item 32: `approve all`; masters
   kept; `calm the ground first`). The look is judged in the owner's playtest.
