## 2024-03-XX - Optimizing Reputation Event Log Appends
**Learning:** In `globals/reputation.gd`, appending to an append-only event log caused $O(N)$ lookup costs because every read queried the entire log (`_log`). As the game progressed and the log grew indefinitely, this led to performance bottlenecks, especially since the `events_for` call is invoked for every new record appended.
**Action:** Implemented an `_events_by_faction` cache Dictionary that groups events by faction. By appending events directly to the target faction's cached array, the append overhead and subsequent query lookups drop from $O(N)$ to $O(1)$. This caching structure ensures continuous scale without re-scanning the unbounded log, while mimicking the necessary duplicate list safety.

## 2026-08-05 - Viewport Culling for Background Work
**Learning:** Headless benchmarks may not reveal rendering bottlenecks but can highlight CPU hotspots (like updating transforms for many off-screen objects). The spawner processed sine waves and wrote properties for every NPC regardless of visibility.
**Action:** Use VisibleOnScreenNotifier2D to track which nodes are on-screen, and only perform per-frame transform updates (like idle animations) for the visible subset.
