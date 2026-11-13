# Field density B2 review — 2026-10-31

P1.2 / #531 slice B2, on `codex/roadmap-p1-2c-ashlaren-kesselford`,
starting at `67767ce6` after B1. Both hubs meet the handoff's **PROVISIONAL**
targets: **4 locks, 3 pockets, and 4 loot-table containers each**. This adds
eight Chest instances and pockets on six existing generated townsfolk.
Distinct field skills remain **13/22**, below the provisional target of 15.
No stretched skill mappings were introduced to increase that number.

## What now works and how to see it

Use a protagonist-bearing game/save to exercise the checks. Direct scene
launches are suitable for placement captures, but have no protagonist and
therefore no effective skill chance. Press E at a crate for its existing
one-attempt lock and loot panel; press F at a pocket target for the existing
one-attempt theft. Existing NPC routines still control presence and position.
The outdoor positions below are the verified morning positions after the
existing grid snap/routines, not newly authored coordinates.

All paths include the scene root. Every crate instances
`actors/chest/chest.tscn`, using its existing `Chest` / `SMInteractable`
scripts, as in B1, Dorthkor Road, and Wound Lip. Every pocket uses the existing
`actors/npc/npc.tscn` instance already created for that roster placement.

| Scene | New object or existing pocket target: node path | Position | Skill / durable ID |
|---|---|---|---|
| `world/interiors/ashlaren_millhouse.tscn` | `AshlarenMillhouseInterior/LockedSupplyCrate` | (1450, 1000) | Slip / `ashlaren-millhouse-locked-supply-crate` |
| `world/interiors/ashlaren_millhouse.tscn` | `AshlarenMillhouseInterior/BracedSupplyCrate` | (400, 1000) | Strain / `ashlaren-millhouse-braced-supply-crate` |
| `world/interiors/ashlaren_weighing_hall.tscn` | `AshlarenWeighingHallInterior/LockedSupplyCrate` | (1450, 1000) | Slip / `ashlaren-weighing-hall-locked-supply-crate` |
| `world/interiors/ashlaren_weighing_hall.tscn` | `AshlarenWeighingHallInterior/BracedSupplyCrate` | (400, 1000) | Strain / `ashlaren-weighing-hall-braced-supply-crate` |
| `world/interiors/kesselford_chandlery.tscn` | `KesselfordChandleryInterior/LockedSupplyCrate` | (1450, 1000) | Slip / `kesselford-chandlery-locked-supply-crate` |
| `world/interiors/kesselford_chandlery.tscn` | `KesselfordChandleryInterior/BracedSupplyCrate` | (400, 1000) | Strain / `kesselford-chandlery-braced-supply-crate` |
| `world/interiors/kesselford_wayhouse.tscn` | `KesselfordWayhouseInterior/LockedSupplyCrate` | (1450, 1000) | Slip / `kesselford-wayhouse-locked-supply-crate` |
| `world/interiors/kesselford_wayhouse.tscn` | `KesselfordWayhouseInterior/BracedSupplyCrate` | (400, 1000) | Strain / `kesselford-wayhouse-braced-supply-crate` |
| `world/ashlaren.tscn` | `Ashlaren/AshlarenBellWarden` | (2492, 708), existing | Slip / `ashlaren-bell-warden-purse` |
| `world/ashlaren.tscn` | `Ashlaren/AshlarenGhorrSteward` | (1500, 1236), existing | Slip / `ashlaren-ghorr-steward-purse` |
| `world/ashlaren.tscn` | `Ashlaren/AshlarenWarehouseWatch` | (2524, 1396), existing | Slip / `ashlaren-warehouse-watch-purse` |
| `world/kesselford.tscn` | `Kesselford/KesselfordBellRinger` | (1564, 788), existing | Slip / `kesselford-bell-ringer-purse` |
| `world/kesselford.tscn` | `Kesselford/KesselfordFerryKeeper` | (2524, 1044), existing | Slip / `kesselford-ferry-keeper-purse` |
| `world/kesselford.tscn` | `Kesselford/KesselfordMenderPairJunior` | (1564, 1076), existing | Slip / `kesselford-mender-pair-junior-purse` |

All eight containers use **`road-cache`**, without a fixed `loot` override,
and therefore also provide its existing Sounding search. All lock and pocket
modifiers are **0.0**, matching the Dorthkor Road/B1 examples and NPC default.
Each pocket contains **9 GP**, copied from Toma Reedhand/B1, with no item reward.
No new difficulty, reward magnitude, item, loot table, or table weight was authored.

