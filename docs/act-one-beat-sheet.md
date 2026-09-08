# Act I beat sheet — "The Front Is Coming"

**Issue:** #246 (C9). **Author:** Claude (beats and canon are Claude/owner per the issue).
**Status:** beats RATIFIED against existing canon; prose in the shipped dialogue is marked
`PROVISIONAL — CANON REVIEW REQUIRED` per repo convention.

Sources this is built from, in precedence order:

1. `soul-meter-crpg-design-doc.md` §Act I — **[CANON inciting need]**.
2. The Dramgid vault — `cities/dom.md`, `factions/kord-rite.md`, `factions/trial-council.md`,
   `cosmology/the-waning.md`. The vault wins where it and the design doc differ.
3. `docs/prd-chapter-one.md` FR-501 — "Act-complete main quest implementing Act I (The Front
   Is Coming) with the Act II hook."

---

## 0. The finding that shaped this brief

**Act I is mostly already built.** #246 reads as "author the main quest", and the honest
finding after reading the tree is that four fifths of it shipped across earlier waves under
other names. What is missing is not a chain — it is Act I's **closing beat**, and the Act II
hook, which appears nowhere in the repository (`grep` for the hook's canon phrase across every
`.gd`, `.dialogue` and `.tres` returns nothing).

Writing a second, parallel "main quest" beside the existing one would have been the expensive
way to satisfy the issue title while making the game worse. This brief names the existing beats
as Act I and adds the one that is missing.

## 1. The canon spine (already shipped)

| # | Beat | Where it lives | Player-visible outcome |
|---|---|---|---|
| 1 | **The Trial** — the player earns standing enough to be charged | `dialogue/lower_trial_hall.dialogue` | Trial complete; the Council will speak to you |
| 2 | **The Council's Charge** — Themka Gaath sends you to Dorthkor Road | `dialogue/council_elder.dialogue` | `DORTHKOR_ROAD` offered |
| 3 | **The Field Debt** — Coiljaw opens the east road | `quests/field_debt.tres` | 4 reward routes; east road open |
| 4 | **The Broken Muster** — the demon vanguard, and a Bloodbellow answering a *living* muster-name | `quests/dorthkor_road.tres` | 3 field outcomes (`slain` / `named` / `released`) |
| 5 | **Dom's Ruling** — what the city does with the proof | `dialogue/marshal_coiljaw.dialogue` | 3 rulings (`demons-first` / `dead-first` / `hold-both`); `chapter_one_resolution` |
| 6 | **The Deep Trial** — the first ledge below the Jawbrace | `quests/deep_trial.tres` | 3 rulings; gated on `prototype_extended_content` |

Beats 3–5 already satisfy the design doc's Act I structure: *the community sends the player
out for something concrete, and the lead half-works.* The road is held. The muster is broken.
And the answer Dom gets back is worse than the question it asked.

## 2. What Act I was missing

The design doc's Act I premise is not "go fight the front". It is a **pattern**:

> Every lead half-works and reveals the same pattern: defenses that should hold don't, rites
> that should banish don't bite, and the priests are quietly terrified because *someone isn't
> answering*. — `soul-meter-crpg-design-doc.md` §Act I **[CANON inciting need]**

Beats 1–6 deliver "defenses that should hold don't". Nothing in the build delivers the second
half, which is the half that becomes Act II.

## 3. The new beat — **The Unanswered Roar**

### Why this and not something invented

The vault hands this beat over almost whole, and it needs no new canon:

- Dom's Agreement integrity sits at **88–90%**, "actively maintained by the **Hammer Roar**"
  — the never-ceasing forge polyrhythm, the city's **Harmonic Constant**, "rhythm poured into
  the agreement like mortar" (`cities/dom.md`).
- A forge-silence in Dom is not a quiet day. It is a structural event.
- Every faction already has a theory about what is wrong, and each theory names a different
  enemy: the Iron Companies say the Breach, the Ironbrand Sentinels say the Wound, and the
  Kord Rite says the god's severed arms are gathering a grip (`factions/kord-rite.md`).

So Dom is a city whose central rite is **performed perfectly and answered less**, surrounded by
people who are each certain it is someone's fault. That is the design doc's sentence, already
standing in the vault, waiting to be pointed at.

