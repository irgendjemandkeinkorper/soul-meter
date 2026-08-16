# Human action checklist

Updated: 2026-08-16

This is the complete human-only checklist for the remaining open issues labelled
`delegated-to-codex`. Code, tests, commits, pull requests, and merges can return to Codex after
these decisions and source materials are available.

Issues #204 and #168 are complete and merged. You do not need to do anything for them.

## At a glance

| Priority | Issue | What only a human can provide | Unblocks |
|---:|---|---|---|
| 1 | [#169](https://github.com/irgendjemandkeinkorper/soul-meter/issues/169) | A ruling on the failed positional-depth gate and its held branch | Gate T and content production |
| 2 | [#175](https://github.com/irgendjemandkeinkorper/soul-meter/issues/175) | Three valid rendered benchmark runs on declared reference hardware | Final FR-904 acceptance |
| 3 | [#98](https://github.com/irgendjemandkeinkorper/soul-meter/issues/98) | Final character-creation ratifications | Character creation and #100 |
| 4 | [#112](https://github.com/irgendjemandkeinkorper/soul-meter/issues/112) | Verbatim design-project source documents | Offline UI source of record |
| 5 | [#115](https://github.com/irgendjemandkeinkorper/soul-meter/issues/115) | Exact image binaries and their provenance/licences | Portrait, token, and battle-board art |
| 6 | [#100](https://github.com/irgendjemandkeinkorper/soul-meter/issues/100) | The FR-601 Wheel-widget visual-language extension, after #98 | Character-sheet implementation |

## 1. Rule on the failed Gate T-2 test (#169)

Do this first. Content production remains blocked until this ruling exists.

The completed deterministic comparison produced:

- positional policy: victory with 46 HP;
- naive policy: victory with 40 HP;
- required result: positional victory and naive defeat, or a pre-registered equivalent;
- conclusion: positioning helped by 6 HP, but the ratified gate did not pass.

Choose one interpretation:

1. **The grid does not buy enough.** Follow the ratified failure path and return to zones, or
   explicitly amend the gate to retain the grid without the falsifiable-depth requirement.
2. **The combat model is incomplete.** Ratify a to-hit system that consumes the existing +8/+15
   facing hit bonuses, build it, then rerun the unchanged gate once. This creates new canon and
   therefore requires an explicit human decision before implementation.
3. **The probe encounter was insufficient.** Authorize one rerun only after approving a
   pre-registered encounter-selection rule. Do not tune an encounter after seeing results merely
   to flip the naive arm.

Also choose what happens to the held `gate-t2-positional-depth` branch. It contains useful
FR-105a resolution and enemy-AI work, plus two deliberately failing gate assertions:

- **Recommended:** merge the implementation after converting the two gate assertions to skipped
  tests that link back to #169; or
- merge with the tests still red, if you intentionally want the failed gate to keep `main` red.

Post a comment on #169 using this template:

```text
Gate T-2 ruling: option [1 / 2 / 3].

Reason:
[Why this interpretation is the correct one.]

Held branch treatment:
[Merge with linked skipped assertions / merge intentionally red / do not merge.]

Any new or amended canon:
[Exact rule, threshold, or document reference. Write “none” if none.]
```

Do not ask an agent to silently lower the threshold, change combat numbers until the test passes,
or choose among these interpretations.

## 2. Run the reference-hardware FR-904 benchmark (#175)

The populated-grid benchmark and provisional WSLg evidence are already merged. WSLg and headless
runs cannot close the gate. The acceptance set must use a real display and declared reference
hardware.

Follow [`docs/fr-904-runbook.md`](fr-904-runbook.md) exactly. In brief:

1. Record the machine, CPU, GPU and driver, RAM, OS, display resolution/refresh, game resolution,
   window mode, scaling, VSync/frame cap, power mode, thermal profile, renderer, Godot version,
   commit SHA, and background-process policy.
2. Keep the same conditions for all three runs. If any declared condition changes, discard the
   set and restart.
3. Use a release-equivalent build on a real display. Do not use the editor, `--headless`, WSLg,
   overlays, downloads, recorders, or automatic power-mode changes.
4. Before Run 1, open the build, reach the rendered scene with the full HUD, leave it idle for 60
   seconds, and quit.
5. Capture `full-hud.png`, `power-mode.png`, and `renderer.png` in
   `reports/fr904-reference/<commit>/`.
6. Run the populated-grid scenario three times, waiting at least 30 seconds between runs:

```bash
DISPLAY=... GODOT_BIN=... bash scripts/benchmark_performance.sh \
  --scenario populated-grid \
  --display-mode rendered \
  -o reports/fr904-reference/<commit>/run-1.json
```

Repeat with `run-2.json` and `run-3.json`. Keep each raw log as well. A teardown error is allowed
only after a well-formed report with `status: "ok"`; judge the report, not the process exit code.

The set passes only when all three runs are valid and:

- median run-level frame-time p95 is at most 16.67 ms;
- draw calls are greater than zero;
- median travel-to-interactive time is under 2,000 ms;
- median battle-event-to-HUD-interactive time is under 2,000 ms.

Attach or commit the declaration, screenshots, raw logs, three JSON reports, and completed
worksheet, then comment on #175 with the evidence path and `PASS` or `FAIL`. Do not omit a valid
slow run as an outlier.

## 3. Ratify the character-creation inputs (#98)

Agents are prohibited from inventing these choices. Post one authoritative decision on #98 or
link to the exact canonical document and commit that contains it.

Your decision must settle:

- **Skill taxonomy:** the final canonical skills and their governing attributes.
- **Advancement:** the final progression model and percentile cost schedule, including how the
  cost scales toward 100%.
- **Ancestries:** the final four or five choices. For each, provide its one mechanical
  inheritance, dialogue-reactivity package, Wheel-affinity nudge, and any supported
  ancestry-by-faction starting-band offsets.

Use this template:

```text
Character-creation ratification

Skill taxonomy:
[Canonical list/table or exact document link + commit.]

Advancement model:
[Rules and cost table or exact document link + commit.]

Ancestry roster:
[Final 4–5 entries and their required fields, or exact document link + commit.]

These decisions supersede:
[Any older draft references, or “none”.]
```

Once posted, Codex can implement the data schema and seed, creation-screen wiring, advancement
loop, and acceptance tests without making product decisions.

## 4. Export the canonical UI specification (#112)

Open the [Soul Meter Claude design project](https://claude.ai/design/p/fc40a9a9-5da2-4a5a-81b7-287c2bac9152)
and export:

- `Godot UI Spec.md` exactly as stored there;
- `Battle Map v2.dc.html` as supporting source material.

Attach the original files to #112 or place them in the repository. Do not paraphrase, reorder,
reformat, or improve the specification text. Include the source-project URL and export/sync date,
and confirm that Battle Map v2 supersedes the older Battle Map.

After the files are available, Codex can create `design/ui-screen-specs.md` verbatim and index it
from `design/DESIGN_SYSTEM.md`.

## 5. Export the exact design-system art and licences (#115)

Export these original PNGs from the same design project:

- `rune-knight-a-bust.png`
- `rune-knight-a-portrait.png`
- `rune-knight-b-bust.png`
- `rune-knight-b-portrait.png`
- `meshy-figure-b-bust.png`
- `spire-figure-bust.png`
- `suulmae-the-undimmed.png`
- `laughing-sisyphus.png`

For every file, provide:

- creator/source provenance;
- licence and redistribution terms;
- whether it is a bust/token crop, dialogue portrait, or backdrop;
- any attribution wording that must be preserved.

Attach the originals and licence information to #115 or add them to the repository. Do not ask an
agent to recreate lookalikes: substitutes cannot establish the required provenance or licence.

Once supplied, Codex can add them under `assets/art/`, update `ATTRIBUTION.md`, run the Godot
import, verify references and crops, and merge the result.

## 6. Supply the FR-601 Wheel-widget visual language (#100)

This work starts only after #98 is ratified. Have Claude add the character-sheet/Wheel-widget
extension to the canonical design-system project, covering the visual treatment and interaction
states required by FR-601. Export it with the #112 source-of-record update rather than describing
it only in a GitHub comment.

Then comment on #100 with:

- the canonical design document and version/commit;
- confirmation that the Background, Mastery, ancestry, and advancement data from #98 are final;
- confirmation that the design is ready for implementation rather than exploratory.

Codex can then build the screen, Wheel legality preview, check-math display, `why()` journal
payoff, and integration tests.

## One-message handoff

When materials and decisions are ready, you can send this single summary:

```text
#169 ruling: [issue comment link]
#175 reference evidence: [path or issue comment link]
#98 ratification: [document or issue comment link]
#112 source exports: [attachment or repository path]
#115 art + licences: [attachment or repository path]
#100 FR-601 extension: [canonical design document/version]

Please implement, verify, commit, push, and merge every newly unblocked Codex issue.
```

You do not need to change labels, create branches, write code, run the ordinary test suite, open
pull requests, or merge anything yourself.
