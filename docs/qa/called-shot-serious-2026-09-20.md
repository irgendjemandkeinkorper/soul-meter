# Called shots: serious production injuries — 2026-09-20

Task 11 follow-through of [the combat expansion checklist](../../tasks/called-shots-and-injuries.md): the first persistent injuries in shipped content, gated on the confirmed recovery routes (10A–10C) already being in place.

## What landed

- **Serious escalation rule.** An aim profile's injury may author a `serious` variant: `{id, min_damage, effects}` with a damage threshold strictly above the minor one (validated by `CalledShot.query`). Same deterministic injury roll, same three forecast chances; when the roll lands and mitigated damage reaches the serious threshold, `_finalize_resolution_damage` applies the serious record instead (`escalated: true` on the resolution). Below it the minor record applies as before. Severity `serious` is exactly what task 9 persists and task 10 treats, so no new state or save shape.
- **Forecast.** `injury_forecast` reports the variant that would apply at the quoted damage (`id`, `severity`) plus `serious_eligible` and `serious_min_damage`. The battle interface appends `· SERIOUS` when eligible, or `· SERIOUS AT n` when the threshold is authored but out of reach.
- **PROVISIONAL content** on `strike` and `enemy-strike` (identical): arm → `arm-broken` at 12 damage (−20 pp attacks); leg → `leg-lamed` at 12 (+100% move cost); head → `eye-swollen` at 14 (−30 pp sight); throat → `throat-crushed` at 14 (voice blocked, −25 pp vocal). No stun, no immobility, no disable beyond the voice rule task 8 already defined.
- **Treatment coverage.** Every production card (Root & Reed setting, Shrine succor, field mending) and the test cards now cure arm, throat, leg, and head, so every serious record shipped here has the fee, the once-per-game fallback, and the qualified field route.

## Evidence

- `test/integration/test_production_aim.gd` (+3, and three minor-case fixtures pinned below the thresholds): a 13-damage aimed arm hit under both schedulers forecasts `arm-broken · serious`, applies it, persists it; a 7-damage hit stays `arm-strained` and the forecast names the threshold; enemy-strike authors the same serious variants with thresholds above the minor ones.
- Persistence and recovery of a serious record are the task 9 and 10 suites (battle, session, treatment, shop, sheet), rerun green here.
- Rendered (`test/manual/serious_aim_capture.gd`, 1920×1080, inspected): [serious marker](called-shot-serious-2026-09-20/serious-aim-1920.png) shows `AIM ARM · COST 3 AP · INJURY 50% ON HIT · 29% OVERALL · SERIOUS`.
- Suites: production aim, injuries, treatment, called shots, battle interface, enemy called shots, treatment shop, character sheet, battle, lab, dev console, Wave C gates, combat_resolution, combat session, leg and head captures and the serious capture: 155 cases, 0 failures.

## Open

- No production action carries `requires_voice`, so `throat-crushed` blocks nothing yet; its vocal accuracy term is inert until a voice-tagged action ships. The design's nonvocal-alternative rule is trivially met by strike.
- Thresholds and effects are provisional; the balance pass should look at how often a starting party can reach 12–14 mitigated damage.
- The enemy AI values a serious outcome no higher than a minor one.
- The lab quote line does not show the serious marker (production HUD does).