Ashlaren crates and pockets use the existing `grain-factors-table` faction;
Kesselford crates and pockets use `wayfare-menders`. These match the selected
NPC roster affiliations and the Flat Bell/Ford Chandlery vendor affiliations.
Crates use the existing `owned_by_faction` theft path; pockets use
`pocket_faction`. The live probe verified the first take writes one theft
penalty per loot-panel session, and caught pockets write their existing
infamy and faction penalties.

The selected existing minor NPCs are Warden Tamsin Flatbell, Steward Ilse
Furrowgood, Pell Haskard, Hesk Waterward, Orla Chainwright, and Mender Nessa
Quill. The hub scenes have no anonymous NPC instances to use. All six selected
roster rows have empty `quest_hooks`; no person, display name, dialogue, or
NPC placement was added. Ashlaren's three outdoor roster NPCs are all used;
Kesselford's elder mender and the indoor NPCs remain without new pockets.

## Generated townsfolk: necessary wiring and audit boundary

Unlike Dom's hand-placed pocket targets, these hubs create their outdoor NPCs
in `TownNpcSpawner`. There were no serialized NPC nodes to add pocket
properties to. The spawner now accepts an optional scene-owned `npc_pockets`
dictionary, keyed by an existing roster ID, and copies only the existing
NPC pocket properties **before** adding that NPC to the tree. This makes the
initial F prompt accurate. The empty default leaves other scenes unchanged;
the two hub scenes are the only scenes that opt in. NPC identity, generated
placements, art, dialogue, routine behavior, and node paths are preserved.

The audit now counts those explicit settings only for an existing outdoor
spawner and matching spawnable roster placement. Missing roster/anchor,
wrong scene, missing placement, invalid offset, malformed settings, and an
empty pocket ID do not become opportunities. A pocket-like property in a
roster remains ignored. The regression fixture also verifies that putting the
same dictionary on an ordinary node produces zero pockets. Targets and the
hub list are unchanged; talk remains 88, with no duplicate NPC opportunities.

This is the only shared runtime change. The existing NPC, chest, lock,
reputation, navigation, save, and GameFlow implementations are unchanged.
Pandora and generated data were not edited or regenerated.

## Placement evidence

The disposable typed probe in `reports/field-density-b2/probe.gd` and
`probe.tscn` follows B1's placement-evidence method. It loads all six scenes
with `capture-scene`, waits for physics, queries the whole **40×40** chest
footprint against live bodies, and checks the center and four corners against
the floor polygon. It checks four approaches **64 pixels** away with a
**16×16** clearance shape. It additionally sweeps that clearance shape along
each direct route from `Room/SpawnEntry` to the approach.

All four interiors have **zero authored ground cells and zero blocking cells**
in `Room/FieldGround` and `Room/FieldBlocking`; their existing movement is free
placement. Accordingly, floor containment uses `Room/Floor`'s polygon and
clearance uses live wall, counter, bench, NPC, and other body collisions.
An empty navigation layer was not treated as proof of physical clearance.
All eight chests have zero footprint collisions, four clear approaches, and
four unobstructed swept paths from the entrance. They sit below the counter
and outside the central door aisle. None of these interiors has an
`AmbientVillager` route.

| Interior / crate | Nearest door (px) | Nearest NPC (px) | Clear approaches / swept paths |
|---|---:|---:|---|
| Ashlaren Millhouse / LockedSupplyCrate | 529.245 | 630.079 | 4 / 4 |
| Ashlaren Millhouse / BracedSupplyCrate | 594.643 | 635.059 | 4 / 4 |
| Ashlaren Weighing Hall / LockedSupplyCrate | 529.245 | 948.755 | 4 / 4 |
| Ashlaren Weighing Hall / BracedSupplyCrate | 594.643 | 635.059 | 4 / 4 |
| Kesselford Chandlery / LockedSupplyCrate | 529.245 | 630.079 | 4 / 4 |
| Kesselford Chandlery / BracedSupplyCrate | 594.643 | 1215.936 | 4 / 4 |
| Kesselford Wayhouse / LockedSupplyCrate | 529.245 | 948.755 | 4 / 4 |
| Kesselford Wayhouse / BracedSupplyCrate | 594.643 | 635.059 | 4 / 4 |

