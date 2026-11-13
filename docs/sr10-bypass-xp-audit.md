# SR10 bypass-XP audit (2026-11-08)

**Ruling.** SR10 (owner, 2026-11-08; `docs/owner-decisions.md` §5): getting past a fight by
talk, stealth or Soul pays the same kill XP as winning it. This extends game-identity
ruling 9 ("XP comes from combat and quests"). It does not change the XP curve, the level cap
or milestone XP.

**The one award call.** `Battle.award_bypass_xp(encounter_id, kind)`, where `kind` is one of
`talk`, `stealth` or `soul`. It pays the encounter's catalog foes through
`GameState.award_party_kill_xp()`, so the amount equals what the same foes pay when defeated.
Its cause reads "Got past <id> (<kind>)". It writes XP and the encounter's `defeated_flag`
only. Reputation, Renown and spoils stay with the route that calls it.

**Paid once, both ways.** `defeated_flag` is the guard:

| Order | Result |
|---|---|
| Bypass, then fight | The fight pays 0: `_apply_victory()` and `_resolve_group()` see the flag |
| Fight, then bypass | The bypass is refused with `already_resolved` |
| Bypass twice | The second call is refused with `already_resolved` |
| Encounter has no `defeated_flag` | Refused with `no_defeated_flag`, because nothing could stop a second award |

## Audit of shipped content

Source: `data/generated/encounters.json` (12 encounters) and the world scenes that place
hostiles.

| Bypass kind | Present in shipped content? | Pays? |
|---|---|---|
| Talk in battle (combat speech: `released`, `named`) | Yes: `dorthkor-muster` (`named`, `released`), `phase2-speech-winnable` (`released`) | Yes, already. A speech END finishes the battle as VICTORY, and `_apply_victory()` pays the full kill XP. Test: `test_talking_a_fight_down_in_battle_pays_the_same_as_slaying_it` |
| Talk before battle (a dialogue that resolves an encounter) | No. No dialogue or quest sets a `defeated_*` flag | Use `award_bypass_xp(id, &"talk")` when one is authored |
| Stealth (pre-alert Tread) | No. Hostiles alert on proximity only, and Tread has no field reader | Use `award_bypass_xp(id, &"stealth")` when one is authored |
| Soul route | No. No Soul route ends an encounter | Use `award_bypass_xp(id, &"soul")` when one is authored |
| Talk in an ambient (open-field) session | Not offered. Ambient sessions carry no `speech_hooks`, so the speech action is unavailable | n/a |

**Encounters a future bypass could use** (they have a `defeated_flag`):
- `bog-wight`
- `dorthkor-muster`
- `dorthkor-vanguard`
- `jawbrace-empty-post`
- `loam-boar`

The `phase2-*` and `trial-*` encounters have no flag. A bypass for one of them needs a
`defeated_flag` authored in Pandora first, then regenerated. P5.5 owns authoring new bypass
routes.
