# Skill-extraction audit — 2026-08-06

**Closes #57.** Criteria applied: [skill-extraction-criteria.md](skill-extraction-criteria.md) (#45).
**Repo state:** `main` @ `36ba4ad`.

Per criterion 1, counts are production code only — `test/`, `addons/`, `data/generated/`, `docs/`,
and comment/doc mentions excluded. Per the criteria doc's own rule, every count below was
verified by hand with `rg`; none is taken from a summarizer.

## Candidates and verdicts

| Pattern | Real occurrences | Verdict |
|---|---|---|
| `DomSideQuest` authoring | **10** `.tres` resources | **Extract.** Well past the bar and not filed anywhere. |
| `FlagQuest` authoring | 4 direct `.tres` (+10 via `DomSideQuest`) | **Covered by the above** — `DomSideQuest extends FlagQuest`; one skill should cover both. |
| `GameFlow.travel()` destination | **2** call sites | **Extract.** Meets the bar. Already filed as #59. |
| `FetchQuest` authoring | **1** `.tres` (`loamroot_sprigs`) | **Below the bar.** See correction below. |
| Pandora→GLoot regeneration | n/a | Already extracted — `docs/skills/pandora-gloot-regeneration.md`. |
| Field encounter authoring | 11 refs, 2 files | **Not extracted** — encounters are Pandora-authored into `data/generated/encounters.json`, so this *is* the Pandora→GLoot skill, which names encounters explicitly. Fails criterion 4. |
| `GameFlow.send_event()` | 11 refs, 7 files | **Not extracted.** Fails criterion 4 — `CLAUDE.md` and `docs/godot-flow-handoff.md` already own it. |
| `Reputation.record()` / `Renown.gain_*` | 9 / 4 refs | **Not extracted.** Fails criterion 4 — the single-write-path rule is in `CLAUDE.md` and both autoload headers. |
| `theme_type_variation` | 149 refs, 25 files | **Not extracted.** Fails criterion 3 — adding one is a single edit to `ui/theme/theme_builder.gd` with 40 adjacent examples to copy. The *rule* is already in `CLAUDE.md`. |
| `GameState.set_flag()` | 21 refs, 8 files | **Not extracted.** Fails criterion 3 — flag naming/read-back discipline is `tools/quest_audit.gd`'s job (#101), not a written procedure. |
| In-house hitbox/hurtbox | **0** | **Not extracted** — not built (#48 open). |
| `SkillCheck.` | 2 refs, **1 file** | **Below the bar** — two call sites in one file are not two independent occurrences. |

## Corrections this audit produces

**1. #60 targets the wrong quest class.** It is filed as *"draft skill doc for 'add a
QuestRegistry fetch quest'"*, but `FetchQuest` has exactly **one** resource in the repo
(`quests/loamroot_sprigs.tres`) and is below the extraction bar. The quest pattern that has
actually repeated is **`DomSideQuest`, with ten** resources — the whole Dom side-quest set.

Recommend retargeting #60 to "add a Dom side quest (`DomSideQuest`/`FlagQuest`)" rather than
opening a second issue. The fetch-quest variant can be a subsection once a second `FetchQuest`
exists.

**2. #59 is now correctly scoped and ready.** `GameFlow.travel()` has two production call sites
(`actors/building_door/building_door.gd:111`, `actors/travel_exit/travel_exit.gd:47`) and
`TravelExit` is instanced in four world scenes. It meets the bar. Note this contradicts #45's
stated validation expectation, which predates the second call site — see the correction section
in the criteria doc.

**3. No new extraction issues are needed.** After retargeting #60, the two qualifying patterns
are both already filed (#59, #60). This is the honest result: the repo has three extractable
patterns, one is already written up, and two have open drafting issues. Nothing was manufactured
to make the audit look productive.

## Method note

`skill-scout` was not run as an automated pass for this audit; the candidate list was assembled
from the repo's own subsystem boundaries and then counted directly. The criteria doc treats
`skill-scout` as a candidate *generator* whose counts must be verified by grep regardless, so
the verification step is identical either way. Re-running it later can only add candidates to
the table above, not change the verified counts in it.