Pockets add no bodies or routes. For both outdoor scenes, the probe compared
all existing generated NPCs against a control instance with the new pocket
settings disabled in memory. Position, presence, collision layer, identity,
and dialogue matched in all four clock phases; population stayed 3 and 4.
Existing scene node/property lines and UID references were also compared
against `67767ce6` and preserved. No new obstacle occupies an NPC route.

The probe exercised all six pockets: 9 GP once on success, no reward on
failure, durable one-attempt state, and existing consequence ledgers. For all
eight chests it checked successful and failed locks without rerolls, one
table search, save-state round trips, the E input handler opening the loot
panel, item transfer, and one owned-container penalty per panel session.
This is headless runtime evidence; rendered captures remain assigned to Claude.

## Owner review: new strings (drafts)

**None.** No new player-facing prompt, description, feedback, NPC name, or
dialogue was authored, so there are no new msgids for PO/gettext extraction.
Every `LockedSupplyCrate` and `BracedSupplyCrate` listed above reuses
`"Supply Crate"` / `"Open"` from the existing Dom interior containers.
Lock, empty-container, owned-property, and pocket feedback come unchanged
from the existing scripts. Selected NPC display names come from their
existing generated roster rows. New IDs and node names are internal only.

## Checks with results (verbatim)

Commands ran from this worktree with Godot
`4.7.1.stable.official.a13da4feb`, no network, and disposable user data.
Full local logs are retained in ignored `reports/field-density-b2/`.
Terminal color escapes are removed from the verbatim summaries below.

### Audit before and after

```bash
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-b2-audit-before.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-b2-audit-after.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd
```

Process exit status: **0 each**. Both complete density and skill tables appear
below. Judge these printed tables, not the process status. Both runs also
emitted the pre-existing asynchronous main-menu shutdown diagnostics:

```text
SCRIPT ERROR: Parse Error: Could not preload resource file "res://ui/screens/main_menu_reflection.gdshader".
ERROR: Failed loading resource: res://ui/screens/main_menu.tscn.
```

The audit's source/classification notes remain: the R7/11c sources are absent
from this checkout, and Long Verge/Hollowmere remain in both reported views.

### Required unit and E2E suites

Requested Xvfb commands:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b2-unit-xvfb.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/unit
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b2-e2e-xvfb.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/e2e
```

Each exited **1** before tests started. Display errors, verbatim:

```text
ERROR: X11 Display is not available
ERROR: Can't connect to a Wayland display.
ERROR: Could not initialize the Wayland thread.
ERROR: Can't create the Wayland display server.
ERROR: Unable to create DisplayServer, all display drivers failed.
```

Authorized CI-equivalent headless fallback:

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b2-unit-headless.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/unit
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b2-e2e-headless.XXXXXX)" timeout 5400 bash scripts/test.sh -a test/e2e
```

Unit process exit status: **0**.

```text
Overall Summary: 1985 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (194/194)
Executed test cases : (1985/1985)
Exit code: 0
```

E2E process exit status: **0**.

```text
Overall Summary: 21 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (2/2)
Executed test cases : (21/21)
Exit code: 0
```

These summaries do not imply empty stderr. Unit negative fixtures emit
expected validation diagnostics. E2E emitted 74 occurrences of
`ERROR: Parameter "data.tree" is null.` from the existing detached Battle
path in `test_field_debt_journey.gd`, also recorded by B1. Teardown included:

```text
ERROR: 74 resources still in use at exit (run with --verbose for details).
ERROR: 56 resources still in use at exit (run with --verbose for details).
ERROR: 3 RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit.
```

The first resource count is from unit tests; the remaining lines are E2E.
These inherited diagnostics were not changed by this slice.

### Generated-data check

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 timeout 300 bash scripts/check_generated_data.sh
```

Process exit status: **0**. Verbatim result:

```text
GLOOT-GEN: no drift.
CANON-SEED: no drift.
LOCATIONS-GEN: no drift.
ISO-SPRITE-GEN: no drift. 598 sprites verified.
```

This check performed comparison only and restored `project.godot`.
No generated file needed regeneration. Its four engine processes also
reported resource-in-use diagnostics at shutdown (13 or 15 resources).

### Headless loading of every changed scene

```bash
for scene in world/ashlaren.tscn world/kesselford.tscn world/interiors/ashlaren_millhouse.tscn world/interiors/ashlaren_weighing_hall.tscn world/interiors/kesselford_chandlery.tscn world/interiors/kesselford_wayhouse.tscn; do
  scene_log="reports/field-density-b2/load-${scene##*/}.log"
  XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-b2-scene.XXXXXX)" LP_NUM_THREADS=1 timeout 60 "$HOME/.local/bin/godot" --headless --path . "res://$scene" --quit-after 30 -- capture-scene > "$scene_log" 2>&1
  printf '%s exit: %s\n' "$scene" "$?"
