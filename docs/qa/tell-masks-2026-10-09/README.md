# #445 tell-mask handoff — 2026-10-09

**Status: masks implemented; unit suite 9/9 and rendered Xvfb capture 2/2 pass (re-run by Claude on the host, 2026-10-09). Owner readability sign-off pending.** The rendered evidence is [tell-masks-contact-sheet-rendered.png](tell-masks-contact-sheet-rendered.png) and [field-strong-left-weak-right-1920.png](field-strong-left-weak-right-1920.png); the CPU preview below is superseded. Changes are uncommitted on `feat/tell-masks`. No GitHub operations, pushes, commits, or delegation were performed.

## Contact sheet

[tell-masks-cpu-preview.png](tell-masks-cpu-preview.png) shows all six archetypes with TYPICAL, STRONG (ember), and WEAK (pale) columns. It is explicitly labeled **CPU reference / Godot capture pending**. The preview reads the existing `Hostile.TELL_COLORS` and shader `tell_strength`, applies the shader's RGB mixing equation, and keeps sprite alpha. It is not evidence of GPU color conversion, filtering, field-scale readability, or a successful Xvfb run. The preview and enlarged anatomy overlays were inspected during authoring.

The amended source is the existing imagegen raster, as recorded in `assets/generated/sprites/manifests/units.json`. No 3D models or source-sprite edits were used. Each mask is a 256×256 RGBA PNG: binary grayscale RGB, white on the traced features, black elsewhere, and alpha copied byte for byte from its source. Canvas coordinates are unchanged, preserving the shared sprite pivot. The shader alone applies `mask.r * mask.a`; alpha is not multiplied into mask RGB during generation.

## Masked anatomy and new assets

All filenames below are under `assets/generated/sprites/units/<archetype>/`.

| Archetype | White regions | New filename | White pixels |
| --- | --- | --- | ---: |
| bog-wight | Eyes; exposed claw tips on both hands | `bog-wight--idle--se--f00--tellmask.png` | 130 |
| loam-maddened-boar | Visible eye; visible tusks | `loam-maddened-boar--idle--se--f00--tellmask.png` | 576 |
| gnaal-breach-hound | Visible eye; paw claw tips; visible maw teeth | `gnaal-breach-hound--idle--se--f00--tellmask.png` | 309 |
| gnaal-rift-scavenger | Visible eye; curved hand claws; foot claw tips | `gnaal-rift-scavenger--idle--se--f00--tellmask.png` | 703 |
| mustered-bloodbellow | Eyes beneath the brow; visible maw teeth | `mustered-bloodbellow--idle--se--f00--tellmask.png` | 52 |
| cleaned-jawbrace-guard | Eye openings through the visor only | `cleaned-jawbrace-guard--idle--se--f00--tellmask.png` | 28 |

Weapons, armor, horns, decorative skulls, hooves, roots and body glow are unmasked. The guard has no exposed claws in this frame. The wight's existing green glow/fringe is unchanged.

## Other changed files

- `tools/generate_tell_masks.py`: named per-archetype polygon traces, source SHA-256 guards, deterministic mask regeneration, `--check`, and optional CPU preview. Requires Python 3 and Pillow; this host's usable interpreter is `/usr/bin/python3` (Pillow 12.3.0). The default `python3` here lacks Pillow. No package was installed.
- `test/unit/test_enemy_derived.gd`: adds canvas/alpha/grayscale/nonempty-mask checks and real Hostile attachment checks for all six archetypes across WEAK/TYPICAL/STRONG.
- `test/manual/capture_spawn_variation.gd`: requires the wild wights' shader masks and adds all-six live shader captures, a labeled contact sheet, and pixel checks that tint changes stay inside masks without changing silhouette alpha.
- QA artifacts: this README, `tell-masks-cpu-preview.png`, `unit-enemy-derived-results.xml`, `unit-enemy-derived.log`, `capture-blocked.log`, and `xvfb-diagnostic.log`.

No `.tscn`, `uid://` reference, source sprite, manifest, gameplay number, tint color, or shader-strength change was made. Generated `.import` sidecars and the authoring helper's Python cache were removed from the working-tree handoff; re-import locally before testing again.

## Verification commands and observed results

Commands ran from the repository root. Every test invocation used its own newly created `SOUL_METER_TEST_DATA_DIR`. The final [unit log](unit-enemy-derived.log), [JUnit report](unit-enemy-derived-results.xml), [capture failure](capture-blocked.log), and [Xvfb diagnostic](xvfb-diagnostic.log) are preserved here. Earlier console logs remain at the `/tmp/codex-445-*.log` paths listed below.

### Generator and asset contract — PASS

```bash
/usr/bin/python3 tools/generate_tell_masks.py
/usr/bin/python3 tools/generate_tell_masks.py --check
/usr/bin/python3 tools/generate_tell_masks.py --check --preview docs/qa/tell-masks-2026-10-09/tell-masks-cpu-preview.png
git diff --check
```

All commands exited 0. Regeneration matches all six stored masks pixel for pixel. Independent Pillow checks also confirmed exact dimensions, grayscale channels and byte-identical source alpha.

