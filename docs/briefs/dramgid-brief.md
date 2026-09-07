# DRAMGID migration fact base

## 1. Ratified rulings on DRAMGID

| Source | Verbatim ruling |
|---|---|
| Game identity 8 | “**Class = identity, DRAMGID = what you can DO.**” Patron class supplies unique functions; DRAMGID’s seven named attributes and 22 skills determine competence, replacing the old six-stat build. `docs/game-identity.md:18` |
| Game identity 9 | “**Progression = XP levels + skill points + class perks.**” Attributes are fixed after a 22-point creation buy except rare story boosts; perks occur every unspecified N levels and some gate on Karma/Fame bands. `docs/game-identity.md:19` |
| Build consequence | “**DRAMGID migration (ruling 8).**” requires a save-schema bump, chargen wizard, Pandora columns, `SkillCheck`, and dialogue rewrites; Karma is not `Reputation`, while Fame maps to `Renown.reputation`/`infamy` with Decorum scaling. `docs/game-identity.md:31-34` |
| Field/progression consequence | Field objects use the 22 skills and Loom-sensitive skills weaken in Hush/Waning zones; XP comes from combat and quests, and patron perk lists become Pandora data. `docs/game-identity.md:35-38` |
| Fleet F3 | “DRAMGID migration: seven attributes + 22 skills replace the six-stat build”; it names save bump, chargen, Pandora, `SkillCheck`, dialogue conditions, and Yothmeru-to-`Renown` mapping with Doctrine/Decorum scaling. `docs/fleet-roadmap.md:111` |
| Fleet F5 | “Progression: XP from combat + quests, skill points per level, perk lists per patron class as Pandora data, Karma/Fame-gated perks.” `docs/fleet-roadmap.md:113` |
| Ship priority | Both DRAMGID #283 and same-map combat #281 are mandatory week-one migrations; downstream content must not touch stats until they merge. `docs/ship-plan-2026-10.md:25-28` |
| Ship scope | Gold includes “same-map combat, ~100-mob floor, DRAMGID, field verbs, progression, hollowing.” `docs/ship-plan-2026-10.md:45-50` |
| Ship ownership | F3’s design half is Claude’s Day-2 gate; its implementation half is Codex’s Day-7 gate, stated as “save schema 7.” `docs/ship-plan-2026-10.md:59-65` |

## 2. The DRAMGID spec itself

RFC-0001 is Accepted and supersedes/amends the character-creation attribute, skill, race, and flow sections plus imported RFC-0004/0005. `../dramgid-mono/00-governance/rfcs/games/soul-meter/RFC-0001-dramgid-attribute-rename.md:1-12`

### Seven attributes

| ID | Name | One-line meaning |
|---|---|---|
| `ATTR.DOCTRINE` | Doctrine | Unpaired Standing attribute; amplifies declining/negative Yothmeru volatility and has no associated skills. `../dramgid-mono/00-governance/rfcs/games/soul-meter/RFC-0001-dramgid-attribute-rename.md:51-58` `../dramgid-mono/00-governance/rfcs/games/soul-meter/RFC-0001-dramgid-attribute-rename.md:62-67` |
| `ATTR.REASON` | Reason | Initiative, tactics, and non-elemental checks. `../dramgid-mono/04-world/systems/character-creation.md:31-36` |
| `ATTR.ALACRITY` | Alacrity | Precision, accuracy, and evasion. `../dramgid-mono/04-world/systems/character-creation.md:31-36` |
| `ATTR.MUSTER` | Muster | Raw physical power and carry weight. `../dramgid-mono/04-world/systems/character-creation.md:31-36` |
| `ATTR.GRIT` | Grit | HP pool and resistance to Discord/backlash. `../dramgid-mono/04-world/systems/character-creation.md:31-36` |
| `ATTR.INTUITION` | Intuition | Soul Gauge/Breath ceiling and base fizzle reduction. `../dramgid-mono/04-world/systems/character-creation.md:31-36` |
| `ATTR.DECORUM` | Decorum | Consonance, Name-Ledger effectiveness, social leverage, and rising/positive Yothmeru volatility. `../dramgid-mono/04-world/systems/character-creation.md:31-36` |

