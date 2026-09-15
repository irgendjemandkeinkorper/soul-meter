# Nine class kits: one per patron, one per element

**2026-09-14 · Proposed kits, not implemented and not ratified.** The
[81-cell chart](deity-element-class-chart.md) gives every deity × element pairing one
sentence. This document develops nine of those cells into playable kits: a starting
loadout, three signature abilities on the existing breadth gates, the decision the kit
poses every fight, its counterplay, and the boundary question it exists to test.

The nine were chosen as a transversal: every patron once, every chosen element once, and
none of them a current runtime class. The chart's suggested first comparison (the three
Pazzah kits: Ash Magistrate, Boundary Warden, Oathclock) is honored by including Ash
Magistrate here; the other two are a follow-up once the engine-across-elements question
has one worked example.

| Patron | Element | Kit | Boundary it tests |
|---|---|---|---|
| Haeren | Tham | Cairnkeeper | Does cover around a recorded ally beat healing them? |
| Kero | Zhem | Unbroken | What do Scars do for a caster whose element deals no damage? |
| Stuid | Mozh | Mortuary Sage | Can information about finite sources be a resource plan? |
| Vhorr | Vekh | Nightfeeder | How does a concealment caster seed Hunger? |
| Vicoar | Zhur | Sparkwright | What does a fizzle engine do with the element that rarely fizzles? |
| Ofshütje | Vel | Wildbloom | What does a non-damaging hidden draw produce? |
| Pazzah | Khash | Ash Magistrate | Can a visible deadline make movement part of an attack? |
| Fickah | Luth | Sluice Runner | Is an interrupt worth more when it buys a replenishment window? |
| Izhakel | Sul | Witness Weaver | Can a contract pay in information instead of damage? |

## Shared kit rules

- **Tiers follow existing gates, not new level numbers.** Tier 1 is available at
  creation. Tier 2 unlocks with the Chord breadth gate. Tier 3 unlocks with the Triad
  gate. Ruling 9's perk cadence (a perk every N levels) is unresolved; when it lands,
  each tier's signature becomes that tier's first perk pick, not an automatic grant.
- **Prices reuse the card conventions.** Spell forms cost their card price
  (N 2 AP / 30 CT / 3 Breath, P 3 / 45 / 6, S 4 / 60 / 12, R 4 / 60 / 24). Engine
  commands keep their current 2 AP / 2 CT. A signature that spends a patron resource
  names the amount; a signature never grants Soul, never bypasses fizzle, and never
  refreshes a finite source.
