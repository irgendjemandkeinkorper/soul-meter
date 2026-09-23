# Element resolution integrity

Continue `element-workings` from the mechanical capability map before adding new
material reactions. Preserve the existing composition catalog, damage constants,
clash detonations, resource costs and forecast/commit path.

1. [x] Reproduce utility-element damage and Hush action refusals in Resolution.
2. [x] Honor composition damage components for direct spell damage, including bonus
   channels and the controller's minimum-damage floor. Mundane attacks remain valid.
3. [x] Suppress local/global Hush tile effects without blocking otherwise legal
   actions or writing temporary weather Hush into persistent tile state.
4. [x] Verify actual casts, costs, useful non-damage effects and forecast equality;
   run regression checks and record the remaining elemental gaps.

Khor/Zhem have no direct elemental damage. Existing Clash detonation damage remains
a separate environmental consequence of striking charged terrain; it is not a new
damage permission for the element. Hush suppresses that detonation and residue.
No new spell magnitudes, elemental conversion amounts, materials or spread rules.

Focused regression: 196/196 passed (`reports/report_1412/results.xml`). Red tests
first reproduced utility damage, a Khash-wing burst in a utility-centered Triad,
and Vhorr Hunger seeding from a non-damaging cast.

Full regression: **1,967 executed cases**, `reports/report_1413/results.xml`. The
run exits 100 with the same nine failed assertions in three tests as baseline
`4e8db002` (`/tmp/soul-meter-structure-baseline/reports/report_2/results.xml`):
outdoor NPC dialogue at lines 72/73, indoor NPC dialogue at lines 48/49, and sprint
speed at line 160. Test names and assertion locations match exactly; no additional
test failures. The runner still emits engine diagnostics, so this is not a claim
that the full run is clean.

Review: composition permission is shared by resolution, controller and Hunger;
forecast and commit use the same result; suppressed tiles cannot emit persistence
writes; documentation links and whitespace checks pass. No save-format, generated
catalog, UI or numeric balance changes.

Implementation and remaining scope: [element resolution integrity](../docs/element-resolution-integrity.md).
