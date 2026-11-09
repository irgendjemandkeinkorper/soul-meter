# Hub portraits — issue #633 handoff

Ready for Claude's review on `codex/hub-npc-portraits`, based on `claude/land-rest`. No git writes or GitHub operations were performed. No production scripts, scenes, vendor code, names, bios, or race records were changed.

## Result

- 20 new portraits, each 512×512 opaque RGB PNG; all inspected individually and in the assembled sheet. No existing portrait overwritten.
- All 20 canon records change only `portrait_path`. The canonical seeder changes exactly 20 Pandora Portrait Path values. The canonical generator changes exactly 20 `portrait.kind` / `portrait.asset_path` pairs across the four hub rosters, with no other roster changes.
- Four 1920×1080 dialogue captures inspected: painted portrait visible, expected texture resource path loaded, monogram hidden. The harness uses each spawned NPC's real dialogue path and cue in the production balloon over its hub scene.
- Four focused suites: **38 tests, 0 errors, 0 failures**, all exit 0. Generated-data drift is checked by `test_generator_reports_sixty_npcs_and_no_committed_drift` in the roster suite.
- Field audit: **29 current density targets PASS, 0 FAIL**. Its per-skill presence diagnostics and explicitly SUPERSEDED comparisons still print FAIL rows; these are not current density gates. See diagnostic notes below.

## Art and generation accounting

Built-in `image_gen`: **22 / 40 submitted generations**, at most 2 per NPC. Eighteen NPCs used 1/2 each. Odile Marrowby and Mabbe Sloe used 2/2 each: their first requests produced no image after approximately 20 minutes, the waiting execution was terminated, and their second requests succeeded. Both stalled requests count toward the cap. No returned image was rejected for quality.

Sources were square RGB images at 1254×1254. Pillow exported each to 512×512 using LANCZOS, without cropping or repainting. PIL checked all final modes and dimensions; there are no alpha channels. Full verbatim prompts, source image paths, per-attempt status, and export details are in [provenance.json](provenance.json).

The sources specify occupations and context but no individual physical descriptions. None lacked enough occupational context to paint. Age, features, hair, presentation, and mundane clothing are artistic interpretations, not new canon. The nineteen human-looking workers have no race assigned; owner item 28 (g) stays open. Ilse is Ghorr per the owner ruling and accepted U1 reference, with four distinct arms and hands visible.

**Unresolved format conflict for the draft PR:** art bible Part II requests transparent busts; the shipped Wave Z set and this issue require opaque RGB dark backgrounds. This batch follows the issue. The bible is unchanged.

## Contact sheet and captures

- [Wave Z format description sheet](../../../assets/generated/portraits/_contact_sheet_hubs_2026-11-09.md)
- [Assembled visual sheet](contact_sheet.png)
- [Kesselford — Hesk Waterward](kesselford_dialogue.png)
- [Ashlaren — Ilse Furrowgood](ashlaren_dialogue.png)
- [Long Verge — Tessaly Brack](long_verge_dialogue.png)
- [Hollowmere — Ysolde Marrow](hollowmere_dialogue.png)

## Commands run and observed summaries

All commands ran from the worktree root with Godot 4.7.1, one Godot process at a time. Every XDG data/config/cache location was under `/tmp/codex-portraits/`. Logs remain there. The test wrapper's XDG override was controlled with the matching `SOUL_METER_TEST_DATA_DIR`.

### Import

The following command was run three times: initial fresh-worktree import, a recheck after cache initialization errors, and final import of the new PNGs and capture harness. All exited 0. Logs: `import.log`, `import-recheck.log`, `import-final.log`.

```bash
XDG_DATA_HOME=/tmp/codex-portraits/data XDG_CONFIG_HOME=/tmp/codex-portraits/config XDG_CACHE_HOME=/tmp/codex-portraits/cache GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 xvfb-run -a "$HOME/.local/bin/godot" --headless --path . --import
```

