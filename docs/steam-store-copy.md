# Steam store copy — Soul Meter, Chapter 1

Ship issue: **#303** (S9). This document is the *copy* half only. The issue assigns the
other two halves to the owner: **the capsule** (via the S2 prompt bible, #296) and
**five screenshots** from the round-1 playtest build. Neither is drafted here.

Tone follows `docs/game-identity.md` ruling 10 — **elegiac and wry**. Scope follows
`docs/ship-plan-2026-10.md`: a complete Chapter 1 of roughly **6–8 hours**, sold as a paid
episodic release, gold **2026-10-02**. §7 is a claims ledger: every factual sentence below,
what backs it, and whether it depends on work that has not landed.

---

## 1. Name and tagline

**Soul Meter**

> *A dying world keeps a ledger.*

Alternate taglines, in order of preference:

1. *A dying world keeps a ledger.*
2. *Everything that matters costs something you cannot buy back.*
3. *Spend carefully. It is not a resource. It is you.*

## 2. Short description

Steam's limit is **300 characters**. Primary:

> A dying world keeps a ledger, and every choice that matters is paid for out of your own
> soul. Turn-based tactical combat, a party of misfits, and consequences that outlive the
> conversation. Chapter One of the Dramgid Cycle.

Backup, if the primary reads too grim on a store row:

> Your soul is the currency. Spending it opens doors, ends arguments, and wins fights — and
> it only comes back when you keep a promise. A tactical CRPG about what you are willing to
> lose. Chapter One.

## 3. About This Game

Steam BBCode. Paste as-is.

```
[h2]The ledger is always open[/h2]

Dom, the City of the Four Arms, is still standing. That is the most anyone will claim for it.

You arrive with a soul and a reputation, and the city will spend both. Every choice that
carries weight — the lie that holds, the door that opens, the word that stops a fight before
it starts — is paid for out of the same meter. It does not refill when you sleep. It does not
refill when you drink. It comes back exactly once: when you keep a promise, and someone alive
is there to see it kept.

Run it to empty and you do not die. You hollow. Doors that were open close. Companions begin
choosing their words carefully around you. Strangers read you as Waning-touched before you
speak. It is a state, not a game over, and you can come back from it — at a price, like
everything else here.

[h2]Combat you have to be present for[/h2]

Fights happen where you are standing. No loading screen, no deployment grid, no separate
arena — the field becomes the battlefield, the party takes its turns, and everything on the
map that heard you is already on its way. A party of up to six against a map that can hold a
hundred.

Positioning matters. Terrain matters. So does the weather, and so does how thin the world has
worn where you are standing: cast a big enough working near the front and it may simply fail,
because there is not enough agreement left in the ground to hold it.

[h2]Ten patrons, seven attributes, twenty-two skills[/h2]

Your patron class is who you are — an Ironbrand banks scars and spends them for a certain
strike; a Lensbearer burns clarity to see a forecast honestly; a Threadwalker binds contracts
nobody else can see. What you can actually DO is yours to build: seven attributes at
character creation, twenty-two skills, and a perk list per class. A soldier who put her points
into archives is a perfectly good soldier who can also read a Registry ledger.

Skills are not combat-only. They open locks, price goods, calm arguments, read rooms, and lie
to clerks.

[h2]Two ledgers, and neither one forgets[/h2]

Sixty factions keep standing on you, separately. The world keeps a second, blunter record of
what you are famous and infamous for. Both are append-only: the game can always tell you
exactly which act moved a number and where it happened.

Standing changes prices. It changes which recruits will sit at your table. It changes whether
a Sentinel toll keeper reads you a line out of the Wound-Watch ledger or watches you walk past.

[h2]A party you have to earn[/h2]

Twenty recruits drink in the Four Arms. Six of them will tell you what they actually want, and
each of those has a quest of their own that ends somewhere you chose. They have opinions about
your ledger. They will say so.

[h2]Chapter One[/h2]

This is a complete Chapter One of the Dramgid Cycle — a first act with its own ending, in a
world with a great deal more of it left. Later chapters and the remaining side quests arrive
as free updates.

[h2]Features[/h2]

[list]
[*] Soul as a spendable currency, restored only by acts of Agreement
[*] Hollowing as a survivable state instead of a failure screen
[*] Same-map turn-based tactical combat, a party of up to six
[*] Ten patron classes, seven attributes, twenty-two skills, class perks
[*] Two independent consequence ledgers across sixty factions
[*] Twenty recruits; six with full personal quests
[*] Three hubs and eight locations across one region, with fast travel
[*] New Game Plus that remembers
[/list]
```

## 4. Feature bullets (short form, for the capsule and press)

- Your soul is the currency. It only comes back when you keep a promise.
- Empty is a *state*, not a death. The world reads it on you.
- Same-map tactical combat: no arena, no deployment, no escape hatch.
- Sixty factions, two ledgers, and a game that can name the act that moved each one.

## 5. Tags and genres

**Genres:** RPG, Strategy, Indie

**Suggested tags**, most defensible first:

`Turn-Based Tactics` · `CRPG` · `Story Rich` · `Choices Matter` · `Isometric` · `Party-Based
RPG` · `Dark Fantasy` · `Tactical RPG` · `Singleplayer` · `Turn-Based Combat` · `Character
Customization` · `Multiple Endings` · `Grid-Based Movement` · `Atmospheric` · `Dialogue System`

Deliberately **not** used: `Roguelike`, `Open World`, `Souls-like`. The last one would draw
exactly the wrong audience for a game whose "soul" is a dialogue currency.

## 6. Store fields the owner still has to fill

| field | status |
|---|---|
| Capsule art (all sizes) | **owner** — S2 prompt bible (#296), per #303 |
| 5 screenshots | **owner** — from the round-1 playtest build, per #303 |
| Trailer | not scoped in #303 |
| System requirements | **owner** — needs real numbers from the FR-904 runbook (`docs/fr-904-runbook.md`) on target hardware; no figure is drafted here rather than invent one |
| Price | **owner** |
| Mature content descriptor | draft: "Frequent violence with lasting consequences; themes of loss, decay, and coerced sacrifice. No sexual content." |
| Release date | 2026-10-02 gold per `docs/ship-plan-2026-10.md` |

## 7. Claims ledger

Every factual claim in §2–§4, what backs it, and whether it is safe to publish today.

| claim | evidence | safe now? |
|---|---|---|
| Soul is spent by meaningful choices | `GameState` Soul Meter; dialogue `[#cost=-6 soul]` tags | yes |
| Soul returns only through acts of Agreement | `docs/game-identity.md` ruling 3; `quests/dom_living_tag.tres` `act_of_agreement` | yes |
| Empty = hollowing, not death | ruling 2; `GameState.HUSKED_FLAG`, `NpcReactions` hollowing rules, companion barks | yes |
| Same-map combat, no deployment for ambient fights | ruling 6 | **depends on #281 (F1)** — do not publish before it merges |
| Party of up to six | ruling 5 | yes |
| A map can hold ~100 hostiles | ruling 5 | **depends on #282 (F2, the 100-mob floor)** |
| Ten patron classes with signature resources | `globals/combat/class_resources/` — all ten shipped | yes |
| Seven attributes, twenty-two skills | `globals/stats/dramgid_schema.gd` | yes |
| Class perks | ruling 9 | **depends on #285 (F5 progression)** |
| Skills work outside combat | ruling 7 | **depends on #284 (F4 field verbs)** |
| Sixty factions | lore vault `factions/` (60) | yes |
| Two append-only ledgers that can name the cause | `globals/reputation.gd`, `globals/renown.gd` | yes |
| Standing changes prices and recruits | `ui/screens/shop.gd`, `GameState.recruitable_candidates()` | yes |
| A Sentinel reads you a Wound-Watch line at warm standing | `globals/npc_reactions.gd` `raika-toll` | **reachable but see #403** — the gate is authored and the faction can reach warm |
| Twenty recruits, six with personal quests | `ui/screens/tavern.gd`; FR-505 all six authored | yes |
| Weather and thinning affect casting | `Weather` + per-cell `TileState` (#209); `docs/thinning-gradient.md` | yes for weather; the per-location gradient **depends on #258** |
| Three hubs, eight locations | `docs/ship-plan-2026-10.md` cut line | **depends on #238–#241** — only 4 macro locations exist today |
| Fast travel | `globals/fast_travel_registry.gd`, `ui/screens/region_map.tscn` | yes |
| New Game Plus | `globals/ng_plus.gd` | yes |
| 6–8 hours | `docs/ship-plan-2026-10.md` lead's assessment 1 | yes — **and 20 h must never appear in store copy**; the owner called it a dream goal, not a gate |

**Six claims are not yet true.** They are all in the ratified gold scope, so the copy is
written for the build being shipped rather than the build that exists today — but the store
page must not go live ahead of #281, #282, #284, #285 and #238–#241. If any of those slips
past content lock, the matching line comes out of §3 and §4 before publish, not after.
