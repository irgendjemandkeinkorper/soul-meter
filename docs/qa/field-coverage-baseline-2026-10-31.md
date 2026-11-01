# Field coverage baseline — 2026-10-31

P1.2 / #531, slice A. Content baseline: `45a83c5f`; instrument and fixtures: `fdb05c87`.
No game content was authored for this measurement. All density targets below are **PROVISIONAL**.

Godot version command: `~/.local/bin/godot --version`

```text
4.7.1.stable.official.a13da4feb
```

Exact audit capture command (repository root; disposable user data):

```bash
PATH="$HOME/.local/bin:$PATH" XDG_DATA_HOME="$(mktemp -d /tmp/soul-meter-field-audit.XXXXXX)" godot --headless --path . --script res://tools/audit_field_coverage.gd > /tmp/soul-meter-field-audit-baseline.log 2>&1
```

The command completed with exit status 0. Judge the printed report, never the exit code:
Godot also printed main-menu preload errors and teardown leak diagnostics after the
measurement. They are preserved in the combined stdout/stderr below.

## Raw output

```text
Godot Engine v4.7.1.stable.official.a13da4feb - https://godotengine.org

Field coverage audit — P1.2 slice A
Judge the printed report, never the exit code.
PROVISIONAL targets: brief citing owner-decisions R7 / item 11c; not ratified here.
Shipped registry world scenes: 33 (templates and test fixtures excluded).

PROVISIONAL density measurements
Measurement | Count | Target | Result
Distinct field skills / 22 | 10 | >= 15 | FAIL
Bellow checks | 0 | >= 1 | FAIL
Verb: lockpick | 1 | >= 5 | FAIL
Verb: pickpocket/steal | 7 | >= 5 | PASS
Verb: loot container | 12 | >= 5 | PASS
Verb: cache | 4 | >= 5 | FAIL
Verb: barter | 16 | >= 5 | PASS
Verb: talk | 88 | >= 5 | PASS
Verb: pickup | 5 | >= 5 | PASS
Verb: switch | 1 | >= 5 | FAIL
Verb: inspect/interact | 7 | >= 5 | PASS
Verb: save | 1 | >= 5 | FAIL
Verb: travel | 67 | >= 5 | PASS
Verb: party selection | 1 | >= 5 | FAIL
Verb: damage structure | 0 | >= 5 | FAIL
Hub dom: locks | 0 | >= 4 | FAIL
Hub dom: pockets | 1 | >= 3 | FAIL
Hub dom: loot-table containers | 0 | >= 4 | FAIL
Hub ashlaren: locks | 0 | >= 4 | FAIL
Hub ashlaren: pockets | 0 | >= 3 | FAIL
Hub ashlaren: loot-table containers | 0 | >= 4 | FAIL
Hub kesselford: locks | 0 | >= 4 | FAIL
Hub kesselford: pockets | 0 | >= 3 | FAIL
Hub kesselford: loot-table containers | 0 | >= 4 | FAIL
Hub long_verge: locks | 0 | >= 4 | FAIL
Hub long_verge: pockets | 0 | >= 3 | FAIL
Hub long_verge: loot-table containers | 0 | >= 4 | FAIL
Hub hollowmere: locks | 0 | >= 4 | FAIL
Hub hollowmere: pockets | 0 | >= 3 | FAIL
Hub hollowmere: loot-table containers | 0 | >= 4 | FAIL
Wild dorthkor_road: caches | 2 | >= 2 | PASS
Wild hollowmere: caches | 0 | >= 2 | FAIL
Wild long_verge: caches | 0 | >= 2 | FAIL
Wild wilds: caches | 0 | >= 2 | FAIL
Wild wound_lip: caches | 2 | >= 2 | PASS
Loot tables | 2 | >= 8 | FAIL
Items | 22 | >= 40 | FAIL

Field skill occurrences (>= 1 contributes to the 15/22 target; no quota for every skill)
Skill | Checks | Presence contribution | Result
Strain | 2 | >= 1 | PASS
Lilt | 0 | >= 1 | FAIL
Slip | 3 | >= 1 | PASS
Tread | 0 | >= 1 | FAIL
Beastbond | 1 | >= 1 | PASS
Varlore | 0 | >= 1 | FAIL
Unweave | 2 | >= 1 | PASS
Recall | 1 | >= 1 | PASS
Wildlore | 0 | >= 1 | FAIL
Devotion | 0 | >= 1 | FAIL
Undertone | 3 | >= 1 | PASS
Mending | 0 | >= 1 | FAIL
Ear | 0 | >= 1 | FAIL
Wayfinding | 1 | >= 1 | PASS
Sounding | 3 | >= 1 | PASS
Falsetto | 0 | >= 1 | FAIL
Bellow | 0 | >= 1 | FAIL
Vārum | 1 | >= 1 | PASS
Sway | 2 | >= 1 | PASS
Downbeat | 0 | >= 1 | FAIL
Brace | 0 | >= 1 | FAIL
Vantage | 0 | >= 1 | FAIL

SUPERSEDED comparison only: >= 12/22 skills, each checked >= 3 times
Skills with >= 3 checks / 22 | 3 | >= 12 | FAIL
Strain | 2 | >= 3 | FAIL
Lilt | 0 | >= 3 | FAIL
Slip | 3 | >= 3 | PASS
Tread | 0 | >= 3 | FAIL
Beastbond | 1 | >= 3 | FAIL
Varlore | 0 | >= 3 | FAIL
Unweave | 2 | >= 3 | FAIL
Recall | 1 | >= 3 | FAIL
Wildlore | 0 | >= 3 | FAIL
Devotion | 0 | >= 3 | FAIL
Undertone | 3 | >= 3 | PASS
Mending | 0 | >= 3 | FAIL
Ear | 0 | >= 3 | FAIL
Wayfinding | 1 | >= 3 | FAIL
Sounding | 3 | >= 3 | PASS
Falsetto | 0 | >= 3 | FAIL
Bellow | 0 | >= 3 | FAIL
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
SCRIPT ERROR: Parse Error: Could not resolve external class member "LOAD_GAME".
   at: GDScript::reload (res://ui/screens/main_menu.gd:69)
SCRIPT ERROR: Parse Error: Could not resolve external class member "SETTINGS".
   at: GDScript::reload (res://ui/screens/main_menu.gd:74)
ERROR: Failed to load script "res://ui/screens/main_menu.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
ERROR: res://ui/screens/main_menu.tscn:7 - Parse Error: .
   at: _printerr (scene/resources/resource_format_text.cpp:41)
ERROR: Failed loading resource: res://ui/screens/main_menu.tscn.
   at: _load (core/io/resource_loader.cpp:317)
WARNING: 5065 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2536)
ERROR: 13 resources still in use at exit (run with --verbose for details).
   at: clear (core/io/resource.cpp:822)
```