### Seeder and generator

The unchanged production scripts were loaded as Nodes after autoload initialization by `/tmp/codex-portraits/run_tool.gd`. This provides their normal `_ready()` execution without editing `project.godot`; the launcher only loads the user argument, instantiates it, and adds it to the SceneTree root. Seeder ran before generator. No generated file was hand-edited.

```bash
XDG_DATA_HOME=/tmp/codex-portraits/seed-data XDG_CONFIG_HOME=/tmp/codex-portraits/config XDG_CACHE_HOME=/tmp/codex-portraits/cache GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 "$HOME/.local/bin/godot" --headless --path . --script /tmp/codex-portraits/run_tool.gd -- res://tools/seed_town_npcs.gd
XDG_DATA_HOME=/tmp/codex-portraits/generate-data XDG_CONFIG_HOME=/tmp/codex-portraits/config XDG_CACHE_HOME=/tmp/codex-portraits/cache GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 "$HOME/.local/bin/godot" --headless --path . --script /tmp/codex-portraits/run_tool.gd -- res://tools/generate_gloot.gd
```

```text
DOM-NPC-SEED: 80 authored townsfolk present.
DATA-GEN: wrote 41 item prototypes, 14 vendors, 12 encounters, and 60 Dom NPCs.
```

Both exited 0; logs: `seed-town-npcs.log`, `generate-gloot.log`.

### Field audit

```bash
XDG_DATA_HOME=/tmp/codex-portraits/data XDG_CONFIG_HOME=/tmp/codex-portraits/config XDG_CACHE_HOME=/tmp/codex-portraits/cache GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 "$HOME/.local/bin/godot" --headless --path . --script res://tools/audit_field_coverage.gd
```

Observed summary from the report's current density section: **29 PASS, 0 FAIL**. Exit 0; log: `audit-field-coverage.log`. This ran after the canon path edits, before regeneration; the later generated diff is verified to contain only portrait descriptors, which do not contribute to field opportunities. The audit unit suite below also passed after regeneration.

### Focused suites

```bash
XDG_DATA_HOME=/tmp/codex-portraits/portrait-suite XDG_CONFIG_HOME=/tmp/codex-portraits/config XDG_CACHE_HOME=/tmp/codex-portraits/cache SOUL_METER_TEST_DATA_DIR=/tmp/codex-portraits/portrait-suite GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/integration/test_dialogue_balloon_portraits.gd
```

```text
Statistics: 2 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 900ms
Exit code: 0
```

Log: `/tmp/codex-portraits/test-dialogue-balloon-portraits.log`.

```bash
XDG_DATA_HOME=/tmp/codex-portraits/roster-suite XDG_CONFIG_HOME=/tmp/codex-portraits/config XDG_CACHE_HOME=/tmp/codex-portraits/cache SOUL_METER_TEST_DATA_DIR=/tmp/codex-portraits/roster-suite GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/unit/test_dom_npc_roster.gd
```

```text
Statistics: 13 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 1s 753ms
Exit code: 0
```

Log: `/tmp/codex-portraits/test-dom-npc-roster.log`.

```bash
XDG_DATA_HOME=/tmp/codex-portraits/audit-suite XDG_CONFIG_HOME=/tmp/codex-portraits/config XDG_CACHE_HOME=/tmp/codex-portraits/cache SOUL_METER_TEST_DATA_DIR=/tmp/codex-portraits/audit-suite GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/unit/test_audit_field_coverage.gd
```

```text
Statistics: 19 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 1s 246ms
Exit code: 0
```

Log: `/tmp/codex-portraits/test-audit-field-coverage.log`.

```bash
XDG_DATA_HOME=/tmp/codex-portraits/capture-suite XDG_CONFIG_HOME=/tmp/codex-portraits/config XDG_CACHE_HOME=/tmp/codex-portraits/cache SOUL_METER_TEST_DATA_DIR=/tmp/codex-portraits/capture-suite GODOT_BIN="$HOME/.local/bin/godot" LP_NUM_THREADS=1 xvfb-run -a -s "-screen 0 1920x1080x24" bash scripts/test.sh -a test/manual/hub_portraits_capture.gd
```

