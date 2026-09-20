# Called shots: healer treatment in the encounter (task 10B) — 2026-09-19

Task 10B in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md): one authored provider interaction drives the shared treatment operation and shows its exact quote. Providers were chosen by the owner on 2026-09-19 from authorized Dom content.

## Content as built

| Card | Provider | Access | Cost | Notes |
|---|---|---|---|---|
| `herbalist-service` "Herbalist's setting" | Root & Reed (`root-and-reed`, dom-herbalist, East Market) | Vendor trade band (Iron Companies; refused at hostile) | 20 GP, PROVISIONAL | Supplies included; no party Mending needed |
| `shrine-succor` "Succor of the Held Flame" | Shrine of the Held Flame (`held-flame-shrine`, dom-shrine-keeper) | Any standing, any purse | 0 GP | Authored finite remedy: once per game (`dom_shrine_succor_spent`) |

The shrine card is the recovery path for a party with no cash, no Mending, or a hostile standing at the herbalist. It is deliberately one use, so it is not a global free-healing rule. The no-cash route also includes selling spoils to Root & Reed through the existing sell path.

## Interaction

`ui/screens/shop.gd` renders a TREATMENT section on any vendor that offers cards: one row per serious injury in the party, titled `MEMBER · LOCATION · SERIOUS`, with the card name, what it lifts (voice, attack accuracy, vocal accuracy), and a `TREAT · N SILVER` button carrying the quoted cost. A refused row disables the button and prints the reason plus the alternative (for example `TRADE UNAVAILABLE AT HOSTILE STANDING · SHRINE OF THE HELD FLAME OFFERS SUCCOR ONCE.`). Pressing commits with `expected_cost`, so a changed price or a changed wound is refused and shown in the status line instead of charged. The status line prints the receipt (`TREATED · VEX THROAT · -20 SILVER`). Treatment is refused while a battle is live.

## Evidence

- `test/integration/test_treatment_shop.gd` (4 rendered-tree tests on the real shop scene): exact quote, press, purse and wound updated, Soul unchanged, voice restored on the next `from_party_member` actor; short purse and hostile standing show the reason and the shrine alternative, shrine treats one wound at 0 GP, second use refused and the spent flag survives reload; live battle disables treatment and a refreshed wound refuses the old quote without charge; recovery loop from a real battle (injury, flee, save/reload, treat, save/reload).
- Rendered: `called-shot-healer-2026-09-19/treatment-shop-1920.png` from `test/manual/treatment_shop_capture.gd` at the 1920×1080 design frame; inspected, section and button inside the shell.
- Regression suites green: injury treatment, dev console, building interiors, starting town, interior population, battle, injuries, save game. 130 tests, 0 failures, across two runs.

## Not covered / open

- The fee is a placeholder until the encounter/resupply pass. Reputation changes from treatment are not authored (none were requested).
- No injury detail on the party/character screen yet (10C).
- Keyboard/controller navigation of the new rows was not exercised with real input events.
