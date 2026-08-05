# SOUL METER (working title — "the measure of a soul")
### A consequence-driven RPG set in Era 3 of the Dramgid Cycle

**Design Document v0.2 — Draft for review**
Engine: Godot 4 (2D) · Solo developer · Canon source: *Dramgid Mythology Bible* + author rulings

> **Canon key:** **[CANON]** = from the bible or the author's direct statements. **[PROPOSAL]** = connective tissue invented for this doc — keep, kill, or rewrite freely.
>
> **Inspiration note:** Fallout 2 is the blueprint for *consequential storytelling only* — decisions rippling across storylines, a world that remembers. It is **not** the gameplay chassis. Witcher-style quest density and BG3-style temptation-progression are the other two lodestars. Moment-to-moment gameplay shape is an open decision (§6).

---

## 1. High Concept

A dialogue-and-consequence-first 2D RPG in the mature fantasy era of Dramgid. The races and gods are in full flower; pre-spore technology survives as half-understood relics — and the world is coming apart, because **Maiiam has been taken**.

The demons of **Agars Reys** and the undead armies of **Harem Stet** seize more land every season and threaten all life on Dramgid. **[CANON]** The player leaves home to stop an invasion and uncovers a layered conspiracy: the order-god hiding in the pantheon manufactured the chaos, a grieving madman leads the dead out of love, and devils are pulling strings behind them both. At the center of it all: a kidnapped goddess, fading — and a meter quietly measuring what the player's soul is made of.

### Design Pillars
1. **Consequence density over content breadth.** Fewer locations, deeply reactive. Every major choice is remembered somewhere else. (The Fallout 2 inheritance — the only one.)
2. **The world's myths are looking back at the truth.** The deep-lore layer (Styganix, QUINE, Baes) is buried under Era 3's religions — archaeology of theology.
3. **Everyone wears the wrong alignment.** The order-god allies with chaos; lawful devils back the shambling dead; the necromancer acts from love. A world with Balance removed *should* look like this.
4. **Power is temptation, and the meter is the bill.** Resonance abilities are desirable, escalating, and cost more than they say. The measure of a soul is literal.
5. **Solo-shippable.** One region, bounded systems, combat serviceable-not-deep in v1.

---

## 2. World State at Game Start

- **Maiiam was kidnapped by Kronos — and placed *outside spacetime*.** **[CANON]** Pazzah — the diminished Kronos, worshipped in plain sight as the Clockless Warden — re-imprisoned her beyond reality itself to regain control. His plan: throw the world into chaos so desperate devotees turn to his perfect, ordered universe. **[CANON]**
- **The imprisonment *is* the invasion.** **[CANON]** Forcing Balance outside spacetime tore the fabric of reality — and that rift/weakening is what allows the demons of Agars Reys to assault the world. The kidnapping and the war are one event with two symptoms. Ending logic follows the same metaphysic: RESTORE pulls her back *through* the wound (which seals as Balance re-enters); REDEFINE seals the wound by force *with her still outside* (why she dies); REPLACE closes the rift by becoming the Balance it lacks (why she dies). **[PROPOSAL framing of CANON facts]**
- **She has been *fading*, not vanished. [CANON-implied]** Harem Stet "lost his mind as she started fading from the world" — implying a gradual disappearance felt first by the most devoted, over a meaningful span (years?). Prayers thinned before they failed. This softly answers "how long": long enough for grief to curdle into doctrine. (Exact span: §10.)
- **Magic is fraying at the edges. [CANON-backed]** Reality's weakening radiates from the rift; "thinning" zones impose miscast risk and grow worse toward the fronts. The map's danger gradient is metaphysical — and it is *evidence*: an attentive player can read the thinning pattern as pointing at a single wound.
- **The two-front war, decoded [CANON structure]:**
  - **Agars Reys (demons) — Pazzah's open secret allies.** The order-god wields chaos as a sales pitch: he is in league with the demonic forces whose rampage he will one day "solve." **[CANON]** The principle of pure definition using flux as a tool — he was defeated by a question he couldn't answer, and he has learned. (Does using chaos change him? — §10.)
  - **Harem Stet (undead) — a man, not a nation.** A former devotee of Maiiam driven mad by her fading. He foresees an apocalypse "only the already dead could survive" — so he is *saving* people, by his lights, into undeath. **[CANON]** His war is a rescue operation run by grief.
  - **The devils — the string-pullers.** Lawful-evil forces working behind Harem Stet, a counterweight to the demons' chaos, hidden from the world and possibly from him. **[CANON]** Their motive **[PROPOSAL]**: a Kronos-locked universe ends free will — and no free will means no temptation, no contracts, no souls. They need Maiiam's messy world to exist; they intend to profit from the collapse in the meantime. Darker option: mass undeath *strips souls loose*, and they harvest what Harem Stet discards while he believes he is saving it.
