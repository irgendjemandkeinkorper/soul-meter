# Dialogue skill checks

Skill checks in dialogue have separate availability and commitment phases.
Never resolve a check while Dialogue Manager is building a choice list.

## Availability and tags

Put the deterministic gate on the response itself, using the self-closing form:

```dialogue
- "Make the case." [#tag=Sway] [if check("sway", 45) /]
```

Combine quest conditions inside the same `[if ... /]` tag when needed. The
balloon renders `[#tag=Sway]` as `[SWAY]`, and when the choice is open it adds
the player's chance (`[SWAY] 62%`, from `SkillCheck.preview`, the same number
`resolve()` rolls against). Do not author a numeric chance in response text,
tags, or consequences; the balloon computes it. A response with a check gate and
no `#tag` gets the skill's label as its tag.

### Which locked choices show (owner, 2026-11-01)

A locked choice stays visible, dim, with a one-line reason
(`Undertone 40 needed — you have 12.`) only when every failing part of its
condition is one the player can earn:

- `check(skill, N)`
- `Reputation.standing(faction) >= N` (or `>`)
- `GameState.soul_meter >= N` (or `>`)
- `not GameState.is_hollowing()`

Any other failing part (quest state, flags, NG+, patron, hollowed-only,
low-Soul-only) hides the choice. The balloon splits the condition on its
top-level `and`s; a top-level `or` keeps it whole. Guard parts are evaluated
first, in authored order, stopping at the first that fails, so Dialogue
Manager's short-circuit still protects comparisons such as
`GameState.get_flag("x") == "returned"`. Override per response with
`[#lock=show]` (always visible when locked) or `[#lock=hide]` (never).

### Effect chips (owner, 2026-11-01)

A choice's chips (`SOUL −6  ·  SSAE SEEDERS +3  ·  INFAMY +5`) are read from
the branch's leading `do` lines, before its first spoken line or condition:
`GameState.set_soul_meter(GameState.soul_meter ± n)`,
`Reputation.record(..., faction, delta, ...)`, `Renown.gain_reputation` and
`Renown.gain_infamy`. Put an effect there if the player should see it before
choosing; an effect inside an `if` is a consequence of the roll and is not
shown. Karma is never shown. `[#cost=...]` is only a fallback when no Soul
mutation is read. After the choice, the reply shows what was recorded on its
ledger strip, and the field notices skip those events.

`check()` calls `preview()`. It is an RNG-free availability gate and does not
consume an Expert reroll or append to `recent_checks()`.

## Commitment and branches

The selected response's first mutation commits exactly one check:

```dialogue
	do SkillCheck.resolve("sway")
	if SkillCheck.last_check_succeeded()
		do GameState.set_flag("quest_evidence_acquired", true)
		=> END
	else
		do GameState.set_flag("quest_check_failed", true)
		=> END
```

Use the same skill for the gate and the commit. The authored difficulty belongs
ONLY to the availability gate: `resolve()` rolls percentile against the
character's effective skill (Fallout-style — your skill is your chance), so a
gated option can still fail on commit; that is what the failure branch is for.
Never pass the difficulty to `resolve()` — it takes a PartyMember, and the
service API is not to be widened for dialogue. Use the implicit protagonist
unless a specific member is required.

Both branches must be authored immediately after the resolve. Success must lead
to a quest continuation. Failure may close this route, but it must set a flag
that another authored response reads to preserve the original acquisition path.
Never end the campaign's only route to a required objective.

Known false-negative modes of the audit heuristic (it is string- and
indentation-based): it does not verify resolve order or count beyond presence,
does not check the resolved skill matches the gated skill, and does not prove
the alternate route is reachable at runtime — reviewers must still read the
branch. It reports:

`tools/quest_audit.gd` reports missing resolves or branches as errors and a
possibly missing alternate route as a warning. Its route check is heuristic;
playtest both outcomes and the fallback path before shipping.
