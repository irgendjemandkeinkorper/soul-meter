# Manual smoke test — field room + Iris Illepah dialogue

Covers the currently-playable loop end to end: boot → menu → field → talk → reputation
consequence. Run this after any change to `ui/flow/`, `actors/`, `ui/dialogue/`,
`globals/reputation.gd`, `globals/game_state.gd`, or `dialogue/iris_illepah.dialogue`.

What this checklist does NOT try to cover: exact wording quality of the prose (that's a
writing pass, not a test), or anything already asserted by
[`test/integration/test_field_room.gd`](../integration/test_field_room.gd) (player movement,
wall collision, talk-prompt range) — re-verify those only if you suspect this checklist and the
automated suite disagree.

**Last run:** _(fill in: Godot version, date, pass/fail)_

## 1. Boot and menu

| Do | Expect |
|---|---|
| Launch the project (editor Play, or the built binary) | Main menu appears, no console errors |
| Select "New Game" (or equivalent) | Field room loads — no loading-screen hang, no `change_scene_to_file` warnings in the console |

## 2. Field movement

| Do | Expect |
|---|---|
| Hold each of WASD in turn | Player moves in the corresponding direction, 8-way diagonals included |
| Walk into a wall and hold the direction | Player stops at the wall, doesn't clip through or jitter |
| Walk near Iris Illepah (the NPC) | An "E — TALK" prompt appears once in range, disappears when you back out of range |

## 3. Opening the conversation

| Do | Expect |
|---|---|
| Stand in range of Iris and press E | The Echo Gate dialogue balloon opens with Iris's opening line ("You walk like the Registry counts your steps...") |
| Read the balloon | Text is legible, portrait (if present) is correctly framed, no layout overlap with the HUD |

## 4. Each dialogue choice — reputation consequence

For each choice below: open the Standing/why() view if one exists yet (`Reputation.why()` —
there's no UI screen for this as of 2026-07-26, see `CLAUDE.md`'s next-candidates list; until
then, add a temporary `print(Reputation.all_standings())` or check via the debugger) and
confirm the delta lands.

| Choice | Do | Expect |
|---|---|---|
| "The Bloom isn't finished, is it?" | Pick it | `ssae-seeders` standing **+8**; Iris responds in character; returns to the hub, doesn't end the conversation |
| "This grove is unregistered..." | Pick it | `ssae-seeders` standing **-6**, `the-registry` standing **+4**; returns to hub |
| "Show me what the Loam remembers." | Pick it | Soul Meter drops by **6**; `ssae-seeders` standing **+3**; HUD's Soul Gauge visibly updates in real time; returns to hub |
| "Teach me the Seeders' rite." | Should be **hidden** until `ssae-seeders` standing ≥ 15 | Pick the "Bloom isn't finished" choice twice (+16 total) to cross the gate, re-open dialogue, confirm the option is now present and selectable, and that it ends the conversation |
| "I should go." | Pick it | Conversation ends cleanly, balloon closes, control returns to the field, no leftover paused state |

## 5. Loamroot resolution

Start a fresh run for each branch. Accept Iris's work, collect all three green loamroot
pickups, then choose one resolution. All three branches must remove the sprigs from inventory,
complete the quest, and disappear from later conversations.

| Resolution | Expect |
|---|---|
| Return them intact | `ssae-seeders` **+10**, Renown **+5**, flag `quest_1_resolution = "returned"` |
| Anchor them with your pattern | Soul Gauge **-8**, `ssae-seeders` **+15** total, Renown **+8**, flag `quest_1_resolution = "communion"` |
| Give them to the Registry | `ssae-seeders` **-8**, `the-registry` **+8**, Infamy **+4**, flag `quest_1_resolution = "registry"` |

## 6. Ledger integrity (why the append-only design exists)

| Do | Expect |
|---|---|
| Make two or three choices in one sitting, then reopen the standing/debug view | Every prior delta is still reflected — nothing got overwritten by the latest choice |
| (If save/load exists yet) Save, reload, reopen the standing view | Standings match pre-save exactly — `to_dict()`/`from_dict()` round-trip, see `test/unit/test_reputation.gd` for the automated version of this check |

## 7. Console hygiene

| Do | Expect |
|---|---|
| Watch the console/output panel through the whole run | No `ERROR:`/`SCRIPT ERROR:` lines beyond the known, harmless Phantom Camera "unregistered singleton" noise documented in `DEPENDENCIES.md` |