The `ATTR.*` identifiers are defined by imported proposed RFC-0004; Accepted RFC-0001 supplies the corrected roles and names. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:71-114` `../dramgid-mono/00-governance/rfcs/games/soul-meter/RFC-0001-dramgid-attribute-rename.md:60-70`

### The 22-skill set named by the imported DRAMGID RFCs

Imported RFC-0004 defines 18 proposed skills; imported RFC-0005 adds four and publishes the only located 22-row table, while both files remain `status: proposed`. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:1-20` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:1-20` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:167-192`

| ID | Name | Governing attribute | Stated gate/equivalent |
|---|---|---|---|
| `SKILL.STRAIN` | Strain | Muster | Athletics; physical, not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:150-153` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:169-172` |
| `SKILL.LILT` | Lilt | Alacrity | Acrobatics; physical, not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:150-154` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:169-173` |
| `SKILL.SLIP` | Slip | Alacrity | Sleight of Hand; physical, not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:150-155` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:169-174` |
| `SKILL.TREAD` | Tread | Alacrity | Stealth; physical, not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:150-156` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:169-175` |
| `SKILL.BEASTBOND` | Beastbond | Intuition | Animal Handling; labeled Body skill and not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:160-163` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:169-176` |
| `SKILL.VARLORE` | Varlore | Reason | Arcana; fully Loom-sensitive because it directly concerns magic. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:156-157` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:176` |
| `SKILL.UNWEAVE` | Unweave | Reason | Investigation/forensic reading of a working; fully Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:157-159` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:177` |
| `SKILL.RECALL` | Recall | Reason | History/factual recall; not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:156-158` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:178` |
| `SKILL.WILDLORE` | Wildlore | Reason | Nature; partially Loom-sensitive with a Pozor exception. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:158-160` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:179` |
| `SKILL.DEVOTION` | Devotion | Reason | Religion; partial Loom sensitivity is explicitly unsettled. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:159-161` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:180,194` |
| `SKILL.UNDERTONE` | Undertone | Intuition | Insight; fully Loom-sensitive and can misread Zhem-tainted targets. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:161-163` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:181` |
| `SKILL.MENDING` | Mending | Intuition | Medicine/physical healing; not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:162-164` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:182` |
| `SKILL.EAR` | Ear | Intuition | Perception/passive Aftertone or signature detection; partially Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:163-165` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:183` |
| `SKILL.WAYFINDING` | Wayfinding | Intuition | Survival; partially Loom-sensitive with a Pozor exception. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:164-166` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:184` |
| `SKILL.SOUNDING` | Sounding | Intuition | Replaces Weft-Sensing; reads Integrity/fizzle risk and is fully Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:118-134` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:185` |
| `SKILL.FALSETTO` | Falsetto | Decorum | Deception; not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:165-167` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:186` |
| `SKILL.BELLOW` | Bellow | Decorum | Intimidation; receives the negative-Karma tier bonus and is not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:166-168` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:187` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0007-yothmeru-reputation.md:176-186` |
| `SKILL.VARUM` | Vārum | Decorum | Performance; a received public performance shifts Fame; not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:167-169` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:188` |
| `SKILL.SWAY` | Sway | Decorum | Persuasion; receives the positive-Karma tier bonus and is not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:168-169` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:189` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0007-yothmeru-reputation.md:176-186` |
| `SKILL.DOWNBEAT` | Downbeat | Decorum | Conducting; banks +1 Tempo or at Expert+ absorbs part of an off-line switch’s Tempo cost. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:129-137` |
| `SKILL.BRACE` | Brace | Grit | Composure; reduces ally Discord damage and at Expert+ can suppress a Discord signature for a round. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:129-139` |
| `SKILL.VANTAGE` | Vantage | Reason | Tactics; battlefield reads, formations, and enemy-pattern prediction; not Loom-sensitive. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:129-139` |

### Resolution, advancement, derived values, classes, peoples, and Yothmeru

| Topic | Stated fact |
|---|---|
| Point buy | Seven attributes start at 2, sum to 22, cap at 5 at creation, and rise only through play. `../dramgid-mono/04-world/systems/character-creation.md:38-44` |
| Accepted skill resolution | The accepted character file instead names 12 skills; checks are d100 roll-under with `effective% = attribute × 8 + tier + advancement + situation`, tier bonuses 0/+20/+35, and Expert gives one failed-check reroll per scene. `../dramgid-mono/04-world/systems/character-creation.md:63-86` |
| Skill advancement | Each +5% costs 1 point through 50%, 2 through 75%, and 3 through 95%; Mirror Rewriting refunds skill advancement once per chapter without changing ancestry, patron, background, or Mastery. `../dramgid-mono/04-world/systems/character-creation.md:88-98` |
| HP / Breath / initiative / carry / to-hit | Grit, Intuition, Reason, Muster, and Alacrity respectively govern these values or concepts, but this source gives no numeric formulas for them. `../dramgid-mono/04-world/systems/character-creation.md:31-44` |
| Fizzle | Magic specifies `(100-integrity + breadth + strain) × magnitude − pitch_reduction − mastery_reduction + relation`, clamped 0–95; `pitch_reduction` is 2 per Pitch above 2. `../dramgid-mono/04-world/systems/magic-system.md:51-63` |
| XP/levels | No XP curve is stated in the located spec; only point-buy “at level” is specified. `../dramgid-mono/04-world/systems/character-creation.md:88-93` |
| Class perks | The patron-class source defines ten Kit/Resource/Signature packages but contains no class perk lists. `../dramgid-mono/04-world/systems/ten-patron-classes.md:13-17` `../dramgid-mono/04-world/systems/ten-patron-classes.md:19-96` |
| Classes | Mirrorblade/Maiiam, River-Mother/Haeren, Ironbrand/Kero, Lensbearer/Stuid, Husk-bearer/Vhorr, Flamebinder/Vicoar, Stormbearer/Ofshütje, Oathclock/Pazzah, Locksmirk/Fickah, and Threadwalker/Izhakel are the ten listed patron classes. `../dramgid-mono/04-world/systems/ten-patron-classes.md:19-96` |
| Peoples with stated leanings | Kaan Muster/Grit; Vael balanced; Ghorr Muster/Grit; Vaerin Reason/Intuition; Weftkin Intuition/Decorum; Shimari Reason/Decorum; Fiel Alacrity/Reason; Kes’reth Decorum/Grit. Their listed traits include vulnerabilities, bonuses, access, training, or one encounter ability rather than quantified attribute deltas. `../dramgid-mono/04-world/systems/character-creation.md:129-145` |
| Peoples still unstatted | The source says the full roster is about 20 playable peoples, but only the listed subset has leanings; Soul Meter scopes its initial roster to Vael, Kaan, Vaerin, Weftkin, and Kes’reth. `../dramgid-mono/04-world/systems/character-creation.md:155-162` |
| Yothmeru axes | Karma is signed −1000..1000 in seven tiers from Damned to Exalted; Fame is unsigned 0..1000 in five tiers from Unknown to Legendary and is independent of Karma’s sign. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0007-yothmeru-reputation.md:83-109` |
| Yothmeru shifts | `karma_shift = base × Doctrine/10`; `fame_shift = abs(base) × witness_factor × Decorum/10`; 10 is the neutral 1× baseline. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0007-yothmeru-reputation.md:123-132` |
| Yothmeru decay | Only Damned, Exalted, and Legendary decay toward their nearest tier boundary; all other tiers persist. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0007-yothmeru-reputation.md:160-171` |

