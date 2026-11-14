# The six stub side quests: finish or cut (owner item 26, roadmap R11)

**Status:** PROPOSAL, 2026-11-14, for owner review. Nothing here is built. Every recommendation is
a draft; the owner rules each stub by name. Every number is PROVISIONAL (owner item 5).

**Answer format** (from item 26): `26: R11 <stub>: finish` or `26: R11 <stub>: cut`, once per stub.
"Finish" can carry edits ("finish, but outcome B is …").

**What R11 asks** (`docs/roadmap-2026-10-30.md`, Phase 5): a finish-or-cut answer for each stub,
"never a silent promotion into canon"; agents present each stub with its current content and a
recommended disposition first. This is that presentation.

## Recommendation at a glance

| Stub (giver, where in Dom) | Recommend | Canon risk if finished | One line |
|---|---|---|---|
| The Compromised Message (Marn Veld, Council runner; Chef's House) | **finish** | medium | The choice is what Marn does with the message; who forged it stays open. |
| The Forbidden Ledge (Daska Threeknots, Deep Salvage broker; Iron Companies hall) | **finish** | medium | The choice is where the suit goes; who stood on the ledge stays unnamed. Gated after The Deep Trial. |
| Two Muster Rolls (Thessa Drumline, muster copyist; Chef's House) | **finish** | medium-high | The choice is who receives line 901; what the break means stays unstated. Feeds a main-quest read-back. |
| The Impossible Cadence (Maela Drumscar, muster drummer; Registry Archive) | **cut** | high | Duplicates Two Muster Rolls, and any ending must say where the extra two beats come from. |
| The Hidden Condition (Kelm Rook, contract reader; Trial Hall) | **cut** | high | Its author is reserved for Chapter 2, and no choice works without knowing what the clause does. |
| The Incomplete Tally (Varrik Deepchalk, lift chalker; Bell House) | **cut** | high | It ends in a chasm descent, which is Chapter 2 and would be a fourth set-piece. |

Finishing three adds three consequence-bearing side quests (about 45–75 minutes of play) toward
the 8–12-hour floor. Cutting three removes thin content that cannot close in Chapter 1.

## Facts that shape the call

- **FR-502 is already met.** Eleven side quests ship complete with two outcomes each (ten Dom and
  the Hollowmere stake). The stubs have no outcomes and count for nothing, so cutting any of them
  costs no requirement. Finishing one adds to the hours, not to a gate.
- **R7 is already met.** The field coverage audit (`tools/audit_field_coverage.gd`, run on `main`
  2026-11-14) counts 16 of 22 field skills checked and Bellow once. Six are never checked: Lilt,
  Varlore, Mending, Falsetto, Downbeat and Brace. The finish sketches below use them.
- **The main quest owns the dead's muster.** "The Broken Muster" asks "why the dead are mustering",
  and the vault's Dom hook is that the chasm's voices call names in muster-roll order and have
  reached a living Company (`cities/dom.md`, `factions/iron-companies.md`). Two stubs sit on that
  hook.
- **The Deep Trial owns the first ledge.** Coiljaw needs proof "that the first ledge can be held
  before he asks Dom to descend into the Hush". The vault reserves the expedition below the last
  ledge (`factions/ironbrand-sentinels.md`, `factions/kord-rite.md`).
- **A2 caps unavoidable combat at three set-pieces.** A stub that needs a descent cannot add one.
- **None of the six givers is in the vault.** They are Soul Meter townsfolk. Their hooks touch
  vault factions (the Trial Council, the Restoration, the Iron Companies, the Kord Rite, the Deep
  Salvage), which is where the risk lives.

## What "finish" and "cut" mean in the code

Each stub is a `StubSideQuest` (`quests/stub_*.tres`, ids 22–27) with one dialogue node in
`dialogue/dom_side_quest_stubs.dialogue`: an opening account that calls `QuestRegistry.offer`,
sets a `..._heard` flag and then `suspend_stub`, which completes the quest with no ledger row and
sets a resume flag. A revisit says the thread is paused.

- **Finish:** the stub becomes a `DomSideQuest` (decision prompt, two outcomes with faction ids,
  Reputation deltas, causes and read-backs), its dialogue gets the legwork and the choice, a
  Paradox route is drafted to the #594 shape, and its read-back is placed in later content
  (FR-403). Saves that hold the suspended stub keep it suspended and re-offer the finished quest.
  About one agent session each, plus a prose review.
- **Cut:** the offer branch is removed, the giver keeps one ambient line, and the quest leaves
  `STUB_SIDE_QUESTS`. The `.tres` stays so old saves load (AGENTS.md: preserve save
  compatibility); a suspended stub in an old save stays completed and silent. About half a
  session for all three, including `test_stub_side_quests` and the quest audit.

## The six

### 1. The Compromised Message: finish

**Built today.** Marn Veld, a Council runner, stands out of sight of the arch in the Chef's House
ward. He carries a Council message that is "correct hand, correct seal, correct wax, wrong": the
fourth line says something other than it should, "in exactly the right voice". The stub suspends
on "I am going to hand it in. And I am going to remember your face". The revisit says he handed
it in sealed, with no note, and copied the fourth line first. Continuation note: a courier-chain
trace, with the interested party (Council or Registry) left open.

**Finish sketch.** The legwork is the courier chain: the runner before Marn, the seal-room clerk,
the hour the message was out of sight.

- Decision: *Hand the message in sealed and let the Council's own channel judge it, or put the
  copied fourth line in front of the Ironbrand Sentinels before the seal is broken.*
- Outcome A, `deliver-sealed` (Trial Council +5): the channel is trusted; whatever the line
  orders, Dom does it. Marn keeps his route.
- Outcome B, `flag-the-line` (Ironbrand Sentinels +5, Trial Council −3): the Sentinels hold the
  order until it is confirmed by hand. Marn loses the route and becomes a witness.
- Act of Agreement: none. Neither outcome restores a name, place or bond.
- Paradox route (draft, −6, "spending yourself"): carry the message in yourself, under your own
  name, and say the fourth line aloud at the bench. The order is heard and questioned at once, and
  Marn walks away clean.
- Skill checks: **Falsetto** (hear that the "right voice" is an imitation; it shortcuts the
  seal-room legwork); **Downbeat** (match the hour against the runner's relay timing).
- Read-back: in "The Broken Muster", the Trial Council scene notes either an order that went
  through unquestioned or one held by the Sentinels.

**Canon risk: medium.** The vault has someone "trying to get Dom to widen the Wound"
(`characters/branek-coiljaw.md`). The finish must not say what the fourth line orders, who wrote
it, or that the two are connected. **Gap:** the line's content has to stay unstated or be
something small and local (a date, a gate). Owner to confirm.

### 2. The Forbidden Ledge: finish

**Built today.** Daska Threeknots, a Deep Salvage broker in the Iron Companies hall, prices
salvage "by what the family can carry". One suit on her bench, "good plate, priced fair", came off
"a ledge that nobody is permitted to stand on". The stub suspends on "Ask me again when you have
standing enough that my answer costs me less than my silence does." Continuation note: a Kord-rite
salvage-legitimacy thread; whether Daska is culpable or the last honest link is undecided.

**Finish sketch.** Gate it after The Deep Trial resolves, so "standing enough" is real and the
first ledge is already known ground. The legwork is the suit's marks (whose plate, which
Company) and the family who would buy it back.

- Decision: *Return the suit to the Wound-Watch as evidence of an unsanctioned descent, or let
  Daska sell it home to the family at her grief price.*
- Outcome A, `evidence-to-the-watch` (Ironbrand Sentinels +5): the descent is on record. Daska's
  bench is closed for a season, and the salvager stays unnamed.
- Outcome B, `bring-it-home` (Kord Rite +4, Iron Companies +3): the family buries the plate. The
  ledge stays forbidden on paper and walked in fact.
- Act of Agreement: **outcome B, +8** (returning the dead's plate to his own fits the ruled
  `bring-them-home` / `return-the-name` family). Owner to confirm.
- Paradox route (draft, −4, "spending yourself"): buy the suit yourself at Daska's price and carry
  it to the family under your own name. The watch gets the marks, not the plate.
- Skill checks: **Brace** (lift and read the plate's inner stamp, which is too heavy for one); **Varlore**
  (read the plate's salvage marks without the broker).
- Read-back: Maura Greyfen, a companion and Deep Salvage veteran, remarks on it. Daska's revisit
  line changes.

**Canon risk: medium.** Deep Salvage descents are canon and unsanctioned
(`characters/maura-greyfen.md`). The finish must keep the ledge in the upper chasm and above the
first ledge, never below the last. It must not say anyone came back from the Hush. **Gap:** "a
ledge nobody is permitted to stand on" needs a sanctioned name; this proposal uses "an upper
chasm ledge closed by the Wound-Watch".

### 3. Two Muster Rolls: finish

**Built today.** Thessa Drumline, a muster copyist in the Chef's House ward. "The dead roll and
the living roll run parallel for nine hundred lines. On line nine hundred and one they stop.
After that line they are simply about different musters, and neither page says so." The stub
suspends because "reading past it means opening the Dorthkor material, and that is above a
copyist". Continuation note: resumes alongside the Dorthkor muster material; the break's meaning
is deliberately not stated in Chapter 1.

**Finish sketch.** The choice is custody, not meaning. The legwork is a clean copy of lines
890–910 and the seal that would make it evidence.

- Decision: *Give line 901 to the Trial Council, who must decide the chasm crisis, or to the Kord
  Rite at the Lip Shrines, who already read the callings as the god's arms.*
- Outcome A, `to-the-council` (Trial Council +5): the copy goes into the Council's evidence. The
  main quest's Council scene can cite it.
- Outcome B, `to-the-lip-shrines` (Kord Rite +5, Ironbrand Sentinels −3): the Rite reads it at
  the shrines. The town hears of it before the Council does.
- Act of Agreement: none.
- Paradox route (draft, −6, "working"): copy line 901 into both rolls by working so that the
  pages agree again for one muster. Neither body gets the evidence, and the drums keep time.
- Skill checks: **Downbeat** (read both rolls against the march cadence to find the line without
  Thessa's eleven copies); **Varlore** (date the ink).
- Read-back: in "The Broken Muster", the Council or the shrine already knows the line.

**Canon risk: medium-high.** This sits on the vault's Dom hook (callings in muster-roll order).
The finish states no meaning for the break and keeps Dorthkor closed. If the main-quest design
wants line 901 for itself, cut this one instead.

### 4. The Impossible Cadence: cut

**Built today.** Maela Drumscar, a muster drummer at the Registry Archive. Her Company is nine,
and the cadence in her hands has counted eleven for three weeks. She wants it read against the
old notation, which sits in an archive sealed until the muster clears.

**Why cut.** Any ending must say whose two beats those are, and that answer belongs to the
main quest or the vault's living-Company hook. The stub also duplicates Two Muster Rolls. Keep
Maela as townsfolk; her "eleven and nine" line can become ambient texture that Broken Muster
reads back (optional).

### 5. The Hidden Condition: cut

**Built today.** Kelm Rook, a Company contract reader at the Trial Hall, has found the same clause
in four Restoration contracts written in four hands. It "does nothing at all until it does
everything at once". He will not say who wrote it. Continuation note: the clause's author is a
Chapter 2 reveal, and no faction is implicated in Chapter 1.

**Why cut.** Every honest choice ("void it", "report it", "sign anyway") needs to know what the
clause triggers. That is the Restoration's plan, and the vault keeps the Restoration's "real
offer" as an open thread (`factions/trial-council.md`). Chapter 2 can take the premise back.

### 6. The Incomplete Tally: cut

**Built today.** Varrik Deepchalk, a mining-lift chalker at the Bell House, will not chalk a
descent cage while the lift crew's safety tally is short one name, eleven days now. The missing
miner is Hennik Coalvein (continuation note). "There is no other way down."

**Why cut.** The only ending is a descent, which is Chapter 2 ground and a fourth unavoidable
set-piece against A2. A finish that ends with the name found above ground would undercut the
premise. Chapter 2 can take it back.

## Gaps and invented material

Everything in the finish sketches is a draft. These are invented or need a ruling:

1. The outcomes, Reputation deltas, factions, Paradox routes and costs in sections 1–3 are
   invented here, in the shapes the ruled quests use.
2. The Forbidden Ledge's outcome B as an act of Agreement (+8). Each new +8 moves the
   all-Agreement Soul endpoint, so R3's band must be re-run if it is approved.
3. The fourth line of Marn's message (stays unstated, or something small and local).
4. "An upper chasm ledge closed by the Wound-Watch" as the forbidden ledge.
5. The Kord Rite as a recipient of evidence in Two Muster Rolls (canon has the Rite reading the
   callings at the Lip Shrines, not receiving Council papers).
6. What each skill does in a check is read from its name, group and attribute
   (`globals/stats/dramgid_schema.gd`); neither the repo nor the vault defines the skills.
7. Cut stubs keep their `.tres` for save compatibility; the save-migration detail is an
   engineering call, not a design one.