- **Starting loadout** = the patron's existing engine command, the element's N form,
  shared Hold Note, one weapon family from the [martial cards](martial-action-cards.md),
  and two DRAMGID skill emphases (the element's Tone skill plus one). DRAMGID still
  decides proficiency; the kit decides what there is to be proficient at.
- **Every signature must survive the design rules** of the chart: it creates a decision,
  it respects persistence, and it does not turn a utility element into a damage element.
- **Counterplay is listed from the enemy's side.** If a kit has no answer listed, it is
  not ready.

Spell-form names below refer to the [elemental cards](elemental-spell-cards.md), the
[Khash packet](khash-prototype-spell-cards.md) and the
[reaction matrix](elemental-reaction-matrix.md) codes (S1, H3, and so on).

---

## Cairnkeeper — Haeren × Tham

**Engine:** Record Name on a living ally; their fall or survival through victory pays
1 Breath once. **Element:** stone, Weighted, cover, anchoring.
**The decision:** every stone you raise protects a recorded name or a route to one. You
choose between raising cover where the party stands and where it will need to be.

**Starting loadout:** Record Name · Ballast (N) · Hold Note · Hammers (Crushing Blow,
Drive Back, Break Masonry) · skills Tham Tone, Brace.

| Tier | Signature | Cost | Effect | Limit |
|---|---|---|---|---|
| 1 | **Cairn** | Raise Cover's S price | Raise Cover (two cells) with one cell adjacent to a recorded ally. That ally's Guard while adjacent to the cairn gains +1 cover step. | One cairn per recorded name at a time. The construct expires on its own card; it is not repaired by re-recording. |
| 2 | **Set the Stone** | 3 AP / 45 CT, 6 Breath | Anchor (P) an Aftertone the recorded ally owns, and the ally's next Guard costs 1 AP / 20 CT less. | Once per recorded name per encounter. Anchoring does not extend duration (K3, Z4). |
| 3 | **Barrow** | Citadel's R price, one R use | Citadel with its access gap placed so every recorded ally inside is at least two cells from the gap. Recorded allies inside ignore Weighted while the formation stands. | Wind-up. Ends on the card's rule; the Breath refund for a recorded name is unchanged and still once per name. |

**Counterplay:** Hammers and Break Masonry against the cairn; Zhem's Unmake ends the
construct (Z4 does not apply, it is a construct, not an Aftertone); pull the recorded ally
out with Hook and Draw. **Leans on:** Ballast, Raise Cover, Anchor, Citadel; T1/T3/T4.

**Boundary:** Haeren's refund is unchanged. The kit's value is whether protecting a
recorded name with stone reads as healing-by-other-means. Playtest: does the party stop
carrying a Luth caster when a Cairnkeeper is present? If yes, the cairn bonus is too high.

## Unbroken — Kero × Zhem

**Engine:** HP loss banks Scars (max five); Spend Scars arms one guaranteed-hit window.
**Element:** silence, Muted, Sever, Unmake. No elemental damage.
**The decision:** Scars are your only damage guarantee, and the weapon is the only
thing they guarantee. Spend a turn stripping the enemy's protection with silence, or
spend the Scar now on a hit that their buff will blunt.

**Starting loadout:** Spend Scars · Quiet (N) · Hold Note · Heavy blades (Great Cut,
Cleaving Arc, Falling Edge) · skills Zhem Tone, Heft.

| Tier | Signature | Cost | Effect | Limit |
|---|---|---|---|---|
| 1 | **Strip and Strike** | Sever's P price + 1 Scar | Sever one eligible buff on a target; if it succeeds, the armed Scar window applies to the caster's next weapon attack on that same target only. | The Scar is spent on arming, not on the Sever. Fizzle of the Sever consumes the Scar (existing rule). |
| 2 | **Silence Bought in Blood** | 2 Scars | Still Choir (S) is cast at the P price. | Once per encounter. Scars still cap at five; taking damage to fund silence is the intended tradeoff. |
| 3 | **Last Word** | Final Cadence's R price, one R use, 3 Scars | Final Cadence, wind-up. At release, each removed effect owned by an enemy within the radius grants the Unbroken +1 to their next weapon attack's `A`, max +3. | The bonus is a mundane attack bonus, not elemental damage. Interruption follows the card rule; the Scars are spent at commitment. |

**Counterplay:** do not feed Scars (ranged pressure, Weighted to hold them at reach);
Vekh Shroud so there is nothing eligible to Sever (X2); rebuff after the strip.
**Leans on:** Quiet, Sever, Still Choir, Final Cadence; Z3, Z4, Z7.

**Boundary:** answers the chart's first question. Scars stay a mundane-attack guarantee;
Zhem buys the *conditions* for that guarantee. New utility Scar spends are not introduced.

## Mortuary Sage — Stuid × Mozh

**Engine:** three Clarity per battle; Spend Clarity reveals the true forecast through
the next committed cast. **Element:** decay, Decaying, Reclaim, Rot the Brace.
**The decision:** Clarity is scarce and sources are finite. Spend Clarity to learn which
remains are worth a Reclaim, or save it for the Wither that must land.

**Starting loadout:** Spend Clarity · Wither (N) · Hold Note · Short blades (Quick Cut,
Open Seam, Feint) · skills Mozh Tone, Unweave.

| Tier | Signature | Cost | Effect | Limit |
|---|---|---|---|---|
| 1 | **Inventory of the Dead** | 1 Clarity, free action | Reveal every eligible Mozh source within 5: its yield, whether it is currently ineligible (burning, essential, already claimed), and when it becomes eligible (M4). | Information only. Does not create or restore eligibility. Once per encounter. |
| 2 | **Assessed Rot** | Rot the Brace's S price + 1 Clarity | Rot the Brace with the collapse footprint and every creature it would affect shown exactly before commitment, including creatures behind cover. | The Clarity reveal is consumed by this cast. Stone remains non-susceptible. |
| 3 | **Ledger of Remains** | Last Harvest's R price, one R use | Last Harvest, wind-up. Sources revealed by Inventory of the Dead this encounter are pre-declared; the wind-up cannot be spoiled by a source becoming ineligible after commitment unless it was destroyed. | A burning source is still skipped (M4). No Breath beyond the card's cap. |

**Counterplay:** Douse or Kindle the sources so they are ineligible at the wrong time;
Vault's Sealed Ground; kill nothing near the Sage. **Leans on:** Wither, Reclaim, Rot
the Brace, Last Harvest; M1, M2, M4, H6.

**Boundary:** turns limited battlefield material into a planned budget. If a Sage
without Clarity plays identically, the Tier 1 information was worthless. Playtest that.

## Nightfeeder — Vhorr × Vekh

**Engine:** successful Strikes and casts seed one recurring Hunger chain per target;
DoT kills pay 1 Breath. **Element:** dark, Blinded, Veil, Shroud.
**The decision:** you must touch a target to seed Hunger, and Vekh gives you nothing to
touch them with. Approach concealed, seed with the weapon, then decide whether to stay
hidden and let it tick or reveal yourself to reseed.

**Starting loadout:** Veil (N) · Hold Note · Short blades (Quick Cut, Open Seam, Feint) ·
skills Vekh Tone, Tread. Hunger is seeded by Quick Cut and Open Seam.

| Tier | Signature | Cost | Effect | Limit |
|---|---|---|---|---|
| 1 | **Fed in the Dark** | passive | While the Nightfeeder's signatures are concealed by their own Veil or Shroud, Hunger ticks they own cannot be traced to them for Jam targeting purposes: a Jam must name the Nightfeeder as a visible source. | Concealment ends on the card's rules; Sul's S3 reveals the source. Ticks themselves are never hidden. |
| 2 | **Blindside Bite** | Blindside's P price | Blindside, then the next Open Seam within two checkpoints treats the target as flanked if it is Blinded. | The Blinded status must already be on the target (from a Blinding Throw or an ally). Consumed by the attempt. |
| 3 | **Eclipse Feast** | Eclipse Procession's R price, one R use | Eclipse Procession; each Hunger chain the Nightfeeder owns on a creature inside the moving shroud advances one extra tick at the end of the checkpoint. | One checkpoint only. A tick is a tick: it uses current Hunger, caps at five, and DoT kills pay the ordinary 1 Breath. |

**Counterplay:** Sul (S3, X1) to expose the source; stay out of blade reach; Jam the
Nightfeeder when visible. **Leans on:** Veil, Blindside, Shroud, Eclipse Procession;
X1, X2, X4.

**Boundary:** answers the chart's second question. Ordinary attacks seed Hunger; Vekh
protects the seeding and the source, never deals the damage.

## Sparkwright — Vicoar × Zhur

**Engine:** fizzles bank Failure Tokens (max three); Spend Token prevents the next cast
from fizzling. **Element:** storm, Shocked, Arc, Conduct; Zhur ignores the Instability
die. **The decision:** your element rarely fizzles, so your engine rarely banks. Cast
strained Chords and reaches at Clash targets *on purpose* to earn Tokens, then spend
them on the Conduct that must not fail with allies on the route.

**Starting loadout:** Spend Token · Arc (N) · Hold Note · Bows (Loose Arrow, Thread the
Cover, Watch Shot) · skills Zhur Tone, Vantage.

| Tier | Signature | Cost | Effect | Limit |
|---|---|---|---|---|
| 1 | **Learn from the Reach** | passive | A Sparkwright's Zhur cast at a Clash-attuned target that fizzles banks two Tokens instead of one. | Still capped at three. The Clash fizzle add and Soul-on-failure from the attunement matrix apply unchanged; this makes the gamble worth more, not safer. |
| 2 | **Grounded Circuit** | Conduct's S price + 1 Token | Conduct with the Token consumed at commitment: the cast cannot fizzle, and every ally on the route is shown with the exact power they will take (R2). | The Token is spent even if the route is later cut (T4, R1). |
| 3 | **Storm Held in the Hand** | Storm Circuit's R price, one R use, 2 Tokens | Storm Circuit, wind-up. If the wind-up is interrupted, the two Tokens are refunded (they were insurance against fizzle, and no fizzle occurred). | Interruption settlement otherwise follows the card rule. The Sure Current exception is not a second insurance. |

**Counterplay:** Tham cover on the route (T4); stay off wet cells; interrupt the wind-up
with Break Cadence. **Leans on:** Arc, Forked Arc, Conduct, Storm Circuit; R1, R2, R3, L3.

**Boundary:** if Zhur's low fizzle rate means a Sparkwright never has Tokens, Tier 1 must
be tuned up or the pairing dropped. Playtest Token income across five fights.

## Wildbloom — Ofshütje × Vel

**Engine:** successful spells draw a hidden storm row; the same seeded result drives
preview and commit. **Element:** growth, Overgrown, Cultivate, Rootwork.
**The decision:** you keep several buffs running so any draw is useful. Prepare
breadth, not depth; the draw decides which preparation pays.

**Starting loadout:** Briar Touch (N) · Hold Note · Staves (Staff Strike, Sweeping
Staff, Break Cadence) · skills Vel Tone, Wildlore.

| Tier | Signature | Cost | Effect | Limit |
|---|---|---|---|---|
| 1 | **Whichever Blooms** | passive | On a successful Vel support cast, the hidden draw selects one eligible owned buff and gives it the Cultivate extension instead of bonus damage. Rows 1/2/3 pick the buff with the least, median or most remaining duration. | Extension obeys the Cultivate cap (V1). If no buff is eligible, the draw produces nothing; it never converts to damage. |
| 2 | **Scattered Seed** | Rootwork's S price | Rootwork with the second cell chosen by the draw among the legal cardinal neighbours of the first. | The preview shows all candidate cells; the seeded draw fixes which one before commitment (same result on preview and commit). |
| 3 | **Crown Uncounted** | Crown of Seasons' R price, one R use | Crown of Seasons, wind-up. At release the draw selects which owned buff receives the card's extension, and the grove's fourth cell, from the legal candidates. | All V-row rejections apply cell by cell; a blocked cell stays empty rather than relocating. |

**Counterplay:** Mozh eats the growth (M1); Zhem severs the extended buff (Z3); do not
let a Wildbloom sit still with three buffs up. **Leans on:** Briar Touch, Cultivate,
Rootwork, Crown of Seasons; V1, V2, M1, Z2.

**Boundary:** answers the chart's third question. The draw table gains a non-damage
column; every row must still help the declared plan.

## Ash Magistrate — Pazzah × Khash

**Engine:** file a consequence for a fixed future beat (three entries max; Jam can
cancel the source's queue). **Element:** fire, Burning, ignition, fuel.
**The decision:** the deadline is visible to everyone. Herd enemies into the area
before it fires, or pull allies out, and never file over your own fuel.

**Starting loadout:** File Sentence · Kindle (N) · Hold Note · Polearms (Thrust, Hook
and Draw, Set Spear) · skills Khash Tone, Reach.

| Tier | Signature | Cost | Effect | Limit |
|---|---|---|---|---|
| 1 | **Sentence of Ash** | Firebreak's S price, one Ledger entry | File Firebreak's three cells to ignite at the beat two rounds hence. Until then the cells are marked and empty. At the beat, the line is created as an ordinary Firebreak. | Occupies a Ledger entry; Jam on the Magistrate cancels it. Cells that become illegal at the beat are skipped. |
| 2 | **Herd** | Hook and Draw's price | Hook and Draw with the destination cell allowed to be a filed Sentence of Ash cell. | Weapon rules unchanged. The target may still move away before the beat. |
| 3 | **Verdict by Fire** | Crown of Embers' R price, one R use, one Ledger entry | Crown of Embers whose release is the Ledger beat rather than the caster's next turn. The three marks may overlap a filed Sentence of Ash. | Two Ledger entries at once. Objects hit by both take each listed integrity hit once (Khash packet). Douse before the beat prevents ignition (H2) but not the direct hit. |

**Counterplay:** Jam the Magistrate; Douse the cells before the beat; walk out of the
marked cells; Raise Cover on them (T3). **Leans on:** Kindle, Firebreak, Crown of Embers;
H1, H2, L2, T3, Z6.

**Boundary:** the chart's fifth question. Pazzah controls *when* the fire starts;
Khor can hold the line after it exists (K4); neither postpones the Ledger beat.

## Sluice Runner — Fickah × Luth

**Engine:** Jam the Gears spends 1 Soul to cancel an enemy's unresolved committed action
(one pending Jam; 5% fizzle floor). **Element:** water, Soaked, Douse, Breath
restoration. **The decision:** a Jam costs Soul, which only Agreement restores. It is
worth it only if the opening it buys is used. This kit uses it to refill a caster.

**Starting loadout:** Jam the Gears · Douse (N) · Hold Note · Thrown weapons (Cast
Iron, Double Cast, Blinding Throw) · skills Luth Tone, Slip.

| Tier | Signature | Cost | Effect | Limit |
|---|---|---|---|---|
| 1 | **Opened Sluice** | Second Breath's P price | Second Breath cast within one checkpoint of a successful Jam restores up to 9 instead of 6. | Still capped by Breath the Runner actually paid; the Jam's Soul does not count as Breath paid. |
| 2 | **Wash the Gears** | Turning Tide's S price | Turning Tide mode B; enemies inside whose action was cancelled by the Runner's Jam this round are Soaked. | Soaked is the only hostile effect; no damage. Mode A is unchanged. |
| 3 | **Floodgate** | Great Confluence's R price, one R use | Great Confluence, instant. If the Runner has a pending armed Jam retry, it is discharged on the nearest eligible enemy inside the radius as part of the release. | Discharging the retry still costs its Soul. No second Jam is created. |

**Counterplay:** instant actions cannot be Jammed; kill the recipient instead of the
Runner; Khash the Soaked (they still take direct damage, H2). **Leans on:** Douse, Second
Breath, Turning Tide, Great Confluence; L2, L3, H2.

**Boundary:** the Luth economy proposal holds: no net-positive Breath. The Runner
redistributes what they paid; the Jam buys the *turn* in which to do it.

## Witness Weaver — Izhakel × Sul

**Engine:** Bind a condition to a target; their next matching action queues a payoff
(three contracts max, one per target, melee range). **Element:** light, Exposed,
revelation. **The decision:** the contract pays in information. The enemy chooses
between restraint and telling your party what it is hiding.

**Starting loadout:** Bind (Hostility) · Unveil (N) · Hold Note · Fists and gauntlets
(Close Strike, Shove, Unseat) · skills Sul Tone, Undertone.

| Tier | Signature | Cost | Effect | Limit |
|---|---|---|---|---|
| 1 | **Term of Witness** | Bind's price | Bind Witness: the target's next ATTACK applies Exposed to it and reveals any Veiled signature it carries (S3) instead of dealing 6 damage. | Same contract slots and melee touch. A target with nothing concealed still becomes Exposed; the contract is not wasted, but it is cheap. |
| 2 | **Term of Daylight** | Bind's price + Witness Light's S price | Bind Daylight on a target: its next MOVE ending inside a chosen Witness Light field makes the field's revelation follow that creature for one checkpoint (radius 0, K1-eligible). | One moving revelation at a time. Ends on the card's rules; Zhem Z1 ends it. |
| 3 | **Noon Contract** | Noonday Revelation's R price, one R use | Noonday Revelation, instant; every enemy inside with an active Witness contract has that contract's payoff triggered immediately and the slot released. | Payoffs are the information payoffs above, never damage. |

**Counterplay:** do not attack the Weaver's side while contracted; Vekh cannot re-veil
an Exposed creature (X1) but can Shroud others; kill the Weaver to void contracts.
**Leans on:** Unveil, Prism Lance, Witness Light, Noonday Revelation; S1, S3, X1, Z1.

**Boundary:** the chart's fourth question. Threads replace their damage payoff with
revelation; the new condition (ATTACK, MOVE-into-field), eligibility and visibility
are stated here so implementation has something to reject.

---

## Cross-kit checks

| Rule | How these nine keep it |
|---|---|
| No Soul income | Only Sluice Runner touches Soul, and only to spend it. |
| Khor and Zhem deal no damage | Unbroken's damage is the weapon; its Tier 3 bonus is a mundane `A` bonus. |
| Finite sources stay finite | Mortuary Sage reveals and pre-declares; it never re-enables a claimed source. |
| Delays do not move Ledger beats | Ash Magistrate's Khor hold begins after the beat creates the line. |
| Hidden draws must help the plan | Wildbloom's draw picks among owned buffs or legal cells; it never produces nothing when something eligible exists. |
| Utility is not a weaker damage kit | Cairnkeeper, Nightfeeder and Witness Weaver have no elemental damage at all and are judged on cover, concealment and information. |

## Owner decisions before implementation

1. **Tier gates.** Confirm tiers ride the Chord and Triad breadth gates rather than a
   level count. If ruling 9's perk cadence should own this, say N.
2. **Sparkwright Tier 1.** Double Tokens on Clash fizzles is the smallest fix for a
   low-income engine. The alternative is to drop Vicoar × Zhur as a starting option.
3. **Term of Witness on a target with nothing hidden.** Exposed only, or should the
   contract refuse to bind? The kit assumes it binds.
4. **Cairn cover step.** +1 cover step for a recorded ally adjacent to a cairn is the
   number most likely to be wrong.

## Runtime handoff

1. Nothing here changes `class_resources/` engines. Each kit is engine + element forms +
   three authored actions, so the B1–B10 recipe in [class-resources.md](../class-resources.md)
   applies: new `.tres` actions under `data/combat/actions/`, rejected before spend on
   wrong patron, missing resource, or illegal target.
2. Implement one damage kit (Ash Magistrate) and one utility kit (Witness Weaver) first;
   they exercise the Ledger beat and the Threads condition seam respectively.
3. The remaining seven follow once the reaction matrix's steps 1–3 exist in the runtime,
   because Cairn, Nightfeeder and Sparkwright depend on K/T/X/R reactions.

### Ash Magistrate runtime (2026-09-15)

The kit and the cards it leans on are live in `CombatController`; the substrate is
`globals/combat/fire_field.gd` (`FireField`). Test suite:
`test/unit/test_ash_magistrate.gd`.

| Piece | Where | Notes |
|---|---|---|
| Burning, Soaked | `BattleActor.impositions` | Burning = 3 HP at the next two checkpoints, refresh not stack, refused while Soaked. Soaked lasts two checkpoints. |
| Firebreak lines, hazard | `CombatController.fire` (`FireField`) | 3 HP + Burning once per creature per round, on entry (move or pull), on creation, and at the checkpoint for anyone standing in it. Lines last two checkpoints. |
| Checkpoint | `_fire_checkpoint()` from the AP `round_ended` / CT measure beat | Order: snapshot Burning → standing hazards → burn ticks for the snapshot → age Soaked → age lines. A checkpoint that empties a side ends the battle; a killed upcoming actor forfeits its seat instead of counting as a defeat. |
| Cards | `data/combat/actions/30–33, 40–41` | Kindle, Firebreak, Crown of Embers, Douse; Thrust, Hook and Draw. Cell cards use `target_profile = &"cells"` with `options.cells = [{x, y}, …]`. |
| Kit | `data/combat/actions/50–52` | Sentence of Ash (Ledger entry, `delay_rounds` 2), Herd (`allow_marked_destination`, Chord gate), Verdict by Fire (Ledger entry, Refrain use, Triad gate, untethered). |
| Gates | `CombatAction.effect_payload` | `requires_patron`, `requires_tier` (2 chord / 3 triad via `CastingGate.query_breadth`), `refrain_use` (one per battle, spent at commit), `ledger_entry` (needs a free Ledger entry). Refusals name the gate: `class_resource`, `var_harmony`, `refrain_spent`, `ledger_full`, `blocked_by_range`, `line_shape`, `pull_geometry`, `pull_destination`. |
| Marks | `snapshot().fire.marks` | Filed-but-unfired cell workings, for the HUD and the Herd rule. Jam the Gears (`request_cancel`) removes them with the entry. |
| Save | `class_resources_to_dict()` keys `__fire__`, `__impositions__` | Additive; older saves restore no fire. |

Not done: the battle HUD (`ui/hud/battle_interface.gd`) still only targets enemies, so
cell cards and Douse-on-ally have no pointer flow yet. Numbers are the cards' provisional
values (B11 owns the cap review).

### Witness Weaver runtime (2026-09-15)

Second kit, on a light substrate: `globals/combat/light_field.gd` (`LightField`). Test
suite: `test/unit/test_witness_weaver.gd`.

| Piece | Where | Notes |
|---|---|---|
| Exposed, Veiled, Lit | `BattleActor.impositions` | Exposed: two checkpoints, cover is worthless against the creature, signatures visible; it tears a Veil (S3). Veiled: two checkpoints, signatures hidden; refused over Exposed (X1). Lit: a revelation that follows the creature for one checkpoint (Term of Daylight). |
| Witness Light fields | `CombatController.light` | Center within 4, radius 1, two checkpoints. Occupants read as Exposed while inside (`snapshot().enemies[].exposed`), nothing persists when they leave. |
| Information payoff | `signature_revealed` event | Torn veil, last cast element, Aftertones, discovered weaknesses. Unveil, Noonday and the Witness contract all pay this; none deal damage. |
| Checkpoint | `_light_checkpoint()` beside the fire checkpoint | Ages impositions, then fields. |
| Cards | `data/combat/actions/34–37, 42–44` | Unveil, Witness Light, Noonday Revelation (radius 2, one checkpoint, Refrain use), Veil (Vekh, ally/self); Close Strike, Shove (`push`), Unseat (needs a guarding target). Prism Lance is not built: no tier leans on it. |
| Kit | `data/combat/actions/53–55` | Term of Witness: a `bind_witness` Thread whose payoff is reveal + Exposed instead of 6 damage. Term of Daylight: Witness Light plus a Thread on the MOVE that ends inside that field (`ended_in_light` on the move outcome), payoff Lit; one moving revelation at a time. Noon Contract: Noonday, then every revealed enemy's Witness contract pays now and frees its Thread (Triad gate, Refrain use). |
| Threads | `IzhakelThreads` | Entries now carry `kind` (`hostility`, `witness`, `daylight`); duplicates are refused per kind and target. |
| Save | `class_resources_to_dict()` key `__light__` | Additive, omitted when empty. |
