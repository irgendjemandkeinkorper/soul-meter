# Dialogue Lab

Dialogue Lab is a debug-only, read-only replay overlay for `.dialogue` resources. It turns dialogue work into a play-edit-reload loop without restarting the game and without letting replayed consequences enter campaign state.

## Enable and open

Run a debug build with:

```bash
SOUL_METER_DIALOGUE_LAB=1
```

Press **F5** to open or hide the overlay. The autoload remains inert unless both conditions are true:

- the executable is a debug build; and
- `SOUL_METER_DIALOGUE_LAB` is exactly `1`.

The `force_enabled_for_tests` property exists only as the test seam for that activation rule.

## Authoring loop

1. Select a resource discovered under `dialogue/*.dialogue` or `dialogue/companions/*.dialogue`.
2. Select one of the titles read from that imported `DialogueResource`.
3. Optionally enter replay-only state:
   - flags as `flag_key=true` or `flag_key=false`, one per line;
   - faction standings as `faction-id=value`, one per line;
   - Renown reputation and infamy target values.
4. Choose **Play conversation**.
5. Edit and save the selected `.dialogue` file in the external editor.
6. Choose **Reload from disk + replay**. This reload uses `ResourceLoader.CACHE_MODE_IGNORE`, so Dialogue Manager receives a fresh parse rather than the cached resource.
7. Choose **End session** when finished.

**Replay same state** restores the previous replay, snapshots the real campaign state again, reapplies the same setup, and starts the same resource/title. Dialogue is launched through `DialogueManager.show_dialogue_balloon(resource, title)`, the same production path used by NPC conversations.

## Containment

Every replay session begins with an armed snapshot of all state surfaces dialogue can mutate. The list is **not maintained here**: it comes from `SaveGame.capture_runtime_state()` / `restore_runtime_state()`, the same enumeration `load_game()` rolls back when a load fails part-way. That covers `GameState`, `Reputation`, `Renown`, `QuestRegistry`, `ng_plus`, `zhavar`, `SkillCheck`, the tactical `unit_roster`, and `WorldClock`.

This used to be a hand-written list of five in each lab, and it was wrong: `zhavar` was missing, so replaying `dialogue/sella_varn.dialogue`'s `do SaveGame.raise_zhavar("wilds")` permanently advanced the campaign's escalation ladder. Adding a runtime global means adding it once, in `SaveGame` — not remembering three call sites.

`SkillCheck.random_number_generator.seed` and `state` are captured separately, because `SkillCheck.to_dict()` serializes reroll usage rather than generator position. Restoration assigns `seed` before `state` because assigning a seed resets the generator state.

## The sandbox

A session opens a **runtime sandbox** (`SaveGame.begin_runtime_sandbox()` / `end_runtime_sandbox()`), which does two things.

**Autosaves cannot be staged.** Eight `QuestRegistry` mutators reachable from a dialogue `do` line call `SaveGame.request_autosave()`. Refusing the write at flush time is *not* sufficient: `request_autosave()` defers the flush, so a request staged during a session runs on a later idle frame — after the session has already restored and closed its sandbox — and would flush unsuppressed. So `request_autosave()` refuses at **staging**; a request that is never staged cannot fire late. `flush_pending_autosave()` also refuses while sandboxed, as a second line of defence against a direct caller.

**The debug labs are mutually exclusive.** Combat Lab and Dialogue Lab each refuse to open or start while `SaveGame.runtime_sandbox_is_armed()` and the armed snapshot is not their own (`another_sandbox_is_armed()`). Two labs holding snapshots at once is unsafe even though each is internally correct: they restore in whatever order they happen to end, and a **non-LIFO restore reinstates the first lab's dirty state after that lab has already cleaned up**. A lab's own armed session is excluded from the check, so restarting a session still works.

Restarting always performs restore-then-capture as an unconditional pair. A session restores exactly once and then disarms its snapshot, preventing a later shutdown from rolling back progress earned after returning to normal play. Ending a session, completing or closing its balloon, disabling the lab, and removing the autoload all restore an armed snapshot.

Setup flags and reputation/Renown targets are applied only after capture, so they are part of the disposable replay state.

## Ownership and read-only boundaries

Dialogue Lab refuses to open or start a replay while a production battle or production dialogue balloon is live. The guarded replay entry points are:

- `start_replay(setup)`
- `start_test_session(setup)`
- `replay_same_state()`
- `reload_and_replay()`

`open_setup()` and the F5 path carry the same ownership guard.

The lab never writes dialogue text and has no export or save path. It only enumerates, loads, and replays resources. In particular, it never writes under `dialogue/` or `dramgid-vault/`.
