# Character creation randomize — 2026-11-01

Branch: `codex/chargen-randomize`. Engine: `4.7.1.stable.official.a13da4feb`.

## Behavior

The shared navigation footer exposes **RANDOMIZE** on all nine leaves, including
Summary. It stays in the keyboard focus cycle and retains the current page and
button focus after a roll. Each press replaces the build through a seedable
`ChargenRandomizer`, using `ChargenBuild`'s selection, purchase and validation API.
It selects a permitted discipline/class pairing and kit, legal Major/Minor and
held Mastery, ancestry, background, likeness, and fully spends both point pools.
Skill purchases happen after choices that would refund them.

Name, epithet and flaw are never rolled: they are the player's own text and carry over
unchanged (Claude review: the first draft drew them from existing NPC names, which would
hand the hero an NPC's identity). A blank name still blocks the summary, so a fresh
character needs a typed name before ACCEPT. The likeness is rolled from the rolled
ancestry's own likenesses.

Randomization also cancels pending attribute-bar tweens: a regression test caught
an old animation repainting a rolled Muster value of 2 as 4 after the roll.

## Changed files

- `ui/screens/character_creation.gd`: shared control, focus, refresh, and tween cancellation.
- `globals/chargen/chargen_randomizer.gd` and `.gd.uid`: seeded model-based roller; likeness follows ancestry.
- `test/unit/test_chargen_randomizer.gd` and `.gd.uid`: 200 seeds, exact budgets, variation of every sourced choice, determinism, identity fallback, immutable inputs, and purchase refund/replay.
- `test/integration/test_character_creation.gd`: scene-runner button → Summary → Confirm, retained member fields/portrait/ledger, every-page rerolls/focus, and animation regression.
- `locale/project.pot`, `locale/es.po`: matching untranslated draft entry; `docs/qa/2026-11-01-chargen-randomize.md`: this evidence.

## Verification

Each runner invocation uses a fresh `SOUL_METER_TEST_DATA_DIR` and `LP_NUM_THREADS=1`.
`xvfb-run` could not open its display: Xvfb reported `Cannot establish any listening
sockets`. Runs therefore use the explicitly permitted `SOUL_METER_HEADLESS=1`
fallback. Control signals and focus links are exercised; rendered appearance and
physical pointer input are **unverified**. No screenshot is claimed as evidence.

Focused chargen integration, after fixing the animation regression:

```text
Overall Summary: 7 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (1/1)
Executed test cases : (7/7)
Total execution time: 3s 81ms
Exit code: 0
```

Required unit command (exit 0):

```bash
SOUL_METER_TEST_DATA_DIR=$(mktemp -d /tmp/chargen-unit.XXXXXX) \
  SOUL_METER_HEADLESS=1 LP_NUM_THREADS=1 bash scripts/test.sh -a test/unit
```

```text
Overall Summary: 1950 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (191/191)
Executed test cases : (1950/1950)
Total execution time: 3min 37s 843ms
Exit code: 0
```

This includes all 200 seeds and the existing chargen build/data/art suites.
Godot printed `388132 ObjectDB instances were leaked at exit` and `74 resources
still in use at exit` after the successful unit summary and exit 0. These shutdown
warnings are retained here; gdUnit reported zero errors and orphans.

Required E2E/integration command:

```bash
SOUL_METER_TEST_DATA_DIR=$(mktemp -d /tmp/chargen-e2e-integration.XXXXXX) \
  SOUL_METER_HEADLESS=1 LP_NUM_THREADS=1 \
  bash scripts/test.sh -a test/e2e -a test/integration
```

```text
Overall Summary: 746 test cases | 0 errors | 0 failures | 0 flaky | 0 skipped | 0 orphans |
Executed test suites: (102/102)
Executed test cases : (746/746)
Total execution time: 4min 23s 881ms
Exit code: 0
```

This includes the seven chargen integration cases, including the original four.
Godot also printed shutdown warnings for 26955 ObjectDB instances, 77 resources,
and 4 dummy texture RIDs after exit 0.

Generated-data command (exit 0):

```bash
LP_NUM_THREADS=1 bash scripts/check_generated_data.sh
```

```text
GLOOT-GEN: no drift.
CANON-SEED: no drift.
LOCATIONS-GEN: no drift.
ISO-SPRITE-GEN: no drift. 598 sprites verified.
```

`git diff --check` passes. The data check restored `project.godot`; no generated
data, vendor addons, or Pandora source data changed. Raw local runner logs are
`/tmp/chargen-unit.log`, `/tmp/chargen-e2e-integration.log`, and
`/tmp/chargen-generated-data.log`. No rendered verification was available.

## Draft string and remaining limits

- **DRAFT: `RANDOMIZE`** — wrapped in `tr()` and present in both gettext catalogs;
  owner wording approval remains pending. No translation was invented.
- The label is added to the current catalogs. The existing `project.godot` POT
  extraction list does not include chargen; that configuration is outside the
  allowed file scope, so future engine template regeneration needs to retain this
  entry or register the source.
- Headless verification cannot establish visual appearance or pointer interaction.
- No gameplay or canon rulings are needed. Identity fallback behavior is the
  requested exception, and the feature remains a player feature.

## Claude review (2026-11-01)

Under Xvfb: renders `docs/qa/chargen-randomize-attributes-2026-11-01.png` and `docs/qa/chargen-randomize-summary-2026-11-01.png` (seed 7, Weftkin with a Weftkin likeness).
