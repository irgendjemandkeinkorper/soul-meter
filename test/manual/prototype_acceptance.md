# External playtest acceptance — The Broken Muster

**Target:** Windows x64, keyboard/mouse, fresh version-2 save, 20–30 minutes.
**Record:** Godot/build version, date, result, and copied end summary.

## 1. Boot, onboarding, and party

| Do | Expect |
|---|---|
| Launch the zip and select New Game | Dom loads at Vex's named arrival point; the HUD shows controls, Vex's HP, and the recruitment objective |
| Walk into locked road markers | Dorthkor asks for Coiljaw's commission; Loamroot says it opens after the ruling |
| Enter the Four Arms | Six candidates appear; Vex is shown as fixed lead; Korrath (Renown 10) and Maura (Infamy 8) explain their locks |
| Try one or three selections | Confirmation remains disabled; a third checked box is rejected |
| Choose two open companions | Party becomes `[Vex, companion, companion]`, objective changes to Coiljaw, and AUTOSAVED appears |
| Open Inventory | Items appear as 64px three-column slots; selecting a slot shows its full name, stack count, and description |

## 2. Commission and Dorthkor

| Do | Expect |
|---|---|
| Talk to Coiljaw | He issues The Broken Muster; north road unlocks and journal/HUD name the next step |
| Travel north | Camera remains bounded; Vex, NPCs, and enemies sort from their feet over the 64×32 isometric ground |
| Approach the Bloodbellow before the vanguard | It visibly says to break the vanguard first |
| Fight the vanguard | Two selectable enemies act after all three companions; Chaos pressure and target state are visible |
| Win | The vanguard disappears, Bloodbellow unlocks, reputation/Renown land once, and an autosave appears |

## 3. Signature encounter (fresh run per route)

| Route | Expect |
|---|---|
| Reduce Bloodbellow to 0 HP | Outcome is **slain**; cause says it was destroyed by force |
| Reach Order +50 with at least 3 Soul, choose Speak Its Muster-Name | 3 Soul is spent; outcome is **named**; binding breaks |
| Survive one enemy round, return Balance to -20…+20, choose Release | Outcome is **released**; soldier's soul leaves the armor |
| Flee | Current wounds remain; no completion flag, reward, or reputation |
| Lose | Company returns at 50% max HP; no completion flag, reward, or reputation |

## 4. Ruling, recap, and free roam

| Do | Expect |
|---|---|
| Return to Coiljaw | Report text reflects slain/named/released before the strategic choices appear |
| Choose a ruling | Companies-first, Sentinels-first, or centered hold-both (only at 40–60 Soul) applies its authored standings and Renown once |
| Finish dialogue | State-chart-owned recap pauses play and lists company, encounter outcome, ruling, Soul, standings, and elapsed time |
| Copy summary | Clipboard contains a single-line offline playtest summary; no network/telemetry prompt appears |
| Continue Exploring | Loamroot road unlocks, autosaves, and returns control; Deep Trial remains absent from this prototype path |
| Return to title/Continue | Version-2 slot restores scene, party order, flags, ledgers, Soul, quest, and position/spawn |

## 5. Release hygiene

- Before sharing a build, run `GODOT_BIN=godot bash scripts/acceptance_gate.sh`; it verifies
  generated-data drift and the full headless journey suite without requiring art assets.
- Complete one route without console script errors.
- Confirm 1280×720 text and disabled-action explanations are readable.
- Confirm UI click/combat resolution sounds honor the SFX setting.
- Confirm the Windows artifact contains `SoulMeter.exe`, its `.pck`, README, and dependencies.
- Run the complete gdUnit4 suite and require zero failures before sharing.
