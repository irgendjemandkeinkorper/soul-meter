# Packet B: Grumbrand and Pozor's reading institutions

Status: **Pending human canon decision**

## Claim under review

Grumbrand describes the Lensbearer College as the body that would take a confessional-style "true
reading" of his life and put it on record. He then distinguishes his right to silence from the
Circle of Readers' power to take the account. The vault makes the College an optics and lens-craft
institution and makes the Circle the archival authority; it does not assign the College a personal
life-reading or confessional office.

## Exact game locations

- `dialogue/companions/old_grumbrand.dialogue:12-14` — the settling, Stuid's doctrine, and the
  College's proposed true reading.
- `dialogue/companions/old_grumbrand.dialogue:15-17` — College-reading branch and letter to Pozor.
- `dialogue/companions/old_grumbrand.dialogue:19-21` — private-mercy branch and the Circle's
  asserted power to take a record.
- `quests/old_grumbrand_the_last_reading.tres:8-12` — quest title, description, objective, giver,
  and camp location.

## Vault citations

- `factions/lensbearer-college.md:2-11` — the College is a Pozor-seated scholarly college of
  lens-craft and reading-optics, aligned to the Circle.
- `factions/lensbearer-college.md:17-23` — its stated work is grinding lenses, working resin-glass,
  and supplying instruments through which the archive is read.
- `factions/lensbearer-college.md:25-36` — it is seated in Pozor, sits under the Circle, and serves
  as instrument-maker to the Scriptorium and Starwell readers.
- `factions/circle-of-readers.md:17-29` — the Circle governs through archive mastery; its certified
  copies and archival services are the continent's memory-of-record.
- `factions/circle-of-readers.md:31-34` — the Lensbearer College sits in the Circle's ruling body;
  that relationship does not by itself transfer archival authority to the College.
- `cities/pozor.md:43-49,65-68` — Pozor separates its archival government from its lens and
  resin-glass exports while naming both the Circle and College in the ruling body.

Vault root used for these read-only citations:
`/home/adamjroder/projects/dramgid-vault/`.

## Conflict nature

The dialogue is compatible with Pozor's theology of preservation, but it assigns a specific
pastoral and record-taking function to the wrong documented institution unless "true reading" is
a currently unstated Lensbearer rite. It also implies that the Circle may compel or claim a private
life record. The vault establishes broad archival authority, not a right to take testimony from an
unwilling person.

## Player-facing consequences

- Ratification expands the Lensbearers from instrument-makers into ritual readers of whole lives.
- Reassignment to the Circle keeps the public-versus-private moral choice but changes who Grumbrand
  writes to and who controls the resulting record.
- Ratifying compulsory Circle authority makes the private branch a refusal of a real institution,
  not merely Grumbrand's fear or rhetoric, affecting how players read Pozor's government.

## Bounded ruling options

1. **Ratify a Lensbearer rite.** Establish that the College uses its optics in voluntary Stuidian
   life-readings and deposits the resulting record with the Circle. Benefit: preserves current
   dialogue and binds craft to theology. Cost: materially expands the College's remit.
2. **Assign the record to the Circle.** Make a Circle archivist or Reader conduct the life account;
   Lensbearers provide instruments only if needed. Benefit: follows the vault's documented division
   between lens-craft and archival authority. Cost: requires targeted dialogue and cause-text edits.
3. **Make the reading private and non-institutional.** Treat it as a personal Stuidian rite that
   Grumbrand may later offer to the Circle. Benefit: preserves consent and avoids granting either
   institution a new office. Cost: loosens the quest's direct tie to Pozor's named institutions.

## Canon-conservative fallback

Use option 2, and phrase Circle involvement as voluntary. This follows the vault's explicit
institutional division without inventing a coercive archival right; the College remains the maker
of reading instruments rather than the taker of a life confession.

## Byte-diff evidence: no prose bleed

Baseline: commit `6cf72ae2232f95453b095826fcc028828ff5c0a3`.

Selection: UTF-8 bytes of working-tree dialogue lines 13, 15, 17, 19, and 21, in order, each
separated and terminated by LF. These are the disputed institutional prose lines; resolver script
calls are excluded. They match baseline `HEAD` lines 13, 15, 18, 20, and 23 exactly; later lines
moved when the resolver-contract edit removed preceding direct completion-flag calls.

- Working-tree SHA-256: `763824654aa11105a92d93ae317ae00042ce2c832da867e3e8ae01a423a51c73`
- `HEAD` SHA-256: `763824654aa11105a92d93ae317ae00042ce2c832da867e3e8ae01a423a51c73`
- Selected byte count: `778`
- Result: **byte-identical**

## Review record

Reviewer: _Unassigned_

Review date: _YYYY-MM-DD_

Decision: _Pending; choose option 1, 2, or 3 and record consent/authority constraints_
