# Session Intent Contract

**Created:** 2026-10-30
**Command:** `/octo:plan` — "revisit the roadmap as a senior game designer advising on how to achieve the vision"
**Owner:** Adam (solo dev)

## Job statement

Revisit the Chapter 1 roadmap (draft PR #528, `docs/roadmap-2026-10-30.md`) through a senior
game designer's lens and re-sequence it so Chapter 1 ships as a **playable, polished** game whose
first-served feeling is **Fallout-full freedom** (rulings 7–9: skill checks on objects, lockpicking,
stealing, barter, loot; class = identity, DRAMGID = what you can do; XP + skill points + perks).
The output is a production-ready revision: a ratifiable roadmap, owner rulings posed as one-line
answers, and GitHub-ready issues with acceptance criteria.

## Intent answers

| Question | Answer |
|---|---|
| Goal | Review/improve existing (the PR #528 roadmap) |
| Knowledge | Expert — owner knows the design; needs ordering and validation |
| Clarity | Clear requirements |
| Success | Clear understanding + Production-ready (roadmap + issues + acceptance criteria) |
| Constraints | Solo-dev capacity (prose and rulings are the bottleneck) + High stakes (first public release) |
| Core feeling to serve first | **Fallout-full freedom** (rulings 7, 8, 9) |
| Ship posture (R8) | **Playable and polished first** — hold 8–12 h; all phases run before gold; calendar follows |
| Rulings open to challenge | **Ruling 5, the ~100-mob scale floor only.** Party size, same-map combat, cap 6 / perks 2-4-6, and the rest stay fixed |

## Success criteria

1. The revised roadmap leads with the field game (ruling 7) and build expression (rulings 8–9), and
   says in one paragraph why that ordering serves the vision better than PR #528's Soul-first order.
2. Every phase names its owner rulings as one-line answers, its agent work, and its prose load
   separately, so solo-dev capacity is visible per phase.
3. The 100-mob challenge is argued with evidence (AI decision time, FR-904 status, encounter data),
   ends in a recommendation the owner can accept or reject in one line, and never silently changes
   ruling 5.
4. Each phase has binary acceptance criteria and an audit tool or test that reports the number.
5. Issues are file-ready (title, body, milestone, acceptance checks, do-not-decide boundary) and
   labelled per the role policy; none filed without the owner's go.
6. Nothing ratified is reopened except ruling 5; nothing in `docs/owner-decisions.md` is resolved
   silently.

## Boundaries

- Do not invent canon. Soul bands, enemy abilities, locations and NPCs come from the vault or the
  ruled packets, or are marked PROVISIONAL.
- Do not move the ship gates: Gate T-6 (outside testers) and FR-904 (rendered reference runs) stay.
- Do not reopen: episodic Chapter 1 as a unit, no Steam for gold, level cap 6, perks at 2/4/6,
  party-size ruling, same-map combat, the five-layer architecture, Pandora/vault ownership.
- Do not file, close, label or merge anything on GitHub without the owner's explicit go.
- Workers get bounded, non-recursive briefs; Claude owns design, sequencing and synthesis.

## Context

- Steam-launch milestone (due 2026-10-02) is historical; the 2026-10-16 assessment set realistic
  gold at early December with the episodic cut. The owner has now chosen polish over calendar.
- PR #528 (today) found the player side of combat strong and three loops thin: Soul spend side,
  enemy AI, companions. It sequenced Soul → enemies → company → field → hours → teach/test/polish.
- The owner's chosen first feeling (Fallout-full freedom) is PR #528's Phase 4, so the revisit is a
  re-sequencing question first and a scope question second.
- Open owner-list items touching this: 5 (Breath/Soul numbers), 7 (DRAMGID leftovers), 11a/11c
  (minimum skill set, loot density), 13 (playtesters), 14 (FR-904 run), 26 (R1–R9 from PR #528).