- **Nobody's banner matches their nature.** Order allies with chaos; law serves evil quietly; the necromancer loves. Attentive players should be able to read this pattern by mid-game — it is the setting's thesis: *this is what a world looks like when Balance is removed.*

---

## 3. Story Spine (three acts)

### Act I — The Front Is Coming **[CANON inciting need]**
The player's home community lies in the path of the advance (which front — demons or undead — can be a character-creation choice that reskins Act I and sets initial reputations **[PROPOSAL]**). The community sends the player out for something concrete: reinforcements, a ward, an evacuation route, a weapon. Every lead half-works and reveals the same pattern: defenses that should hold don't, rites that should banish don't bite, and the priests are quietly terrified because *someone isn't answering*.

### Act II — The Missing God
The errand becomes an investigation, threading:
- **The Elvish insight-orders** — hoard the true history; know the most about the fading; gatekeepers of the deep-lore layer. **[CANON: Stuid's domain]**
- **The Dragonborn archives** — Styganix documents as sacred artifacts; pre-spore corporate files as dungeon loot; the names *QUINE*, *Site K*, *Baes Kuchnik*. **[CANON]**
- **The Tiefling mirror-mystics** — Maiiam's own; their mirrors have stopped reflecting true; fracturing into cults (she will return / she abandoned us / we must replace her). **[CANON race / PROPOSAL schism]**
- **The Harem Stet thread** — contact with the undead front reveals its master is a *mourner*, and that something lawful and patient stands behind him that is not undead at all. **[CANON basis]**
Act II culminates in the layered reveal: *what* Maiiam is; *who* she was (Baes); that the chaos is **manufactured** — Pazzah is Kronos, Kronos has her, and the demons are his instrument **[CANON]**; and that a third power (the devils) is playing its own game in the shadows. The faction whose libraries enabled the investigation is the faction whose god is the culprit — the oath-orders split into loyalists, reformers, and oath-breakers. **[PROPOSAL staging of CANON facts]**

### Act III — The Measure of a Soul
The player crosses the rift to the second imprisonment — **outside spacetime** **[CANON]** — and the game reads the Soul Meter it has kept all along. The final dungeon is a non-place where the engine's own rules visibly break: rooms that repeat, turns that echo, the fogspace texture of the novel era returned as architecture **[PROPOSAL]**. Gating option worth strong consideration **[PROPOSAL]**: only a **non-closure** soul can cross a wound in definition — the undefined passes where the defined cannot. History rhymes on purpose: a mortal once again stands at the door of Maiiam's prison. *"The door does not know it is a door"* may be said of the player this time.

**Ending families — a starting set, explicitly non-exhaustive [CANON: more outcomes to come]:**
1. **RESTORE — the equilibrium path.** Free her; diminish Pazzah a second time. Balance returns; the fronts recede; the world stays messy, magical, paradoxical. Unlocked by a *neutral* meter and deliberately the **hardest** road — see §4.3: this path means having *refused* both power trees all game. Equilibrium is fought for, not defaulted into.
2. **REPLACE — the Maiiam-resonant path.** Ascend as the new Balance. **Maiiam stays gone forever — she dies. [CANON]** The mechanical why **[PROPOSAL §4.2]**: the player has been built out of her consumed essence all game; there is not enough of her left to restore *because of what the player became*. A victory that removes the player from the world and buries the woman who saved it twice. Epilogues: a world saved by someone it will misremember, exactly as it misremembers Baes.
3. **REDEFINE — the Kronos-resonant path.** Use recovered QUINE remnants / definition-magic to unmake the fronts. It works — **and it completes Kronos's plan**, knowingly (side with Pazzah; his solution genuinely solves the crisis he authored) or unwittingly. **Maiiam stays gone forever — she dies. [CANON]** The world re-locks: magic dims, oaths tighten, epilogues run cold.
4. **Further outcomes [CANON: to be designed]** — candidates worth exploring later: a Harem Stet alliance ending (the dead march on the Clockless Warden), a devil-bargain ending (they also want Kronos stopped — at a price), a Tiefling-schism ending. Design space intentionally left open.

**The Harem Stet pivot (the "talk to the Master" path). [PROPOSAL on CANON foundation]** His plan rests on one premise: the apocalypse is inevitable because she is fading. But she isn't fading by nature — *she was taken.* Proving this to him collapses his doctrine and forces the best scene in the game: a grieving devotee with an army of the dead and a suddenly restored reason to hope. Branches: he turns his legions against Pazzah (endgame ally); he shatters (mercy or tragedy); he refuses the truth — sunk cost for a man who has killed thousands to save them — and remains a boss. If the devil-harvest proposal is canon, revealing *that* betrayal is a second lever. Every branch should leave permanent marks on the ending slate.

---

## 4. Character System

### 4.1 Skills & Ancestries — **RATIFIED 2026-08-03** (Phase 0; see `docs/phase-0-ratification.md`)
- **Skills are percentile. [CANON, ratified]** Twelve skills across three domains, resolved by one
  path: `d100 ≤ effective%`, rolled on commitment. The percentage derives from the vault Ledger's
  Untrained/Trained/Expert tiers (`attribute × 8 + tier_bonus + advancement_points`). Body:
  Athletics, Stealth, Sleight of Hand, Beast Handling. Mind: Lore (tagged), Survival,
  Investigation, Alchemy. Soul: Persuasion, Weft-Sensing, Performance, Insight.
- **Advancement is point-buy at level. [CANON, ratified]** No use-based drift. One partial respec
  per chapter (the **Mirror Rewriting**) reaches advancement points only — ancestry, patron,
  Background, and Mastery are permanent.
- **Race = ancestry + magical inheritance. [CANON]** ⚠ **The god-keyed D&D-analogue list this
  section originally carried (Orc/Dragonborn/Halfling/Elvish/…) is superseded by the lore vault's
  `peoples/`** — the vault wins per the CLAUDE.md conflict rule, and the PRD forbids D&D stand-ins
  in presentation. Chapter 1 ships **five playable ancestries**: **Vael** (generalist), **Kaan**
  (Forge/Anchor martial), **Vaerin** (Spark/Pitch caster, carries the Fading track), **Weftkin**
  (Pitch/Voice, innate Weft-Sensing), **Kes'reth** (Voice/Anchor, *Mirrored Scars* — the
  centre-holding build). Each gets one mechanical inheritance, one dialogue-reactivity package, and
  a Wheel affinity nudge (never a hard lock). Every other people remains playable in the ruleset and
  appears as NPC culture first (§8).

