# Destructible field object

Approved continuation of persistent structures: bind a physical field object to
saved integrity, show its four states, and keep collision and navigation aligned.
The first playable fixture is a separate structure yard. Campaign assignments,
spell damage formulas, and merchant movement remain outside this slice.

1. [x] Verify live obstacle changes reach existing grids without losing occupants or weights.
2. [x] Add an interactable structure with an authored Blocking footprint, saved damage,
   four-state art, and recovery deferred for occupied footprints or active combat.
3. [x] Ship a runnable yard showing maintained versus abandoned recovery, test the
   input/save/navigation loop, and record validation.

Acceptance: E strikes the nearby fixture barricade using the normal interactable
input path. Partial damage retains collision; ruin removes only its own painted
cells. Re-entry restores saved art and passability. Declared world phases rebuild
the maintained barricade; the abandoned one stays ruined. Actors, including
non-colliding followers, cannot be enclosed by restoration. Clearing a footprint
retries a due repair at the same world phase. Existing field combat suppresses E.

The fixture's 30 integrity, 10 damage per interaction, and two-phase recovery are
test values, not balance or elemental rules. Authored footprints must not overlap.
State art is generated with the built-in imagegen tool; its prompt is recorded
beside the source sheet. No campaign scene or canonical content assignment changes.

Verification: 50/50 focused cases pass (`reports/report_1385/results.xml`). The
final full run executed 1,936 cases with zero errors and the same nine assertion
failures in three baseline tests (`reports/report_1386/results.xml`), confirmed by
matching test names and failure locations. Native Godot/OpenGL captures verify
all four visual states. Run `bash scripts/play_structure_yard.sh` to play the
fixture; see `docs/persistent-structures.md` for controls and remaining scope.
