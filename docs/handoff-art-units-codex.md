# Race and class unit models — Codex handoff (2026-10-31)

**Status: handoff for owner dispatch.** Written by Claude as architect at the owner's 2026-10-31
request ("detailed instructions for Codex to generate art assets … models for the different races
… incorporate all the classes"). This is the go-ahead to *plan and build* the unit-model lane that
`CODEX_ACTION_PLAN.md` M6 held back. It is **not** approval of any generation batch: under
`docs/art-aesthetics-bible.md` Part III ("Owner-gated agent-generated model drafts") every Meshy
batch needs the owner's approval before it starts, approval of finished assets is a separate
decision, and nothing generated ships without the owner's explicit approval. Each milestone below
names what it needs before it may start.

Owner-list item 22's "Claude implements; no Codex" (2026-10-23) governed its own scope; this handoff
is authorized by the owner's 2026-10-31 request. Claude owns design direction, review and
integration decisions; Codex implements and drafts; the owner approves.

## 1. Read first, in this order

1. `AGENTS.md` (repository rules; they win over this file).
2. `docs/art-aesthetics-bible.md`: Part I Technique and the standing capture constraints; Part III
   in full (nine seed lineages, every **Open** line, the Mirror-Veil drop, the draft policy).
3. `design/god-aesthetic-style-guide.md` (the ten patrons' material language; working draft).
4. `art-request.md` §2–§3 (per-character silhouette notes; its 32×48 / 48×64 sprite spec is legacy).
5. `tools/render_isometric_sprites.gd` (the camera contract) and `globals/unit_art.gd` (the
   resolver, pivot and the 112 px rule).
6. `CODEX_ACTION_PLAN.md` and `/home/adamjroder/projects/_planning/asset-pipeline/CODEX_ACTION_PLAN.md`
   (the shared Meshy/Blender pipeline plan; `agent-handoffs/asset-forge-next.md` holds its P0 gate).
7. `docs/agent-verification.md` and `WORLD_ART_BRIEF.md` §Calibration-first batch loop.
8. Vault: `../dramgid-vault/peoples/*.md`, `systems/ten-patron-classes.md`,
   `characters/{serai-lun,old-grumbrand,wyneth-hallow-tide,ressa-quickfingers,korrath-ninefold,maura-greyfen}.md`,
   `_source/dramgid-lore-dump.md` lines 1386–1477 (faction colours and gear; frozen source, never edit).

## 2. What exists today (verified 2026-10-31)

| Fact | Evidence |
|---|---|
| Every field actor is one painted `Sprite2D`, `units/<id>/<id>--idle--se--f00.png`, mirrored with `flip_h` for west-facing. No `AnimatedSprite2D`, no `Node3D`, no project-made `.glb`/`.blend` on any branch. | `actors/player/player.tscn`, `actors/npc/npc.gd:444`, `world/combat_overlay.gd:508`; `git ls-tree` of five art branches |
| 88 unit folders (Vex, six companions, 60 Dom NPCs, 12 crowd figures, 8 enemy archetypes, 3 fauna), all "Agent-generated raster via built-in imagegen", one state, one direction. | `assets/generated/sprites/manifests/units.json` |
| 66 NPC portraits plus 10 player likeness plates; **no companion portraits**. | `assets/generated/portraits/` |
| Five `ancestry_*.png` chargen plates exist. | `assets/generated/chargen/` |
| `assets/generated/models/units/*/` holds only `*--imagegen-source.png` reference images. | `CODEX_ACTION_PLAN.md` status |
| Deterministic 3D→2D renderer: orthographic, yaw 45°, pitch `atan(0.5)`, 256×256 RGBA, one fixed view per model, manifest with SHA-256 drift check in CI. Real renders need a display (Xvfb). | `tools/render_isometric_sprites.gd`, `scripts/check_generated_data.sh:68`, `test/unit/test_isometric_render_pipeline.gd` |
| Adult actors draw at **112 px ±10** occupied height at zoom 1; `UnitArt` scales each texture from its drawn height; creature exceptions in `UNIT_HEIGHT_PX`. | `globals/unit_art.gd`; ruling 2026-10-05 in `docs/art/fallout2-unification-spec.md` (unmerged branch `art/fallout2-unification`) |
| The created character never looks like their ancestry or class: `ChargenData.LIKENESSES` maps ten likeness plates to `crowd-*` field sprites. | `globals/chargen_data.gd:109-127`, `ui/screens/chargen/chargen_art_resolver.gd` |
| Chargen offers five ancestries (`vael`, `kaan`, `vaerin`, `weftkin`, `kes-reth` labelled "Kes'reth (Mirror-Veil)"); Pandora "Peoples" holds the nine seed races; the bible drops Mirror-Veil. | `globals/chargen_data.gd:23-40`, `data.pandora`, bible Part III |
| Ten classes with kit text and no art field; combat facing is 8-way (`e se s sw w nw n ne`). | `globals/stats/class_catalog.gd`, `world/combat_overlay.gd:97` |
| Hub NPCs without art: Ashlaren 6, Kesselford 6, Long Verge 5, Hollowmere 3 (crowd fallback). `iris-illepah` has a portrait, no sprite. | `data/generated/*_npc_roster.json`, `UnitArt.resolve` |
| No shared pipeline yet: `/home/adamjroder/projects/asset-forge` does not exist, Blender is not installed in WSL, no `MESHY_API_KEY` is set. Codex's built-in image tool works (it produced every unit and portrait). | shared plan status; `which blender`; `env` |

## 3. The target: modular units, not bespoke sprites

One sprite per character does not scale to nine races × ten classes × crowds, and it is why the
world reads as one people. The target is a **modular unit**:

```
unit = race base body  ×  class kit (weapon, regalia, marks)  ×  role dressing (crowd/profession)
     + bespoke overrides for named characters
→ composed in Blender → rendered by the extended render tool
→ assets/generated/sprites/units/<unit_id>/<unit_id>--<state>--<dir>--f<NN>.png + manifest row
→ resolved by UnitArt (race_id, class_id, role, variant) with the existing single-sprite fallback
```

Consequences this handoff commits to:

- **The player looks like their build.** `UnitArt` resolves `player-<ancestry>-<class>` first,
  then `player-<ancestry>`, then the likeness unit, then the crowd fallback (U0).
- **Crowds carry the canon population mix.** Dom is Ghorr 58 % / Vael 27 % / Kaan 6 % /
  Kes'reth 4 % / Orthos minority (`../dramgid-vault/cities/dom.md`). Crowd ids become
  `crowd-<race>-<role>-<variant>` and `world/town_npc_spawner.gd` draws from a per-hub mix table
  (U0 data shape; U6 art). The other four hubs have no canon mix: owner item 28.
- **Named characters keep their ids** and their existing art until a modelled replacement is
  approved side by side with the current sprite.
- **Enemies stay bespoke** (eight archetypes). Their current painted art is Soul Meter's own
  reference; the vault does not describe them. Modelled replacements come last (U8).
- **Hollow has no body.** Canon makes husking behavioural ("the body walks, eats, and answers to
  its name", `cosmology/souls.md`). Do not model or tint a Hollow body; the gauge and read-back lines
  carry it (roadmap Phase 2). Only an owner ruling changes this.

## 4. Roster and matrix

### 4.1 Race bodies (seven for Chapter 1)

Bible Part III fixes nine seed races and leaves most anatomy **Open**. Chapter 1 needs seven bodies
(five playable plus Wyneth's and Korrath's peoples). Snarlin (Maura) is a shapeshifting people with
no base form in canon: owner item 28 decides what Maura presents as.

| race_id | Bible fixed facts (Part III) | Open per the bible (art proposes, owner decides) | Chapter 1 use |
|---|---|---|---|
| `vael` | Certainty-Bearers; rigidity becoming unstable; "baseline" people (vault) | silhouette, substrate, face, proportions, palette | playable; Ressa; Dom 27 % |
| `ghorr` | **four arms, almost ursine body, warthog-like face**; heavy and brittle under the Waning | arm-pair placement and size, hands, fur, snout and tusks, leg posture, scale, palette | Wyneth; Dom 58 %; Ashlaren stewards |
| `kaan` | stone-fused, part-mineral; reverts to inert rock ("the settling") | proportions, mineral coverage, exposed flesh, hair, joints, healthy→stone progression | playable; Grumbrand (left hand stiffening) |
| `kes-reth` | horns and heat-blood; **Mirror-Veil dropped**; Ash-Bound keeps cinder-ink names | horn arrangement, face, build, skin and ash palette, tail/feet, healthy→combusting | playable; Vex ("Ash-Bound"); Serai-Lun (data says "Mirror-Veil"); Dom 4 % |
| `vaerin` | archivists; vellum and silence; lost lifespan has no fixed look | ears, facial proportions, build, palette, lifespan consequence | playable |
| `weftkin` | biological person plus interrupted signal; cultivated tissue (vault); severed = shadow puppet | healthy anatomy and material, how signal reads, severed state | playable |
| `orthos` | Dragonborn reference; left-right double-tap cadence; six-minute loops | head and muzzle, scales, horns, tail, limbs, how draconic | Korrath; Dom minority |
| `fiel`, `shimari` | monkey–turtle hybrid; mycorrhizal | all | not in the Chapter 1 region: later |

Relative heights are an owner decision; PROVISIONAL defaults for the identity sheets only:
Ghorr 1.15×, Orthos 1.1×, Vael/Vaerin/Weftkin/Kes'reth 1.0×, Kaan 0.9×, Fiel 0.75× of the 112 px
adult. Ship nothing at a non-1.0 factor without the ruling.

### 4.2 Class kits (ten)

Kit text is canon (`globals/stats/class_catalog.gd`, vault `systems/ten-patron-classes.md`); the
material language is the style guide's working draft; colours come from the lore dump's faction
table and are missing for three patrons.

| class_id | Patron | Kit (canon) | Material cue (style guide) | Colours (lore dump) |
|---|---|---|---|---|
| `mirrorblade` | Maiiam | paired balanced daggers, Mirrorwalking footwork | polished silver, quicksilver glass, delayed reflections | Forest Green / Lilac (Mirror Choir) |
| `river-mother` | Haeren | water harp, net-and-whip, hospice tools | wet re-used vellum, tarred net cordage; the Name-Ledger | **none in canon** |
| `ironbrand` | Kero | greatsword or spiked gauntlet, ritual branding | cauterized rejoined metal, brands as a counted ledger | Sunset Orange / Robin's Egg Blue (Sentinels) |
| `lensbearer` | Stuid | quarterstaff, precision monocle | ground optical glass, dull brass casings | Seafoam Green / Parchment Beige |
| `husk-bearer` | Vhorr | cleaver or sickle, gut-lute | pruned trellised growth, root-bound wood, matte ceramic | **none in canon** |
| `flamebinder` | Vicoar | war pick, kinetic-sculpture constructs | cast iron, soot-blackened steel, working foundry | Copper Orange / Steel Gray |
| `stormbearer` | Ofshütje | greatclub, cloud-drum | salt-scoured lightning-scarred timber, meteoric iron | Storm Gray / Lightning Yellow; **never depict the god** |
| `oathclock` | Pazzah | halberd, pendulum bell | the most refined materials, a lie that reads only in hindsight | Ash Black / Bronze |
| `locksmirk` | Fickah | blowgun, trap poetry | small precise brass mechanisms, worn leather | **none in canon** |
| `threadwalker` | Izhakel | whip-dagger, glass chimes | wax seals, ribbon, fine cord, redacted text; silver thread at the wrist | Violet-Black / Thread-Silver |

A kit is a mesh set that attaches to any race base: weapon(s), one regalia piece, one mark or
accessory. Kits never change the body. Ghorr's four arms need a kit attachment rule (which pair
holds the weapon): owner item 28.

### 4.3 Named characters

| Character | race × class (as recorded in `globals/game_state.gd`) | Existing art | Note |
|---|---|---|---|
| Vex | Ash-Bound Kes'reth × Ironbrand | sprite `vex`; Pandora Portrait Ref | protagonist; `art-request.md` silhouette notes |
| Serai-Lun | "Mirror-Veil Kes'reth" × Mirrorblade | sprite | conflicts with the bible's Mirror-Veil drop: item 28 |
| Old Grumbrand | Kaan × Lensbearer | sprite | soot-stained; left hand settling to stone (vault) |
| Wyneth Hallow-Tide | Ghorr × River-Mother | sprite | first four-armed companion; no colours for Haeren |
| Ressa Quickfingers | Vael × Locksmirk | sprite | |
| Korrath Ninefold | Orthos × Ironbrand | sprite | |
| Maura Greyfen | Snarlin × Husk-bearer | sprite | base form undefined: item 28 |

None of the six companions has a portrait (`docs/ship-plan-2026-10.md` line 80 schedules them as
a Day-14 deliverable through #298 with the owner approving the batch). Portraits are not part of this handoff unless the owner adds them in item 28.

### 4.4 Crowds, hub NPCs, enemies, fauna

- **Crowd set** today: 12 figures, no race. Target: `crowd-<race>-<role>-<a|b>` for the roles
  already in use (acolyte, guard, merchant, laborer, dockworker, beggar) across the seven races,
  weighted by each hub's mix. PROVISIONAL first set: 7 races × 3 roles × 2 variants = 42 units.
- **Hub NPCs without art**: 20 (Ashlaren 6, Kesselford 6, Long Verge 5, Hollowmere 3) plus
  `iris-illepah`. They get race-tagged crowd bodies with a role kit first; bespoke only on request.
- **Enemies**: `bog-wight`, `loam-maddened-boar`, `gnaal-breach-hound`, `gnaal-rift-scavenger`,
  `mustered-bloodbellow`, `cleaned-jawbrace-guard`, `trial-warden`, `trial-keeper`. The
  Bloodbellow and the Jawbrace guard are Ghorr-adjacent (Iron Companies, "armor perfectly cleaned of
  the wearer"); the rest have no canon body. Six carry tell masks (`--tellmask.png`) that any
  replacement must regenerate (`tools/generate_tell_masks.py`).
- **Fauna**: rat, crow, stray dog keep their `UNIT_HEIGHT_PX` exceptions.

## 5. Contracts (do not relax)

**Camera and canvas.** Orthographic, yaw 45°, pitch `atan(0.5)`, 64×32 tile, 256×256 RGBA8
transparent, bottom-centre feet contact, one subject per image. Constants live in
`tools/render_isometric_sprites.gd` and are not tuned per model.

**Scale.** Model at 1 unit = 1 m, +Y up, facing −Z, origin at the feet centre (the convention the
shared plan adopts from `dramsurvive/assets/models/README.md`). A 1.75 m adult must occupy
112 px ±10 on screen at zoom 1 after `UnitArt.apply_world_scale`; record each unit's measured drawn
height in the manifest. Race height factors wait on item 28.

**Directions and states.** Directions follow `world/combat_overlay.gd` `FACING_STEPS`:
`e se s sw w nw n ne`, rendered by rotating the model in 45° steps under the fixed camera.
PROVISIONAL state set per unit: `idle` 1 frame, `walk` 8, `attack` 6, `hit` 3, `down` 1, at
12 fps. First integration ships `idle` + `walk` only; `attack`/`hit`/`down` land with U7. Image-lane
drafts stay one direction (`se`) and keep the `flip_h` fallback.

**Naming.** `assets/generated/sprites/units/<unit_id>/<unit_id>--<state>--<dir>--f<NN>.png`
(unchanged). Models: `assets/generated/models/races/<race_id>/base.glb`,
`assets/generated/models/kits/<class_id>/*.glb`, composed units
`assets/generated/models/units/<unit_id>/model.glb` beside the existing reference PNG. Every model
folder carries `provenance.json` following the world batch files
(`assets/generated/models/world/*.json`: `set_id`, `provenance`, `camera_contract`, `assets[]`) plus
per-model `generator`, `prompt` or `source`, `meshy_task_id`, `licence` and `sha256`.

**Manifest.** Extend `assets/generated/sprites/manifests/units.json` rows with `race_id`,
`class_id`, `role`, `variant`, `directions[]`, `states{}`, `drawn_height_px`, `height_factor`.
`UnitArt` reads the manifest; it never guesses paths for multi-direction sets. The CI drift check
(`scripts/check_generated_data.sh`) must keep passing: every output is hashed, generator version
bumps on any contract change.

**Budgets (PROVISIONAL until asset-forge P1 fixes them).** ≤ 12 k triangles per composed unit,
one 1024² albedo plus normal, no Draco. Kits ≤ 4 k. Real renders run under Xvfb; headless Godot
cannot rasterize the SubViewport.

**Repository rules.** Never hand-edit `data/generated/*` (regenerate with `tools/generate_gloot.gd`
and `tools/seed_town_npcs.gd`); never write back to Pandora from generated artifacts; preserve
`.tscn` ownership, node paths and `uid://`; no per-node theme overrides; `addons/*` untouched except
`addons/soul_meter_tools`; `.import` files are not source. Branch `codex/<topic>` from the base
branch the owner names at dispatch; commit, push, open a PR; never merge, never change labels,
milestones or assignees; never commit `MESHY_API_KEY`.

## 6. Milestones (one PR each, in order)

Sessions are PROVISIONAL Codex working sessions; owner time is review.

**U0 — Resolver and data contracts (code only; may start on dispatch). ≈2 sessions.**
Objective: make the runtime able to consume modular, multi-direction unit sets without changing
any art. Scope: `globals/unit_art.gd`, `globals/chargen_data.gd` (read only), a new
`globals/unit_frames.gd` (manifest-driven frame lookup `(unit_id, state, dir, frame) → path`),
`actors/player/player.gd`, `actors/npc/npc.gd`, `actors/party_followers/`, `world/combat_overlay.gd`
(facing → direction key with `flip_h` fallback when a set has one direction), the manifest schema,
`world/town_npc_spawner.gd` (per-hub race mix table, data-driven, defaulting to today's behaviour),
unit tests. Deliverables: `UnitArt.player_unit_id(ancestry_id, class_id, likeness_id)` with the
fallback chain in §3; frame lookup; mix-table hook; schema doc in this file's §5.
Acceptance: `bash scripts/test.sh -a test/unit` green including new `test_unit_frames.gd` and
extended `test_unit_art_height.gd` / `test_chargen_art_resolver.gd`; `test/manual/screenshot_sweep.gd`
captures show no visual change (before/after pair in `docs/qa/units-u0-<date>/`).
Do not decide: race mix numbers for hubs other than Dom (ship the table empty with Dom filled from
canon); any state list beyond §5.

**U1 — Identity sheets (Codex image tool; needs owner "go U1"). ≈3 sessions.**
Objective: one review sheet per Chapter 1 race (seven) and per class kit (ten) that *proposes*
answers to the bible's Open lines so the owner can rule once, in pictures. Each race sheet: front,
three-quarter and back turnaround; one healthy and one Waning-touched state; one Dom-dressed
crowd variant; a scale bar against a Vael adult. Each kit sheet: weapon(s), regalia, mark, shown on
two different race bases. Output: `assets/generated/models/races/<race_id>/identity-sheet.png`
and `assets/generated/models/kits/<class_id>/identity-sheet.png`, each with a sidecar
`identity-sheet.md` listing, line by line, which Open decision the sheet proposes and the bible
sentence it answers; plus `docs/qa/identity-sheets-<date>/README.md` contact sheet. Prompts follow
the bible's shared preamble and avoid-list and the style guide's materials; faction colours only
where §4.2 has them. Acceptance: every Open line in Part III for the seven races appears exactly
once across the sidecars; no sheet shows Mirror-Veil anatomy, a two-armed Ghorr, a depicted
Ofshütje, or a Hollow body. Owner approves or annotates per sheet; approved sheets become the
reference for U3+. Do not decide: anything the sidecar lists; these are drafts.

**U2 — Shared pipeline P0–P1 (asset-forge; needs owner "go P0" and `MESHY_API_KEY`). ≈3 sessions.**
Follow `/home/adamjroder/projects/_planning/asset-pipeline/CODEX_ACTION_PLAN.md` P0 (Linux Blender
in WSL matching the Windows 5.2 major; headless cube→GLB proof) and P1 (Meshy client with an
approval gate that refuses to generate without an owner-approved batch file). Soul Meter calls the
repo; it does not vendor the scripts. Acceptance: the shared plan's own "done when" lines.

**U3 — Pilot: two race bases (needs an owner-approved batch). ≈4 sessions.**
Vael (baseline) and Ghorr (the hardest anatomy, Dom's majority). Generate from the approved
identity sheets, clean in Blender (scale, origin, facing, naming, budget), rig to a shared humanoid
skeleton (Ghorr with the extra arm pair), author `idle` and `walk`, render all eight directions
through the extended tool, and put the result beside the current painted sprite in a contact sheet
at 1× and 3×. Acceptance: both pass the drift check and `test_unit_frames.gd`; measured adult
height 112 px ±10 (Ghorr at the PROVISIONAL factor, clearly labelled); all four arms readable in
every direction; the owner approves the look. If not approved, stop.

**U4 — Class kits on the pilot bases (needs batch approval). ≈4 sessions.**
Ten kits, each composed onto both pilot bases (20 renders, `idle`+`walk`). Acceptance: every kit
reads at 1× against the field (`test/manual/actor_scale_capture.gd`); the weapon hand rule for
Ghorr follows item 28; `player-vael-<class>` and `player-ghorr-<class>` resolve for all ten
classes in a chargen round trip test.

**U5 — Remaining Chapter 1 race bases (needs batch approval). ≈5 sessions.**
Kaan, Kes'reth, Vaerin, Weftkin, Orthos, same recipe as U3; then the 50 player combinations
(5 playable ancestries × 10 kits) plus Orthos and Ghorr kits for companions. Acceptance: chargen
shows the chosen ancestry and class in the field for every combination
(`test_chargen_art_resolver.gd` extended); `screenshot_sweep.gd` captures attached.

**U6 — Named characters and crowds (needs batch approval). ≈5 sessions.**
Vex and the six companions as bespoke overrides on their race × class unit (Serai-Lun and Maura
only after item 28); the 42-unit crowd set; the 20 hub NPCs and `iris-illepah` on crowd bodies with
role kits; Dom spawner mix switched on. Acceptance: Dom's street capture shows the canon mix within
±10 % over 100 spawns (log in the QA readme); every named replacement approved side by side.

**U7 — Combat states (needs batch approval). ≈3 sessions.** `attack`, `hit`, `down` for every
modelled unit; `combat_overlay.gd` plays them from the frame lookup. Acceptance:
`test/manual/combat_legibility_capture.gd` plus the FR-109 telegraph checks still pass.

**U8 — Enemies and fauna (needs batch approval). ≈4 sessions.** Eight archetypes, three fauna,
tell masks regenerated. Acceptance: `docs/qa/tell-masks-*/` recipe repeated; Gate T legibility
captures unchanged or better.

## 7. Do not decide (owner item 28 and standing boundaries)

Stop and ask, never infer, on any of these:

1. Which races get bodies beyond the seven (Fiel, Shimari) and whether Snarlin/Maura gets a base
   form or presents as another race.
2. The Mirror-Veil conflict: the bible drops it; `chargen_data.gd`, two likeness labels, Serai-Lun's
   race string and the vault still carry it. Rename, re-race, or keep as a historical label.
3. Relative race heights (§4.1 factors) and the Ghorr weapon-hand rule.
4. Population mixes for Kesselford, Ashlaren, The Long Verge and Hollowmere (Dom's is canon).
5. Kit colours for Haeren, Vhorr and Fickah (none in canon).
6. Every **Open** line in bible Part III: U1 proposes, the owner rules, U3+ implements.
7. Whether companions get portraits in this lane.
8. Batch approvals: U1 (image tool), P0 Blender install, and each Meshy batch U3–U8.
9. Standing: never depict Ofshütje; Pazzah's erased notch stays a mystery; no Hollow body; no new
   canon for enemies or for Dorthkor Road / Wound Lip / Loamroot Grove (none has a vault entity);
   Vex is not in the vault, so Vex's look comes from `art-request.md` and the approved calibration
   render only.

## 8. Verification recipe

- Unit: `bash scripts/test.sh -a test/unit` (render pipeline, unit art height, chargen art
  resolver, unit frames).
- Drift: `bash scripts/check_generated_data.sh` after every regeneration.
- Rendered: `bash scripts/test.sh -a test/manual/screenshot_sweep.gd`,
  `test/manual/actor_scale_capture.gd`, `test/manual/combat_legibility_capture.gd` under Xvfb at
  1920×1080; inspect the PNGs yourself; put before/after pairs in `docs/qa/units-<milestone>-<date>/`.
- Contact sheets at 1× and 3× tile width next to the current sprite, as in
  `assets/generated/sprites/units/_contact_sheet.md`.
- A headless pass never proves the art reads; say so in the PR if a capture is missing.

## 9. Handoff back (every PR body)

What now works and how to see it; changed files; batch file and provenance paths; checks run with
results; measured heights; risks; the exact Open decisions the owner must rule on, each as one
line they can answer; next milestone. Never merge. Never edit issue labels, milestones or assignees.

## 10. Evidence

Repository: `AGENTS.md`, `CODEX_ACTION_PLAN.md`, `WORLD_ART_BRIEF.md`, `art-request.md`,
`docs/art-aesthetics-bible.md`, `docs/briefs/race-appearance-source-survey.md`,
`design/god-aesthetic-style-guide.md`, `docs/ship-plan-2026-10.md`, `docs/owner-decisions.md`,
`tools/render_isometric_sprites.gd`, `tools/generate_tell_masks.py`, `globals/unit_art.gd`,
`globals/chargen_data.gd`, `globals/party_member.gd`, `globals/game_state.gd:798-1045`,
`globals/stats/class_catalog.gd`, `ui/screens/chargen/chargen_art_resolver.gd`,
`world/combat_overlay.gd`, `world/town_npc_spawner.gd`, `actors/*/`,
`assets/generated/sprites/manifests/units.json`, `data/generated/*_npc_roster.json`,
`data/generated/encounters.json`; unmerged `art/fallout2-unification`:
`docs/art/fallout2-unification-spec.md`. Shared plan:
`/home/adamjroder/projects/_planning/asset-pipeline/{CODEX_ACTION_PLAN.md,agent-handoffs/asset-forge-next.md}`.
Vault: `peoples/*.md`, `systems/ten-patron-classes.md`, `systems/character-creation.md`,
`characters/*.md` (six companions), `cities/dom.md`, `cosmology/souls.md`,
`_source/dramgid-lore-dump.md:1386-1477`, `proposals/lore-reconciliation-interview.md` (ruling 16).
