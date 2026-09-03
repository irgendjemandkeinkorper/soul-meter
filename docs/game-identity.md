# Game identity — playstyle and function

Status: RATIFIED 2026-09-02 (owner, ten-question pass). Sits above `soul-meter-crpg-design-doc.md`
and `docs/prd-chapter-one.md`; where an older doc conflicts, this file wins until that doc is
revised. Each ruling names its target: **identity**, **function**, or **design**.

## The ten rulings

| # | Target | Ruling |
|---|---|---|
| 1 | identity | **Soul-as-currency.** The hook: every meaningful act spends a piece of your soul and the world keeps a ledger. Combat and quests exist to make spending hurt. |
| 2 | function | **Empty Soul = hollowing, not death.** Zero is a state: lost dialogue options, companion reactions, NPCs read you as Waning-touched. Recoverable only at a price. Never a game-over. |
| 3 | design | **Soul returns only through acts of Agreement** (promises kept, companion quests resolved well, places re-Agreed). Never rest, never potions. The meter trends down across a chapter. |
| 4 | function | **Combat is the tactical centerpiece.** Fights are frequent and deep. Soul is one resource among several in battle; grid mastery is its own reward. |
| 5 | design | **Fallout 2 lineage, not FFT.** Party of 4–6 on the map; up to ~100 hostile mobs on a map at once. Turn-based tactical combat, not squad-tactics. |
| 6 | function | **Same-map combat.** Combat mode toggles on the field scene. No deployment for ambient fights; off-screen mobs join the CT order when alerted. Deployment survives only for scripted set-pieces. |
| 7 | design | **Fallout-full field game.** Skill checks on objects, lockpicking, stealing, barter, loot. Stats matter outside combat. |
| 8 | function | **Class = identity, DRAMGID = what you can DO.** Patron class grants unique abilities and functions; DRAMGID attributes + the 22 skills decide what you do with them. A warrior may invest in academic skills and keep weaker class abilities. DRAMGID (Doctrine, Reason, Alacrity, Muster, Grit, Intuition, Decorum) replaces SPECIAL and the old six-stat build; source: dramgid-mono RFC-0001 + `04-world/systems/character-creation.md`, Yothmeru Karma/Fame. |
| 9 | design | **Progression = XP levels + skill points + class perks.** Fallout skeleton: skill points into the 22 skills, a perk every N levels from patron-class lists, attributes fixed at creation (22-point buy) except rare story boosts. A few perks gate on Karma/Fame bands. |
| 10 | identity | **Tone: elegiac and wry.** Dying world, gallows humor from companions, Soul spend felt as loss rather than punished as failure. Grounded, consequential violence. |

## What this changes in the build (owner-visible consequences)

- **Battle stage (ruling 6) is the largest architectural shift.** Today battle is an overlay with a
  separate grid battlefield and deployment chart states. Same-map combat means the field scene's
  tiles become the battle grid, the CT scheduler admits actors on alert, and deployment becomes a
  set-piece-only path. #211 (battle stage presentation) and D4 (`battle.gd` unification) are
  re-scoped under this ruling.
- **Scale (ruling 5): ~100 mobs.** #175 performance floor becomes a hard gate; AI turn batching,
  off-screen actor skipping, and the six-region interface at that unit count need a design pass.
- **DRAMGID migration (ruling 8).** The build still runs the old six-stat system. Migration is a
  save-schema bump plus chargen wizard, Pandora columns, skill-check service, and dialogue
  condition rewrites. Yothmeru (Karma/Fame) maps onto the existing `Renown` ledger: Karma is not
  `Reputation`, and Fame is `Renown.reputation`/`infamy` scaled by Decorum.
- **Field skills (ruling 7).** New interactable kinds (locked container, pickpocketable NPC, barter
  screen) checked against the 22 skills; Loom-sensitive skills degrade in Hush/Waning zones.
- **Progression (ruling 9).** XP source is combat + quests; perk lists per patron class are new
  Pandora data.
- **Hollowing (ruling 2)** is a Soul band with its own dialogue conditions and companion barks.
  Soul income (ruling 3) is the quest system's job: `acts of Agreement` become a tagged quest
  outcome that credits the gauge.

## Open questions (not resolved here; do not resolve silently)

- Perk cadence (every 3 levels?) and Chapter 1 level cap.
- Which of the 22 skills the Chapter 1 content actually checks (minimum viable set).
- Whether ambient same-map fights can be fled by leaving the alert radius (Fallout allows it).
- Loot density target for a Fallout-full field game in a world with a Mirror Shop.
