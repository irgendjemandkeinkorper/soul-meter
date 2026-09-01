# Consequence Timeline

The Consequence Timeline is a debug-build-only, read-only overlay for validating authored consequence writes during play. It observes both append-only evidence ledgers:

- `Reputation`: per-faction standing changes.
- `Renown`: faction-independent reputation and infamy changes.

Enable it with `SOUL_METER_CONSEQUENCE_TIMELINE=1` in a debug build, then press F4 to show or hide it. Release builds and runs without the environment flag are inert: the autoload creates no children, connects no ledger signals, handles no input, and writes no files. Tests may use `force_enabled_for_tests` through the same debug-build gate.

## Read-only contract

The timeline never calls `Reputation.record()`, `Renown.gain_reputation()`, `Renown.gain_infamy()`, either ledger's `from_dict()`, or any other mutator. It connects only `Reputation.reputation_changed` and `Renown.renown_changed`, then uses derived reads for history and summaries. The ledgers remain the sole evidence source.

`Reputation.history()` and `Renown.history()` are whole-ledger, newest-first derived queries. A non-positive limit returns all history. They return new arrays and do not expose or modify either private log.

## Ordering

Live rows are newest-first and use the timeline's private signal-arrival counter as the merged ordering authority. This counter exists only inside the viewer and is never written into either ledger. A Renown event that arrives after a Reputation event therefore appears later even when its ledger-local `order` is lower.

Restored history predates the observer. Within each ledger, that ledger's own `order` remains authoritative. Across ledgers, only the coarse Unix-second `at` timestamps are available, so ties and clock inversions can make the merged presentation ambiguous. Every backfilled row is visibly labelled `RESTORED HISTORY / CROSS-LEDGER ORDER APPROXIMATE`; the overlay does not claim that cross-ledger restored ordering is exact.

## Rows and provenance

Each row shows timestamp, ledger, faction id or renown kind, signed delta, resulting standing or total, cause, actor, and scene. Causes beginning with `DevConsole.DEBUG_CAUSE_PREFIX` are labelled `DEBUG-INJECTED` and use a distinct semantic theme variation, keeping console-injected consequences visually separate from gameplay consequences.

The header shows current standings for every touched faction plus current reputation and infamy totals. The timeline retains at most `MAX_RETAINED_ROWS` (200) rows, newest-first, so long playtests cannot grow the overlay without bound.
