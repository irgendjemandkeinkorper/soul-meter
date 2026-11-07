# Field density E review — 2026-11-01

P1.2 / #531 slice E; owner item 30c/d/e from the 2026-11-01 handoff.
Branch: `codex/roadmap-p1-2e-hubs-skills`. No network or branch changes.

Implementation and verification are complete in the working tree, with one scope
mismatch: **Dom has no unnamed generated roster entries**. C uses two existing
named minor townsfolk with no quest hooks. Their identities remain intact.
Two commits succeeded; subsequent Git writes failed because the worktree metadata
is read-only. The final D placement correction, E, and this report are uncommitted.

## What now works

| Part | Result |
|---|---|
| C | `StartingTown/HadrikVale` and `StartingTown/SellaVarn` match their pre-B1 serialized node blocks byte for byte (`07cf4f39^`). B1's pocket properties and Bellow theft comment are removed. The spawner map adds a Slip pocket to Dorran Rask and a Tread pocket to Jessa Longbrace, each 9 GP with its existing faction. Toma's original pocket remains; Dom still has 3. |
| D | Each added hub receives 4 locked, owned `road-cache` stores and 3 minor-NPC pockets. Neither scene has an interior or building-door destination, so stores sit outdoors beside existing camp, cart, or landing dressing. Each hub's two original wild caches are unchanged. |
| E | Wildlore opens the overgrown ShoulderStore, Vantage assesses a FormationPlan, and Devotion reads a ShrineInscription. Distinct skills rise from 12 after C to 15. The two inspection checks persist optional feedback flags, without a progression gate or combat bonus. |

New locks/pockets retain the existing **0.0** default modifier; pockets reuse
**9 GP**. All stores reuse the existing table's rolls, quantities, gated search,
ownership consequences, and one-attempt/save-state contract. No new items, tables,
economy values, schemas, travel paths, or interaction system were introduced.
Unused Hadrik/Sella pocket flags can remain harmlessly in existing saves.

## Audit before/after

The unchanged audit counts inspection skill gates as locks and every Chest in a
wild scene as a cache. Thus each new hub has four locked containers plus one
inspection gate, and its six caches include the four new stores.

| Measurement | Before | After C | Final |
|---|---:|---:|---:|
| Distinct field skills / 22 | 13 | 12 | 15 |
| Bellow checks | 1 | 0 | 0 |
| Dom: locks / pockets / table containers | 4 / 3 / 4 | 4 / 3 / 4 | 4 / 3 / 4 |
| Ashlaren: locks / pockets / table containers | 4 / 3 / 4 | 4 / 3 / 4 | 4 / 3 / 4 |
| Kesselford: locks / pockets / table containers | 4 / 3 / 4 | 4 / 3 / 4 | 4 / 3 / 4 |
| Long Verge: locks / pockets / table containers | 0 / 0 / 2 | 0 / 0 / 2 | 5 / 3 / 6 |
| Hollowmere: locks / pockets / table containers | 0 / 0 / 2 | 0 / 0 / 2 | 5 / 3 / 6 |
| Long Verge / Hollowmere wild caches | 2 / 2 | 2 / 2 | 6 / 6 |
| Loot tables / items | 2 / 22 | 2 / 22 | 2 / 22 |

The audit still prints FAIL for Bellow, eight tables, and forty items.
Bellow-as-pickpocket was withdrawn; this slice adds no replacement Bellow check.
Tables/items belong to the separate packet. The audit's superseded comparison and
source/classification notes are reproduced, not silently rewritten.

## New objects and pocket targets

The chests use `actors/chest/chest.tscn`; the two inspections use
`actors/interactable/interactable.tscn`. Each has unique durable IDs/flags.
Chest derives its lock ID from its container ID.

