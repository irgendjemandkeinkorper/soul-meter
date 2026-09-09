# Persistent structures — first implementation slice

Owner-approved behavior: destruction survives combat/travel/save-load; selected
maintained structures rebuild on world time; abandoned structures require an
explicit restoration event; temporary merchant relocation is selective.

Use the existing save owner and event-driven WorldClock. Keep the state model
independent of scenes, following the existing UnitRoster/TileState pattern.
No new autoload, dependencies, canonical building assignments, or merchant stock
copies. Registrations are opt-in; unregistered campaign content behaves as before.

1. [x] Implement structure integrity, recovery deadlines and explicit story repair.
2. [x] Persist/validate state through save, load, rollback and new game; advance only on real world-clock events.
3. [x] Expose per-merchant home/temporary/closed service state and enforce closures in trading.
4. [x] Verify abandoned versus maintained recovery, interrupted repairs, save isolation and vendor behavior; full-suite failures reproduced on baseline.
5. [x] Document the usable API, evidence and remaining field-art/navigation integration in `docs/persistent-structures.md`.

Acceptance: a registered maintained structure and an abandoned structure retain
their damage through a disk save/load; only the maintained one restores with time.
A story event can begin abandoned-site rebuilding exactly once. A registered
relocating merchant has one effective service location; a non-relocating merchant
cannot trade until repair. Queries and reloads do not age the world or reset stock.

Verification uses `SOUL_METER_HEADLESS=1 GODOT_BIN=/home/adamjroder/.local/bin/godot
bash scripts/test.sh` with focused suites during implementation and the repository
suite before handoff. Test data uses temporary save paths. The existing map/spell
targeting and visual footprint contracts are not changed by this foundation.

Evidence: 18 new tests pass. Feature full suite: 1,930 cases, nine failed assertions
in three existing tests. Baseline `4e8db002`: 1,912 cases, the same nine failed
assertions in the same three tests. Both branches pass those 22 focused cases.
See `docs/persistent-structures.md` for report paths and remaining integration scope.
