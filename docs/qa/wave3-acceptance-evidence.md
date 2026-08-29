# Wave 3 acceptance evidence — dialogue checks + quest verbs

**Date:** 2026-08-29 · **Contract:** `docs/fallout2-adoption-spec.md` Wave 3 acceptance
criteria. Commits under evidence: `2dd9632` (subtask 1 — convention + plumbing +
audit rule), `b7698a6` (subtask 2 — four quests), `ada1b8f` (subtask 3 — five
quests + band-pricing proof), `8ca5a63` (e2e exemplar).

## What shipped

- **Convention** (`docs/dialogue-checks.md`, ratified pattern): `check(skill,
  difficulty)` is the RNG-free availability gate rendered as an UPPERCASE tag —
  never a number (owner ruling 2); the selected response commits exactly one
  `SkillCheck.resolve(skill)` — the roll is against effective skill, so the
  authored difficulty never reaches `resolve()` and the service API stays
  unwidened; branch on the new `SkillCheck.last_check_succeeded()` (thin
  `_check_log` read, the only API addition); failure sets a `<quest>_check_failed`
  flag, closes only the check path, and the original `required_flags` route stays
  completable.
- **All ten Dom side quests** now have ≥2 acquisition routes (original evidence
  route + a build-expressive check verb whose success sets the quest's real
  `required_flags`): Dishonest Casks (persuasion 45, the exemplar), Ash in the
  Rain (investigation 45), Cold Bowl (beast_handling 40), Fifth Echo
  (performance 45), Last Safe Course (survival 50), Living Tag (lore 45),
  Unclaimed Bed (insight 45), Rainbound Register (investigation 50), Marching
  Knots (sleight_of_hand 40), Smoothed Weights (athletics 50). Eight distinct
  skills across ten quests.
- **Softlock audit rule**: `tools/quest_audit.gd` `check_softlocks` — missing
  resolve or missing success/failure branch = error; only-acquisition-route
  heuristic = warning (limitations documented in the header; else-scan is
  indentation-matched, `=> END`-only branches rejected as continuations).
- **Thin Wave-4 slice — vendor prices by faction band**: DISCOVERY — this
  consumer already exists in production for ALL vendors
  (`data/generated/vendors.json` `band_price_modifiers` +
  `VendorRegistry.price_for` resolving the live `Reputation.band`). A planned
  one-vendor modifier layer was dropped as redundant; `test/unit/
  test_vendor_pricing.gd` instead proves the existing path: band-ordered prices
  on Iron & Thread, display==purchase price, and **Unclaimed Bed's resolution
  crossing neutral→warm visibly lowers the price** through the production
  `resolve_side_quest → Reputation.record` write; a different-faction vendor is
  unaffected. Wave 4's "all vendors price by faction band" consumer should be
  marked already-satisfied (test coverage, not new code, is its remaining work).

## Acceptance items

| Criterion | Evidence |
|---|---|
| Quest audit clean incl. new rule | Production run at `ada1b8f`: **0 errors** across all seven categories; `check_softlocks` count 0 on all ten retrofits |
| Zero RNG during choice display | `test_dialogue_checks.gd::test_building_checked_choice_consumes_no_rng_or_check_log_entry` (asserts RNG state and check-log length unchanged through DialogueManager condition evaluation) |
| Exactly one committed resolve | `test_selecting_checked_response_commits_exactly_one_check` |
| E2E exemplar: both verb routes + one failure route | `test_first_chapter_journey.gd::test_dishonest_casks_exemplar_passes_both_verb_routes_and_a_failure_route` — persuasion route completes the quest; failed check sets its flag, closes only that path, and the original evidence route still resolves. Per-quest contract tests cover the other nine (`_assert_quest_check_route`) |
| Canon / vault review | **Vault-review items: none.** Every name and fact in the new lines pre-exists in the quest content (verified by corpus search per name); no new lore facts were introduced |
| Suite green | Full gdUnit4 run at `8ca5a63`: **938 test cases / 0 errors / 0 failures / 0 flaky** |

## Residuals

- Check difficulties (35–55 band) and the failure-flag retry lockout are
  PROVISIONAL balance surfaces.
- The `check_softlocks` only-route heuristic is warning-severity by design;
  its limitations are documented in the audit header.
