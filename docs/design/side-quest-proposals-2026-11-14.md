# Side quests for Kesselford and Ashlaren: proposals

**Status:** PROPOSAL, 2026-11-14, for owner review. Nothing here is built or canon. Two premises
(K1, A1) are the side quests the vault already records as "ratified as authored"; the other six are
invented here and listed in the gaps section. Every number is PROVISIONAL (owner item 5).

**Why now.** Hubs 2 and 3 have townsfolk, talk and loot, but no side quest. Phase 5 needs hours
toward the held 8–12-hour floor "through consequential quests, not padding" (roadmap R8). FR-502 is
already met (eleven complete side quests), so these add hours, Reputation weight and read-backs, not
a gate.

**Suggested answer format:** `K1: approve` / `K1: edit …` / `K1: drop`, per proposal.

## Rules every proposal follows

- **FR-502:** two genuinely different outcomes, at least one ledger write, and a resolution that is
  a choice (legwork may carry the quest).
- **FR-403 / G5:** each outcome names where later content reads it back.
- **Acts of Agreement** (2026-10-29): side quests are in scope at **+8** each. An outcome is proposed
  as an act only where it restores a name, record or honest bond, the shape of the ruled
  `restore-the-entry` / `return-the-name` / `bring-them-home`. Not every quest has one.
