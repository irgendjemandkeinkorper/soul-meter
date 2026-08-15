# GameState and Battle decomposition plan (issue #84)

Revised 2026-08-15 at HEAD 5b7a674. This supersedes the earlier scoping note: the measured
facts below are current, and the plan is now ordered by measured coupling, not intuition.
It remains a plan, not an immediate refactor — land feature work through the current public
seams, then migrate one seam at a time with characterization tests.

## Measured state (2026-08-15)

- `globals/game_state.gd`: **1015 lines** (the issue's 366 is stale).
- `globals/battle.gd`: **741 lines** — but it is now explicitly a *facade*: all turn
  authority and live pricing sit behind `globals/combat/` (controller 996, grid model 615,
  schedulers 502/428/217, tile_state/weather/resolution 249/232/229, plus catalogs and
  value objects). The AP compatibility shim it carried was removed with #176.
- Battle state is **not serialized**; battle outcomes reach persistence only as GameState
  flags via `_apply_authored_flags` / `_record_last_outcome` (battle.gd:536–596).
- GameState's settings/locale/audio persist to `user://settings.cfg`, **not** the save
  payload — which is exactly why that seam is the cheapest cut.

## GameState seams, ordered by measured coupling (call sites / files)

| seam | coupling | verdict |
|---|---|---|
| settings + locale + audio buses | 9 / 2 | **Cut first.** Zero save-payload entanglement, two consumers. Extract `SettingsService` (owns `user://settings.cfg`, fullscreen, locale, bus volumes). |
| Vär harmony | 5 / 1 | Cut second, or fold into the combat-knowledge move below. |
| vendors / trade | 17 / 4 | **Cut third — the cluster the old note missed entirely (~157 lines, game_state.gd:366–522).** Extract `VendorService` around the existing `VendorData` preload; it already has its own signal (`vendor_stock_changed`) and payload keys (`vendor_stock`, `vendor_restock_cycles`). |
| combat knowledge / weaknesses | 13 / 3 | Move toward `globals/combat/` alongside the identity catalog; serialization stays in the facade payload. |
| fast-travel discovery | 17 / 4 | Leave: it is flag-prefix sugar, not real state. Goes wherever flags go. |
| inventory (GLoot) | 38 / 12 | Extract only the *setup/adapter* half; the `inventory` handle stays on the facade. |
| gp / economy, soul meter / husking | 43/9, 76/14 | Facade-core. Do not extract. |
| flags, party | 274/41, 163/29 | **Facade-core, load-bearing.** Never extract; these plus serialization ARE GameState. |

Target end-state: `GameState` = flags + party + soul/husk + gp + serialization facade
(~450 lines), with `SettingsService`, `VendorService`, and an inventory adapter as
autoload-free helpers owned by it. Every extraction keeps the facade methods as
delegating shims until the last consumer migrates (SaveGame's private-method reach —
`GameState._seed_demo_data()` at save_game.gd:374 — must become a public reset seam in
the same pass).

## Battle seams

The old note's "extract a resolver" already happened (`globals/combat/resolution.gd`,
pure, gate-proven forecast==resolution). What remains in `battle.gd`:

1. **Consequence writer (~190 lines, battle.gd:403–596)** — `_finish`, `_apply_victory`,
   `_apply_flee_consequence`, `_record_renown`, authored-flag writes. This is persistence
   policy, not combat. Extract `BattleOutcomeWriter` (plain RefCounted, injected with the
   ledgers) — it is the only part of Battle that touches GameState/Reputation/Renown, and
   extracting it makes the append-only ledger rule mechanically auditable.
2. **Session state + controller bridge** — stays. It is the facade the UI consumes.
3. **Legacy convenience wrappers** (battle.gd:298–319) — delete after the battle screen
   migrates to `use_action` paths; they predate the controller.

The one genuinely broad Battle surface is the `combat_event` signal (stage, battle_hud,
battle_interface, combat_audio, combat_style_tracker all consume it, with replay). That
contract is now load-bearing for the six-region interface — treat it as frozen; any
decomposition must keep `combat_event` + `replay_combat_events` byte-compatible.

## Sequencing

1. `SettingsService` (9 call sites, 2 files) — one afternoon, zero save risk.
2. `VendorService` — before any shop/economy feature work adds more vendor code.
3. `BattleOutcomeWriter` — before Chapter 2 content multiplies consequence writes.
4. Combat-knowledge move + Vär fold-in — opportunistic, next time that code is touched.
5. Inventory adapter — only when a real inventory feature forces it.

Each step: characterization tests first, delegating shims until consumers migrate, one
seam per PR, suite green throughout.
