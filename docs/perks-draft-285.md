# Perk lists per patron class — draft for review (#285, owner item 2)

**Status: approved 2026-10-24** (owner item 22: `perks: approved`, `perks karma gate: wait`).
**Slice 1 landed (#285 PR 1):** the 40 perks are canon (`canon/dom/perks/*.json`, `weftlumin.perk.v1`,
flat gate fields `minimum_fame_tier` / `minimum_karma_tier` / `maximum_karma_tier`), seeded into the
Pandora `Perks` root and emitted to `data/generated/perks.json` with `PERK_*` keys in the POT;
`PerkCatalog` reads them, `PartyMember.perk_ids` records picks (no save bump), and the character sheet
offers each pick at levels 2 / 4 / 6. Karma gates are authored but not enforced
(`PerkCatalog.KARMA_GATES_LIVE := false`) until Karma has writers. No perk effect is wired in this slice:
the sheet marks every pick "(planned)" except Jam the Gears and Nothing Wasted, which already shipped as
class features. Blurbs carrying a `[n]` below are worded without the number in canon until the effect
slice sets it. `effect.op` (§3) arrives with that slice.

The text below is the approved draft as reviewed.

Sources: `globals/stats/class_catalog.gd` (resource, signature, kit skills), `docs/class-resources-numbers.md`
(B11, the caps the level-2 perks move), `docs/ideas/class-kits-first-nine.md` § Shared kit rules ("when
the perk cadence lands, each tier's signature becomes that tier's first perk pick, not an automatic
grant"), `docs/architecture-dramgid.md` §1.2 (the 22 skills), `docs/dramgid-numbers.md` §9 (Karma / Fame
tiers), issue #285 ("perk lists per patron class as Pandora data, Karma/Fame-gated perks").

## 1. The rule of three

| level | pick | why |
|---|---|---|
| 2 | **a resource perk** — moves the class resource's cap or refresh by `[n]` | the first pick deepens what the class already does; B11 already swept these caps, so the number has a table behind it |
| 4 | **the class signature** from `class_catalog.gd`, as a pick | the kits doc's rule; the catalog marks every signature "Planned" and this is where it lands |
| 6 | **a capstone, chosen from two**: one **gated** on a Fame or Karma tier, one **ungated** | #285 asks for Karma/Fame-gated perks; offering a pair means no character is locked out of a level-6 pick by the ledger. Fame gates read "the world has noticed you"; Karma gates read "what kind" and are deliberately split — four classes reward Troubled-or-worse, two reward Upright-or-better — so neither pole is the only one with toys |