### 4.2 The Soul Meter (the measure of a soul)
- **The Meter is an axis of principle-resonance. [CANON]** Kronos-resonant conduct and powers pull one way (weighting **REDEFINE**); Maiiam-resonant conduct and powers pull the other (weighting **REPLACE**); a soul near equilibrium walks the mortal road (**RESTORE**). The Meter weights and unlocks endings rather than silently forcing them.
- **Resonance grants abilities — the temptation engine. [CANON intent, BG3-tadpole model]** Two escalating ability trees:
  - **The Definition tree (Kronos):** binding, stasis, judgment, truth-compulsion, unmaking-by-naming. Fed by QUINE shards and order-relics.
  - **The Paradox tree (Maiiam):** holding-both, mirror-walking, permeability, mercy-with-teeth, probability-bending. Fed by... her.
- **The essence-consumption rule. [PROPOSAL — load-bearing]** Maiiam is kidnapped and *fading*; her essence bleeds loose into the world. Every Paradox power the player absorbs and uses is literally a piece of her, consumed. Every Definition power feeds Kronos's return. Investing in either tree is eating a god — which is *why* REPLACE and REDEFINE both end with her permanently gone, and why the meter deserves its name. The game should whisper this long before it says it.
- **Neutrality = refusal, not passivity.** The RESTORE path means declining two entire ability trees while the game actively tempts with them. To keep it playable, the unaligned road gets compensation **[PROPOSAL]**: mortal-excellence perks, deeper companion loyalty powers, and the **non-closure** line — the rare acquirable state (immune to scrying, fate-magic, divination, *and* magical healing) **[CANON condition]**, a perk-curse that late-game factions react to strongly and that may matter at the prison door.
- **Diegetic visibility:** temples read the player aloud, Tiefling mirrors show resonance, god-keyed NPCs react. The world itself is the karma system — in this universe, literally.

