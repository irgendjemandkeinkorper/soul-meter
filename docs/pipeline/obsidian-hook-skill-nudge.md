# Proposal: skill-extraction nudge in the global push hook

**Status: PROPOSAL ONLY — NOT APPLIED. Requires explicit human sign-off before any edit.**
Closes #61. Related: [skill-extraction-criteria.md](skill-extraction-criteria.md) (#45).

## Why this needs sign-off rather than a patch

`~/.claude/hooks/obsidian-vault-reminder.sh` is **user-scoped, cross-project infrastructure**. It
is registered in `~/.claude/settings.json` as a `PostToolUse` hook on `Bash`, and it fires on
**every `git push` in every repository on this machine** — not just Soul Meter. A regression in
it degrades every project at once, and the failure would show up as "Claude stopped doing the
vault ritual," which is easy to miss for days.

So the deliverable for #61 is this document. The sign-off requirement is itself the validation
gate, and satisfying it means *not* editing the file.

## What the hook does today

Verified 2026-08-06 (68 lines; `.sh` extension, Python 3 content — worth knowing before editing):

1. Reads the `PostToolUse` payload from stdin; exits 0 immediately unless the command contains
   `git push`.
2. Fires `dev-memory-push-sync.py` as a subprocess (12s timeout, wrapped in try/except — fail-open).
3. Gathers repo facts via `git` (remote, branch, last commit, toplevel), derives the project name
   from the remote.
4. Prints one JSON blob with `hookSpecificOutput.additionalContext` — the standing vault
   instruction.

Two properties are load-bearing and must survive any change: **no external dependencies** (pure
`python3`, explicitly no `jq`), and **fail-open** (it must never block a push).

## The proposed change

Append a skill-extraction sentence to `ctx` — but only under conditions that keep it off
unrelated repos and off most pushes.

### Gate 1 — repo opt-in, self-describing

Nudge only when the pushed repo contains `docs/pipeline/skill-extraction-criteria.md`. A repo
that has not defined an extraction bar has nothing to be nudged toward, and this needs no
registry or config: the presence of the criteria doc *is* the opt-in. Soul Meter is currently the
only repo that would qualify.

### Gate 2 — throttle

Nudging on every push is noise, and noise is how a standing instruction gets ignored. `#45` says
the bar is evaluated at push time, but "at push time" means "not on local commits," not "every
single push."

Proposal: at most once per **14 days per repo**, tracked in a small JSON state file
(`~/.claude/state/skill-nudge.json`, `{repo: last_iso_date}`). Read-modify-write inside the
existing try/except so a corrupt or unwritable state file degrades to "no nudge," never to an
error.

### Gate 3 — only when production code moved

Skip when the push touched only `docs/`, `test/`, or `.github/`. Extraction is a judgement about
production patterns; a docs-only push cannot have crossed the bar.

```python
changed = sh(["git", "diff-tree", "--no-commit-id", "--name-only", "-r", "HEAD"], hook_cwd)
prod = [p for p in changed.splitlines()
        if p and not p.startswith(("docs/", "test/", ".github/", "addons/", "data/generated/"))]
```

Note the limitation honestly: `HEAD` is the last commit, not the full pushed range. Computing the
true range needs the pre-push remote ref, which a `PostToolUse` hook sees only after the fact.
Last-commit is a deliberate approximation — it under-triggers (a multi-commit push whose final
commit is docs-only is skipped) and under-triggering is the right direction for a nudge.

### The appended text

```
Additionally: this repo defines a skill-extraction bar
(docs/pipeline/skill-extraction-criteria.md). It has been >14 days since the last
check. Consider whether any pattern has crossed the 2-occurrence threshold —
verify counts with rg before accepting any candidate, and record the result as a
dated audit under docs/pipeline/. If nothing qualifies, say so and move on.
```

The last sentence matters: without it the nudge creates pressure to find *something*, which is
how audits start manufacturing candidates.

## Risks

| Risk | Severity | Mitigation |
|---|---|---|
| Bug breaks the vault ritual in **all** repos | **High** | Every addition inside try/except; the vault `ctx` is built and printed before any new logic can fail. Test by running the hook manually with a synthetic payload against a scratch repo. |
| Added latency on every push | Low | One extra `git diff-tree` and one small file read, both gated behind the cheap "does the criteria file exist" check. |
| Nudge fatigue | Medium | Gates 1–3; 14-day floor. |
| State file grows unbounded | Negligible | One short key per repo. |
| Someone edits it and loses the no-deps property | Medium | Note it at the top of the file if the change is accepted. |

## Recommendation

**Worth doing, but it is not urgent, and it should not be bundled with anything else.**

The honest case against: #57's audit found that the repo's qualifying patterns are *already*
filed as issues (#59, #60). The nudge would currently fire and produce "nothing new." Its value
is prospective — catching the third and fourth patterns months from now, when nobody is thinking
about extraction.

Given that, the sequencing I would suggest: leave the hook alone until #59 and #60 are actually
written up and the skill-extraction workflow has been exercised end to end at least once. A
nudge toward a process that has not yet been run once is premature.

## If accepted

1. Human approves in writing on #61.
2. Back up: `cp ~/.claude/hooks/obsidian-vault-reminder.sh{,.bak-$(date +%s)}`.
3. Apply the gates above; keep the vault `ctx` construction untouched and first.
4. Test against a scratch repo and a synthetic stdin payload — confirm a **non**-opted-in repo
   still gets the normal vault nudge and nothing extra.
5. Push once from Soul Meter and once from another repo to confirm both paths.

Rollback is restoring the `.bak`.
