# Ten patron classes: playable resource pass

2026-09-09. User priority: classes before further environmental systems. This completes the
existing resource loops and their command routing. It does **not** declare full progression,
every named signature, or class art finished. Class identity and DRAMGID remain independent.

## What each class can do now

Numbers below describe the current playable build and remain provisional. The separate
`class-resources-numbers.md` proposals have not been applied.

| Class / god | Playable loop | Limit or tradeoff | Signature boundary |
|---|---|---|---|
| Mirrorblade / Maiiam | Alternate Strike and Guard to stay Balanced. Repeating either twice enters Unbalanced: 1.25 attack scale and −15 casting accord. | Switching between Strike and Guard restores balance. Other actions do not advance the streak. | Reflection and movement-based balance are not implemented. |
| River-Mother / Haeren | Record Name on a living ally, including self. Their fall or survival through victory pays 1 Breath once. | A name cannot be recorded twice; no Soul income. Deferred falls and peaceful victories count. | Last Washing stabilization is not implemented. |
| Ironbrand / Kero | HP loss banks one Scar. Spend Scars arms a guaranteed hit for the next resolved attack/cast. | Five Scars maximum; one armed window. A spell can still fizzle and consume it. | Guaranteed crit and Debt of Arms are not implemented. |
| Lensbearer / Stuid | Spend Clarity reveals true spell forecast terms through the next committed cast. | Three Clarity per battle. Previewing, moving and guarding preserve the reveal. | Permanent Fading, trap revelation and Sacred Clarity enemy telegraphs are not implemented. |
| Husk-bearer / Vhorr | Successful Strikes/casts seed one recurring DoT chain per target. Hits and damaging Hunger ticks raise Hunger; later ticks use the new value. DoT kills pay 1 Breath. | Hunger caps at five. Jam cancels a chain; subsequent hits can reapply it. No Soul income. | Nothing Wasted uses the current fixed Breath refund, not the older proportional Gauge proposal. |
| Flamebinder / Vicoar | Fizzles bank Failure Tokens. Spend Token prevents the next cast from fizzling. | Three tokens maximum; one armed window. Forecasts never consume it. | Any next spell qualifies. Same-spell tracking and retrospective Second Casting are not implemented. |
| Stormbearer / Ofshütje | Successful spells draw a hidden storm row worth 1, 2 or 3 bonus damage. The same seeded result drives preview and commit. | Draw remains hidden unless the forecast is revealed. | Distinct secondary effects and Tuned Thunder crit chaining are not implemented. |
| Oathclock / Pazzah | File Sentence queues 6 damage against an enemy, due in two rounds. | Three entries maximum; ranged targeting/LOS; Jam can cancel the source's queue. Downing the source does not cancel a filed effect. | More sentence payloads and Sequenced Verdict are not implemented. |
| Locksmirk / Fickah | Jam the Gears spends 1 Soul to cancel an enemy's unresolved committed action and enemy-owned queued effects. If none can be cancelled, it arms a retry on the owner's turns. | One pending Jam. Dead/missing target clears the retry. Existing 5% fizzle floor remains. | Uses the existing scheduler cancellation seam; instant actions cannot be cancelled after resolution. |
| Threadwalker / Izhakel | Bind Hostility touches an enemy; their next ATTACK action queues one 6-damage payoff. | Three contracts maximum, one Hostility per target, melee range. Unrelated actions preserve the contract; a dead target releases its slot. | More conditions, manual collection and the broader Unspoken Term signature are not implemented. |

## Authored commands

Existing actions: `record-name`, `spend-scars`, `spend-clarity`, `spend-token`.
New actions: `file-sentence`, `jam-the-gears`, `bind-hostility`, authored under
`data/combat/actions/23_*.tres` through `25_*.tres`.

The three new actions cost 2 AP / 2 CT. Their damage, delay and Soul cost are initial playable
content, pending balance review. All seven commands reject incompatible patrons, unavailable
resources, duplicate/armed/full state, malformed payloads and invalid targets before spending.
Threadwalker uses the existing melee reach across disciplines; no new reach exception exists.

Oathclock and Threads read parameters from the authored action resource. Player options cannot
replace these payloads. The existing action list, target controls and tooltips expose the
commands without a separate class menu. ClassCatalog describes current resources and labels
unimplemented signatures as Planned.

The forecast panel describes delayed/conditional commands directly, without showing a fictional
immediate attack or hit chance. Browsing the element wheel preserves that command description.

## Persistence and combat closure

Class resources and deferred entries retain their existing model-level save round-trip. This
does not enable mid-battle saving in Chapter 1. At battle end, named survivors earn their
refund, then already-due pure Breath refunds settle before `battle_finished` copies values
back to the party. The clock does not advance and offensive/future entries do not fire early.
Defeat still does not copy battle Breath back to the party. No class increases the Soul Gauge.

## Verification

`test/integration/test_class_completion.gd` covers readiness in AP and CT modes, queued effects
across resource save/restore, enemy contract triggers, cancellation/reapplication, final-kill
and peaceful-victory refunds, real CAST forecasts/commits, public Battle command routing,
Soul costs, melee range, and queue caps. Existing class-resource, action-catalog, controller
and battle pointer suites cover the shared seams.

Focused acceptance: **172/172 passed**, `reports/report_1405/results.xml`, including real
Mirrorblade/Ironbrand action loops and the forecast panel scene. Full-suite results are recorded
in `tasks/class-completion.md` after the final regression run.

Run the focused acceptance suite:

```bash
SOUL_METER_HEADLESS=1 GODOT_BIN=/home/adamjroder/.local/bin/godot bash scripts/test.sh -a test/integration/test_class_completion.gd
```

Next class decision: review the signature-boundary column before scheduling progression or
additional signature abilities. Those require authored behavior and acceptance criteria.
