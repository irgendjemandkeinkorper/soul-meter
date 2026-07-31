# Manual smoke test — Turn-based Battle screen

Covers the turn-based Battle screen end-to-end: actions (Attack, Defend, Flee), HP reporting, mitigation communication, victory, and defeat. Run this after any change to `ui/screens/battle.gd`.

**Last run:** _(fill in: Godot version, date, pass/fail)_

## 1. Entering Battle

| Do | Expect |
|---|---|
| Approach a field enemy (e.g. Bog Wight) in the wilds and interact to start combat | Battle overlay opens. Player and Enemy display names and HP progress bars are rendered clearly. |

## 2. Attack and Counterattack

| Do | Expect |
|---|---|
| Select the "Attack" option | • Log text updates to show the player's attack damage and the enemy's remaining HP.<br>• If the enemy survives, the log also shows the enemy counterattacking, the damage dealt to the player, and the player's remaining HP.<br>• Player and Enemy HP labels and bars visibly update to match the logged values. |

## 3. Defend and Mitigation

| Do | Expect |
|---|---|
| Select the "Defend" option | • Log text updates to show that the player braced and mitigated incoming damage.<br>• The log clearly communicates the incoming damage after mitigation and player's remaining HP, specifically showing how much damage was blocked (mitigated) or if it was mitigated to the minimum limit.<br>• Player HP labels and bars update. |

## 4. Flee

| Do | Expect |
|---|---|
| Select the "Flee" option | • Log text updates to say "You disengage and fall back."<br>• The battle overlay closes on "Continue", and player returns to the field cleanly. |

## 5. Victory (Defeating the Enemy)

| Do | Expect |
|---|---|
| Attack the enemy until their HP is 0 | • Log text shows the final attack, the enemy's HP at 0, and that the enemy is defeated.<br>• No enemy counterattack occurs.<br>• The Battle overlay transitions to the outcome state with the "Continue" button.<br>• Post-battle rewards (reputation/renown) are recorded correctly. |

## 6. Defeat (Player Falls)

| Do | Expect |
|---|---|
| Allow the enemy to attack/counterattack until the player's HP is 0 | • Log text shows the enemy's final blow, player's HP at 0, and that the player falls.<br>• The Battle overlay transitions to the outcome state with the "Continue" button.<br>• Post-battle penalties (e.g. loss faction reputation changes) are recorded correctly. |

## 7. UI Theme and Styling

| Do | Expect |
|---|---|
| Inspect the layout, text wrapping, and controls | • No hardcoded color overrides are used.<br>• No per-node style overrides exist; fits perfectly within the design system.<br>• Custom minimum sizes prevent text from clipping. |
