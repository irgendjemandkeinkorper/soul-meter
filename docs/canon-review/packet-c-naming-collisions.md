# Packet C: companion naming collisions

Status: **Pending human canon decision**

## Collision 1: Serai-Lun and Serai of Lun

### Exact game locations

- `dialogue/companions/serai_lun.dialogue:5-25` — the companion's displayed speaker name and
  personal-quest conversation.
- `quests/serai_lun_mirror_line.tres:8-12` — quest title, description, objective, giver, and camp
  location use the companion name.
- `globals/game_state.gd:704-717` — recruit construction uses stable `PartyMember.id`
  `"serai-lun"` and display name `"Serai-Lun"` as separate arguments.
- `globals/quest_registry.gd:37-61` — companion quest/dialogue maps are keyed by `PartyMember.id`.

### Vault citations

- `characters/serai-of-lun.md:2-12` — `Serai of Lun` is a mythic founder associated with the
  Mirror Choir and Vervulling.
- `characters/serai-of-lun.md:16-24` — the Twin Pools of Serai of Lun are a founding holy site.
- `characters/serai-of-lun.md:26-35` — the founder predates the schism and is the institutional
  ancestor of the Mirror Choir.

### Conflict nature and consequences

The hyphenated companion name is close enough to the founder's title that players may infer
identity, descent, office, reincarnation, or deliberate naming. None of those relationships is
currently ruled. Keeping the collision without explanation makes every introduction of the
companion carry unintended high-canon implications.

### Bounded ruling options

1. **Keep and relate.** Retain `Serai-Lun` and explicitly define why the companion bears a name
   derived from Serai of Lun. This preserves recognition but adds religious and biographical canon.
2. **Keep and disambiguate.** Retain the companion name while adding one early line that denies or
   bounds the relationship. This minimizes renaming but spends dialogue on clarification and may
   still imply a naming tradition.
3. **Rename the companion display name.** Preserve the stable ID `serai-lun` internally while
   changing player-facing name and prose after approval. This avoids new founder lore but requires
   a bounded text/UI asset pass.

Canon-conservative fallback: option 3. Reserve the vault-established founder's distinctive name
and do not create a relationship by implication.

## Collision 2: Ressa's quest and The Open Hand

### Exact game locations

- `quests/ressa_quickfingers_open_hand.tres:7-12` — numeric quest ID `19`, title `The Open Hand`,
  description, objective, giver, and camp location.
- `dialogue/companions/ressa_quickfingers.dialogue:6-21` — Ressa's opening/weak-flank dilemma;
  the dialogue contains no stated faction connection.
- `globals/game_state.gd:745-756` — recruit construction uses stable `PartyMember.id`
  `"ressa-quickfingers"` and display name `"Ressa Quickfingers"` separately.
- `globals/quest_registry.gd:37-61` — the Ressa quest/dialogue lookup is keyed by that stable ID.

### Vault citations

- `factions/open-hand.md:2-11` — The Open Hand is a named Milinel-based Shimari religious
  movement practicing the Loophole through unpayable giving.
- `factions/open-hand.md:15-29` — its identity is preemptive generosity and the Day of Open Hands,
  with continent-wide reach.
- `factions/open-hand.md:31-42` — its anonymous structure and religious conflict have no stated
  relationship to Ressa's tactical weak-flank question.

### Conflict nature and consequences

The quest title exactly matches a major faction name while the quest concerns tactical openings,
not Shimari gift-culture. Players may reasonably expect faction content, infer Ressa membership,
or misread quest-log references. Search, review, and localization discussions also become
ambiguous.

### Bounded ruling options

1. **Keep and connect.** Establish an intentional relationship between Ressa and the faction.
   Benefit: makes the duplicate meaningful. Cost: broadens her biography and the quest beyond its
   current tactical scope.
2. **Keep as an explicit thematic echo.** Preserve the title but add a clear disambiguation in the
   quest description. Benefit: minimal title churn. Cost: the exact-name collision remains in the
   quest log and still consumes canon attention.
3. **Retitle quest ID 19.** Choose a title about openings, flanks, or restraint without changing
   the quest's numeric ID. Benefit: removes the false faction signal without changing mechanics or
   saves. Cost: requires title approval and localization follow-through.

Canon-conservative fallback: option 3. The current content does not need an Open Hand connection.

## Save and migration finding

These player-facing renames require **no save migration and no save-schema bump** if stable keys
remain unchanged:

- Character display-name changes leave `PartyMember.id` unchanged (`"serai-lun"` and
  `"ressa-quickfingers"` are the current keys).
- Ressa's quest-title change leaves numeric quest ID `19` unchanged.
- Serai-Lun's quest resource also has numeric ID `16`; a display-name edit should leave it intact.

Do not rename the stable IDs, change numeric quest IDs, or add alias/migration mechanics as part of
a prose ruling.

## Review record

Reviewer: _Unassigned_

Review date: _YYYY-MM-DD_

Decision — Serai-Lun: _Pending; choose option 1, 2, or 3_

Decision — The Open Hand: _Pending; choose option 1, 2, or 3_