| Scene | New runtime node path | Position | Check | Table / faction | Placement context |
|---|---|---|---|---|---|
| `world/long_verge.tscn` | `LongVerge/ShoulderStore` | (1740, 520) | Wildlore | road-cache / iron-companies | Moor shoulder west of ColumnTent |
| same | `LongVerge/ColumnStore` | (1930, 600) | Slip | road-cache / iron-companies | In front of ColumnTent, west of CampFire |
| same | `LongVerge/CartStore` | (2620, 640) | Strain | road-cache / iron-companies | East of PayCart |
| same | `LongVerge/CrateStore` | (2510, 430) | Slip | road-cache / iron-companies | Stock north/east of PayCart |
| same | `LongVerge/FormationPlan` | (1800, 790) | Vantage | Optional inspection | Camp approach west of MusterDrum |
| `world/hollowmere.tscn` | `Hollowmere/TentStore` | (420, 480) | Slip | road-cache / widow-watchers | West of EnvoyTent |
| same | `Hollowmere/CrateStore` | (900, 520) | Slip | road-cache / widow-watchers | East of EnvoyCrates |
| same | `Hollowmere/MenderStore` | (700, 1340) | Strain | road-cache / wayfare-menders | West of MenderCart |
| same | `Hollowmere/LandingStore` | (1620, 1110) | Slip | road-cache / wayfare-menders | North/east of ReedLanding |
| same | `Hollowmere/ShrineInscription` | (1420, 1410) | Devotion | Optional inspection | In front of existing DrownedShrine |

All pockets are scene-owned entries on `OutdoorTownsfolk.npc_pockets`.
No NPC bodies, identity strings, placements, routines, dialogue, or art changed.

| Map key | Existing runtime NPC path | Skill | GP | Existing faction |
|---|---|---|---:|---|
| `dorran-rask` | `StartingTown/DorranRask` | Slip | 9 | wayfare-menders |
| `jessa-longbrace` | `StartingTown/JessaLongbrace` | Tread | 9 | trial-council |
| `long-verge-cairn-warden` | `LongVerge/LongVergeCairnWarden` | Slip | 9 | iron-companies |
| `long-verge-old-soldier` | `LongVerge/LongVergeOldSoldier` | Slip | 9 | iron-companies |
| `long-verge-recruit` | `LongVerge/LongVergeRecruit` | Slip | 9 | iron-companies |
| `hollowmere-envoy` | `Hollowmere/HollowmereEnvoy` | Slip | 9 | widow-watchers |
| `hollowmere-mender` | `Hollowmere/HollowmereMender` | Slip | 9 | wayfare-menders |
| `hollowmere-watcher` | `Hollowmere/HollowmereWatcher` | Slip | 9 | widow-watchers |

All eight selected roster records have empty quest-hook lists. The Dom pair are
the road cobbler and bridge rope-splicer. The literal “unnamed” condition cannot
be met by an existing generated Dom record without changing identity or adding
content outside the prescribed map-only move.

## Skill-to-object rationale

