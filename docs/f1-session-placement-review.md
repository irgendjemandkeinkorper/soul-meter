# F1 session startup: overlapping party actors

Status: **RULED 2026-09-06** — accepted with three amendments (player is the anchor and is
never relocated; relocation is BFS over *reachable* cells, not Euclidean; the search is
capped at `PLACEMENT_SEARCH_RADIUS = 4` and the whole session is refused past it). The
binding text is ruling 4 in `docs/architecture-same-map-combat.md` §4; this note is the
superseded proposal, kept for provenance.

F0 requires ambient combat on the actors' existing field cells without deployment.
Current exploration deliberately puts companions on the player's starting cell until
the trail has enough history; teleport reset also stacks every companion there.
`test/integration/test_party_followers.gd` explicitly verifies this behavior.
`GridBattlefieldModel` has one occupant per cell, and admission refuses occupied cells.
Thus direct conversion cannot place every party member after arrival or teleport.

## Proposed behavior for review

Keep each party member on its current cell when it is available. For overlapping
members only, assign the nearest reachable free cell, processing party members in
party order and breaking equal-distance ties by row then column. Preserve authored
blocking and hostile occupancy. If there are insufficient reachable cells, refuse
startup without moving actors or changing their state. No deployment screen opens.

This changes combat starting positions, so the role policy reserves the choice for
the architecture/product owner. F0 does not currently specify an overlap rule.
An alternative is to stagger exploration followers before alerts can begin; that
would change existing exploration behavior and its acceptance tests.

## Implemented independently

- Persistent Hostile identity and cached actor, safe-field alert refusal, corpse state.
- Chain propagation snapshots sources, so synchronous admission cannot cascade.
- Initial battlefield placement validates bounds, blocking, and duplicate cells.
- Combat freezes follower trail movement and restores its previous process state.
- Admission rejects distinct actors sharing a combat ID; neutral tile state is lazy.

The branch does not yet connect proximity sensors, Battle.start_session/admit, or
the CT boundary to these helpers. No live Enemy scene has been replaced. Issue #281
remains open; this is a partial second handoff, not completed same-map combat.

Validation: 134 tests across seven focused suites passed, with zero test failures,
errors, flaky cases, or orphans. Godot still reports 39 resources in use at process
exit; this is separate from GdUnit's zero-orphan result. Full CI is pending.