## Gap to target

“More required” is `max(0, target - measured)`. Skill-presence rows show the
contribution of each skill to the **15 of 22** aggregate; they do not impose a
one-check quota on all 22 skills. Superseded rows are comparison only.

| Measurement | More required |
|---|---:|
| Provisional: Distinct field skills / 22 | 5 |
| Provisional: Bellow checks | 1 |
| Provisional: Verb: lockpick | 4 |
| Provisional: Verb: pickpocket/steal | 0 |
| Provisional: Verb: loot container | 0 |
| Provisional: Verb: cache | 1 |
| Provisional: Verb: barter | 0 |
| Provisional: Verb: talk | 0 |
| Provisional: Verb: pickup | 0 |
| Provisional: Verb: switch | 4 |
| Provisional: Verb: inspect/interact | 0 |
| Provisional: Verb: save | 4 |
| Provisional: Verb: travel | 0 |
| Provisional: Verb: party selection | 4 |
| Provisional: Verb: damage structure | 5 |
| Provisional: Hub dom: locks | 4 |
| Provisional: Hub dom: pockets | 2 |
| Provisional: Hub dom: loot-table containers | 4 |
| Provisional: Hub ashlaren: locks | 4 |
| Provisional: Hub ashlaren: pockets | 3 |
| Provisional: Hub ashlaren: loot-table containers | 4 |
| Provisional: Hub kesselford: locks | 4 |
| Provisional: Hub kesselford: pockets | 3 |
| Provisional: Hub kesselford: loot-table containers | 4 |
| Provisional: Hub long_verge: locks | 4 |
| Provisional: Hub long_verge: pockets | 3 |
| Provisional: Hub long_verge: loot-table containers | 4 |
| Provisional: Hub hollowmere: locks | 4 |
| Provisional: Hub hollowmere: pockets | 3 |
| Provisional: Hub hollowmere: loot-table containers | 4 |
| Provisional: Wild dorthkor_road: caches | 0 |
| Provisional: Wild hollowmere: caches | 2 |
| Provisional: Wild long_verge: caches | 2 |
| Provisional: Wild wilds: caches | 2 |
| Provisional: Wild wound_lip: caches | 0 |
| Provisional: Loot tables | 6 |
| Provisional: Items | 18 |
| Skill presence contribution: Strain | 0 |
| Skill presence contribution: Lilt | 1 |
| Skill presence contribution: Slip | 0 |
| Skill presence contribution: Tread | 1 |
| Skill presence contribution: Beastbond | 0 |
| Skill presence contribution: Varlore | 1 |
| Skill presence contribution: Unweave | 0 |
| Skill presence contribution: Recall | 0 |
| Skill presence contribution: Wildlore | 1 |
| Skill presence contribution: Devotion | 1 |
| Skill presence contribution: Undertone | 0 |
| Skill presence contribution: Mending | 1 |
| Skill presence contribution: Ear | 1 |
| Skill presence contribution: Wayfinding | 0 |
| Skill presence contribution: Sounding | 0 |
| Skill presence contribution: Falsetto | 1 |
| Skill presence contribution: Bellow | 1 |
| Skill presence contribution: Vārum | 0 |
| Skill presence contribution: Sway | 0 |
| Skill presence contribution: Downbeat | 1 |
| Skill presence contribution: Brace | 1 |
| Skill presence contribution: Vantage | 1 |
| Superseded: Skills with >= 3 checks / 22 | 9 |
| Superseded: Strain | 1 |
| Superseded: Lilt | 3 |
| Superseded: Slip | 0 |
| Superseded: Tread | 3 |
| Superseded: Beastbond | 2 |
| Superseded: Varlore | 3 |
| Superseded: Unweave | 1 |
| Superseded: Recall | 2 |
| Superseded: Wildlore | 3 |
| Superseded: Devotion | 3 |
| Superseded: Undertone | 0 |
| Superseded: Mending | 3 |
| Superseded: Ear | 3 |
| Superseded: Wayfinding | 2 |
| Superseded: Sounding | 0 |
| Superseded: Falsetto | 3 |
| Superseded: Bellow | 3 |
| Superseded: Vārum | 2 |
| Superseded: Sway | 1 |
| Superseded: Downbeat | 3 |
| Superseded: Brace | 3 |
| Superseded: Vantage | 3 |