- **Paradox routes** (R1, SR3; drafts in #594 / owner item 42): one per quest, always listed with its
  SOUL −N chip, **−4 to −10**, in one of the two drafted shapes ("a working" or "spending yourself").
  It forgoes any +8 and writes no Reputation.
- **Skill checks** use the dialogue pattern already in `dialogue/dom_side_quests.dialogue`: a
  `check("skill", DC)` choice shortcuts legwork and a fail flag sends the player back to it. R7 is
  met on `main` (16/22 checked, Bellow once, per `tools/audit_field_coverage.gd` 2026-11-14). These
  proposals favour the **six skills never checked (Lilt, Varlore, Mending, Falsetto, Downbeat,
  Brace)** and **Bellow** (checked once).
- **Faction ids** come from `data/generated/faction_ids.gd`. Reputation deltas sit in the ±3 to ±6
  range the Dom quests use.

## At a glance

| # | Quest (giver) | Status | Outcomes | +8 | Paradox | Checks |
|---|---|---|---|---|---|---|
| K1 | The River Answers Late (Mender pair) | ratified premise | expose · formalize | — | −8 | Downbeat, Mending, Tread |
| K2 | No Safe Hour (Wendel Marrow, Orla Chainwright) | invented | cross in the margin · sell at the ford | — | −6 | Brace, Bellow |
| K3 | The Safe-Hours Map (Nessa Quill) | invented | file it true · round it up | A | −8 | Varlore, Lilt |
| K4 | The Second Voice (Ivo Threnlow) | invented | tell the charter · keep the pair | B | −6 | Falsetto, Mending, Downbeat |
| A1 | The Twice-Certified Sack (Brannoc Ledgerwell, Ilse Furrowgood) | ratified premise | bury · publish | — | −10 | Varlore, Bellow |
| A2 | A Disputed Day (Tamsin Flatbell) | invented | record it flat · record it true | A | −6 | Falsetto, Downbeat |
| A3 | Short Weight (Gaut Stonebrook) | invented | report the miller · certify the margins | B | −4 | Lilt, Brace |
| A4 | The Margin Rows (Ilse Furrowgood) | invented | samples to the Menders · samples to the Table | — | −10 | Mending, Varlore |

Eight quests at about 20–30 minutes each add roughly 3–4 hours. All six never-checked skills get at
least two checks each; Bellow gets two more. Four new +8 acts (K3, K4, A2, A3).

**Suggested order:** K1 and A1 first (ratified, lowest canon risk); then K2, which carries the
link between the hubs that Wendel Marrow's vault entry describes; then the rest.

## Kesselford (hub 2)

### K1. The River Answers Late: ratified premise

**Giver:** the dawn pair, Mender Ivo Threnlow and Mender Nessa Quill, at the Mender Stone.

**Premise (vault, `locations/kesselford.md`, ratified as authored).** The pair asks the party to
walk the far bank and learn why the river answers their dawn song late. The trail leads upstream to
a hospice-chain wayhouse that ferries the dying across by night.

**Legwork.** Count the late note with the pair at dawn; walk the far bank; find the night landing;
talk to a dying traveller waiting for the crossing.

**Decision.** *Expose the night crossings, or let them go on under River-Mother supervision.*

- **A `expose-the-crossing`** (Wayfare-Menders +5, Hospice Chain −5): the upstream wayhouse
  closes. The dying wait half-held in a town with no rite for them.
- **B `formalize-the-crossing`** (Hospice Chain +5, Wayfare-Menders −3): the crossings go on under
  River-Mother supervision. The ford's thinning measurably worsens.
- Either way the river keeps answering late (ratified).

**Act of Agreement:** none. The ratified outcomes mend nothing.

**Paradox route (−8, spending yourself):** carry tonight's dying across yourself, with the dawn
pair's note sung at night under your own name. They cross; the wayhouse is neither exposed nor
formalized; the river still answers late.

**Checks:** **Downbeat** (keep the pair's count and hear exactly how late the note returns, which
skips a dawn of waiting); **Mending** (ease a dying traveller enough to say where the boat lands);
Tread (follow the night ferry unseen; checked once today).

**Read-back:** Nessa's monthly map on the next visit (B shrinks the safe hours, A does not); Hesk
Waterward's bell talk; Dagny Kettlebrook's wayhouse fills with families waiting (A).

### K2. No Safe Hour: invented

**Givers:** Factor Wendel Marrow (Grain Factors' Table, stranded four days) and Orla Chainwright
(the chained ferry).

**Premise.** Wendel's Ashlaren-certified consignment will spoil if it waits out another closed
week. He wants Orla to cross in the half hour she judges marginal. Orla will not cross without a
second pair of hands on the chain.

**Legwork.** Read the river with Orla before dawn; check the chain stakes on both banks; look over
Wendel's certificates.

**Decision.** *Cross in the marginal half hour, or keep the ferry chained and let Wendel sell the
consignment in Kesselford.*

- **A `cross-in-the-margin`** (Grain Factors' Table +5, Wayfare-Menders −3): the consignment goes
  on toward the coast. The chain takes a strain Orla must report to the charter.
- **B `sell-at-the-ford`** (Wayfare-Menders +4, Grain Factors' Table −4): Kesselford eats certified
  grain this week, and Wendel's certificate is spent outside the Table's channel.

**Act of Agreement:** none.

**Paradox route (−6, a working):** hold the river's note yourself for the crossing. The ferry
crosses, the chain takes no strain, and Orla saw you do it.

**Checks:** **Brace** (be the second pair of hands; success means A costs no chain strain);
**Bellow** (make the ferry crew stand to their posts when the water turns).

**Read-back:** in Ashlaren, Factor Brannoc Ledgerwell mentions the Kesselford consignment arrived
(A) or that "Marrow sold certified grain to a wayhouse" (B).

### K3. The Safe-Hours Map: invented

**Giver:** Mender Nessa Quill, who keeps the monthly map of where the weather-songs still hold.

**Premise.** This month's map shows the safe hours shrinking by more than the town's trade can
bear. The ferry trade wants last month's hours filed again. Nessa asks the party to walk the hours
with her before she decides what she files with the charter.

**Legwork.** Test the edge of each safe hour at the shallows; compare the old maps; hear the trade's
case at the wayhouse.

**Decision.** *File the true map, or file last month's hours.*

- **A `file-it-true`** (Wayfare-Menders +5, Grain Factors' Table −2): crossings close at the new
  hours, and the wayhouse fills.
- **B `round-it-up`** (Wayfare-Menders −3, Grain Factors' Table +3): crossings keep last month's
  hours. Later, a cart is lost in a "safe" hour.

**Act of Agreement:** **A, +8** (an honest record restored, the shape of `restore-the-entry`).

**Paradox route (−8, a working):** sing the lost hour back yourself each dawn this month. The map
is filed true and the hour holds, paid from your Gauge.

**Checks:** **Varlore** (read the weather-song notation on Nessa's map, which skips walking every
hour); **Lilt** (cross the stepping-stones at the hour's edge to test it).

**Read-back:** Hesk Waterward counts the month's rings; the lost cart is told at the wayhouse (B).

### K4. The Second Voice: invented

**Giver:** Mender Ivo Threnlow, the senior of the dawn pair.

**Premise.** Ivo's voice is failing. If the charter hears, it retires him and sends a stranger, and
Nessa cannot sing the pair alone yet. He asks the party to stand as the second voice for three
dawns while he decides what to tell the charter.

**Gate:** after K1, so the pair that leads K1 is the pair it knows.

**Decision.** *Tell the charter, or keep the pair as it is.*

- **A `tell-the-charter`** (Wayfare-Menders +4): a new Mender is sent and Ivo retires to the
  wayhouse. The dawn song is steady and strange to the town.
- **B `keep-the-pair`** (Wayfare-Menders −2): Ivo stays, and Nessa carries more of each dawn. Some
  mornings a note is not caught.

**Act of Agreement:** **B, +8** (the pair's bond kept, the shape of `bring-them-home`). Owner to
judge; A is the more cautious reading.

**Paradox route (−6, spending yourself):** sing the second voice yourself at each dawn you are in
Kesselford. Ivo is neither retired nor exposed.

**Checks:** **Falsetto** (match Nessa's register as the second voice); **Mending** (ease Ivo's
voice for one dawn); **Downbeat** (keep the pair's count when he falters).

**Read-back:** the dawn scene at the Mender Stone (a stranger in A; Ivo and Nessa in B, with a
missed note on some mornings).

## Ashlaren (hub 3)

### A1. The Twice-Certified Sack: ratified premise

**Givers:** Factor Brannoc Ledgerwell (head of the counting-house) and Steward Ilse Furrowgood
(Ghorr steward); Pell Haskard guards the sack and Clerk Odile Marrowby keeps the ledger.

**Premise (vault, `locations/ashlaren.md`, ratified as authored).** A certified-empty sack is
found to weigh full again three towns away. The Factors want the anomaly suppressed before the
price of certified grain collapses; a knot of Ghorr stewards want it studied as proof the Waning
touches harvests, not just castings.

**Legwork.** Odile's two ledgers against Tamsin Flatbell's list of flat days; the warehouse (Pell's
existing Bellow challenge); the report from three towns away (carried by a traveller or by Wendel
Marrow if K2 sent him on).

**Decision.** *Bury the record, or publish it.*

- **A `bury-the-record`** (Grain Factors' Table +6, Ghorr stewards: see gaps): prices hold and the
  stewards are discredited. One steward hangs herself when her own field fails uncertified
  (ratified text).
- **B `publish-the-record`** (Grain Factors' Table −6, the Registry: see gaps): faith in
  certification cracks, and a Registry audit office comes to Ashlaren, ending the town's easy
  independence.
- Neither outcome feeds anyone longer (ratified).

**Act of Agreement:** none.

**Paradox route (−10, spending yourself):** witness both certificates under your own name. The
record is filed, but as yours, not the Table's. Prices hold for a season and the stewards' study
goes on.

**Checks:** **Varlore** (read the two ledgers against the flat days, which skips the warehouse
step); **Bellow** (make Brannoc open the ledger room).

**Read-back:** the Registry office in the square (B); the closed farmstead and Ilse's line (A); in
Kesselford, Wendel Marrow's talk of the price.

**Content note for the owner:** outcome A includes a suicide (ratified text). This proposal keeps it
off screen and reads it back only as a closed farmstead and one line. The vault says the game may
name which steward; this proposal does not.

### A2. A Disputed Day: invented

**Giver:** Warden Tamsin Flatbell, who rings the shrine-bell at weighing and keeps the list of flat
days.

**Premise.** A Ghorr steward's harvest was weighed on a day Tamsin heard as flat. On the flat-day
weights it fails certification; on the true-day weights it passes. Brannoc wants the day recorded
true. Tamsin asks the party to hear the bell at the next weighing and say what they heard.

**Decision.** *Record the day flat, or record it true.*

- **A `record-it-flat`** (Grain Factors' Table −3): the harvest fails certification and sells
  uncertified at half price. The list stays honest.
- **B `record-it-true`** (Grain Factors' Table +4): the harvest is certified, and Tamsin's list now
  carries a false day, which A1's ledger later shows.

**Act of Agreement:** **A, +8** (honest measure sealed by the bell, which is the bell's whole
office).

**Paradox route (−6, a working):** ring the bell true yourself for this one weighing. The harvest
certifies honestly and the list stays honest.

**Checks:** **Falsetto** (sing against the bell to pitch its note); **Downbeat** (count the ring's
decay against the true-day count).

**Read-back:** Tamsin's list on the next visit; A1's ledger includes the false day if B was chosen.

### A3. Short Weight: invented

**Giver:** Miller Gaut Stonebrook, at the millhouse called The Flat Bell.

**Premise.** Certified bred grain has started to mill short; the flour weighs less than the grain.
Gaut has been making weight with grain from the stewards' weedy margins, bought quietly and never
certified. He asks the party to keep their mouths shut, or to help him make it honest.

**Legwork.** See the hopper in use; weigh a sack in and its flour out; find the margin grower.

**Decision.** *Report the miller to the Factors, or bring the margin grain into certification
openly.*

- **A `report-the-miller`** (Grain Factors' Table +5): Gaut loses the millhouse lease, and certified
  flour is openly short weight from now on.
- **B `certify-the-margins`** (Grain Factors' Table −3, Ghorr stewards: see gaps): the margin
  growers are weighed at the hall like anyone else. Gaut keeps the mill.

**Act of Agreement:** **B, +8** (the margin growers brought into the honest chain).

**Paradox route (−4, spending yourself):** buy the margin grain in your own name and sell it to the
mill. Gaut's secret becomes yours to keep.

**Checks:** **Lilt** (climb the sack-hoist to see the hopper in use, which skips a night watch);
**Brace** (hold the runner stone so Gaut can show the short fall).

**Read-back:** Dagny's bread in Kesselford ("margin bread" in B); Ilse's study in A4 cites the
margin grain.

### A4. The Margin Rows: invented

**Giver:** Steward Ilse Furrowgood.

**Premise.** Ilse wants the rot studied, not buried. She asks the party to take clean samples from
a failing bred row and its weedy margin and carry them where someone will study them.

**Decision.** *Take the samples to the Kesselford Menders, who keep maps of where the songs hold, or
give them to Brannoc, who will certify the margin grain as a new grade.*

- **A `to-the-menders`** (Wayfare-Menders +5, Grain Factors' Table −2): the samples go on Nessa
  Quill's map table in Kesselford. Nothing is concluded in Chapter 1.
- **B `to-the-table`** (Grain Factors' Table +5): a new certified grade is struck for margin grain,
  and the study is shelved.

**Act of Agreement:** none.

**Paradox route (−10, a working):** sing one bred row whole for a season. Ilse has a living
control row, paid from your Gauge.

**Checks:** **Mending** (tend the failing row long enough to cut a clean sample); **Varlore** (read
the row's breeding marks).

**Read-back:** Nessa's map table in Kesselford (A); the new grade on the Weighing Hall board (B).

**Canon guard:** the vault frames the rot as "the Weft breaking the precise". This quest must not
state a mechanism or let the study conclude in Chapter 1.

## Gaps and invented material

1. **K2, K3, K4, A2, A3 and A4 are invented**, including Ivo's failing voice, the margin-grain trade,
   the disputed day, and every outcome, delta and route in them.
2. **All town NPC hooks are PROVISIONAL** in the vault ("CANON REVIEW REQUIRED", owner item 9).
   These proposals lean on them.
3. **No game faction id for the Registry or for the Ghorr stewards.** `data/generated/faction_ids.gd`
   has neither (`the-registry` is a vault faction only). A1 and A3 need one, or need to write their
   Reputation elsewhere.
4. **River-Mother supervision** (K1) is a vault term with no game representation yet.
5. **New locations:** K1 needs an upstream far-bank landing; A1's report comes from "three towns
   away" and needs a carrier, not a scene.
6. **Four new acts of Agreement** (K3, K4, A2, A3) move the all-Agreement Soul endpoint. R3's band
   must be re-run for whichever are approved.
7. **Paradox costs and shapes** follow the #594 drafts, which await owner item 42. If item 42
   changes the policy, these follow it.
8. **What each skill does in a check** is read from its name, group and attribute; neither the repo
   nor the vault defines the skills. Bellow as intimidation is confirmed by the warehouse
   challenge (`test/integration/test_ashlaren_bellow.gd`).
9. **The suicide in A1's ratified outcome A** needs an owner ruling on handling.
