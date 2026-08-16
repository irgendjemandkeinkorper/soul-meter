# Issue #168 — Gate T-1 clearability plan

Tracker: https://github.com/irgendjemandkeinkorper/soul-meter/issues/168

Status: implementation and local verification complete; pending PR checks and merge.

## Scope and assumptions

- Preserve the ratified five encounters and four build archetype names.
- Reuse authored combat actions, encounter stats, charge-time scheduling, grid positioning,
  speech resolution, and Stillpoint's exact-centre lock. Do not invent abilities or rebalance.
- Model the four builds as deterministic self-play policies over the mechanics currently
  available. Where an archetype-specific action is not yet wired into combat, record that as a
  gate blocker instead of labelling a generic Strike as that build's mechanic.

## Ordered work

1. Add a failing integration characterization for all five encounter definitions requiring an
   encounter grid and charge-time controller.
2. Add the minimum authored encounter-grid overlay for the five Gate T-1 encounter IDs and make
   the characterization pass.
3. Build a deterministic self-play matrix for the four canonical archetypes, using only actions
   and effects reachable through current combat APIs; assert 20/20 victories and the authored
   speech resolution where applicable.
4. Assert that the stabilizer policy receives a measurable advantage from Stillpoint's
   centre-lock in the stabilizer showcase.
5. If steps 3–4 expose a missing playable archetype mechanic, stop and post exact dependency
   evidence on #168. Otherwise run focused and full suites, review, commit, push, open a PR, wait
   for checks, and merge.

## Verification checkpoints

- Focused Gate T-1 integration test is red before production/data changes and green afterward.
- Existing tactical gate and deployment-flow tests remain green.
- Full GdUnit suite passes with zero failures and no orphan nodes.
- PR checks pass before merge.
