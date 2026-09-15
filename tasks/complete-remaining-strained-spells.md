# Complete the remaining strained spell families

**2026-09-10 · Design continuation requested by the owner.**

## Acceptance scope

Finish the 26 unauthored legal distant pairs on the existing ten-element Wheel.
Give each a secondary (Phrase), tertiary (Song) and ultimate (Refrain) card with
concrete targeting, effect budgets, duration, counterplay and visual direction.
Retain the existing four strained families, ten natural Chords, ten elemental
families and ten separate Triad compatibility cards. Opposed pairs remain refused.
Use the accepted shared costs, weakened statuses, finite resource accounting,
Khor access boundaries and persistent destruction rules. This is design authoring;
runtime spell implementation, new elements and selection changes are outside scope.

## Completion

- [x] Audit generated Wheel distances against authored family headers: 26 missing.
- [x] Author 78 unique P/S/R forms covering those 26 pairs.
- [x] Update the packet index and current capability summary.
- [x] Validate pair coverage, names, costs, links, table shape and resource examples.
- [x] Review the design contracts and prepare only the completed documentation for the local commit.

## Evidence

Context Mode JavaScript audits against `data/generated/elements.json` verified:

- Exactly 40 unique legal pairs: 10 adjacent and 30 strained; no missing pair,
  duplicate family, incorrect distance or authored opposed pair. The supplement
  adds 9 distance-2, 8 distance-3 and 9 distance-4 families to the existing four.
- 78 new cards, one P/S/R per new family. All 170 canonical names are unique:
  20 N, 50 P, 50 S and 50 R. Existing 52 hybrid card rows are unchanged.
- All 26 new families include playstyle, visual direction and counter/aftermath
  guidance. Every card uses the declared P/S/R default costs and a valid three-column
  table; every new R has explicit timing (3 instant, 23 wind-up).
- All 60 local links/anchors in the five changed design documents resolve. Eight
  arithmetic/state-model checks pass for the supplement's acceptance examples:
  actual-payment caps, independent source allocations, finite held pools, spent
  trigger/source ledgers, burning growth and separate damage channels.
- `git diff --check` passes. No runtime source, generated data or assets changed;
  Godot tests were not run for this documentation-only pass. The model calculations
  specify expected behavior and are not evidence of runtime/save-load correctness.

Review refined Khor/Mozh into a held opportunity for other allies to collect finite
original sources, giving sustain a useful purpose without freezing physical source
eligibility. Fields with finite pools/triggers cannot be copied; upkeep cannot
replenish their budgets. Original source claims and spent recipient/trigger ids must
survive snapshots in the eventual implementation.

The prior 92-form task remains a historical record of its scope. This pass completes
legal pair/form design coverage. Prices and strain settlement remain provisional;
runtime intent, fields, material fire, finite claims and Triad adapters still require
implementation and playtesting. No further design input is blocking this packet.