**Nothing in this beat names Maiiam, Rhea, or the Waning.** Naming the cause is Act II's job
("The Missing God"); Act I only establishes that the far end of the line has gone quiet. The
player leaves Chapter One knowing the shape of the problem and not its name — which is also
what makes the ending elegiac rather than a cliffhanger.

### Structure

**Giver:** Themka Gaath, Trial Council (`dialogue/council_elder.dialogue`). The Council
commissions it, because the Council is the body that cannot admit this in public and therefore
needs it measured in private.

**Gate:** offered only once `chapter_one_resolution` is set — i.e. after the player has ruled
on the Broken Muster. This makes it structurally Act I's closer, not a side thread.

**Beat A — the commission.** Gaath does not say the Roar is failing. He says the Council has
had three separate reports of the Constant reading short, from three benches who do not talk to
each other, and he wants a fourth number from someone who owes none of them anything.

**Beat B — the measure.** A `sounding` check (DRAMGID: Intuition; the skill for reading what a
place actually sounds like). Deliberately chosen: `sounding` is `LoomSensitivity.FULL`, so once
#349 lands, *measuring the Agreement in a thinning city is itself harder inside a thinned
place*. The mechanic agrees with the fiction rather than sitting beside it.

Failure does not dead-end. A failed check yields the count without the confidence — the player
gets a number they cannot vouch for, and the ruling stage opens anyway with that fact recorded
(`chapter_roar_certain`). This follows the #414 convention: the fail-safe direction runs
toward the content, not away from it.

**Beat C — the ruling.** Three outcomes, each writing faction ledger events and a durable flag:

| Ruling | What the player does | Ledger |
|---|---|---|
| `sound-the-shortfall` | Say it plainly, in the open, where the Arms can hear | Kord Rite **+**, Trial Council **−**, Renown **+** — their theology predicted this and the pews will fill |
| `seal-the-measure` | Give the number to Gaath alone | Trial Council **+**, Kord Rite **−**, Renown small — the Council keeps its city calm and its problem |
| `carry-it-yourself` | Report nothing; keep the only honest number in Dom | No faction movement. A flag Chapter Two reads |

`carry-it-yourself` is deliberately unrewarded rather than punished. It is not a crime and no
ledger should treat it as one; the cost is that the player is now the only person in the city
holding a true measurement, and nobody knows to ask them for it.

**Beat D — the hook.** Every ruling sets `chapter_two_hook_open`. The closing line is the design
doc's sentence, in Gaath's mouth and stripped of every proper noun: the rite is being performed
correctly, and nothing on the other side is answering.

## 4. Flags this beat writes

| Flag | Set by | Read back by |
|---|---|---|
| `chapter_roar_measured` | Beat B, either branch | Quest stage; Beat C's gate |
| `chapter_roar_certain` | Beat B, on a passed `sounding` | Gaath's reply text; Chapter Two |
| `chapter_roar_resolution` | Beat C | Chapter-complete screen; Chapter Two |
| `chapter_two_hook_open` | Beat C, all three rulings | Chapter Two's entry condition |

Every one of the three rulings writes at least one flag **and** at least one ledger event
except `carry-it-yourself`, which writes flags only — by design, stated above, and asserted in
the e2e test so the omission cannot be mistaken for a bug later.

## 5. What this beat deliberately does not do

- **No new scenes, actors or encounters.** Act I's closer is pattern recognition, not another
  dungeon; the fights already happened in beats 4 and 6.
- **No new mechanics.** One `sounding` check through the existing `SkillCheck` seam.
- **No canon resolution.** The cause of the shortfall is not named, diagnosed, or fixed.
- **No world-clock advance.** `advances_clock` stays `false`, matching every other story quest
  in the tree. Whether Act I's end should be a clock phase boundary is an owner call
  (FR-504a §3.1) and is flagged as one rather than decided here.

## 6. Act II hook, stated for the next chapter's author

At the end of Chapter One the player knows:

1. Defenses that should hold do not — the road, the muster, the ledge.
2. The dead are answering a **living** muster-roll, in order, by name.
3. Dom's central rite is being performed correctly and is being answered **less**.
4. Three factions have three confident, incompatible explanations, and none of them is about
   the rite itself.

They do not know that this is one problem. Act II — "The Missing God" — is where those four
facts turn out to be the same fact.