```text
Statistics: 4 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans | PASSED 51s 706ms
Exit code: 0
```

Log: `/tmp/codex-portraits/capture-hub-portraits.log`.

### Static checks

PIL: 20/20 PNGs, 512×512 RGB, no alpha; 22/40 calls, maximum 2 per NPC. Canon comparison against HEAD: 20/20 records differ only in `portrait_path`. Generated roster comparison: exactly 20 kind/path pairs changed. `git diff --check`: exit 0. Final changed-path scope check: no out-of-scope files.

## Diagnostics and deviations

- Initial fresh-cache import printed UID/plugin parse errors; the recheck cleared those. Final import had no parse errors but printed a Phantom Camera updater `add_theme_color_override` on Nil at `addons/phantom_camera/scripts/panel/updater/update_button.gd:101`, plus editor singleton/dock and shutdown leak messages. Vendor code is unchanged.
- The direct field-audit script printed its complete report, then main-menu `GameFlow.LOAD_GAME` / `SETTINGS` external-member parse errors during shutdown; exit remained 0. The runtime suites subsequently loaded successfully. These diagnostics were not suppressed or patched.
- Focused suite assertions all passed; Godot still printed ObjectDB/resource leak diagnostics after their summaries (15 resources in the portrait suite; 18 in the capture suite). No process crashed. Full logs are retained under `/tmp/codex-portraits/`.
- Two image requests stalled; counted and retried once each, within the cap.
- Temporary launcher replaces temporary autoload registration solely to avoid editing out-of-scope `project.godot`; both canonical tools executed unchanged in the required order.

## Changed files by directory

### `assets/generated/portraits/`

Twenty new portrait PNGs, their twenty engine-generated `.png.import` sidecars, and `_contact_sheet_hubs_2026-11-09.md`. Every PNG stem and description is listed in the contact sheet.

### Canon character records

`canon/kesselford/characters/`:

- `kesselford-bell-ringer.json`
- `kesselford-ferry-keeper.json`
- `kesselford-grain-factor.json`
- `kesselford-mender-pair-elder.json`
- `kesselford-mender-pair-junior.json`
- `kesselford-wayhouse-keeper.json`

`canon/ashlaren/characters/`:

- `ashlaren-bell-warden.json`
- `ashlaren-ghorr-steward.json`
- `ashlaren-head-factor.json`
- `ashlaren-miller.json`
- `ashlaren-warehouse-watch.json`
- `ashlaren-weigh-clerk.json`

`canon/long_verge/characters/`:

- `long-verge-cairn-warden.json`
- `long-verge-old-soldier.json`
- `long-verge-paymaster.json`
- `long-verge-recruit.json`
- `long-verge-sergeant.json`

`canon/hollowmere/characters/`:

- `hollowmere-envoy.json`
- `hollowmere-mender.json`
- `hollowmere-watcher.json`

### Database and generated data

- `data.pandora`
- `data/generated/kesselford_npc_roster.json`
- `data/generated/ashlaren_npc_roster.json`
- `data/generated/long_verge_npc_roster.json`
- `data/generated/hollowmere_npc_roster.json`

### `docs/qa/hub-portraits-2026-11-09/`

`README.md`, `provenance.json`, `contact_sheet.png`, `test/manual/hub_portraits_capture.gd` (moved there by Claude; it now writes to `user://qa/hub-portraits/`), plus `kesselford_dialogue.png`, `ashlaren_dialogue.png`, `long_verge_dialogue.png`, and `hollowmere_dialogue.png`.

Next owner of work: Claude reviews the assets/diff, includes the format conflict in the draft PR, and handles commits and GitHub. No further generation or implementation is needed for this batch.