## 3. Current six-stat build — migration surfaces

| Surface | Symbol/range and current stat behavior |
|---|---|
| Chargen data | `ATTRIBUTE_IDS`, labels, hints, domains use Forge/Edge/Anchor/Spark/Pitch/Voice; floor 2, cap 5, budget 20; 12 old skill IDs/labels follow. `globals/chargen_data.gd:12-58` |
| Chargen data content | Five ancestry entries expose unquantified old-stat leanings; backgrounds train old skill IDs; helper API supplies defaults, validation, remaining points, labels, and skill previews. `globals/chargen_data.gd:59-130` `globals/chargen_data.gd:191-272` |
| Chargen scene/script | `character_creation.tscn` attaches the wizard; `_build_attributes_page`, `_build_attribute_row`, `_build_skills_page`, `_on_attribute_step`, `_refresh_all`, `_summary_text`, `_step_is_valid`, and `_build_member` construct/validate/display/store the old stats. `ui/screens/character_creation.tscn:1-8` `ui/screens/character_creation.gd:272-369` `ui/screens/character_creation.gd:605-694` `ui/screens/character_creation.gd:740-754` `ui/screens/character_creation.gd:850-889` |
| Chargen support | `chargen_art_resolver.gd` resolves presentation art only and contains no stat model. `ui/screens/chargen/chargen_art_resolver.gd:1-82` |
| `PartyMember` | Stores level/advancement, HP, Breath, attack/defense, `attributes`, skill percentages/tiers, and recruitment thresholds; `to_dict`/`from_dict` persist them. `globals/party_member.gd:31-53` `globals/party_member.gd:56-120` |
| `BattleActor` | Stores combat HP/attack/defense/Breath plus an attribute dictionary; `attribute_value` and `combat_stat` expose it. `globals/battle_actor.gd:12-24` `globals/battle_actor.gd:99-124` |
| `UnitRoster*` | Only `globals/units/unit_roster.gd` plus its UID exist; it persists unit definitions, attunements, loadouts, and progression through `to_dict`/`from_dict`, with no direct attribute schema. `globals/units/unit_roster.gd:5-16` `globals/units/unit_roster.gd:55-148` |
| `SkillCheck` definitions/API | Twelve definitions govern on old attributes; public API is `preview` 52–75, `effective_percent` 77–85, `resolve` 87–126, `recent_checks` 128–131, `last_check_succeeded` 133–141, `check` 143–145, `reset_scene_rerolls` 147–152, `to_dict` 154–156, `from_dict` 158–161, `normalize_save_data` 163–193, `fizzle_percent` 195–230, `location_fizzle_integrity` 232–235, and `calculate_fizzle` 237–247. `globals/skill_check.gd:10-35` `globals/skill_check.gd:52-247` |
| `SkillCheck` dialogue callers | `council_elder` and `lower_trial_hall` each resolve/check success; `dom_side_quests` does so for ten branches across eight old skills. `dialogue/council_elder.dialogue:8-9` `dialogue/lower_trial_hall.dialogue:5-40` `dialogue/dom_side_quests.dialogue:15-412` |
| `SkillCheck` runtime callers | Advancement preview; Battle integrity/resolve/lore preview; combat/dialogue labs RNG state; SaveGame state; survival encounter preview. `globals/advancement.gd:35` `globals/battle.gd:163-832` `globals/combat_lab.gd:388-736` `globals/dialogue_lab.gd:256-278` `globals/save_game.gd:241-596` `globals/travel/encounter_director.gd:51` |
| `SkillCheck` UI/tool callers | Character sheet previews and history; casting sweep names fizzle; quest audit searches dialogue calls. `ui/screens/character_sheet.gd:153-198` `tools/casting_economy_sweep.gd:8` `tools/quest_audit.gd:1100` |
| `SkillCheck` documentation callers | Casting economy, combat/dialogue labs, dialogue-check example, fleet roadmap, extraction audit, acceptance evidence, and location template reference the service. `docs/casting-economy.md:176` `docs/combat-lab.md:61` `docs/dialogue-checks.md:28-29` `docs/dialogue-lab.md:41` `docs/fleet-roadmap.md:43-45` `docs/pipeline/skill-extraction-audit-2026-08-06.md:25` `docs/qa/wave3-acceptance-evidence.md:13-15` `docs/templates/location.md:32` |
| `SkillCheck` test callers | E2E first journey; character sheet/combat controller/lower hall/travel integrations; advancement, combat/dialogue labs, dialogue checks, living-world texture, manual slots, quest editor, save game, and skill-check units. `test/e2e/test_first_chapter_journey.gd:159-541` `test/integration/test_character_sheet.gd:86` `test/integration/test_combat_controller.gd:544-581` `test/integration/test_lower_trial_hall.gd:14-91` `test/integration/test_travel_flow.gd:25-69` `test/unit/test_advancement.gd:54` `test/unit/test_combat_lab.gd:34-174` `test/unit/test_dialogue_checks.gd:15-343` `test/unit/test_dialogue_lab.gd:15-313` `test/unit/test_living_world_texture.gd:113-122` `test/unit/test_manual_slots.gd:25-46` `test/unit/test_quest_editor.gd:561-572` `test/unit/test_save_game.gd:24-144` `test/unit/test_skill_check.gd:133-148` |
| Resolution/controller | `Resolution` reads attacker/target Edge for to-hit and a Pitch fizzle input; `CombatController.calculate_damage` supplies Edge, `_fizzle_context` supplies Pitch, and resolution writes update Breath. `globals/combat/resolution.gd:19-29` `globals/combat/resolution.gd:544-567` `globals/combat/combat_controller.gd:650-712` `globals/combat/combat_controller.gd:1236-1246` `globals/combat/combat_controller.gd:1299-1364` |
| Combat rules | Both AP and CT speed derive from Edge; charge speed is `base + Edge/divisor` under configured clamps. `globals/combat/combat_rules.gd:6-10` `globals/combat/combat_rules.gd:31-37` `globals/combat/combat_rules.gd:58-71` |
| Class resources | No class resource directly reads the six-attribute dictionary; Haeren observes HP/death writes, Maiiam overrides `attack_scale`, and Vicoar can force fizzle to 0%. `globals/combat/class_resources/haeren_name_ledger.gd:36-48` `globals/combat/class_resources/maiiam_balance.gd:25-34` `globals/combat/class_resources/vicoar_instructive_failure.gd:24-30` |
| `Renown` | Independent append-only reputation/infamy totals expose `gain_reputation`, `gain_infamy`, totals, `why`, `history`, `to_dict`, and `from_dict`; tavern recruitment consumes the totals. `globals/renown.gd:1-14` `globals/renown.gd:26-63` `globals/renown.gd:92-116` `ui/screens/tavern.gd:139-145` |
| `Reputation` | Faction ledger bands are hostile/cold/neutral/warm/allied at −40/−15/15/40, exposed by `band` and `band_at_least`; gates occur in doors, dialogue, reactions, encounters, vendors, flow, chapter/standing UI. `globals/reputation.gd:18-34` `globals/reputation.gd:75-104` `actors/building_door/building_door.gd:128` `dialogue/dom_townsfolk.dialogue:62-254` `dialogue/hadrik_vale.dialogue:19-22` `dialogue/iris_illepah.dialogue:29` `dialogue/sella_varn.dialogue:26-29` `dialogue/toma_reedhand.dialogue:17-20` `globals/npc_reactions.gd:85` `globals/travel/encounter_director.gd:79` `globals/vendor_registry.gd:46` `ui/flow/game_flow.gd:347` `ui/screens/chapter_complete.gd:80-81` `ui/screens/standing.gd:84-108` |
| Save migration/stat keys | Current schema is 7; PartyMember rows carry `attributes`, `skill_percentages`, `skill_tiers`, HP, Breath, attack/defense, level, and advancement points. `globals/save_migrations.gd:5-6` `globals/party_member.gd:56-84` |
| Pandora Classes | Properties are Display Name, Patron, Resource Name, Vault Id; there are no perk or stat properties. `tools/seed_pandora.gd:92-116` |
| Pandora Peoples | Properties are Display Name, Analogue, Homeland, Vault Id; there are no leaning/modifier properties. `tools/seed_pandora.gd:122-145` |
| Pandora Combatants | Properties include Max HP, Attack, Defense, and only one legacy attribute, Edge; seeded enemies carry that ninth value. `tools/seed_pandora.gd:478-506` |
| Encounter loader | `ENEMY_FIELDS` requires `max_hp`, `attack`, `defense`, and `edge` alongside identity/balance/element data. `globals/campaign_encounter_loader.gd:5-16` |
| Generated stat data | `encounters.json` repeats `max_hp`/attack/defense/Edge enemy blocks; `combat_identity.json` uses attack/defense effect and resistance stat keys. `data/generated/encounters.json:29-35` `data/generated/encounters.json:111-739` `data/generated/combat_identity.json:75-306` |
| Dialogue stat conditions | Production dialogue has no direct six-attribute comparison; its stat gates are the `SkillCheck.resolve`/`last_check_succeeded` pairs listed above. `dialogue/council_elder.dialogue:8-9` `dialogue/dom_side_quests.dialogue:15-412` `dialogue/lower_trial_hall.dialogue:5-40` |
| Test reference counts | Legacy-ID line counts are Forge 15, Edge 40, Anchor 29, Spark 27, Pitch 24, Voice 12 across `test/`; the densest direct fixture is the six-stat chargen suite. `test/unit/test_chargen_data.gd:14-65` |