Karma gates are unreachable until Karma has writers (`docs/karma-acts-draft.md`). If that table is not
approved before #285 ships, the four Karma-gated capstones ship **ungated** and gain their gate later; the
Fame-gated ones are reachable today (Whispered by Act I's end, Known for a fighting player).

A perk never grants Soul, never bypasses fizzle, and never refreshes a finite source (kits doc,
shared rules). Nothing below touches class identity as ratified: Fickah still never reaches 0 % fizzle,
Haeren's refund is unchanged, and so on.

## 2. The lists

### Mirrorblade — Maiiam (Duelist; resource: Balance; kit skills: keen)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Second Footing | — | Once per battle, repeating Strike or Guard a third time does not break Balance. |
| 4 | Reflection | — | once per encounter, redirect an incoming spell effect back at its caster at reduced power. |
| 6a | Known Edge | Fame ≥ Known | The first enemy to act against the Mirrorblade each battle acts [n] CT late: it has heard of you. |
| 6b | Even Hand | — | The first fizzle each battle does not unbalance you. |

### River-Mother — Haeren (Support; resource: The Name-Ledger; kit skills: reach)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Longer Ledger | — | The Name-Ledger holds [n] more names. |
| 4 | Last Washing | — | when an ally hits 0 HP, spend a Ledger entry to stabilize them. |
| 6a | Names Carried | Karma ≥ Upright | When a recorded ally falls, the Breath refund reaches every recorded ally, not only the River-Mother. |
| 6b | Own Name Twice | — | Your own name may be recorded twice per battle, and pays twice. |

### Ironbrand — Kero (Berserker; resource: Scars; kit skills: heft, grip)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Thick Hide | — | Scar cap +[n] (B11 §3 sweeps caps 2 / 3 / 5 / 8). |
| 4 | Debt of Arms | — | trade current HP for a damage or buff spike on yourself or an ally. |
| 6a | Debt Collected | Karma ≤ Troubled | A Scar spent on an attack that downs its target is returned. |
| 6b | First Blood | — | The first Scar each battle is banked when combat starts, before any damage. |

### Lensbearer — Stuid (Buffer/Debuffer; resource: Clarity; kit skills: reach)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Wider Lens | — | Start each battle with [n] more Clarity. |
| 4 | Sacred Clarity | — | force a target's next action to be telegraphed to the whole party, at Fading cost. |
| 6a | Read Aloud | Fame ≥ Known | A forecast you reveal is shown to the whole party for that turn. |
| 6b | Kept Focus | — | One unspent Clarity carries into the next battle. |

### Husk-bearer — Vhorr (DoT controller; resource: Hunger; kit skills: keen)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Patient Hunger | — | Hunger cap +[n] (B11 §4 sweeps 3 / 5 / 8). |
| 4 | Nothing Wasted | — | A kill from your damage-over-time effect returns 1 Breath, including the final enemy's death. |
| 6a | Feed the Husk | Karma ≤ Troubled | A Hunger tick that kills refunds [n] Hunger. |
| 6b | Slow Rot | — | A Hunger tick survives one round after its target is cured or jammed. |

### Flamebinder — Vicoar (Artificer; resource: Instructive Failure; kit skills: heft)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Third Lesson | — | Failure Token cap +[n] (B11 §7 Vicoar table). |
| 4 | Second Casting | — | once per encounter, spend two banked tokens to turn a fizzle into a success after the fact. |
| 6a | Spectacular Failure | Fame ≥ Whispered | A fizzle in a populated zone banks two tokens: somebody saw it. |
| 6b | Carried Lesson | — | One banked token survives to the next battle. |

### Stormbearer — Ofshütje (Skirmisher; resource: Attribution; kit skills: heft)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Steadier Hand | — | Reroll one Attribution result per battle. |
| 4 | Tuned Thunder | — | an ability critical hit chains into a second, random effect. |
| 6a | Named Storm | Fame ≥ Known | Attribution rolls on the wider table B11 §6 proposes (tailed), not the shipped three rows. |
| 6b | Grounded | — | The lowest Attribution result is read as the next one up. |

### Oathclock — Pazzah (Controller; resource: The Ledger; kit skills: reach)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Longer Docket | — | Hold [n] more Sentences (B11 §7 budget caps). |
| 4 | Sequenced Verdict | — | bank a powerful delayed verdict that resolves on a fixed future turn. |
| 6a | Public Verdict | Karma ≥ Upright | A Sentence filed while an ally is adjacent cannot be Jammed. |
| 6b | Prompt Court | — | Sentences fall due one round sooner. |

### Locksmirk — Fickah (Trickster; resource: Rule-breaker; kit skills: loose)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Second Pick | — | Jam the Gears may wait and retry on ally turns as well as your own. |
| 4 | Jam the Gears | — | Spend 1 Soul to cancel an enemy's pending action and queued effects. If nothing is pending, Jam waits and retries on your turns. |
| 6a | Pocketed Gear | Karma ≤ Troubled | A Jam that cancels something refunds its Soul. |
| 6b | Jammed Twice | — | A Jam that finds nothing pending also delays the target's next action by [n] CT. |

### Threadwalker — Izhakel (Summoner/Debuffer; resource: Threads; kit skills: keen)

| level | perk | gate | effect |
|---|---|---|---|
| 2 | Fourth Thread | — | Hold [n] more contracts. |
| 4 | The Unspoken Term | — | bind Threads with more conditions and choose when to cash them in. |
| 6a | Known Contract | Fame ≥ Known | A bound enemy's first attack after binding is delayed [n] CT: it has heard what the thread costs. |
| 6b | Doubled Knot | — | A contract may be placed twice on the same enemy. |

## 3. Pandora shape (architecture, for Codex)

A new canon kind `perks`, one document per perk, generated like every other kind:

```json
{
  "schema": "weftlumin.perk.v1",
  "id": "mirrorblade-second-footing",
  "display_name": "Second Footing",
  "class_id": "mirrorblade",
  "level": 2,
  "slot": "resource",
  "gate": { "minimum_fame_tier": "", "minimum_karma_tier": "", "maximum_karma_tier": "" },
  "blurb": "Once per battle, repeating Strike or Guard a third time does not break Balance.",
  "effect": { "op": "", "value": 0 },
  "vault_id": ""
}
```

- `tools/seed_pandora.gd` `SCHEMAS` gains `"perks": {"noun": "perk", "schema": "weftlumin.perk.v1",
  "fields": ["id", "display_name", "class_id", "slot", "blurb", "vault_id"], "integers": ["level"]}`;
  the Weftlumin kind validates `class_id` against `ClassCatalog.ids()`, `level ∈ {2, 4, 6}`,
  `slot ∈ {resource, signature, capstone}`, and gate names against `Renown.FAME_TIER_NAMES` /
  `Renown.KARMA_TIER_NAMES` (the same check `NpcReactions.rule_is_valid` makes).
- `effect.op` is the one typed field: an enum Codex defines from the ten resource systems
  (`cap_delta`, `start_delta`, `carry_one`, `refund_on_kill`, `delay_ct`, …). A blurb is prose for the
  sheet; the op is what the engine reads. Unknown ops fail the bake, not the runtime.
- Runtime: a `PerkCatalog` autoload reads `data/generated/perks.json`; `PartyMember` gains
  `perk_ids: PackedStringArray` with an empty default, so old saves load without a schema bump
  (coordinate with #342 PR 1, which already takes the envelope v9 → v10). Level-up offers the
  `level` row for the member's `class_id` and filters gated capstones through `Renown.*_tier_at_least`.
- Character sheet: a Perks line under the class resource, using the existing `ds` type variations; no
  per-node overrides.

## 4. What this draft does not decide

- Every `[n]` (DeepSeek, with the B11 tables as the starting sweep).
- Skill points per level into the 22 skills (#285's other half) — unchanged by this draft; perks are
  additive to it, not a replacement.
- Whether a perk can be respecced — not in Chapter 1; a pick is a pick.

## 5. Answer format

```
perks: approved                 (or edit rows in place and say "perks: as edited")
perks karma gates: wait         (ship the four Karma capstones ungated until the act table lands) | gate
```
