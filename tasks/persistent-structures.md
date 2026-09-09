# Persistent structures — first implementation slice

Owner-approved behavior: destruction survives combat/travel/save-load; selected
maintained structures rebuild on world time; abandoned structures require an
explicit restoration event; temporary merchant relocation is selective.

Use the existing save owner and event-driven WorldClock. Keep the state model
independent of scenes, following the existing UnitRoster/TileState pattern.
No new autoload, dependencies, canonical building assignments, or merchant stock
copies. Registrations are opt-in; unregistered campaign content behaves as before.

1. [ ] Implement structure integrity, recovery deadlines and explicit story repair.
2. [ ] Persist/validate state through save, load, rollback and new game; advance only on real world-clock events.
3. [ ] Expose per-merchant home/temporary/closed service state and enforce closures in trading.
4. [ ] Verify abandoned versus maintained recovery, interrupted repairs, save isolation and vendor behavior.
5. [ ] Document the usable API, evidence and remaining field-art/navigation integration.

Acceptance: a registered maintained structure and an abandoned structure retain
their damage through a disk save/load; only the maintained one restores with time.
A story event can begin abandoned-site rebuilding exactly once. A registered
relocating merchant has one effective service location; a non-relocating merchant
cannot trade until repair. Queries and reloads do not age the world or reset stock.

Verification uses `SOUL_METER_HEADLESS=1 GODOT_BIN=/home/adamjroder/.local/bin/godot
bash scripts/test.sh` with focused suites during implementation and the repository
suite before handoff. Test data uses temporary save paths. The existing map/spell
targeting and visual footprint contracts are not changed by this foundation.
