# Element and spell resolution integrity

Implemented against the existing ten-element composition catalog and the no-direct-
damage rule for Khor/Zhem in `docs/prd-chapter-one.md` (FR302). No new balance values,
material interactions or deity/element classes are introduced.

## Behavior

| Situation | Result |
|---|---|
| Pure Khor or Zhem spell | No direct damage; existing support effects, Breath costs and casting requirements still apply. |
| Khor-centered Founding or Zhem-centered Stillpoint Triad | The center's empty damage components remain authoritative. A Khash wing cannot add direct burst damage. |
| Damage-bearing composition or mundane attack | Existing damage calculation remains available. A weapon's element label alone does not remove its physical hit. |
| Utility spell plus patron bonuses | Ofshütje cannot add direct damage; the controller cannot create a minimum-one-damage hit; Vhorr cannot seed damaging Hunger from the utility cast. |
| Strike on opposing charged terrain | Existing Clash detonation remains environmental damage, including when triggered by a utility spell. It does not grant that spell direct damage or Hunger seeding. |
| Local Hush | The affected tile supplies no charge multiplier, residue or detonation. Other tiles still react. The action remains subject to normal casting and resource gates. |
| Global weather Hush | Both tiles suppress charge effects. Temporary weather suppression is never saved into their local Hush flags; normal reactions resume when weather Hush ends. |

Khor's held aftertones and Zhem's aftertone removal/Tempo reset continue through the
same forecast and commit path. This patch does not make Zhem a physical repair spell.
Destroyed structures retain the separately implemented persistence/rebuilding rules.

## Implementation boundary

`Resolution.resolve()` reports `direct_damage_enabled` from the composition's
`damage_components`, with mundane attacks explicitly retaining damage permission.
This flag controls base power and additive damage channels. Total `damage` may still
include a legal environmental detonation.

`CombatController` applies its existing defense/cover adjustments and minimum damage
only when direct damage is permitted or environmental damage actually exists.
`VhorrHunger` uses the permission flag to reject utility-cast seeds. Older event
fixtures without the additive flag retain their existing behavior.

Hush suppression stays local to tile operations. Weather Hush is applied to private
tile clones for calculation, and suppressed tiles emit no persistence writes.

## Verification

- `test/combat_resolution/test_element_resolution_integrity.gd`: utility Tones and
  Triads, additive damage, support effects, costs, input purity, weapon behavior,
  local/global Hush and environmental detonation.
- `test/integration/test_elemental_casts.gd`: actual AP/CT casts, forecast/commit
  equality, Breath/Soul effects, patron interactions and weather ending without
  leaving persistent Hush behind.
- Focused regression: **196/196 passed**, `reports/report_1412/results.xml`.

Full regression executed **1,967 cases** (`reports/report_1413/results.xml`): the
same nine failed assertions in three NPC/sprint tests as baseline `4e8db002`, with
no additional test failures. The full run is not green. Exact comparison and review
evidence are recorded in [the completed task](../tasks/element-resolution-integrity.md).

## Remaining gameplay work

The catalog and [deity/element chart](ideas/deity-element-class-chart.md) describe
more than the executable spell set. This patch does not claim complete generic
Sul/Vekh information effects, Vel buff extension, Luth restoration or Mozh object
conversion. Their targeting, amounts and presentation need authored acceptance cases.

Physical spell targets, Khash ignition, Luth extinguishing, Tham obstacle creation
and Zhur material conduction remain proposals in the
[mechanical capability map](../CAPABILITY-MAP-mechanical-systems.md). Actor status,
aftertone, tile charge and physical material remain separate state systems. The
next world-reaction slice needs concrete material eligibility, costs, durations and
damage rules before implementation.
