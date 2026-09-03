# Issue #286 — Hollowing and acts of Agreement core plan

Tracker: https://github.com/irgendjemandkeinkorper/soul-meter/issues/286

Status: core implementation and local verification complete on
`feature/f6-hollowing-agreement-core`. Issue #286 remains open for authored dialogue/barks and
the project audit's seven pre-existing `bellhouse_repair`/`deep_trial` errors.

## Scope and assumptions

- Preserve `soul_husked` and the existing save-compatible husking implementation; expose
  Hollowing as an additive public vocabulary.
- Keep Soul income quest-owned. Combat, rest, and items gain no recovery path.
- Add an optional, backward-compatible outcome reward contract so existing quest resources and
  campaign packages remain valid without edits.
- Do not author canon, reward amounts, recovery prices, companion barks, or dialogue branches.

## Ordered work

1. Add failing GameState tests for Hollowing aliases and state-change compatibility.
2. Implement the additive Hollowing signal/query aliases without changing persisted flags.
3. Add failing quest-resource and resolution tests for a tagged act-of-Agreement Soul reward.
4. Implement optional outcome tags and Soul deltas through DomSideQuest, campaign loading,
   quest resolution, and reward summaries; reject malformed reward contracts before mutation.
5. Extend quest audit coverage, run focused and full suites, review the diff, and commit the
   verified slice without changing authored quest data.

## Verification checkpoints

- Old `soul_husked` saves still report Hollowing and clear both state signals after recovery.
- Only a completed outcome tagged `act_of_agreement` can raise Soul.
- Invalid tags/deltas do not complete a quest or change Soul.
- Existing resources with no reward metadata remain valid.
- Quest audit exits 0 with no reward-contract regression; its seven pre-existing content errors
  remain. The full GdUnit suite reports zero failures.