done
```

Verbatim process results:

```text
world/ashlaren.tscn exit: 0
world/kesselford.tscn exit: 0
world/interiors/ashlaren_millhouse.tscn exit: 0
world/interiors/ashlaren_weighing_hall.tscn exit: 0
world/interiors/kesselford_chandlery.tscn exit: 0
world/interiors/kesselford_wayhouse.tscn exit: 0
```

All six loaded with **no script, parse, or scene-load errors**. The literal
zero-error-output criterion is not satisfied: each process reported the
following during shutdown, also reproduced with the unchanged Item Shop
using the same invocation (`load-unchanged-item-shop.log`):

```text
WARNING: 5061 ObjectDB instances were leaked at exit (run with `--verbose` for details).
ERROR: 13 resources still in use at exit (run with --verbose for details).
```

Both outdoor hubs also retain their existing empty-Blocking warning:

```text
WARNING: Blocking is empty — nothing in this scene blocks movement. If that is intentional, delete the layer instead of leaving it unpainted.
```

The live physics checks include their existing StaticBody2D dressing; no
navigation layer, wall, door, or NPC path was edited to suppress a diagnostic.

### Focused regression and live placement/behavior probe

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b2-focused.XXXXXX)" timeout 180 bash scripts/test.sh -a test/unit/test_audit_field_coverage.gd -a test/unit/test_pickpocket.gd
XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-b2-probe.XXXXXX)" LP_NUM_THREADS=1 timeout 120 "$HOME/.local/bin/godot" --headless --path . res://reports/field-density-b2/probe.tscn -- capture-scene
```

Both process exit statuses: **0**. Verbatim summaries:

```text
Overall Summary: 32 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (2/2)
Executed test cases : (32/32)
Exit code: 0
B2 PROBE: 8 chests | 6 pockets | 0 failures
```

The probe's final run includes actual E-handler loot opening and item transfer.
It also reports 15 resources in use at shutdown. Its source and complete
placement/behavior output remain in the ignored reports directory for Claude.

### Existing hub population integration checks

The shared spawner change also passed the existing Ashlaren, Kesselford,
and Dom townsfolk suites, covering the generated populations, placement,
dialogue routes, interior NPCs, and existing hub contracts.

```bash
GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/soul-meter-b2-hubs.XXXXXX)" timeout 300 bash scripts/test.sh -a test/integration/test_ashlaren.gd -a test/integration/test_kesselford.gd -a test/integration/test_town_townsfolk.gd
```

Process exit status: **0**. Verbatim summary:

```text
Overall Summary: 19 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (3/3)
Executed test cases : (19/19)
Exit code: 0
```

The run also reported 13 resources still in use at shutdown, with no other
`ERROR:` or `SCRIPT ERROR:` lines. `git diff --check` passed, and the density,
skill, test-summary, and generator-result text in this document was checked
against the local logs for exact matches.

## Audit before

```text
PROVISIONAL density measurements
Measurement | Count | Target | Result
Distinct field skills / 22 | 13 | >= 15 | FAIL
Bellow checks | 1 | >= 1 | PASS
Verb: lockpick | 5 | >= 5 | PASS
Verb: pickpocket/steal | 13 | >= 5 | PASS
Verb: loot container | 22 | >= 5 | PASS
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
Hub ashlaren: locks | 0 | >= 4 | FAIL
Hub ashlaren: pockets | 0 | >= 3 | FAIL
Hub ashlaren: loot-table containers | 0 | >= 4 | FAIL
Hub kesselford: locks | 0 | >= 4 | FAIL
Hub kesselford: pockets | 0 | >= 3 | FAIL
Hub kesselford: loot-table containers | 0 | >= 4 | FAIL
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
Strain | 3 | >= 1 | PASS
Lilt | 0 | >= 1 | FAIL
Slip | 5 | >= 1 | PASS
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
Sounding | 13 | >= 1 | PASS
Falsetto | 0 | >= 1 | FAIL
Bellow | 1 | >= 1 | PASS
Vārum | 1 | >= 1 | PASS
Sway | 2 | >= 1 | PASS
Downbeat | 0 | >= 1 | FAIL
Brace | 0 | >= 1 | FAIL
Vantage | 0 | >= 1 | FAIL
```

