# Chapter-end export: the record Chapter 2 reads (#616, SR15) — design note

**Status:** PROPOSAL, 2026-11-08, for owner review. Nothing is built. The record's version 1 freezes
only after #597 (P2.4, the Soul log) fixes the log's entry shape. Implementation may be delegated
once you approve this note.

**Ruling.** SR15 (owner, 2026-11-08; `docs/owner-decisions.md` §5): Chapter 2 imports **end-states
only**. That means flags for who lived and what the player ruled, plus Soul, Renown and Reputation.
Party, gear and levels rebuild in Chapter 2.

**What this note does not decide:** Chapter 2 content, how Chapter 2 rebuilds the party, or NG+ rules
(`globals/ng_plus.gd` stays as it is).

## 1. The shape: a projection of the finished save

The record is a **pure projection of the save payload** that `SaveGame` already writes, not new
state. Every field below is already serialized today, except the Soul log, which #597 adds.

- **No save schema change.** `SaveMigrations.CURRENT_SCHEMA_VERSION` stays 11, and this note adds
  no field to the save.
- **Rebuildable.** Any end-of-chapter save can regenerate its record. A record lost or written by an
  older build is rebuilt from the save, not repaired by hand.
- **One owner per fact.** The record copies values; it never becomes their source. The table names
  the source of each field.

**Proposed API (Systems layer):** `ChapterEndExport.from_save_payload(payload: Dictionary) ->
Dictionary` is static and pure, so it compiles under `--script`. It has two companions:
`ChapterEndExport.write(record, path)` and `ChapterEndExport.read(path) -> Dictionary`. Reading
refuses a record whose version it does not know, the same way `SaveMigrations` refuses an unknown
`schema_version`.

**When it is written.** It is written once, when the statechart enters `Playing/ChapterComplete`
(`GameFlow._on_chapter_complete_entered()`, reached when `ChapterOneProgress.current_stage()` is
`COMPLETE`). It goes to `user://exports/chapter-1-end.json`, from the same snapshot as that moment's
checkpoint. Flow calls Systems. Nothing in the record is read back into Chapter 1.

## 2. The record (version 1)

| Field | Type | Source of truth |
|---|---|---|
| `record` | String, always `"soul_meter.chapter_end"` | constant |
| `record_version` | int, `1` | constant; bumped on any shape change (§4) |
| `chapter` | int, `1` | constant |
| `source_save_schema` | int | the save payload's `schema_version` (11 today) |
| `written_at` | int, unix seconds | the save payload's `saved_at` |
| **What the player ruled** | | |
| `rulings.broken_muster` | String: `demons-first` / `dead-first` / `hold-both` | `GameState` flag `chapter_one_resolution`, written by `QuestRegistry.resolve_broken_muster()` |
| `rulings.unanswered_roar` | String: `sound-the-shortfall` / `seal-the-measure` / `carry-it-yourself` | flag `chapter_roar_resolution`, written by `QuestRegistry.resolve_unanswered_roar()` |
| `rulings.deep_trial` | String: `seal-the-ledge` / `sentinel-descent` / `witnessed-descent` | flag `deep_trial_resolution`, written in `dialogue/marshal_coiljaw.dialogue` |
| `rulings.side_quests` | Dictionary: quest `stable_id` → outcome id; resolved quests only | each `DomSideQuest.resolution_flag`: the 10 Dom quests plus `hollowmere_instrument_stake` |
| `rulings.companion_quests` | Array[String] of companion ids whose quest resolved | `QuestRegistry.COMPANION_QUEST_COMPLETION_FLAGS` (six `party_*_resolved` flags) |
| **Who lived** | | |
| `fates.bloodbellow` | String: `slain` / `named` / `released` | flag `dorthkor_muster_outcome` |
| **Soul** | | |
| `soul.value` | float | `GameState.soul_meter` |
| `soul.lowest` | float | `GameState.soul_lowest` |
| `soul.hollow` | bool: Hollow at chapter end | flag `soul_husked` (`GameState.is_husked()`) |
| `soul.scar_ceiling` | float, or `null` if never husked | flag `soul_husked_recovery_ceiling` (`GameState.husked_recovery_ceiling()`; present exactly when `has_been_husked()`) |
| `soul.log` | Array[Dictionary], the #597 entry shape verbatim | the Soul log #597 adds to saves. Today's in-memory entry carries `index`, `cause`, `requested`, `before`, `after`, `changed`, `clamped`, `ceiling`, `husked_before`, `husked_after`, `band_id` |
| **Standing** | | |
| `reputation` | Dictionary, `Reputation.to_dict()` verbatim: `log` (each row `actor`, `faction`, `delta`, `cause`, `scene`, `at`, `order`) and `next_order` | the Reputation ledger |
| `renown` | Dictionary, `Renown.to_dict()` verbatim: `log`, `next_order`, `last_decayed_day` | the Renown ledger. Karma rides here as the `karma` kind, beside `reputation` (fame) and `infamy` |

**Why whole ledgers, not standings.** Reputation and Renown are append-only (`AGENTS.md`), and their
standings are derived from the log. Copying the log keeps every cause, so Chapter 2 can say *why* a
faction is cold, and `from_dict()` rebuilds the standings exactly. Copying standings alone would lose
the causes for good.