## 4. Player-facing attribute and skill strings

| Surface | Strings |
|---|---|
| Chargen source | Attribute labels/hints name all six old attributes; skill labels name Athletics, Stealth, Sleight of Hand, Beast Handling, Lore, Survival, Investigation, Alchemy, Persuasion, Weft-Sensing, Performance, Insight. `globals/chargen_data.gd:14-28` `globals/chargen_data.gd:45-58` |
| Chargen display | The wizard says “Distribute the sanctioned twenty points; no measure may exceed five,” renders dynamic attribute labels/hints and skill percentages, and summarizes all attribute labels. `ui/screens/character_creation.gd:272-369` `ui/screens/character_creation.gd:633-694` |
| Character sheet | The sheet iterates the same attribute IDs/labels and skill IDs/labels, displaying effective percentages from `SkillCheck.preview`. `ui/screens/character_sheet.gd:114-163` |
| POT | The only `Forge` POT entries are the item localization keys for “Forge Hammer,” not an attribute label; no attribute/skill label entries are present there. `data/generated/items.pot:200-209` |

## 5. Save-schema history

| Version | Contents/change | Migration |
|---|---|---|
| 1 | Unsupported: versions below legacy schema 2 are refused; no v1 migration exists. `globals/save_migrations.gd:5-6` `globals/save_migrations.gd:21-22` |
| 2 | Oldest accepted legacy envelope; may use `version` in place of `schema_version`. `globals/save_migrations.gd:25-26` `globals/save_migrations.gd:42-49` |
| 3 | Adds `game_state.skills`, `var_harmony`, top-level `zhavar`, normalized `ng_plus`, and stable-ID schema manifest. `_migrate_v2_to_v3`. `globals/save_migrations.gd:52-63` |
| 4 | Adds `game_state.combat_knowledge`. `_migrate_v3_to_v4`. `globals/save_migrations.gd:66-73` |
| 5 | Adds vendor stock/restock cycles and refreshes stable-ID manifest. `_migrate_v4_to_v5`. `globals/save_migrations.gd:76-87` |
| 6 | Adds top-level tactical per-unit state derived from party rows and persisted Expert-reroll usage under `skill_check`. `_migrate_v5_to_v6`. `globals/save_migrations.gd:90-114` |
| 7 | Adds top-level `world_clock`; adds `breath_max`/`breath` defaults to party and custom-recruit rows. `_migrate_v6_to_v7`; it does not add the already-serialized `attributes`/skill dictionaries. `globals/save_migrations.gd:117-138` `globals/party_member.gd:70-82` |

