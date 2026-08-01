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

### Gotchas (hit while writing the examples above — save yourself the debugging)

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
