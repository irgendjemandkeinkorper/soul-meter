# Called shots: persistent serious injuries (task 9) — 2026-09-19

Task 9 in [the combat expansion checklist](../../tasks/called-shots-and-injuries.md): serious injuries outlive combat until treated, using the existing durable owners.

## Contract as built

- Severity decides lifetime. `serious` records persist; `minor` records end with the fight (their duration is still an authored rule to settle, so nothing carries them out).
- Party owner is `PartyMember.injuries`, keyed by location. `to_dict` writes it; `from_dict` loads through `CombatInjury.records_from_save`. Old saves without the key load with no injuries. A record missing `injury_id` or `location_id` is dropped as malformed. Extra keys inside a record are preserved verbatim. Ids are plain strings, so a future rename ships its own `SaveMigrations` step; none exists today and the schema version is unchanged.
- `BattleActor.from_party_member` copies the records in; `Battle._sync_party_hp` writes the persistent subset back at every finish (victory, defeat, flee), so retreat and travel see the same state. Defeat halves HP and does not clear injuries: revival is not treatment.
- Hostiles: the authoritative same-map state is the `Hostile` node, whose `battle_actor()` is memoized for the field scene's lifetime. `Battle._end_session` prunes minor records from every session hostile; serious ones carry into the next session by themselves. No new registry, no corpse or despawn change. Set-piece enemies are rebuilt per encounter and keep nothing, as before.

## Evidence

- `test/unit/test_party_member.gd`: round trip with an unknown extra key, legacy save loads empty, malformed and non-dictionary payloads drop safely.
- `test/unit/test_battle.gd`: serious record enters combat, survives flee, defeat (HP halved, record kept), and victory; a minor record added mid-fight never reaches the party.
- `test/integration/test_combat_session.gd`: a serious throat injury on a hostile survives session end and voice-blocks it in the next session on the same field; its minor injury does not.
- Regression suites green: save game, save migrations, migration sweep, schema six, DRAMGID migration, game state, travel flow, character sheet, called shots, combat controller, injuries. 245 tests, 0 failures, across two runs.

## Not covered / open

- No treatment path yet (task 10), so a serious injury applied in production content would be permanent. Production aim profiles still author only minor injuries.
- Reload was proven through `PartyMember`/`GameState` serialization, not a rendered save/load flow.
