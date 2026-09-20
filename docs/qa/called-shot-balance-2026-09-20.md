# Called shots: balance pass — 2026-09-20

The measured pass over every provisional aim and injury number from tasks 3–12, using the real starting party (Vex plus the six recruitable companions) against the six production archetypes, both directions, AP scheduler. Probe: `test/manual/aim_balance_probe.gd` (prints one `BAL` line per pairing and aim; asserts nothing).

## What the probe found before tuning

| Finding | Evidence | Consequence |
|---|---|---|
| Party members had no anatomy | `BattleActor.from_party_member` never set `anatomy`; every enemy aim query against the party refused with `aim_location` | Enemy called-shot AI (task 12) and party-side persistent injuries (tasks 9–10) were unreachable in shipped play |
| Serious thresholds unreachable | Highest party damage on hit vs any aimable archetype: 10 (Vex, Ressa vs wight); thresholds were 12 and 14 | No serious injury could ever occur |
| Enemy damage is 1–4 everywhere | 33 of 42 pairings quote 1 damage on hit | Enemies can inflict minor injuries but never serious ones; with damage that low, any positive injury value makes the AI aim |
| Party hit chances | Ordinary 62–66%; torso −5; arm/leg 47–51%; throat 41%; head 36% | Spread is legible: torso is the safe aim, head the gamble |
| Aim cost | Party 4 AP, strike 2, aimed strike 3 | One aimed strike per round instead of two ordinary: a real trade |

## What changed (all PROVISIONAL)

- **Party anatomy.** `PartyMember.anatomy` (optional in saves, default `HUMANOID_ANATOMY`: torso, arm, leg, head, throat) mirrored into `BattleActor`. Every recruitable member is a humanoid; per-character anatomy in canon can replace the default later. Legacy saves load the default.
- **Serious thresholds** lowered: arm and leg 12 → 9, head and throat 14 → 10. After: 14 of 210 party aims are serious-eligible, all from Vex, Ressa, or Serai against the wight or the scavenger. Serious is rare and needs a strong hitter on a soft target, which is the intended shape.
- Unchanged: aim surcharges, accuracy penalties, minor injury chances (50/40/35/30), minor effects, `PROVISIONAL_AI_INJURY_VALUE` 6, treatment fee 20 GP.

## After tuning

- Enemy AI now aims in every pairing, and always the arm (42/42): with 1 damage on hit, the arm's 50% × 6 injury value beats everything else. This is rational given the current enemy damage, not a bug in the chooser. Variety needs either higher enemy damage (an owner balance decision outside this expansion) or a per-location value model for the AI.
- Enemies never reach a serious threshold, so the party never carries a persistent injury from shipped encounters; the treatment economy is only exercised by the party injuring enemies (whose serious records persist for the hostile's field lifetime).

## Verification

- `test/unit/test_party_member.gd` (+1): anatomy default, round trip, legacy save, mirror into the actor.
- `test/integration/test_production_aim.gd`: thresholds updated (9), minor-case fixtures pinned below them.
- Full `test/unit` + `test/integration` + `test/combat_resolution` in one run: 2105 cases, 10 failures across four suites (town townsfolk, consequence notices, interior population, field room), none combat or party related; the same four pass together in isolation (27 cases, 0 failures). Same order-dependent input bleed noted in the Checkpoint D doc.

## Owner decisions surfaced

1. Enemy damage against the starting party is 1–4 with the current attack/defense numbers. Until that changes, enemies cannot inflict serious injuries and the AI will always pick the arm.
2. Whether party anatomy should be authored per character in canon (horned Kes'reth, veils) rather than the humanoid default.
3. Whether the AI should value locations by what they deny the target (arm for attackers, leg for skirmishers, throat for casters) instead of one flat value.
