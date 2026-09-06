# Testing

Answers the open human question in `docs/godot-architecture.md` ("gdUnit4 or GUT?"): **gdUnit4**,
because its `SceneRunner` can simulate real input and step real physics frames against an
actual scene — most of what's worth testing here (reputation-gated dialogue, field-room
movement/collision, statechart transitions) is a *scene* behaving correctly, not just a
function returning the right value. Decision recorded 2026-07-26.

This doc covers both halves: **automated tests** (gdUnit4, deterministic, run by a machine) and
**manual tests** (checklists a human runs, for anything that's about *feel* — readability,
pacing, "does this look right").

## Automated tests

### Where they live

```
test/
  unit/         # pure logic, no scene tree needed — instantiate a script, assert on it
  integration/  # a real .tscn driven via SceneRunner — input, physics, node wiring
```

One `GdUnitTestSuite` subclass per file, named `test_<thing>.gd`. gdUnit4's default scan root
is `res://test` — that's not configurable in this project and there's no reason to change it.

Two worked examples to copy from:

- [`test/unit/test_reputation.gd`](../test/unit/test_reputation.gd) — pure-logic suite against
  `globals/reputation.gd`. Every public method (`record`, `standing`, `band`, `why`,
  `events_for`, the `reputation_changed` signal, `to_dict`/`from_dict` save round-trip).
- [`test/integration/test_field_room.gd`](../test/integration/test_field_room.gd) — drives
  `world/test_room.tscn` with simulated input: player movement, wall collision, and the NPC
  talk-prompt appearing only in range.
- [`test/unit/test_fast_travel.gd`](../test/unit/test_fast_travel.gd) — validates the FR-503
  registry, discovery/save round-trip, affordability, exact GP deduction, and failure invariants.
- [`test/integration/test_region_map.gd`](../test/integration/test_region_map.gd) — verifies
  discovered-only destination filtering, current/unaffordable button states, pause-menu wiring,
  purchase feedback, and post-load discovery.

### Running them

The project's headless Godot binary runs the suite via gdUnit4's own CLI wrapper (same binary
and pattern as the `--import` headless-verify step in `DEPENDENCIES.md`):

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh
```

Narrow to one directory or one file the same way:

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh -a test/unit/test_reputation.gd
```

Run the focused FR-503 suites before the full suite:

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh -a test/unit/test_fast_travel.gd
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh -a test/integration/test_region_map.gd
```

Field-dressing changes should run the reference Wound Lip contract together with the
scene being changed. For Dorthkor Road:

```bash
GODOT_BIN=~/.local/bin/godot SOUL_METER_HEADLESS=1 bash scripts/test.sh \
  -a test/integration/test_wound_lip.gd \
  -a test/integration/test_dorthkor_road.gd
```

These contracts assert the exact three-layer composition, collision-bearing solid
props, bounded ambient motion, and (for Dorthkor) traveler containment plus actual
movement. The paired movement assertion prevents a stationary traveler from producing
a false-green containment result.

Exit code `0` means every test passed — that's the signal to check in CI or a pre-push hook.
`scripts/test.sh` intentionally invokes `GdUnitCmdTool.gd` directly: the addon wrapper's
remote-debug `tcp://127.0.0.1:0` mode is not accepted by Godot 4.7.1. `reports/` (HTML + JUnit
XML, gitignored) is regenerated each run.

On a machine without a working X display, set `SOUL_METER_HEADLESS=1`. This is useful for unit
tests, but integration tests that depend on transported input should run with Xvfb normally.

### Generated-data drift

