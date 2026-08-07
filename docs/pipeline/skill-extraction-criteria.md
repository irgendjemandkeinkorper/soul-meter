# Skill-extraction criteria for Godot patterns

**Status:** ratified bar for this repo. Closes #45.
**Applied by:** #57 (the periodic audit). **Mechanism:** the `skill-scout` skill.
**Related:** [maker-checker.md](maker-checker.md), [octo-escalation.md](octo-escalation.md).

A "skill" here means a written procedure under `docs/skills/` that captures how *this* repo does
a recurring thing — `docs/skills/pandora-gloot-regeneration.md` is the existing example. The
point is to stop re-deriving the same sequence, not to accumulate documentation.

The failure mode this guards against is extracting too early. A pattern written down after one
use encodes a guess about the general case; the same pattern written down after two independent
uses encodes what actually stayed constant between them. Waiting is what makes the note true.

## The bar

A pattern is extraction-worthy when **all five** hold. Any one failing means leave it alone.

**1. At least two real occurrences in shipped code.**
Counted in production code only — `actors/`, `globals/`, `ui/`, `world/`, `tools/`. Explicitly
*not* counted: `test/`, `addons/` (never ours to edit), `data/generated/` (regenerated, not
authored), comments and doc prose that merely mention the API, and `docs/` itself. Two call
sites of the same helper is the floor, not two mentions of its name.

**2. The occurrences are structurally similar, not just nominally.**
Two calls to the same function are not a pattern; two places that had to assemble the *same
several steps in the same order* are. If the second occurrence was a one-line call because the
first one built the helper, the helper already is the abstraction — there is nothing left to
extract into prose.

**3. There is a decision or a trap worth recording.**
An ordering constraint, a gotcha, a "this looks like it should work and silently doesn't."
If the procedure is discoverable in under a minute by reading the code, a skill adds a second
source of truth that will drift. `[if expr /]` needing the self-closing form is a trap worth
writing down; "call `add_child`" is not.

**4. It is not already covered.**
Check `CLAUDE.md`, `docs/godot-architecture.md`, `DEPENDENCIES.md`, and existing
`docs/skills/*` first. Prefer extending the doc that already owns the topic over minting a new
skill beside it.

**5. It is stable.**
Do not extract a pattern that a ratified-but-unimplemented decision is about to invalidate.
`docs/prd-amendment-tactical-layer.md` retiring AP and zones for charge time is the live
example: anything shaped around the AP loop is on a countdown and should not be written up as
settled practice.

## When the bar is evaluated

**At push time only — never on local commits.** Extraction is a judgement about the shipped
state of the repo, and local commits are frequently mid-thought. Evaluating per-commit produces
noise proportional to how granularly someone commits, which is not a signal about anything.

In practice this means the audit (#57) runs against `origin/main`, and the push hook is the
natural nudge point — see the proposal in [obsidian-hook-skill-nudge.md](obsidian-hook-skill-nudge.md) (#61),
which is deliberately a proposal and not an edit.

## Mechanism, and why its output is not trusted

Run the `skill-scout` skill against the repo to *generate candidates*. Then verify every count
by hand before accepting any candidate:

```bash
# production call sites only — the number that actually decides the bar
rg -n '<pattern>' -g'*.gd' -g'*.tscn' --glob '!addons/**' . | grep -v '^\./test/'
```

`skill-scout` proposes; grep decides. An audit that reports "3 occurrences" without a file-and-line
list has not established anything — counts that include a doc mention, a comment, and a test
are the normal way this goes wrong. #57's acceptance criteria make this cross-check mandatory
for exactly that reason.

Note that `rg` is unavailable inside the context-mode sandbox (`exit 127`); run these counts
through plain Bash.

## Worked validation against the current repo

Run 2026-08-06 against `main` @ `36ba4ad`, as the retroactive check #45 requires.

| Pattern | Real occurrences | Verdict |
|---|---|---|
| In-house hitbox/hurtbox Area2D pair | **0** — not built (#48 open) | **Not flagged.** Nothing to extract from an unwritten pattern. |
| `GameFlow.travel()` destination wiring | **2** — `actors/building_door/building_door.gd:111`, `actors/travel_exit/travel_exit.gd:47` | **Flagged — meets the bar.** |
| Pandora→GLoot regeneration | n/a | Already extracted: `docs/skills/pandora-gloot-regeneration.md`. |

### Correction to #45's stated expectation

The issue's validation gate expects this checklist to *not* flag `GameFlow.travel()`, on the
grounds that it is "built once so far, below threshold." **That is no longer accurate.** There
are two independent production call sites, and `TravelExit` is instanced in four world scenes
(`test_room`, `starting_town`, `dorthkor_road`, `wound_lip`). Under the bar above it qualifies.

The bar was not adjusted to preserve the issue's expected answer. Criteria that are tuned until
they reproduce a stale prediction measure nothing. The hitbox/hurtbox half of the gate — the
half that tests whether the bar correctly declines an unbuilt pattern — passes as written.

Whether to actually write the `GameFlow.travel()` skill is #57's call, not this document's; #59
already exists as the drafting issue for it.

## What a skill looks like once extracted

Lives at `docs/skills/<kebab-name>.md`. States the trigger ("you are adding a new travel
destination"), the ordered steps, the traps, and how to verify you got it right — ideally a
command whose output settles it. `docs/skills/pandora-gloot-regeneration.md` is the shape to
copy.