| New skill | Rationale, citing the DRAMGID brief |
|---|---|
| Wildlore | Recognizing natural root growth concealing the store opening uses **Nature** ([brief §2, line 49](../briefs/dramgid-brief.md#the-22-skill-set-named-by-the-imported-dramgid-rfcs)); it does not force or pick a metal lock. |
| Devotion | Interpreting marks on the existing DrownedShrine uses **Religion** ([brief §2, line 50](../briefs/dramgid-brief.md#the-22-skill-set-named-by-the-imported-dramgid-rfcs)); the draft names no faith, deity, or rite. |
| Vantage | Assessing the camp formation plan uses **Tactics / formations / battlefield reads** ([brief §2, line 62](../briefs/dramgid-brief.md#the-22-skill-set-named-by-the-imported-dramgid-rfcs)). |

Recall already contributes a shipped check. Mending is **Medicine/physical healing**
(brief line 52), so it was not mapped to machinery. Other unused skills were skipped.

## Placement evidence

The disposable typed `reports/field-density-e/probe.gd` and `probe.tscn` follow
B1/B2's method: load with `capture-scene` and isolated user data; wait for physics;
query the full **40×40** footprint against live bodies; sample center and four
corners against ground and the player's IsoGrid; check four approaches **64 px**
away with a **16×16** clearance shape and actual ClickMoveController paths.
The probe also sweeps that clearance shape from the road to each approach.

Both hubs have **11,025 generated ground cells and zero authored Blocking cells**.
Static dressing and NPC bodies are included in collision tests. No authored ambient
patrol routes exist in these scenes; pockets add no geometry.

All ten objects have **zero footprint collisions, 5/5 floor samples, 4/4 clear
approaches, and 4/4 accepted grid paths**. Every object has at least three clear
swept routes. The shrine uses a dogleg (1250, 900) → (1250, 1410) before approaching,
avoiding the existing landing and shrine bodies.

| Object | Ground cell | Clear swept routes / 4 | Nearest exit (px) | Nearest live NPC (px) |
|---|---|---:|---:|---:|
| LongVerge/ShoulderStore | (43, 37) | 4 | 1258.729 | 413.241 |
| LongVerge/ColumnStore | (49, 36) | 3 | 1053.613 | 208.202 |
| LongVerge/CartStore | (61, 27) | 4 | 412.311 | 252.254 |
| LongVerge/CrateStore | (53, 22) | 3 | 637.024 | 345.358 |
| LongVerge/FormationPlan | (53, 44) | 4 | 1145.295 | 308.318 |
| Hollowmere/TentStore | (21, 56) | 4 | 553.173 | 305.601 |
| Hollowmere/CrateStore | (30, 50) | 4 | 921.954 | 359.489 |
| Hollowmere/MenderStore | (53, 79) | 4 | 776.659 | 352.817 |
| Hollowmere/LandingStore | (60, 57) | 4 | 1574.071 | 190.000 |
| Hollowmere/ShrineInscription | (66, 70) | 4 | 1452.481 | 370.864 |

The initial probe caught CrateStore intersecting FreshBandCairn at (2440, 780).
Moving it to (2510, 430) fixed its footprint and corner-sample failures; the
corrected scene was re-probed and reloaded. Two objects have one straight route
obstructed by existing dressing; their other three routes are clear.

Runtime probes verify every new pocket's 9 GP success exactly once, failed reward
denial, existing infamy/faction consequences, and success/failure persistence through
GameState serialization. All ten object checks exercise both outcomes without
rerolls, state round trips, and the E input handler. Each new chest searches its
existing table once without duplicating rewards. **Rendered captures remain with Claude.**

## Owner review: new strings (drafts)

All **13** strings below are DRAFTS, marked in scene comments and
`locale/project.pot`. Exported prose goes through the existing Godot
`tr()` / PO-gettext path before prompt composition. Two unit regressions verify
translated labels, lock/open prompts, failed feedback, and repeated feedback.
No translated prose was invented.

| Node | Property | DRAFT string |
|---|---|---|
| LongVerge/ShoulderStore | display_name | OVERGROWN CACHE |
| same | locked_message | Find the opening beneath the roots. |
| same | lock_failed_message | You cannot find the opening. |
| LongVerge/FormationPlan | display_name | FORMATION PLAN |
| same | prompt_text | ASSESS FORMATION |
| same | interaction_text | Formation assessed. |
| same | locked_message | Read the formation. |
| same | lock_failed_message | You cannot assess the formation. |
| Hollowmere/ShrineInscription | display_name | SHRINE INSCRIPTION |
| same | prompt_text | READ INSCRIPTION |
| same | interaction_text | Devotional marks identified. |
| same | locked_message | Interpret the devotional marks. |
| same | lock_failed_message | You cannot interpret the marks. |

C/D otherwise reuse existing strings. Existing skill labels, generic prompts,
and consequence-message templates are unchanged.

## Checks with results (verbatim)

Local logs/probe: `reports/field-density-e/` (ignored, not shipped).
Engine: `v4.7.1.stable.official.a13da4feb`.

### Field audit

```bash
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-e-audit-before.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-e-audit-c.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-e-audit-after.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd
```

Exit status: **0 each**. Full printed before/after reports are below. The coordinate
correction does not affect counts. Standalone audit runs reproduce B1/B2's
asynchronous title-screen shutdown errors, including:

```text
SCRIPT ERROR: Parse Error: Could not preload resource file "res://ui/screens/main_menu_reflection.gdshader".
ERROR: Failed loading resource: res://ui/screens/main_menu.tscn.
```

These audit shutdown errors are separate from changed-scene loading, which has no
script errors under `capture-scene`.

### Unit and E2E

Requested Xvfb commands:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-e-unit-xvfb.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/unit
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-e-e2e-xvfb.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/e2e
```

Each exited **1 before tests started**, with:

```text
ERROR: X11 Display is not available
ERROR: Can't connect to a Wayland display.
ERROR: Could not initialize the Wayland thread.
ERROR: Can't create the Wayland display server.
ERROR: Unable to create DisplayServer, all display drivers failed.
```

Authorized **CI-equivalent headless fallback**:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-e-unit-headless.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/unit
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-e-e2e-headless.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/e2e
```

Unit exit status **0**, verbatim:

```text
Overall Summary: 1987 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (194/194)
Executed test cases : (1987/1987)
Exit code: 0
```

E2E exit status **0**, verbatim:

```text
Overall Summary: 21 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (2/2)
Executed test cases : (21/21)
Exit code: 0
```

Neither suite emitted a `SCRIPT ERROR:` line. Passing assertions do not mean empty
stderr: negative fixtures emit validation errors; other diagnostics include missing
TileSet custom-data fields in `test_weftlumin_tile_painter.gd`, formatting errors
originating in `test_composition_resolver.gd:171`, and detached-tree errors.
E2E emitted 74 `ERROR: Parameter "data.tree" is null.` lines from its detached
Battle fixture, also recorded in B1/B2. Unrelated diagnostics were not changed.
Teardown excerpts (unit first, then E2E):

```text
ERROR: 74 resources still in use at exit (run with --verbose for details).
ERROR: 56 resources still in use at exit (run with --verbose for details).
ERROR: 3 RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit.
```

Unit tests completed before the final coordinate correction; the corrected scene
was re-probed/reloaded. No tested runtime or test code changed after the passing run.

### Generated-data check

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 timeout 300 bash scripts/check_generated_data.sh
```

Exit status **0**, verbatim:

```text
GLOOT-GEN: no drift.
CANON-SEED: no drift.
LOCATIONS-GEN: no drift.
ISO-SPRITE-GEN: no drift. 598 sprites verified.
```

No script errors. Existing shutdown errors reported 13 or 15 resources still in
use. The runner restored project.godot; generated files remain unchanged.

### Every changed scene loading headless

Each scene received its own isolated data directory:

```bash
for scene in starting_town long_verge hollowmere; do
  XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-e-load.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --quit-after 180 "res://world/$scene.tscn" -- capture-scene > "reports/field-density-e/load-$scene.log" 2>&1
  status=$?
  printf '%s exit=%s\n' "$scene" "$status"
done
```

Verbatim results:

```text
starting_town exit=0
long_verge exit=0
hollowmere exit=0
```

Long Verge was reloaded after correcting CrateStore. All three final logs have
**zero script/load/parse errors**. Each retains this existing teardown error:

```text
ERROR: 13 resources still in use at exit (run with --verbose for details).
```

The two added hubs retain their existing warning:

```text
WARNING: Blocking is empty — nothing in this scene blocks movement. If that is intentional, delete the layer instead of leaving it unpainted.
```

### Live probes

Example command; repeated with separate data directories for all three scenes:

```bash
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-e-probe.XXXXXX)" LP_NUM_THREADS=1 SOUL_METER_PROBE_SCENE=res://world/long_verge.tscn timeout 120 "$HOME/.local/bin/godot" --headless --path . res://reports/field-density-e/probe.tscn -- capture-scene
```

Final exit status **0 each**, verbatim:

```text
E-PROBE PASS: 23 checks, 0 failures (res://world/starting_town.tscn)
E-PROBE PASS: 93 checks, 0 failures (res://world/long_verge.tscn)
E-PROBE PASS: 93 checks, 0 failures (res://world/hollowmere.tscn)
```

The rejected initial position is recorded in `probe-long-verge.log`; the corrected
run is `probe-long_verge.log`. Final probes have no script errors and retain
the disclosed shutdown diagnostics. `git diff --check` passes.

## Audit before (verbatim)

```text
Field coverage audit — P1.2 slice A
Judge the printed report, never the exit code.
PROVISIONAL targets: brief citing owner-decisions R7 / item 11c; not ratified here.
Shipped registry world scenes: 33 (templates and test fixtures excluded).

PROVISIONAL density measurements
Measurement | Count | Target | Result
Distinct field skills / 22 | 13 | >= 15 | FAIL
Bellow checks | 1 | >= 1 | PASS
Verb: lockpick | 13 | >= 5 | PASS
Verb: pickpocket/steal | 27 | >= 5 | PASS
Verb: loot container | 30 | >= 5 | PASS
Verb: cache | 10 | >= 5 | PASS
Verb: barter | 16 | >= 5 | PASS
Verb (info): talk | 88 | — | INFO
Verb (info): pickup | 5 | — | INFO
Verb (info): switch | 1 | — | INFO
Verb (info): inspect/interact | 7 | — | INFO
Verb (info): save | 1 | — | INFO
Verb (info): travel | 67 | — | INFO
Verb (info): party selection | 1 | — | INFO
Verb (info): damage structure | 0 | — | INFO
Hub dom: locks | 4 | >= 4 | PASS
Hub dom: pockets | 3 | >= 3 | PASS
Hub dom: loot-table containers | 4 | >= 4 | PASS
Hub ashlaren: locks | 4 | >= 4 | PASS
Hub ashlaren: pockets | 3 | >= 3 | PASS
Hub ashlaren: loot-table containers | 4 | >= 4 | PASS
Hub kesselford: locks | 4 | >= 4 | PASS
Hub kesselford: pockets | 3 | >= 3 | PASS
Hub kesselford: loot-table containers | 4 | >= 4 | PASS
Hub long_verge: locks | 0 | >= 4 | FAIL
Hub long_verge: pockets | 0 | >= 3 | FAIL
Hub long_verge: loot-table containers | 2 | >= 4 | FAIL
Hub hollowmere: locks | 0 | >= 4 | FAIL
Hub hollowmere: pockets | 0 | >= 3 | FAIL
Hub hollowmere: loot-table containers | 2 | >= 4 | FAIL
Wild dorthkor_road: caches | 2 | >= 2 | PASS
Wild hollowmere: caches | 2 | >= 2 | PASS
Wild long_verge: caches | 2 | >= 2 | PASS
Wild wilds: caches | 2 | >= 2 | PASS
Wild wound_lip: caches | 2 | >= 2 | PASS
Loot tables | 2 | >= 8 | FAIL
Items | 22 | >= 40 | FAIL

Field skill occurrences (>= 1 contributes to the 15/22 target; no quota for every skill)
Skill | Checks | Presence contribution | Result
Strain | 7 | >= 1 | PASS
Lilt | 0 | >= 1 | FAIL
Slip | 15 | >= 1 | PASS
Tread | 1 | >= 1 | PASS
Beastbond | 1 | >= 1 | PASS
Varlore | 0 | >= 1 | FAIL
Unweave | 2 | >= 1 | PASS
Recall | 1 | >= 1 | PASS
Wildlore | 0 | >= 1 | FAIL
Devotion | 0 | >= 1 | FAIL
Undertone | 3 | >= 1 | PASS
Mending | 0 | >= 1 | FAIL
Ear | 1 | >= 1 | PASS
Wayfinding | 1 | >= 1 | PASS
Sounding | 21 | >= 1 | PASS
Falsetto | 0 | >= 1 | FAIL
Bellow | 1 | >= 1 | PASS
Vārum | 1 | >= 1 | PASS
Sway | 2 | >= 1 | PASS
Downbeat | 0 | >= 1 | FAIL
Brace | 0 | >= 1 | FAIL
Vantage | 0 | >= 1 | FAIL

SUPERSEDED comparison only: >= 12/22 skills, each checked >= 3 times
Skills with >= 3 checks / 22 | 4 | >= 12 | FAIL
Strain | 7 | >= 3 | PASS
Lilt | 0 | >= 3 | FAIL
Slip | 15 | >= 3 | PASS
Tread | 1 | >= 3 | FAIL
Beastbond | 1 | >= 3 | FAIL
Varlore | 0 | >= 3 | FAIL
Unweave | 2 | >= 3 | FAIL
Recall | 1 | >= 3 | FAIL
Wildlore | 0 | >= 3 | FAIL
Devotion | 0 | >= 3 | FAIL
Undertone | 3 | >= 3 | PASS
Mending | 0 | >= 3 | FAIL
Ear | 1 | >= 3 | FAIL
Wayfinding | 1 | >= 3 | FAIL
Sounding | 21 | >= 3 | PASS
Falsetto | 0 | >= 3 | FAIL
Bellow | 1 | >= 3 | FAIL
Vārum | 1 | >= 3 | FAIL
Sway | 2 | >= 3 | FAIL
Downbeat | 0 | >= 3 | FAIL
Brace | 0 | >= 3 | FAIL
Vantage | 0 | >= 3 | FAIL

Counting rules: skill locks include force/strain; flag-only gates are not locks.
Caches are Chest instances in wild scenes; hub containers require a live loot table (authored loot overrides it).
Hub counts include recursively linked interiors. Pockets are NPC pockets; steal also includes owned loot/pickups.
Barter counts placed vendor/shop access points; passive Sway pricing is not a rolled skill check.
Loot searches count each distinct table skill once per placed container; unused tables add no checks.
Dialogue counts executable check calls once per source site, not tags, prose, retries, or runtime reachability.
Other verbs are explicit actor interactions; combat, automatic events, and UI-only actions are excluded.
NOTE: Classification discrepancy: brief hub hollowmere has no fast-travel facet (retained in both applicable views).
NOTE: Classification discrepancy: brief hub long_verge has no fast-travel facet (retained in both applicable views).
NOTE: Source discrepancy: roadmap-2026-10-30.md is absent; targets are from the slice-A brief.
NOTE: Source discrepancy: R7/11c answered density entries are absent; targets remain PROVISIONAL.
```

## Audit after (verbatim)

```text
Field coverage audit — P1.2 slice A
Judge the printed report, never the exit code.
PROVISIONAL targets: brief citing owner-decisions R7 / item 11c; not ratified here.
Shipped registry world scenes: 33 (templates and test fixtures excluded).

PROVISIONAL density measurements
Measurement | Count | Target | Result
Distinct field skills / 22 | 15 | >= 15 | PASS
Bellow checks | 0 | >= 1 | FAIL
Verb: lockpick | 23 | >= 5 | PASS
Verb: pickpocket/steal | 41 | >= 5 | PASS
Verb: loot container | 38 | >= 5 | PASS
Verb: cache | 18 | >= 5 | PASS
Verb: barter | 16 | >= 5 | PASS
Verb (info): talk | 88 | — | INFO
Verb (info): pickup | 5 | — | INFO
Verb (info): switch | 1 | — | INFO
Verb (info): inspect/interact | 9 | — | INFO
Verb (info): save | 1 | — | INFO
Verb (info): travel | 67 | — | INFO
Verb (info): party selection | 1 | — | INFO
Verb (info): damage structure | 0 | — | INFO
Hub dom: locks | 4 | >= 4 | PASS
Hub dom: pockets | 3 | >= 3 | PASS
Hub dom: loot-table containers | 4 | >= 4 | PASS
Hub ashlaren: locks | 4 | >= 4 | PASS
Hub ashlaren: pockets | 3 | >= 3 | PASS
Hub ashlaren: loot-table containers | 4 | >= 4 | PASS
Hub kesselford: locks | 4 | >= 4 | PASS
Hub kesselford: pockets | 3 | >= 3 | PASS
Hub kesselford: loot-table containers | 4 | >= 4 | PASS
Hub long_verge: locks | 5 | >= 4 | PASS
Hub long_verge: pockets | 3 | >= 3 | PASS
Hub long_verge: loot-table containers | 6 | >= 4 | PASS
Hub hollowmere: locks | 5 | >= 4 | PASS
Hub hollowmere: pockets | 3 | >= 3 | PASS
Hub hollowmere: loot-table containers | 6 | >= 4 | PASS
Wild dorthkor_road: caches | 2 | >= 2 | PASS
Wild hollowmere: caches | 6 | >= 2 | PASS
Wild long_verge: caches | 6 | >= 2 | PASS
Wild wilds: caches | 2 | >= 2 | PASS
Wild wound_lip: caches | 2 | >= 2 | PASS
Loot tables | 2 | >= 8 | FAIL
Items | 22 | >= 40 | FAIL

Field skill occurrences (>= 1 contributes to the 15/22 target; no quota for every skill)
Skill | Checks | Presence contribution | Result
Strain | 9 | >= 1 | PASS
Lilt | 0 | >= 1 | FAIL
Slip | 27 | >= 1 | PASS
Tread | 1 | >= 1 | PASS
Beastbond | 1 | >= 1 | PASS
Varlore | 0 | >= 1 | FAIL
Unweave | 2 | >= 1 | PASS
Recall | 1 | >= 1 | PASS
Wildlore | 1 | >= 1 | PASS
Devotion | 1 | >= 1 | PASS
Undertone | 3 | >= 1 | PASS
Mending | 0 | >= 1 | FAIL
Ear | 1 | >= 1 | PASS
Wayfinding | 1 | >= 1 | PASS
Sounding | 29 | >= 1 | PASS
Falsetto | 0 | >= 1 | FAIL
Bellow | 0 | >= 1 | FAIL
Vārum | 1 | >= 1 | PASS
Sway | 2 | >= 1 | PASS
Downbeat | 0 | >= 1 | FAIL
Brace | 0 | >= 1 | FAIL
Vantage | 1 | >= 1 | PASS

SUPERSEDED comparison only: >= 12/22 skills, each checked >= 3 times
Skills with >= 3 checks / 22 | 4 | >= 12 | FAIL
Strain | 9 | >= 3 | PASS
Lilt | 0 | >= 3 | FAIL
Slip | 27 | >= 3 | PASS
Tread | 1 | >= 3 | FAIL
Beastbond | 1 | >= 3 | FAIL
Varlore | 0 | >= 3 | FAIL
Unweave | 2 | >= 3 | FAIL
Recall | 1 | >= 3 | FAIL
Wildlore | 1 | >= 3 | FAIL
Devotion | 1 | >= 3 | FAIL
Undertone | 3 | >= 3 | PASS
Mending | 0 | >= 3 | FAIL
Ear | 1 | >= 3 | FAIL
Wayfinding | 1 | >= 3 | FAIL
Sounding | 29 | >= 3 | PASS
Falsetto | 0 | >= 3 | FAIL
Bellow | 0 | >= 3 | FAIL
Vārum | 1 | >= 3 | FAIL
Sway | 2 | >= 3 | FAIL
Downbeat | 0 | >= 3 | FAIL
Brace | 0 | >= 3 | FAIL
Vantage | 1 | >= 3 | FAIL

Counting rules: skill locks include force/strain; flag-only gates are not locks.
Caches are Chest instances in wild scenes; hub containers require a live loot table (authored loot overrides it).
Hub counts include recursively linked interiors. Pockets are NPC pockets; steal also includes owned loot/pickups.
Barter counts placed vendor/shop access points; passive Sway pricing is not a rolled skill check.
Loot searches count each distinct table skill once per placed container; unused tables add no checks.
Dialogue counts executable check calls once per source site, not tags, prose, retries, or runtime reachability.
Other verbs are explicit actor interactions; combat, automatic events, and UI-only actions are excluded.
NOTE: Classification discrepancy: brief hub hollowmere has no fast-travel facet (retained in both applicable views).
NOTE: Classification discrepancy: brief hub long_verge has no fast-travel facet (retained in both applicable views).
NOTE: Source discrepancy: roadmap-2026-10-30.md is absent; targets are from the slice-A brief.
NOTE: Source discrepancy: R7/11c answered density entries are absent; targets remain PROVISIONAL.
```

## Changed files

| File | Change |
|---|---|
| `world/starting_town.tscn` | Restore Hadrik/Sella; two generated minor-NPC pockets |
| `world/long_verge.tscn` | Four stores, three pockets, Wildlore/Vantage checks |
| `world/hollowmere.tscn` | Four stores, three pockets, Devotion check |
| `actors/interactable/interactable.gd` | Translate exported feedback before composition |
| `actors/chest/chest.gd` | Translate exported lock/open prompt strings |
| `locale/project.pot` | Thirteen DRAFT msgids |
| `test/unit/test_interactive_props.gd` | Two localization regressions |
| `docs/qa/field-density-e-review-2026-11-01.md` | This report |

The six pre-existing untracked .gd.uid files were preserved. No protected source,
generated data, Pandora, art, or owner/roadmap document changed.

## Commits and Git limitation

| Part | Commit / state |
|---|---|
| C | `6ba443acee438e5b8a8027ad66d88a47eb6cdcaf` — fix(field): move Dom pockets to generated minor townsfolk |
| D | `011e8ccdc1bad90bfc1d55180481cef7428ae36b` — feat(field): add Long Verge and Hollowmere hub stores and pockets |
| D coordinate correction | Verified working-tree change; not in the D commit. Single-hunk patch: `reports/field-density-e/d-placement.patch`. |
| E and report | Verified working-tree changes; third commit blocked. |

Staging the coordinate correction to amend D failed with:

```text
fatal: Unable to create '/home/adamjroder/projects/soul-meter/.git/worktrees/codex-p1-2e/index.lock': Read-only file system
```

No alternate filesystem/tool route was used to bypass the denial. No push/PR
operation was attempted.

## Risks

The two Dom replacements have names; literal unnamed targets are unavailable.
Claude's rendered captures must assess appearance, label overlap, overgrowth
wording, and the inspection markers. Headless evidence does not establish visual
quality. Global audit failures and existing diagnostics are disclosed above.
The final D correction, E, and report are uncommitted due to the Git restriction.

## Open decisions

30c: confirm Dorran Rask and Jessa Longbrace qualify for the requested move to
townsfolk despite the roster having no unnamed entries.

Strings: owner review of the thirteen DRAFTS remains pending.

Other gameplay, economy, architecture, or canon decisions: none.

## Handoff back

What now works: C restores Hadrik/Sella and retains three Dom pockets on the
existing population; D provides four locked stores and three pockets per added
hub while preserving wild caches; E reaches 15/22 using natural object checks.

Changed files: eight files listed above; local logs/probe under
`reports/field-density-e/`.

Checks with results: unit 1987/1987 and E2E 21/21 passed using the authorized
headless fallback; generated-data checks report no drift; all three changed scenes
load without script errors; final runtime probes pass 209 checks. Verbatim
commands/results and both complete audit reports appear above.

Audit before/after: distinct skills 13 → 12 after C → 15; each added hub
0/0/2 → 5/3/6 locks/pockets/table containers; Dom remains 4/3/4.

New strings: thirteen DRAFTS under “Owner review: new strings (drafts)”.

Risks: named-minor substitution, rendered captures pending, disclosed existing
diagnostics, and uncommitted changes due to read-only Git metadata.

Open decisions: accept the two minor Dom targets and review the thirteen drafts;
none otherwise.

Commits: `6ba443acee438e5b8a8027ad66d88a47eb6cdcaf`;
`011e8ccdc1bad90bfc1d55180481cef7428ae36b`.

Claude's next action: review this report's scope mismatch before integrating
the remaining changes and making the assigned rendered captures.


## Rendered check (Claude, Xvfb, 2026-11-01)

`field-density-e-hubs-2026-11-01.png`: top row Long Verge camp (two framings), bottom row Hollowmere west camp and DrownedShrine. All stores sit beside existing tents, carts, crates or the landing, clear of paths. FormationPlan and ShrineInscription render with the interactable placeholder marker (yellow square), not an art prop. Four crate labels cluster around the single Long Verge camp.
