# Soul Meter design pillars

This is the short review sheet for new mechanics, content, and interface work. The full
game-design spec remains [`soul-meter-crpg-design-doc.md`](../soul-meter-crpg-design-doc.md);
the design system remains [`DESIGN_SYSTEM.md`](DESIGN_SYSTEM.md). This document turns both
into decisions a feature can be checked against.

## 1. The world remembers

Choices are durable, legible, and specific. A consequence should appear in at least one
ledger, flag, dialogue branch, quest state, encounter, or location change. The player should
be able to discover what changed and why.

## 2. Balance is tension, not morality

The Soul Meter and the Balance Gauge are measures of pressure, resonance, and cost—not a
simple good/evil score. Order, Chaos, and equilibrium should all be tempting, useful, and
dangerous in different ways.

## 3. Speech, knowledge, mercy, and force are peer verbs

Conversation is not a pause between gameplay systems. A named weakness, a remembered oath, a
careful retreat, and a decisive strike can all be valid ways through a problem. Nonviolent
outcomes must carry authored risk and consequence rather than functioning as a free skip.

## 4. Every system must feed dialogue, consequence, or the Meter

New mechanics need a clear relationship to at least one of these three spines. A system that
only adds inventory busywork, damage inflation, or content volume without changing what the
world knows is a candidate for cutting.

## 5. The interface is carved, ledgered, and slightly wrong

UI should feel like an instrument made by an exacting civilization that understands horror
administratively. Exact numbers, visible requirements, restrained motion, notched stone,
tarnished metal, and uncomfortable explanations are part of the fiction—not decoration added
after the mechanics.

## Feature review checklist

Before merging a feature, answer these questions in its issue or design note:

- Which pillar does it strengthen?
- What durable fact, ledger entry, or visible world echo does it produce?
- What does the player understand before committing to it?
- What is the cost, risk, or temptation?
- Does the feature still work if the player chooses restraint, speech, retreat, or equilibrium?
- Which automated test and which manual smoke step prove it works?

## Cut-list signals

Pause and revisit scope when a proposal:

- adds a meter that duplicates Soul, Balance, Reputation, or Renown;
- hides a requirement until after the player commits;
- makes a choice consequence-free because it is the “nice” option;
- introduces a new accent, font, or rounded control outside the design system;
- requires a second source of truth for data already owned by Pandora or the lore vault.