Pandora is the source of truth for generated runtime artifacts. Run the same guard used by CI
after changing `data.pandora` or `tools/generate_gloot.gd`:

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/check_generated_data.sh
```

The check temporarily registers the generator as an autoload, compares every generated artifact
without writing it, and restores the project configuration before exiting. A non-zero exit means
regenerate locally and commit the resulting files.

You can also run tests from inside the editor: the gdUnit4 dock (bottom panel, once the addon
is enabled — it's already registered in `project.godot`) shows the same suites with a
run/debug button per test. Useful for stepping through a failure; the CLI is what CI would use.

### Writing a new unit test

For logic living on an autoload script (`globals/*.gd`), don't touch the shared singleton —
instantiate the script fresh so tests can't leak state into each other:

```gdscript
extends GdUnitTestSuite

const ReputationScript := preload("res://globals/reputation.gd")

## Untyped on purpose — see the gotcha below.
var rep

func before_test() -> void:
	rep = auto_free(ReputationScript.new())

func test_standing_is_the_sum_of_deltas() -> void:
	rep.record("player", "mirror-choir", 10.0, "Returned the lost relic", "test_room")
	rep.record("player", "mirror-choir", -3.0, "Was late to the meeting", "test_room")
	assert_float(rep.standing("mirror-choir")).is_equal_approx(7.0, 0.001)
```

### Writing a new integration test

For anything that's really "does the scene behave correctly" — movement, collision, an
Area2D trigger, a statechart transition — load the real scene and drive it:

```gdscript
extends GdUnitTestSuite

func test_player_moves_right_when_holding_move_right() -> void:
	var runner := scene_runner("res://world/test_room.tscn")
	var player: Node2D = runner.find_child("Player", true, false)
	var start_x: float = player.global_position.x

	runner.simulate_action_press("move_right")
	await runner.simulate_frames(30)
	runner.simulate_action_release("move_right")

	assert_float(player.global_position.x).is_greater(start_x)
```

`scene_runner()` instantiates the scene for real (physics, `_ready()`, the works).
`simulate_action_*`/`simulate_key_*` fake input; `simulate_frames(n)` advances the engine n
frames (physics included) and must be `await`ed. `find_child(name, recursive, owned)` — pass
`owned: false`, or nodes created at runtime in code (not part of the `.tscn`) won't be found.

### Filesystem-I/O exception: save rotation tests

Most unit tests instantiate a fresh autoload script and avoid filesystem I/O. Save rotation and
recovery are the deliberate exception: the write-to-temp, backup rename, primary corruption, and
load fallback only make sense when exercised against real files. These tests still instantiate a
fresh `SaveGame`, override its three paths with unique files under `OS.get_temp_dir()`, and remove
those files before and after each test. They must never use the production `user://chapter_one.save`
paths, because that would make a test alter a developer's real save and could make a second run
depend on the first.

### Gotchas (hit while writing the examples above — save yourself the debugging)

- **⚠ `Autoload.CONST.mutable_property` reads a STALE value in GDScript.** Found 2026-08-07.
  `QuestRegistry.LOAMROOT_SPRIGS` is a `const`, so GDScript folds the whole member-access
  expression at parse time. The read returns the property's authored default forever, no matter
  what the game did to it at runtime. It is the same object — `get_instance_id()` matches — and
  the write succeeded; only the folded read lies.

  ```gdscript
  var quest: FetchQuest = QuestRegistry.LOAMROOT_SPRIGS
  quest.objective_completed = true
  quest.objective_completed                              # true   — correct
  QuestRegistry.LOAMROOT_SPRIGS.objective_completed      # FALSE  — folded, wrong
  ```

  **Fix: bind the const to a local typed variable, then read the property off that.** Method
  calls through the same chain (`QuestRegistry.is_active(...)`, `quest.update()`) are
  unaffected, as are never-mutated authored fields such as `required_flags`.

  **Two things this does NOT affect, both verified rather than assumed:**
  - **Dialogue conditions are safe.** Dialogue Manager resolves expressions at runtime instead
    of through the GDScript compiler. Eight shipped conditions read
    `QuestRegistry.LOAMROOT_SPRIGS.objective_completed`, and they evaluate correctly — checked
    against `DialogueResponse.is_allowed`, not by inspection.
  - **Production `.gd` code is clean.** The only chained read outside tests is
    `QuestRegistry.DOM_SIDE_QUESTS.size()`, a method call on an array that is never mutated.

  So the blast radius is test code. It is listed here because a test written the natural way
  fails for a reason that looks impossible, and the debugging cost is high.

- **Nodes built with `Foo.new()` at runtime don't keep the name you'd expect.** `npc.gd`
  builds its talk-prompt with `Label.new()` — Godot auto-names it `@Label@21` (id varies), not
  `"Label"`. `find_child("@Label@*", true, false)` (wildcard) finds it; `find_child("Label", ...)`
  silently returns `null`.
- **`var x := some_autoload_script.method()` fails to parse** ("Cannot infer the type of `x`")
  when the script has no `class_name` and the variable holding the instance is typed as `Node`
  (or untyped/dynamic) — the static analyzer can't see methods that only exist on the attached
  script. Fix: give the call an explicit type instead of inferring it —
  `var e: ReputationEvent = rep.record(...)` — or just don't type-annotate the receiving
  variable at all when the return type doesn't matter to the test.
- **`monitor_signals(obj)` auto-frees `obj` when the test ends** (default `_auto_free := true`).
  If your `after_test()` also calls `obj.free()`, that's a double free — a hard engine crash
  ("double free or corruption"), not a failed assertion. Use `auto_free()` everywhere and drop
  manual `.free()` calls instead of mixing the two.
- **Signal args must be unpacked, not passed as one array.**
  `assert_signal(x).is_emitted("sig", "a", "b")`, not `.is_emitted("sig", ["a", "b"])` — the
  latter tries to match a single array argument and always times out. If a signal carries an
  object you can't predict ahead of time (a freshly-constructed `ReputationEvent`, here), match
  it loosely with the `any()` argument matcher instead of a value.

### What isn't covered yet

CI imports with the pinned engine, runs the full suite, checks generated-data drift with the dedicated
generator guard, and packages the Windows playtest artifact only after tests pass. Property-based tests over the
reputation derivation and the (future) magic-system effect matrix — flagged as the reason
testing was worth doing at all (`docs/godot-architecture.md`) — don't exist yet; write them
once there's more than `_derive()`'s simple sum to get wrong.

### Headless Suite Stability Triage (Wave D7)

The four test suites flagged as potentially flaky under headless rendering and navmesh execution were rechecked on 2026-09-06 via 10 consecutive headless runs against Godot 4.7.1-stable, with `SOUL_METER_HEADLESS=1` and `LP_NUM_THREADS=1`:

- `test/unit/test_actor_presentation.gd`: 10/10 runs passed (2/2 test cases per run).
- `test/integration/test_y_sort.gd`: 10/10 runs passed (7/7 test cases per run).
- `test/integration/test_click_to_move.gd`: 10/10 runs passed (8/8 test cases per run).
- `test/nav_acceptance/test_click_to_move_input.gd`: 10/10 runs passed (1/1 test cases per run).

All 18 test cases passed in this sample (0 failures / 0 skips). A passing sample does not rule out intermittent failures; keep using Xvfb for input-dependent integration tests as described above.

## Manual tests

Some things a machine shouldn't grade: does the balloon text read at a sane pace, does a
reputation swing feel earned, is a screen legible at 1080p. Those get a **checklist**, not an
assertion — a markdown file a human (you, or a future contributor) works through and records
pass/fail against, the same way you'd file a bug.

### Where they live

```
test/manual/<system>_smoke_test.md
```

One file per feature area, not per session — update it in place as the feature grows instead
of writing a new dated file each time. [`test/manual/field_dialogue_smoke_test.md`](../test/manual/field_dialogue_smoke_test.md)
is the worked example, covering the currently-playable loop end to end.

### Format

Each checklist step is: **do this** → **expect this**. Keep steps small enough that a failure
points at one thing. A step that can be asserted by a machine belongs in `test/`, not here —
if you catch yourself writing "verify the number equals 7," that's `assert_int(...).is_equal(7)`
in a unit test, not a manual step.

### When to write one

- A new dialogue scene or reputation-gated choice → add steps to the dialogue smoke test (or a
  new file, if it's a genuinely separate conversation/location worth checking on its own).
- A new screen (Standing screen, the GLoot inventory screen once it's wired up) → new checklist
  file, same format: launch → interact → what should be on screen → what should update live.
- Anything about *feel* (camera easing, balloon pacing, whether a Soul Meter change reads as
  significant) — manual only; don't try to force these into an automated assertion.

### Running one

Launch the game the normal way (editor Play, or `godot --path .` from the built binary once
there is one) and work the checklist top to bottom. Note the Godot version and date at the top
of the file when you run it — that's what tells the next person whether a checklist is stale
relative to the current build.

### Manual run logs

The two release-facing checklists, [`prototype_acceptance.md`](../test/manual/prototype_acceptance.md)
and [`localization_smoke_test.md`](../test/manual/localization_smoke_test.md), each keep an
append-only run log with the date, build or commit, runner, and pass/fail summary. Record `NOT
RUN` when an interactive pass was not performed; never turn automated CI results into a claimed
human playtest. Backfill a prior entry only when its date and result can be reconstructed from
repository evidence.
