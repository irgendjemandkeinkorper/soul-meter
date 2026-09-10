# Martial combat and defensive counterplay design

**2026-09-10 · Owner requested continued combat design.**

Produce the next packet identified in `docs/ideas/combat-gap-review.md`: weapon and
armor identity, concrete martial/defensive cards, explicit timing and terrain rules,
and one mixed encounter showing enemies using them. Preserve deity/element identity,
the existing five Arms skills, spell costs and persistent-world rulings. New tuning
is proposed playtest data, not a runtime change or a new ratified skill system.

- [x] Inspect existing actions, Guard paths, equipment records and Arms skills.
- [x] Author shared martial/armor/response contracts and weapon-family cards.
- [x] Specify enemy roles, a bounded mixed encounter and readable visual cues.
- [x] Check coverage, costs, links, timing and numerical acceptance examples.
- [x] Review and update the combat gap packet; prepare the documentation-only commit.

Scope boundary: this pass does not implement actions, repair Guard, grant new class
signatures, set final level/perk thresholds, redesign UI or change generated equipment.
Runtime verification must accompany the later implementation slices.

## Deliverables and evidence

- `docs/ideas/martial-action-cards.md`: nine weapon families across the five existing
  Arms skills; 27 unique, sequentially identified action cards with explicit AP/CT
  prices, targeting, power/utility limits, counterplay and visual direction.
- `docs/ideas/martial-combat-rules.md`: three armor profiles, six defensive cards,
  shared response/interrupt/displacement rules and explicit elemental/patron boundaries.
- `docs/ideas/martial-combat-encounter.md`: a four-character/three-enemy fixture with
  a separate rescue objective, finite resources and three persistent structures.
- Programmatic document audit: card counts/names, family/skill mapping, prices and
  table shape pass. Local links in the packet/review resolve. Fourteen arithmetic/
  state-model checks pass, including damage order, finite arrows, bounded shove/hazard
  events, material damage, objective deduplication and legal initial grid occupancy.
- Review clarified personal-defense precedence over Interpose, allowed one defensive
  response to a prepared attack without recursive reactions, preserved Stabilize's
  useful Balance action without refreshing an existing Guard, and corrected the
  30-integrity barricade example to four 9-integrity impacts. A Brace+Refrain example
  cannot invent the extra AP needed on a four-AP fixture.

These are specification checks, not Godot/runtime test results or balance evidence.
No runtime or generated data changed. Main-controller Guard resolution remains a
documented implementation gap. Numeric progression gates, full enemy rosters, class
signatures and the larger recovery economy remain subsequent design work.

The fourteenth numerical check compares equal-cost Great Cut and Crushing Blow at
fixture attack 9/defense 3: with AR 0/1/2 the results are 9/8/7 versus 8/8/8.
Crushing Blow bypasses up to 2 equipment AR, so each family has a useful physical
matchup without bypassing underlying actor defense or changing its action price.
