# Dialogue skill checks

Skill checks in dialogue have separate availability and commitment phases.
Never resolve a check while Dialogue Manager is building a choice list.

## Availability and tags

Put the deterministic gate on the response itself, using the self-closing form:

```dialogue
- "Make the case." [#tag=Persuasion] [if check("persuasion", 45) /]
```

Combine quest conditions inside the same `[if ... /]` tag when needed. The
balloon renders `[#tag=Persuasion]` as `[PERSUASION]`. Do not author a numeric
chance in response text, tags, or consequences. If a choice should remain
visible but locked, use the existing balloon's shows-but-locked condition form
and keep the same non-numeric tag.

`check()` calls `preview()`. It is an RNG-free availability gate and does not
consume an Expert reroll or append to `recent_checks()`.

## Commitment and branches

The selected response's first mutation commits exactly one check:

```dialogue
	do SkillCheck.resolve("persuasion")
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

`tools/quest_audit.gd` reports missing resolves or branches as errors and a
possibly missing alternate route as a warning. Its route check is heuristic;
playtest both outcomes and the fallback path before shipping.