## Counting boundaries

- Sources are registry-backed scenes under `world/`, their actor/inherited scene
  dependencies, `dialogue/**/*.dialogue`, loot tables, item prototypes, and placed
  roster/vendor rows. Templates, unregistered scenes, and test fixtures do not add
  instances. `world/test_room.tscn` is included because it ships as Wilds.
- A lock is the `SMInteractable` skill-lock mechanism with a skill and durable ID
  (a Chest may inherit its container ID). This includes Strain/force locks.
  Flag-only doors and a dialogue's Slip check do not become lockpick instances.
- A cache is a Chest in a mapped non-fast-travel location, regardless of name or
  prose; it also counts as a loot container. Hub lock/pocket/container totals include
  interiors reached recursively through registry `transition.source_scene` links.
  A hub loot-table container must reference a known table and have no fixed loot
  override, matching Chest's runtime precedence.
- Steal opportunities include NPC pockets plus owned chests/pickups; only NPC pockets
  contribute to the per-hub pocket target. Barter counts access points (14 spawned
  vendors plus two legacy shop doors here), so it is not a count of unique merchants.
  Runtime roster NPCs contribute talk opportunities, but their spawners do not wire
  pocket properties. Passive Sway prices are not rolled checks.
- Skill checks count executable dialogue call sites, skill locks, NPC pockets, and
  each distinct loot-search skill once per placed table-backed container. Repeated
  table rows for the same skill do not create extra rolls. Unused loot tables still
  count as tables but create no check opportunities. Combat checks, automatic
  events, and UI-only actions are outside this field audit.

## Risks and open decisions

The source parser handles serialized nodes, nested/inherited instances, script class
inheritance, literal exported defaults, and the current dialogue check syntax. It
does not prove runtime reachability or execute arbitrary procedural spawning code;
the roster/vendor spawners and DomTavern's counter/exit have explicit adapters.
New interaction classes or spawning conventions require updating the instrument.

The checkout does not contain `docs/roadmap-2026-10-30.md` or the cited R7/11c
answered density entries. Its item 11 still leaves skill coverage and loot density
open. The brief's targets are shown provisionally; the 12-skills/3-checks comparison
is retained separately. **Open:** reconcile the missing decision sources before
treating these numbers as ratified.

The brief fixes five hub rows. The shipped fast-travel index has Dom, Ashlaren, and
Kesselford; Long Verge and Hollowmere are mapped wilds with no fast-travel facet.
Both requested hub rows and registry wild rows are retained. **Open:** reconcile
the five-hub density scope with the three-hub registry; no membership was changed.

