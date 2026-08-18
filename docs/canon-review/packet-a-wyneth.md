# Packet A: Wyneth and the Hospice Chain in Dom

Status: **Pending human canon decision**

## Claim under review

Wyneth says her first patient was at the Hospice Chain, that he held a line at Dom, and that Dom
can answer for him on a wall. The Hospice Chain's presence in Dom is already supported by the
vault. The unresolved extension is whether the muster-roll and wall are established Chain or Dom
memorial practices, and whether Wyneth served at that specific house.

## Exact game locations

- `dialogue/companions/wyneth_hallow_tide.dialogue:12` — first patient at the Hospice Chain;
  patient held a line at Dom.
- `dialogue/companions/wyneth_hallow_tide.dialogue:15-17` — public muster-roll branch and Dom wall.
- `dialogue/companions/wyneth_hallow_tide.dialogue:19-21` — private-ledger branch.
- `quests/wyneth_hallow_tide_kept_name.tres:8-12` — quest title, description, objective, giver,
  and camp location.

## Vault citations

- `factions/hospice-chain.md:2-11` — the Chain is a Deivel-seated, Haeren-aligned,
  continent-spanning religious order.
- `factions/hospice-chain.md:22-26` — its houses tend the dying and its work is tied to Vael
  Name-Ledgers and remembrance.
- `factions/hospice-chain.md:30-33` — explicit support: the Chain keeps a hospice in Dom's
  Drownedmouth harbor.
- `factions/hospice-chain.md:48-51` — naming, remembering, and ledgering the dead are central to
  the Chain's vocation.
- `factions/vharrowport-hospice-keepers.md:21-25,36-40` — a distinct hospice order works under
  local River-Mother jurisdiction alongside the continent-wide Chain, showing that hospice
  institutions should not be treated as interchangeable.

Vault root used for these read-only citations:
`/home/adamjroder/projects/dramgid-vault/`.

## Conflict nature

There is no direct contradiction in placing a Chain hospice in Dom; the vault states that fact.
The dialogue adds three unratified specifics: Wyneth's service there, a patient attached to Dom's
military history, and a public wall/muster-roll remembrance procedure. Those details could become
canon through player-facing dialogue even though the vault currently establishes only the house,
its keepers' protection, and the Chain's general ledger theology.

## Player-facing consequences

- Ratification anchors Wyneth's biography in Dom and connects her healing ethic to a named
  military casualty.
- The public branch establishes Dom as willing to memorialize the patient; the private branch
  frames Wyneth's personal ledger as sufficient remembrance.
- A later contradiction would require visible dialogue revision and could change the moral meaning
  of the branch choice, even though no gameplay schema is involved.

## Bounded ruling options

1. **Ratify the current local practice.** Confirm Wyneth served at the Dom Chain house and that a
   Dom muster-roll wall can receive the patient's name. Benefit: preserves the strongest place tie
   and all current branch text. Cost: adds institutional and military-remembrance canon.
2. **Ratify the house and Wyneth, narrow the record.** Keep her first patient at the documented Dom
   hospice, but replace the wall/muster-roll language with a generic public record maintained by an
   appropriate Dom authority. Benefit: preserves biography and choice structure while avoiding an
   unsupported Chain custom. Cost: requires a small prose pass after approval.
3. **Keep the event geographically unspecified.** Retain a Chain patient and the public/private
   remembrance choice, but remove the claim that Wyneth served in Dom and that Dom owns the record.
   Benefit: minimizes new place canon. Cost: weakens the quest's connection to Chapter One.

## Canon-conservative fallback

Use option 2. It preserves the vault-confirmed Dom hospice and the quest's public-versus-private
choice while declining to canonize a specific memorial wall or Chain-controlled muster-roll.

## Byte-diff evidence: no prose bleed

Baseline: commit `6cf72ae2232f95453b095826fcc028828ff5c0a3`.

Selection: UTF-8 bytes of working-tree dialogue lines 12 and 17, in order, each separated and
terminated by LF. These are the disputed institutional prose lines; resolver script calls are
excluded. They match baseline `HEAD` lines 12 and 18 exactly; the second line moved when the
resolver-contract edit removed a preceding direct completion-flag call.

- Working-tree SHA-256: `f4b53a829395c1f7c611671209a8eb3157d978f7f21a4acc7117eb3d31b55504`
- `HEAD` SHA-256: `f4b53a829395c1f7c611671209a8eb3157d978f7f21a4acc7117eb3d31b55504`
- Selected byte count: `314`
- Result: **byte-identical**

## Review record

Reviewer: _Unassigned_

Review date: _YYYY-MM-DD_

Decision: _Pending; choose option 1, 2, or 3 and record any approved wording constraints_
