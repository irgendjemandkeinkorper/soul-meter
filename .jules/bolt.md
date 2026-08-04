## 2024-03-XX - Optimizing Reputation Event Log Appends
**Learning:** In `globals/reputation.gd`, appending to an append-only event log caused $O(N)$ lookup costs because every read queried the entire log (`_log`). As the game progressed and the log grew indefinitely, this led to performance bottlenecks, especially since the `events_for` call is invoked for every new record appended.
**Action:** Implemented an `_events_by_faction` cache Dictionary that groups events by faction. By appending events directly to the target faction's cached array, the append overhead and subsequent query lookups drop from $O(N)$ to $O(1)$. This caching structure ensures continuous scale without re-scanning the unbounded log, while mimicking the necessary duplicate list safety.

## 2024-03-XX - Optimizing Static Dictionary Parsing
**Learning:** In `globals/elements/elements_data.gd`, data for elements and triads is stored in static constant arrays of Dictionaries. Helper functions like `element()`, `all_elements()`, `triad()`, and `all_triads()` were re-parsing these dictionaries and instantiating `ElementDefinition` or `TriadDefinition` objects on every single call. Because these functions are heavily used in O(N) operations like `triad_for_elements` and heavily called during combat composition resolution, this continuous re-parsing and instantiation created a substantial performance bottleneck.

Implemented static cached arrays and dictionaries (`_elements_cache`, `_triads_cache`, etc.) that are initialized lazily exactly once on the first call via a `_init_caches()` function. Subsequent calls use these parsed data structures. Also ensured methods like `Dictionary.get(id, default)` do not accidentally evaluate object instantiation for the default argument by switching to a two-step `var cached = dict.get(id); if cached != null: return cached` approach.

**Crucial Correction:** The file `globals/elements/elements_data.gd` is actually a **generated file** (created from `data.pandora` using `tools/generate_gloot.gd`). Because it is generated, any manual edits made to it will be overwritten the next time the generator runs, silently destroying the optimization. Additionally, it fails CI drift checks (`SOUL_METER_DRIFT_CHECK`).

**Action:**
1. When optimizing a file, **always check its header for a "GENERATED" warning**. If a file is generated, the optimization must be applied to the *generator* (in this case, `tools/generate_gloot.gd`), not the output artifact.
2. When caching objects and returning them to consumers, ensure the objects are treated as immutable (or add a comment warning consumers not to mutate shared instances), as returning shared references can lead to unintended side effects if a caller mutates the object.