## 6. Sibling references

```text
(no DRAMGID attribute/skill implementation paths found under petalkeep, hexgame, squadtactics, dayinthelife-godot, idyllicdram, or site-k)
```

## 7. Contradictions and gaps

- Ratified Soul Meter identity requires 22 skills, but the Accepted mono character-creation source explicitly ratifies twelve. `docs/game-identity.md:18-19` `../dramgid-mono/04-world/systems/character-creation.md:63-72`
- The only located 22-row skill table is in imported RFC-0005 with `status: proposed`; Accepted RFC-0001 says it supersedes imported RFC-0004/0005. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:1-20` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0005-dramgid-absorbs-legacy-attributes.md:167-194` `../dramgid-mono/00-governance/rfcs/games/soul-meter/RFC-0001-dramgid-attribute-rename.md:9-12`
- The vault character source still states six attributes and a 20-point buy, while mono states seven DRAMGID attributes and a 22-point buy. `../dramgid-vault/systems/character-creation.md:23-38` `../dramgid-mono/04-world/systems/character-creation.md:23-40`
- Accepted DRAMGID assigns base fizzle reduction to Intuition, while both magic-system copies still name `pitch_reduction` and Pitch. `../dramgid-mono/04-world/systems/character-creation.md:31-36` `../dramgid-mono/04-world/systems/magic-system.md:51-63` `../dramgid-vault/systems/magic-system.md:51-63`
- Imported RFC-0004 describes Doctrine/Decorum as Soul-Gauge volatility, while Accepted RFC-0001 corrects the target to Yothmeru. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:80-90` `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0004-dramgid-attributes-skills.md:111-122` `../dramgid-mono/00-governance/rfcs/games/soul-meter/RFC-0001-dramgid-attribute-rename.md:51-58`
- Yothmeru specifies separate signed Karma and unsigned Fame axes; current `Renown` instead stores reputation and infamy totals, and no Karma field exists in that API. `../dramgid-mono/00-governance/rfcs/imports/ledger/RFC-0007-yothmeru-reputation.md:83-113` `globals/renown.gd:18-44`
- Ratified identity says XP comes from combat and quests, while current advancement says levels come from authored story milestones and never kill/use XP. `docs/game-identity.md:37-38` `globals/advancement.gd:12-13`
- Perk cadence and the Chapter 1 level cap are explicitly open. `docs/game-identity.md:43-46`
- No patron class perk lists are present: the class source stops at Kit/Resource/Signature identities, while identity requires perk lists. `../dramgid-mono/04-world/systems/ten-patron-classes.md:13-17` `../dramgid-mono/04-world/systems/ten-patron-classes.md:19-96` `docs/game-identity.md:19`
- HP, Breath ceiling, initiative/CT, carry, and to-hit have governing attributes but no DRAMGID numeric formulas in the accepted character source. `../dramgid-mono/04-world/systems/character-creation.md:31-44`
- Peoples’ “leanings” are described as nudges but have no numeric modifier rule, and roughly twelve of the ~20 peoples lack even named leanings. `../dramgid-mono/04-world/systems/character-creation.md:129-160`
- Ship plan calls DRAMGID’s implementation gate “save schema 7,” but schema 7 is already current and contains world-clock/Breath migration rather than DRAMGID migration. `docs/ship-plan-2026-10.md:62-64` `globals/save_migrations.gd:5-6` `globals/save_migrations.gd:117-138`
- Pandora has no perk fields on Classes, no stat-leaning/modifier fields on Peoples, and only Edge rather than a complete attribute set on Combatants. `tools/seed_pandora.gd:92-116` `tools/seed_pandora.gd:122-145` `tools/seed_pandora.gd:478-506`
- Current combat derives AP/CT speed and to-hit from Edge, while DRAMGID assigns initiative to Reason and accuracy/evasion to Alacrity. `globals/combat/combat_rules.gd:6-10` `globals/combat/combat_rules.gd:31-37` `globals/combat/resolution.gd:23-28` `../dramgid-mono/04-world/systems/character-creation.md:31-36`

## 8. Numbers Claude will need

| Area | Current constants/formula |
|---|---|
| Old chargen | Floor 2, cap 5, budget 20 across six attributes; new accepted spec says floor 2, cap 5, budget 22 across seven. `globals/chargen_data.gd:36-41` `../dramgid-mono/04-world/systems/character-creation.md:38-40` |
| Skill checks | Effective cap 95; roll 1–100; one Expert reroll; attribute multiplier 8; tier bonuses 0/20/35. `globals/skill_check.gd:10-14` `globals/skill_check.gd:17-35` `globals/skill_check.gd:52-73` |
| Advancement | 3 points/level; +5% steps; cap 95; costs 1 through 50, 2 through 75, 3 through 95. `globals/advancement.gd:22-29` |
| Current derived chargen | `max_hp = Anchor × 8`; attack = Forge; defense = Edge; current base Breath maximum is a fixed provisional 15. `ui/screens/character_creation.gd:886-889` `globals/party_member.gd:5-7` |
| Breath costs | Note 3, Phrase 6, Song 12, Refrain 24. `globals/jobs/ability_definition.gd:21-26` |
| Fizzle table | Breadth Tone/Chord/Triad = 0/5/12; strain steps 0..4 = 0/0/6/12/18; magnitude Note/Phrase/Song/Refrain = ×0.5/1/1.75/2.75. `globals/default_fizzle_table.tres:9-25` |
| Fizzle stat terms | Base is `100 − integrity`; Pitch reduction is `max(Pitch−2,0) × 2`; Note/Phrase Mastery reduction is 100; overall cap 95; Fickah/Locksmirk floor 5; thinning penalty is 5 integrity/tier. `globals/skill_check.gd:10-15` `globals/skill_check.gd:195-229` |
| To-hit | Height damage +10%/step; facing front/side/back damage ×1/1.1/1.25 and hit +0/+8/+15; hit base 70, height +4/step, Edge difference +2/point, clamp 5–95. `globals/combat/resolution.gd:10-29` |
| AP | Base 4; Edge per 2 points; min 2, max 8; context-resolution cost 2; cover defense +2; flank power +2. `globals/combat/combat_rules.gd:6-13` |
| CT | Ready at 100; 16 ticks/measure; speed `6 + Edge/2`, clamped 1–30; 15 CT/AP fallback, move 20, action 30–60. `globals/combat/turn_scheduler.gd:22-24` `globals/combat/combat_rules.gd:31-44` `globals/combat/combat_rules.gd:68-83` |
| Wait/cancel | Wait discards overflow then sets CT to floor(Ready/2) = 50; at most two consecutive waits; cancellation refund ratio defaults to 1.0. `globals/combat/charge_time_scheduler.gd:270-298` `globals/combat/charge_time_scheduler.gd:321-337` `globals/combat/combat_rules.gd:45-46` |
