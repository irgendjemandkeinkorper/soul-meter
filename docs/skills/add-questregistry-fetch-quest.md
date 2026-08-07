# Skill: add a QuestRegistry fetch quest

Use this workflow for a quest whose progress is a count of one inventory
prototype. `FetchQuest` derives completion from live GLoot inventory state; do
not duplicate that count in dialogue or a second global flag.

## Recipe

1. Add a `FetchQuest` resource under `quests/`. Set its stable id, name,
   description, objective, `item_id`, `required_amount`, giver/location, and
   reward fields (`reward_faction`, `reward_amount`, `reward_cause`).
2. Preload the resource as a named constant in `globals/quest_registry.gd`.
   Add it to `ALL_QUESTS`; add it to `STORY_QUESTS` only when it is part of the
   main chapter spine.
3. Add the quest's dialogue starter. The dialogue should call
   `QuestRegistry.offer(QuestRegistry.<NAME>)` and guard follow-up lines with
   `is_active`, `objective_completed`, or the appropriate quest-state helper.
4. Ensure the giver has a stable actor id and a reachable placement. For a
   generated Dom side quest, use the authored `DomSideQuest` path instead of
   adding a second fetch-quest write path.
5. Let `QuestRegistry._on_inventory_changed()` call `FetchQuest.update()`.
   `FetchQuest.complete()` records the resolution and the default faction
   reward through `Reputation.record()`; callers should not write the ledger a
   second time.
6. Add a test that starts the quest, changes inventory below and above the
   required amount, confirms the objective updates, and verifies completion and
   reward behavior.

## Existing example

`quests/loamroot_sprigs.tres` is the canonical fetch quest. Its item id is
`materials/loamroot_sprig`, it requires three items, and Iris's dialogue starts
it through `QuestRegistry.LOAMROOT_SPRIGS`. The end-to-end coverage lives in
`test/e2e/test_first_chapter_journey.gd`.