## Audit after

```text
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
```

## Changed files

| Files | Change |
|---|---|
| `world/ashlaren.tscn`, `world/kesselford.tscn` | Pocket settings for three existing outdoor NPCs per hub |
| `world/interiors/ashlaren_millhouse.tscn`, `world/interiors/ashlaren_weighing_hall.tscn`, `world/interiors/kesselford_chandlery.tscn`, `world/interiors/kesselford_wayhouse.tscn` | Two existing-template locked table-backed crates per scene |
| `world/town_npc_spawner.gd`, `tools/audit_field_coverage.gd` | Opt-in pocket wiring and matching structural audit support |
| `test/unit/test_pickpocket.gd`, `test/unit/test_audit_field_coverage.gd` | Three regression cases for real pocket behavior and counting boundaries |
| `docs/qa/field-density-b2-review-2026-10-31.md` | This review and verbatim evidence |

Dom, Long Verge, Hollowmere, all wild scenes, Pandora, generated artifacts,
art, vendor addons, owner decisions, and roadmaps are unchanged. The six
untracked `.gd.uid` files already present at dispatch were preserved and
excluded from commits. Local ignored probes/logs are not shipped source.

## Commits

- `77312c52` — `feat(field): support pockets on existing generated townsfolk`
- `24aaa006` — `feat(world): add Ashlaren and Kesselford field opportunities`

The implementation commits succeeded. The final attempt to stage and commit
this evidence document was refused because the shared worktree Git metadata
was read-only. This file remains complete but untracked. Exact error:

```text
fatal: Unable to create '/home/adamjroder/projects/soul-meter/.git/worktrees/codex-p1-2c/index.lock': Read-only file system
```

No branch switch, push, PR, or network call. No permission workaround was used.

## Risks

Rendered placement, readability, and pointer behavior remain unverified here;
Claude owns the requested rendered captures. Headless scene loading and the
physics probe establish placement and behavior, not visual quality.

The command-line audit still emits its baseline main-menu shutdown errors.
All scene processes still emit baseline resource-leak diagnostics at teardown;
thus a literal completely error-free log is not claimed. Xvfb was unavailable,
so unit/E2E evidence uses the explicitly authorized headless fallback.

The spawner's new optional dictionary is shared code, but only these two scenes
configure it. Natural Slip/Strain choices deliberately leave the distinct-skill
target short. Existing lock/pocket failures remain permanent one-attempt
outcomes; no difficulty, persistence, or economy policy was revised.

## Open decisions

New B2 decisions: none. Stretched skill mappings used: none.

Existing owner question: Long Verge/Hollowmere hub classification remains unresolved and untouched.

Global shortfall: two additional natural field-skill opportunities remain for a separately scoped slice.

## Next slice

Claude should commit this completed review document when Git metadata is
writable, then capture the six changed scenes using the object table above.
The next implementation handoff can address naturally fitting absent skills;
item/loot-table expansion needs its separate authorized scope. Do not infer
permission to fill Long Verge/Hollowmere hub rows before the hub question is
resolved.

## Handoff back

Ashlaren and Kesselford each moved from **0/0/0 to 4/3/4**
(locks/pockets/table-backed containers). The scene/node table above identifies
every new object and existing pocket target. The required unit and E2E suites
passed with headless fallback; generated-data checks report no drift. All six
changed scenes load, with the documented inherited teardown diagnostics.
No new strings or stretched skill mappings require owner review. Distinct
skills remain 13. Implementation commits are `77312c52` and `24aaa006`;
this review document remains untracked because the final Git write was
refused. Claude should commit the document and perform the rendered captures.

## Rendered check (Claude, Xvfb, 2026-10-31)

`field-density-b2-interiors-2026-10-31.png`: the four changed interiors (Ashlaren Millhouse, Kesselford Wayhouse, Kesselford Chandlery, Ashlaren Weighing Hall). In each, the two new crates sit either side of the exit door on open floor, clear of the door and the counter. The outdoor pockets reuse existing townsfolk and add no visible object.