**Why an allow-list of flags, not all flags.** Chapter 1 writes 82 literal flags
(`tools/quest_audit.gd`, `metrics.flags.written`), plus prefix families such as the per-location
discovery flags. Most are tutorial, dialogue-progress and loot flags. Passing them all would make
every Chapter 1 flag name a Chapter 2 contract. The record names its flags in one table inside
`ChapterEndExport`. A pinned test fails if a listed flag has no writer, using the same scan as
`tools/quest_audit.gd`'s orphan check.

## 3. Left out on purpose

| Left out | Save field | Why |
|---|---|---|
| Party, companions present, custom recruits | `game_state.party`, `custom_recruits`, `tactical` | SR15: the party rebuilds. SR14 keeps companions through Chapter 1, so "who lived" adds nothing for them; their quest results ride in `rulings.companion_quests` |
| Gear, inventory, loot | `inventory`, equipment, `loot_containers` | SR15: gear rebuilds |
| Levels, XP, skills, Tones, combat knowledge | party members, `skills`, `var_harmony`, `combat_knowledge`, `skill_check` | SR15: levels rebuild |
| Class resources | `class_resources` | per-fight state, not an end-state |
| Gold | `gp` | not named by SR15; left out pending §6 question 2 |
| World clock, spawns, structures, travel plan, discovery flags | `world_clock`, `spawn_state`, `world_structures`, `travel_plan`, `*_discovered:*` flags | Chapter 1's map, not Chapter 2's |
| Zhavar rungs | `zhavar` | not named by SR15; left out pending §6 question 1 |
| NG+ block | `ng_plus` | NG+ is its own rule set; this note does not touch it |

A pinned test fails if the record carries any of these keys.

## 4. The Soul scar and an active Hollow

Canon (`../dramgid-vault/cosmology/souls.md`, "Reaching zero"): a husked Gauge "never reads as bright
again", and recovery is slow and partial. Chapter 1 models this with two flags (`globals/game_state.gd`):

- `soul_husked`: Hollow right now. Recovery above zero clears it.
- `soul_husked_recovery_ceiling`: set the first time the Gauge reaches zero and **never cleared**. Its
  value is the most the Gauge may ever read again: `HUSKED_CEILING_RATIO` (0.5, PROVISIONAL, owner
  item 5) × the reading just before zero.

The record carries both, under different names, so neither can be confused with the other:

| Chapter 1 end | `soul.hollow` | `soul.scar_ceiling` | `soul.value` |
|---|---|---|---|
| Never husked | `false` | `null` | the Gauge |
| Husked, recovered above zero | `false` | the ceiling | the Gauge, ≤ the ceiling |
| Hollow at the end | `true` | the ceiling | `0.0` |

The record stores facts, not Chapter 2 behaviour. It carries enough for Chapter 2 to keep the scar
permanent: the ceiling travels as a value, not as a recomputation. How Chapter 2 starts a Hollow or
scarred character is Chapter 2's design. This note does not decide it.

## 5. Versioning

- `record_version` is an integer. Any change of shape bumps it: a field added, removed, renamed or
  retyped.
- `ChapterEndExport.read()` migrates older versions forward, one step per version, like
  `SaveMigrations`. It refuses a newer one.
- `soul.log` is the one field whose shape another issue owns. Version 1 copies #597's entry shape
  verbatim, so a later change to the Soul log entry also bumps `record_version`.

## 6. Questions for you

1. **Zhavar rungs.** SR15 does not name them. FR-308 makes the Zhavar's full systemization Chapter 2+
   work, so Chapter 2 is the first chapter that would read them. Carry `zhavar` across, or leave it
   out? Recommended: carry it. It is one small dictionary, and leaving it out cannot be undone for a
   finished save.
2. **Gold.** SR15 rebuilds gear. Does gold rebuild too? Recommended: yes, leave `gp` out, matching
   gear.
3. **Karma.** It rides inside the Renown log, so carrying Renown carries Karma. Keep it, or strip the
   `karma` kind? Recommended: keep it. Karma's tiers come from RFC-0007 (Yothmeru), and stripping
   it would rewrite an append-only ledger.
4. **Fates beyond Bloodbellow.** Chapter 1 has one authored fate flag (`dorthkor_muster_outcome`).
   Encounter `defeated_flag`s record who was beaten, not who lived. Recommended: only authored fate
   flags are fates; add each new one to the allow-list when its scene is written.

## 7. Pinned test (lands with the build, after #597)

`test/integration/test_chapter_end_export.gd`, on the chapter-journey harness:

1. Play the journey to `ChapterOneProgress.Stage.COMPLETE` on one fixed path: hold-both, released,
   one side quest each way, one companion quest. Take the save payload.
2. `from_save_payload()` → `write()` → `read()`. The two dictionaries are equal, and the file matches
   the checked-in fixture `test/fixtures/chapter_end/chapter-1-end.v1.json`, apart from `written_at`.
3. `Reputation.from_dict(record.reputation)` and `Renown.from_dict(record.renown)` reproduce every
   faction standing and every Renown total of the finished save exactly.
4. A Hollow end and a scarred, recovered end each round-trip `soul.hollow` and `soul.scar_ceiling`.
5. A shape check: every field in §2 is present and typed. No key from §3 appears. An unknown
   `record_version` is refused.

Any field without a source, any party, gear or level field, or an unversioned record fails the
test. That is #616's acceptance check.