### Focused unit suite — PASS (headless)

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/codex-445-unit-03.XXXXXX)" bash scripts/test.sh -a test/unit/test_enemy_derived.gd > /tmp/codex-445-unit-03.log 2>&1
```

Godot 4.7.1: **9/9 cases, 0 errors, 0 failures, 0 flaky, 0 skipped, 0 orphans; process exit 0**. gdUnit reported 237 ms. JUnit was copied from `reports/report_2/results.xml` to [unit-enemy-derived-results.xml](unit-enemy-derived-results.xml). Engine shutdown additionally reported 3,985 ObjectDB instances leaked and 13 resources still in use; there was no crash or script error. These diagnostics are retained as a limitation, not counted as clean engine shutdown.

Earlier exact invocations:

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/codex-445-unit-01.XXXXXX)" bash scripts/test.sh -a test/unit/test_enemy_derived.gd > /tmp/codex-445-unit-01.log 2>&1
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/codex-445-unit-02.XXXXXX)" bash scripts/test.sh -a test/unit/test_enemy_derived.gd > /tmp/codex-445-unit-02.log 2>&1
```

`unit-01`: exit 1 before test discovery because the display could not open. `unit-02`: 9/9 passed, exit 0; raw-PNG loading emitted export warnings. The test now reads PNG buffers directly; `unit-03` confirms those warnings are gone.

### Required Xvfb capture — PASS on host (blocked only inside the Codex sandbox)

Re-run by Claude outside the sandbox after `godot --headless --import` generated the masks' `.import` sidecars (which the repo tracks, like every sprite's): `scripts/test.sh -a test/manual/capture_spawn_variation.gd` → 2/2 passed, exit 0. Without the sidecars `Hostile` skips the tint (`ResourceLoader.exists` is false) and the wild-wight assertion fails.

The Codex sandbox run, kept for the record:

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/codex-445-capture-01.XXXXXX)" bash scripts/test.sh -a test/manual/capture_spawn_variation.gd > /tmp/codex-445-capture-01.log 2>&1
```

**Exit 1 before test execution.** Godot: `X11 Display is not available`, followed by failure to create any DisplayServer. The wrapper invokes Xvfb. A separate `xvfb-run -a -e /tmp/codex-445-xvfb.log xdpyinfo` diagnostic exited 1; Xvfb reported `Cannot establish any listening sockets`. No system display permissions were changed or sandbox restrictions bypassed.

The capture suite was also loaded through gdUnit discovery with its cases excluded:

```bash
GODOT_BIN=/home/adamjroder/.local/bin/godot LP_NUM_THREADS=1 SOUL_METER_HEADLESS=1 SOUL_METER_TEST_DATA_DIR="$(mktemp -d /tmp/codex-445-capture-parse-01.XXXXXX)" bash scripts/test.sh -a test/manual/capture_spawn_variation.gd -i capture_spawn_variation > /tmp/codex-445-capture-parse-01.log 2>&1
```

Discovery exited 0 without script errors, then reported no test cases because all were excluded. **Zero rendered tests ran; this is not a rendering pass.**

In an environment with a working display, the capture suite writes `user://qa/spawn_variation.png`, `user://qa/tell-masks-contact-sheet.png`, and 18 per-archetype native-resolution images. The Godot contact sheet uses the actual existing shader with its default strength. Copy the rendered sheet and field screenshot into this QA directory after a successful run; inspect them before treating acceptance as complete.

### Import preparation

This was a fresh worktree without an import cache. Two imports followed the repository CI's UID-cache bootstrap pattern:

```bash
task_import_data=$(mktemp -d /tmp/codex-445-import-01.XXXXXX)
SOUL_METER_TEST_DATA_DIR="$task_import_data" XDG_DATA_HOME="$task_import_data" LP_NUM_THREADS=1 /home/adamjroder/.local/bin/godot --headless --path . --import --quit > /tmp/codex-445-import-01.log 2>&1
task_import_data=$(mktemp -d /tmp/codex-445-import-02.XXXXXX)
SOUL_METER_TEST_DATA_DIR="$task_import_data" XDG_DATA_HOME="$task_import_data" LP_NUM_THREADS=1 /home/adamjroder/.local/bin/godot --headless --path . --import --quit > /tmp/codex-445-import-02.log 2>&1
```

Both exited 0. First scan: seven Pandora preload UID errors. Second scan: zero script parse/compile errors; editor socket, PhantomCamera singleton and shutdown-allocation diagnostics remained. No UID references were edited to resolve them.

## Risks and open questions

1. Field-scale readability is weak. At the in-world scale (~0.45) the strong wight shows only a faint ember fleck on a claw, and the weak wight's pale tint is barely visible. The guard's and bloodbellow's tells are hard to see even at the 256 px source size.
2. Owner anatomy/readability sign-off is pending, especially the guard's 28-pixel eye slit and bloodbellow's 52-pixel eye/maw mask at field scale. No extra body regions or stronger tint were added to compensate.
3. These traces apply only to the supplied idle/SE/frame-0 rasters. Future frames or changed art need reviewed traces; changed source hashes stop the generator before any mask is written.

No gameplay/design question was resolved beyond the owner's amendment. The remaining owner decision is whether the selected anatomy and eventual in-world readability are acceptable.
