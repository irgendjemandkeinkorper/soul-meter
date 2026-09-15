# Opening-route art and gameplay pass

Status: working proposal, 2026-09-09. Baseline: `4e8db002`.
Scope superseded by the user's mechanical-systems clarification; use
[the mechanical systems packet](../CAPABILITY-MAP-mechanical-systems.md) for current work.
Purpose: turn the existing opening route into one coherent, reviewable playthrough.
This packet extends the approved briefs; it does not ratify new mechanics or canon.

## What the repository establishes

- The visual standard is painterly **gothic mythopunk**: worn stone, damp iron,
  tarnished bronze, restrained supernatural accents. World assets follow Part I of
  [the art bible](art-aesthetics-bible.md); UI chrome follows Part II.
- Dom already has dedicated building facades and a substantial painted unit set.
  `world/starting_town.gd` renders the `Facade` child of twelve named buildings;
  `world/town_npc_spawner.gd` resolves townsfolk art through `globals/unit_art.gd`.
- The [ratified Act I spine](act-one-beat-sheet.md) runs Trial → Council's Charge →
  Field Debt → Broken Muster → Dom's Ruling. The opening gauntlet's completion
  triggers an existing Council nudge in `world/starting_town.gd`.
- Commit `4e8db002` adds ambient combat presentation on the field grid. Its runtime
  appearance has not been assessed in this pass.
- The [enemy-curve packet](enemy-curve-packet.md) still records unresolved rulings.
  Enemy variation is a separate decision dependency.

## The bounded deliverable

Working assumption: prioritize the opening route. Follow one fresh character from
the Trial through Dom and Dorthkor to the first city ruling, using existing quests,
dialogue, rewards, and combat rules. Capture the moments below before selecting
asset replacements or implementation fixes. Planning estimate: 45–60 minutes for
the capture and triage session; production estimates depend on what it reveals.

| Moment | Art review | Gameplay review | Evidence that the moment works |
|---|---|---|---|
| Trial exit and Council approach | Actor silhouettes, readable entrances, foot placement and facade occlusion at normal zoom | Existing Council nudge appears at the correct story state; the intended entrance remains reachable | Screenshot of the approach and a recorded walk into the Council |
| Council charge and Field Debt | Existing NPC artwork and signs distinguish the relevant people and route | Dialogue, journal objective and road gate agree about what is required next | Journal capture plus the blocked and unlocked road states |
| Dorthkor exploration | Existing road, muster landmarks and hostiles remain legible against the ground | Approaching a hostile starts combat in the existing field space | Before-combat and combat screenshots from the same camera position |
| First field combat | Actor feet, selection diamonds, target highlights and terrain read together | Movement follows the indicated cells; actions affect the indicated target; control returns after combat | Short recording of movement, an action and combat exit |
| Broken Muster outcome and return | Existing portraits and consequence presentation remain readable | One authored `slain`, `named` or `released` outcome reaches the corresponding dialogue and city ruling; state survives a reload | Outcome, ruling and post-reload journal captures |

## Production rules for this pass

1. **Reuse the approved assets first.** Identify a specific failing screenshot before
   replacing art. A source comment saying “placeholder” is not proof that the current
   scene still looks unfinished.
2. **Keep world-art replacements drop-in compatible.** Preserve subject, footprint,
   ground contact and collision. Follow the existing 256×256 transparent unit/prop
   contract and 64×32 tile seams where applicable. Compare with the ratified
   calibration art; inspect at gameplay zoom as well as source resolution.
3. **Keep gameplay work tied to an observed failure.** Repair existing transitions,
   interaction reach, targeting, quest feedback or persistence against the relevant
   architecture and tests. Record the reproduction before changing behavior.
4. **Review art in context.** Capture the replacement in the actual field scene,
   including actor overlap and the combat overlay. A standalone image is insufficient
   evidence of integration quality. New generated batches retain the existing owner
   review requirement before merging.
5. **Keep authored branches intact.** The field outcome and city ruling are separate
   decisions. Check their current data contracts rather than inventing new rewards,
   consequences, enemy curves or dialogue to make the route appear complete.

## Known verification gap

`test/manual/starting_town_smoke_test.md` still describes a new-game objective pointing
to the Four Arms and assembly before the road commission. The current town script
contains a post-gauntlet Council nudge, and the ratified beat sheet includes the Trial
and Council charge. Reconcile the checklist against a fresh runtime playthrough;
the source discrepancy alone does not prove the full current new-game sequence.

## Execution handoff

1. Capture the five moments above on a fresh save and log actual failures with scene,
   reproduction, expected behavior and screenshot or recording path.
2. Select the first observed art-integration or gameplay defect; implement it within
   its existing brief and run the relevant checks from [testing.md](testing.md).
3. Repeat that moment in-game, including reload when state changes, and return the
   before/after evidence for review.

Acceptance: the selected defect is fixed, the focused checks pass, and the affected
moment works at normal gameplay zoom. This packet itself is documentation only:
no art was generated, gameplay changed, or runtime test completed.
