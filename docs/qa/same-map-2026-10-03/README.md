# Same-map combat — set-pieces on the field, 2026-10-03

Branch: `port/424-unique`. Tracker: #281 (D5).

## What changed

`Battle.start_set_piece(field, encounter)` now fights an authored encounter on the field it is
handed. The grid is the field's, the party is seated where it stands, each encounter enemy is
seated across from the player, and Battle spawns one `Hostile` body per enemy that adopts the
actor the encounter already built. The bodies are freed with the session. The Lower Trial Hall
and the journey ambush both go through this path; no world scene calls `Battle.start()`.

## Rendered check (Xvfb, 1920x1080)

`test/manual/ambient_session_capture.gd`, case
`test_trial_warden_set_piece_stands_in_the_hall`: the hall is loaded, `request_warden_encounter()`
opens the fight through the production path, and the frame is captured with no battle screen
mounted.

| Shot | File | Observed |
|---|---|---|
| Warden set-piece open | `trial-warden-set-piece.png` | Player on cell (53, 54); the warden's body on cell (56, 54), on the hall floor, inside the walls, not overlapping the player. |

Visible gaps, not fixed here:

1. The warden's body covers part of the `EntranceInstruction` label ("Speak with the aide or
   begin…"). The label is not hidden while a fight is live.
2. Enemy seating is the provisional rule "three cells east of the player". Authored set-piece
   cells are #348's contract. For the keeper fight this means the `TrialKeeper` NPC stays where
   it is authored while a separate keeper body is spawned next to the party.

## Automated checks

See the PR body for the exact suites and their summaries.