### 4.3 Companions
- Small roster (3–5 in v1), faction/race-keyed, each with one loyalty questline touching the main mystery from their culture's angle. Companions are meter-aware — and at least one should be *tempted alongside the player*, mirroring the trees. **[PROPOSAL]**

---

## 5. Factions

| Faction | Role | Canon basis |
|---|---|---|
| **Pazzah / the Clockless Warden** | The hidden antagonist — order-god manufacturing chaos to sell order; in league with Agars Reys | **[CANON]** |
| **Agars Reys** (demons) | Chaotic front; Pazzah's instrument and open-secret ally | **[CANON]** |
| **Harem Stet** (undead) | The tragic Master-figure: Maiiam's maddened devotee "rescuing" the world into undeath; negotiable via the truth | **[CANON]** |
| **The devils** | Lawful-evil string-pullers behind Harem Stet; motive proposal: they need a world of free will to harvest, and Kronos's order ends the market | **[CANON existence / PROPOSAL motive]** |
| **Dragonborn oath-orders** | Lawful power bloc; archive-keepers; tragic centerpiece — their god is the kidnapper; Act III schism: loyalists / reformers / oath-breakers | **[CANON basis / PROPOSAL schism]** |
| **Elvish insight-orders** | Knowledge-hoarders; Act II gatekeepers | **[CANON]** |
| **Tiefling mirror-mystics** | Maiiam's own, grief-fracturing into cults | **[CANON race / PROPOSAL schism]** |
| **The Baes cults** | Fringe sects worshipping the Ascended One's *human* life; garbled crew-relics; comic and tragic by turns | **[PROPOSAL]** |
| **Free settlements** | The player's home context; hubs; the stakes made local | — |

## 6. Gameplay Chassis — DECIDED

**Structure [DECIDED]:** Real-time 2D field exploration → transition into a dedicated 2D battle scene → turn-based combat → return to field. This is the Tales of Symphonia *encounter architecture* without ToS's real-time combat or 3D — fully proven in 2D (Chrono Trigger, Grandia, Sea of Stars, Octopath). Field maps keep the living-world feel; battles stay authorable and solo-buildable. Fallout is vibe, not blueprint. **[CANON direction: turn-based, hybrid]**

