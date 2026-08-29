# Wave 4 acceptance evidence — reputation reactivity

**Date:** 2026-08-29 · **Contract:** `docs/fallout2-adoption-spec.md` Wave 4 acceptance
criteria. Commits under evidence: `65f8866` (subtask 1 — consequence notices),
`6f4adb7` (subtask 2 — ambient acknowledgements + band-aware encounter weighting),
plus the generated-data repair commit (this change — moves the ambient lines into
the Pandora-canonical pipeline).

## What shipped

- **Consequence notice HUD** (`ui/hud/consequence_notices.gd/.tscn`, on
  `field_hud.tscn`): every `Reputation.reputation_changed` /
  `Renown.renown_changed` event surfaces as a transient field notice —
  "<FACTION> WILL REMEMBER — <cause>" / "WORD OF YOU SPREADS — <cause>".
  Event-object dedupe, 3-visible FIFO cap, pause-safe (defers while paused and
  flushes on `NOTIFICATION_UNPAUSED`; tweens stop while paused). Styled via
  theme type variations only (`ConsequenceNoticePanel`/`ConsequenceNoticeLabel`).
- **Three ambient townsfolk acknowledgements** — Droma Flintjaw and Ressa
  Ironmouth react to the live `ironbrand-sentinels` band (their own Pandora
  `Faction Id`), Edda Broadmark to `iron-companies`: hostile/cold gets a cold
  line, warm/allied a warm line, neutral the original greeting. **Authored in
  Pandora, not by hand:** the townsfolk schema gained optional
  `Dialogue Hostile`/`Dialogue Warm` properties (`tools/seed_town_npcs.gd`
  `REACTIVE_DIALOGUE`), and `tools/generate_gloot.gd` emits the band-gated
  block into the GENERATED `dialogue/dom_townsfolk.dialogue`. An earlier
  hand-edit of that generated file was reverted in favor of this pipeline —
  the drift check now passes because generation is the only author.
- **Band-aware travel encounters** (`globals/travel/encounter_director.gd`
  `_encounter_table_for_route()`): a route may declare
  `band_encounter_weights` `{faction_id, bands: {band: {encounter_id: weight}}}`,
  applied at schedule-build time only (determinism preserved — same seed +
  same band ⇒ same schedule); zero weight drops an entry; routes without the
  key build byte-identical schedules. Authored on dom→dorthkor-road
  (iron-companies: hostile vanguard 3 / cold 2 / warm 1 / allied 0 —
  PROVISIONAL balance surface).
- **Vendor pricing + trade access by band — DISCOVERY, already in production:**
  all vendors already price by live `Reputation.band` (generated
  `band_price_modifiers` + `VendorRegistry.price_for`), and trade access is
  already band-gated (`trade_status` `minimum_band`, e.g. Held Flame Shrine
  trades only at warm+). Wave 4's consumers here are proven by tests
  (`test/unit/test_vendor_pricing.gd`), not duplicated by new code: band-ordered
  prices, display==purchase price, a quest resolution (Unclaimed Bed,
  neutral→warm) visibly lowering a price through the production
  `resolve_side_quest → Reputation.record` write, and a different-faction
  vendor unaffected (its stock reached non-vacuously by first earning warm
  Sentinel standing).

## Acceptance items

| Criterion | Evidence |
|---|---|
| Reputation writes produce visible in-world feedback | `ConsequenceNotices` listens to both ledgers' signals; `test/integration/test_consequence_notices.gd` (dedupe, FIFO cap, pause deferral) |
| ≥3 ambient NPC acknowledgements of standing | `test/integration/test_dom_ambient_reputation.gd` — each of the three speakers switches hostile↔warm lines through the real DialogueManager against their own faction's band |
| Ambient lines live in the canonical data pipeline | `scripts/check_generated_data.sh` (drift check) green after regeneration; `test/unit/test_dom_npc_roster.gd` validates every generated block (≥3 speaker lines, conditions well-formed) |
| Encounter composition reacts to standing, deterministically | `test/unit/test_encounter_director.gd` band-weighting cases: per-band table weights, absent-key identical-schedule, seed determinism per band, and SCHEDULE-LEVEL proof — a single-entry route zeroed at allied builds an empty table AND empty schedule (non-empty at hostile), and allied schedules never contain the zeroed encounter across 64 seeds |
| Vendors price by faction band | `test/unit/test_vendor_pricing.gd` (see above) — existing production path proven |
| Trade access band-gated | `test/unit/test_vendors.gd::test_band_gated_shrine_refuses_then_accepts_after_standing_changes` (pre-existing refusal→acceptance coverage incl. `nearest_unblock`); `test_vendor_pricing.gd`'s shrine case additionally asserts the neutral-band refusal before earning warm standing, so it cannot pass with the gate removed |
| Canon / vault review | No new lore facts: the three NPCs, both factions, and all locations pre-exist in the seeded roster; new lines are attitude re-wordings of existing relationships |
| Suite green | Full gdUnit4 run recorded below |

## Suite

Full `runtest.sh -a test` after the pipeline repair: see delivery log entry
(recorded at commit time).

## Residuals

- `band_encounter_weights` values, notice wording, and which NPCs get reactive
  lines are PROVISIONAL balance/content surfaces (owner pass).
- Band reactions re-evaluate on the next conversation start (schedule-build /
  dialogue-run time), not mid-conversation — deliberate.