**Combat identity [DECIDED 2026-07-31 — the signature mechanic]:**
- **The Balance Gauge.** Every battle displays an order↔chaos axis that actions push. Demons drag it chaosward (wild surges, crits, mutations strengthen); undead and devil-forces drag it orderward (turns rigidify, effects become predictable, bindings strengthen); the player's Definition powers push order, Paradox powers push chaos, mundane actions pull toward center. Extremes are dangerous *for everyone*; mixed-force fights whipsaw. The cosmological thesis becomes a tactical resource — the player literally manages balance in every fight. A RESTORE-path player who refuses both trees is the party's *stabilizer*: the refusal build is mechanically real in combat, not just narratively.
- **Defining strikes.** Called shots, reflavored as the setting's own magic: Lore/insight lets the player *name* a weakness ("the knee," "the oath that binds it") for targeted effects. Fallout's targeting *feel*, entirely this world's fiction.
- **Speech is a combat verb.** Fights can be ended, split, or turned mid-battle through dialogue checks — essential against Harem Stet's forces, where every soldier was somebody's rescued dead.
- **Zones, not grids (v1).** Front/back/flank positioning delivers most tactical decisions at a fraction of a full tactics-grid's build cost. Race inheritances + the two ability trees carry build diversity. ⚑ **Under amendment — see the note below this section.**
- **Consequence-permanence.** Fleeing, sparing, and slaughtering all write flags. Combat outcomes are story outcomes.

**Combat spec status [RATIFIED 2026-08-03]:** the five bullets above are no longer direction-only.
`docs/prd-chapter-one.md` §6.1 (FR-101–110) is **the ratified build spec** for this chassis — AP
economy, `BattlefieldModel` zone interface, Pandora-driven Balance thresholds, the Defining Strikes
weakness tables, and speech-in-battle. Anything in §6 and the PRD that disagrees resolves to the
PRD. The zones-vs-grid question is settled at the Phase 2 gate, not deferred to v2.

⚑ **Amendment pending (2026-08-05).** The owner set a tactical-layer direction on 2026-08-04
that supersedes two of the five bullets above: **zones become a grid with elevation and facing**,
and the **AP economy becomes charge-time turn order**. Defining Strikes, the Balance Gauge, and
speech-as-a-verb are all **kept** (repriced/re-homed, not cut). See
`docs/prd-amendment-tactical-layer.md`; it is DRAFT and not yet ratified, so the text above
remains in force until it is.

Note what this does to the sentence directly above: the zones-vs-grid question is now being
answered **ahead of** the Phase 2 gate rather than by it. The gate's evidentiary bar is replaced,
not removed — amendment §5 (Gate T) restates it for the new chassis, and §8 records what triggers
a reversal.

## 7. Systems Notes

- **Dialogue engine is the product.** Tree-based, with skill/meter/race/faction checks visible. Build first, build well.
- **Global flag store from day one** — the reactivity spine; every location module reads/writes it; design flags for cross-location echoes explicitly.
- **Casting is Elements & Music [CANON, ratified 2026-08-03].** Two independent axes — Breadth
  (Tone/Chord/Triad) × Magnitude (Note/Phrase/Song/Refrain) — over the vault's ten-element Wheel,
  each element carrying a fixed Imposition and Rule-Bend, ten Triads with structural (never
  damage) effects, Strained Chords at penalty, and the **Vär** harmony gauge gating Breadth. Spec:
  `docs/prd-chapter-one.md` §6.3 and vault `systems/elements-and-music.md`.
- **Casting fuel: the boundary model [CANON, ratified 2026-08-03].** **Breath** is the per-scene
  pool; casting past empty Breath spends the **Soul Meter**, permanently. This keeps canon fact 8
  ("magic spends the Gauge, and it mostly only goes down") literally true while giving routine
  casting a floor. It is the only route from casting to Meter loss, and it is always knowing.
- **Magic thinning zones [CANON, ratified 2026-08-03]** — environmental storytelling of the failing
  balance; difficulty by geography, now with numbers: fizzle scales off local Agreement Integrity
  (see vault `systems/magic-system.md` §fizzle math), so in the Hush only Notes are honest. The
  **Zhavar** ladder is the other half — banking harmony makes a zone reliable *and* audible, up to
  a dragon noticing. Chapter 1 telegraphs the ladder and scripts one tolling event.
- **Relic-tech [CANON]** — pre-spore items as rare, lore-bearing loot; reading relics is how the deep-lore layer physically enters play; QUINE shards double as Definition-tree fuel.
- **Epilogue slides** per location/faction/companion — the cheapest high-impact reactivity in the genre; write them alongside quests, not after.

## 8. Scope Guardrails

- v1 = one region (8–12 locations, 3 hubs, 15–25 hours), one act-complete main quest, 4–5 playable races, 3–5 companions, the three core ending families + the Harem Stet pivot. Additional ending families are sequel/expansion space — write them down, don't build them.
- Novel-era content (Site K, the crew) appears **only as archaeology** — documents, ruins, murals, relics. No playable flashbacks in v1.
- If a system doesn't feed dialogue, consequence, or the Meter, it's a candidate for cutting.

## 9. Godot Implementation Notes

- Chassis-agnostic core first: dialogue engine + flag store + meter as one serialized game-state singleton (inspectable, trivially saved).
- One hub location as vertical slice (all systems shallow) → combat prototype *after* §6 decision → region production line.
- UI in Control nodes; the dialogue screen and the Meter's diegetic readings (temple scenes, mirror scenes) are the flagship UI investments.

---

## 10. Open Canon Questions

> ~~Why is Maiiam missing?~~ **ANSWERED [CANON]:** Kronos-as-Pazzah kidnapped her to manufacture chaos and win worship for his ordered universe.
> ~~Harem Stet's nature?~~ **ANSWERED [CANON]:** a maddened devotee of Maiiam, backed by hidden devils, saving the world into undeath ahead of a foreseen apocalypse.

1. **Where is she held?** The second prison's nature and geography — inside the Oathclocks of Rennen, a rebuilt QUINE fragment, a definition itself, somewhere in time? Decides Act III's final dungeon and tone. *The biggest open door.*
2. **How long has she been fading?** The "fading" framing implies years — long enough for grief to become doctrine. Pin the span; it calibrates the whole world's mood and how far Pazzah's plan has advanced.
3. **The other nine gods:** complicit, deceived, or divided? Does any deity suspect Pazzah? Decides divine politics and whether any god can be recruited.
4. **The devils:** origin in this cosmology (the bible defines demons-adjacent questions but not devils), their true motive (soul-market proposal — confirm/replace), whether Harem Stet knows they stand behind him, and whether the harvest-betrayal lever exists.
5. **Agars Reys:** what demons *are* here — fogspace residue, 6th-dimension bleed via the Negation Axe wound, or original — and how openly they serve Pazzah. Ties to bible open question #1.
6. **The Harem Stet pivot branches:** which of ally/shatter/refuse are in v1, and what each permanently marks on the world.
7. **Race count (bible Q3):** nine or ten — decides the playable pool and Tiefling status.
8. **Timeline (bible Q7):** generations between the spore event and this game.
9. **Does Baes-as-Maiiam retain anything of Baes?** Decides the register of the prison-door scene — and whether the melody (bible Q9) appears as motif, key, or ghost.
10. **The new entity from Act V of the novel** (bible Q8): present in Era 3? Faction, place, or ending wildcard — possibly one of the "further outcomes."
11. **Has wielding chaos changed Kronos?** The paradox thread — canonize, hint, or drop.
12. **Gameplay chassis (§6).** The only non-canon question on this list, and the next one to answer.

---

*Fallout 2 for the consequences, Witcher for the density, BG3's tadpole for the temptation — soul entirely Dramgid. v0.2 canon: the kidnapping, the fading, the devil-backed mourner, endings 2 and 3 as her death, the meter as ability engine.*
