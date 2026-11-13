# Character creation overhaul — plan (2026-11-02)

Status: **approved by the owner 2026-11-02** ("approve; build it"); **B1–B5 built 2026-11-02** on
the same PR. Tones in the preview: "show it honestly"; the mechanic is owner-list item 27.
Stacked on `claude/chargen-summary-fix` (#561). Where the build differs from this plan, see
"As built" below.

Mockup: `docs/qa/chargen-overhaul-2026-11-02/01-mockup-calling-tab.jpg`, rendered from
`mockup.html` in the same folder. The mockup's numbers are taken from the game data (classes,
kits, resources, signatures, AP costs, element emblems, the seven measures). It shows the
CALLING tab with the Crown of Embers hover card open.

## Owner rulings this plan implements (2026-11-02 playtest)

1. **One screen, tabs, ready anytime.** Every choice is pre-rolled when the screen opens. The
   tabs ORIGIN · CALLING · MEASURES · NAME can be visited in any order. The portrait and a live
   summary stay visible. BEGIN works from any tab.
2. **Ability tiles with hover cards**, built from the existing action tables. A class with no
   linked abilities is listed as a gap; abilities are never invented.
3. Plan and mockup first (this document), then the build (about one day).

The playtest note behind it: the current nine-leaf form has too much friction, and it is not
clear which abilities you are choosing. The model is Divinity: Original Sin's class preview.

## What the player sees

| Area | Contents | Notes |
|---|---|---|
| Header | Title, RANDOMIZE ALL, QUICK START, BEGIN | Same buttons as today. RANDOMIZE becomes RANDOMIZE ALL beside the per-tab roll. BEGIN moves up from the last leaf. |
| Entry column (left, always visible) | Likeness plate, name field, one identity line, HP · Breath · Scars, the seven measures, an "In a fight" 8-slot hotbar preview | Replaces leaf 9 (the summary). It updates live on every change. |
| Tabs | ORIGIN · CALLING · MEASURES · NAME, plus ROLL THIS TAB | A dot marks a tab that still needs something. MEASURES shows unspent skill points. |
| Footer | CANCEL ENTRY · one status line naming what blocks BEGIN · the Soul gauge | The status line replaces per-leaf validation text. |

The screen opens on **CALLING**, because that is the choice the playtest said was unclear. Tab
order and keyboard navigation run left to right.

### Mapping the nine steps to four tabs

| Today's step (`ChargenSteps.STEPS`) | Tab |
|---|---|
| ancestry, background | ORIGIN |
| patron (class + kit skill), discipline, elements (Major/Minor tones) | CALLING |
| attributes, skills (creation buys) | MEASURES |
| identity (name, epithet, flaw, likeness) | NAME |
| summary | Retired. The entry column is the summary. |

`ChargenBuild` and its `validate(step_id)` are unchanged. Each tab validates the steps it owns.
BEGIN calls `is_complete()`. Save data and `to_party_member()` are untouched.

### BEGIN and the name

- The build is pre-rolled, so it is already complete except for the name. Names are never
  rolled because there is no name pool, and inventing one would be new canon.
- BEGIN with a blank name opens NAME and focuses the field. With a name, BEGIN starts the game
  from any tab.
- Unspent **skill** points are allowed and carry into play, as today. Attribute points must
  still all be placed, but the pre-roll always places them.

### CALLING tab

1. Ten class tiles. Each shows the emblem of the class's suggested Major tone, the class name,
   and its role.
2. Class detail: patron, role, Kit (with the arms-skill choice where the class offers two),
   Resource + blurb, Signature + blurb, Tones (Major/Minor chips, "Change on the wheel…"), and
   Discipline chips with their one-line descriptions.
3. Ability tiles in three groups:
   - **What <class> adds**: actions only this class can use (its resource commands and the
     actions locked to its patron).
   - **Your tones**: spells in the held Major and Minor tones.
   - **Every body can**: the universal actions, shown small, with "+N more".
4. Hovering or focusing a tile opens a card with name, AP/Breath/Soul cost, target, area, tone,
   and the effect line from `CombatAction.summary()`. No new effect copy is written: 51 of the 62
   player actions carry a `description`, and the other 11 are core commands whose `summary()`
   already writes their effect.
5. A locked tile (for example a triad-tier spell) shows its lock and the requirement from
   `CastingGate`.

## One kit query, shared with combat

Today, combat's `_query_effect_gate` decides patron locks, the class resource's
`accepts_command` decides resource actions, and the hotbar derives "in kit" from those
refusals. The preview must say exactly what combat will allow.

- **New `KitPreview`** (`globals/chargen/kit_preview.gd`, static): given a class id, held tones,
  and attributes, it returns the three tile groups plus lock reasons. It reads the patron lock
  and the resource commands through the same helpers combat uses. Those checks are extracted
  from `CombatController._query_effect_gate` into a small static function that both call, with
  no behaviour change.
- **Hotbar preview** calls the battle bar's existing default fill (made static). Fill order was
  ruled "Keep as built", so the preview shows the bar the battle will slot. That fill lives in
  #556, which is not under this branch, so the entry column's "In a fight" row lands as a
  follow-up once #556 is on `main`. Until then the column ends at the seven measures.
- **Parity test**: for each of the 10 classes, every tile in "What <class> adds" is allowed by
  combat for a member of that class, and blocked for a member of every other class.

## Gaps found while planning (shown, not filled)

1. **Tones do not affect casting yet.** `SkillCheck.tone_bonus_for` has no caller outside
   tests. F3c (`docs/architecture-chargen-dramgid.md` §3) has not decided how the Major feeds
   casting. So every class can cast every spell that is not locked to a patron. Ironbrand, for
   example, can also cast 14 spells in other tones. The preview says so ("+14 in other tones")
   rather than implying a lock. The battle bar's fill also ignores tones, so the mockup's hotbar
   (all Khash/Mozh) is illustrative. The real preview shows whatever the fill picks.
   Ruled 2026-11-02: show it honestly; the mechanic is owner-list item 27.
2. **No class art.** The class tiles use the suggested Major's element glyph. Locksmirk has no
   suggested tones, so its tile shows a dash. Class plates go on the art list.
3. **Vel and Zhur have no spells.** River-Mother and Lensbearer suggest a Vel minor, and
   Stormbearer suggests a Zhur major. Their "Your tones" row shows "No Vel spells yet" rather
   than borrowing from another tone.
4. **Patron-locked spells sit inside tone lists.** For example, Sentence of Ash and Verdict by
   Fire are Khash spells locked to Pazzah. They appear under their own class's "adds" group
   and never under another class's tones.
5. **Stormbearer adds no actions of its own.** Ofshütje's Attribution is passive, with no class
   command and no patron working. Its "What Stormbearer adds" group reads "No actions of its
   own yet". `test_kit_preview.gd` pins this gap list.

## Build slices (about 1 day after approval)

| # | Slice | Time | Proof |
|---|---|---|---|
| B1 | `KitPreview` + gate extraction + parity test | 2 h | Unit tests; the combat suites stay green. |
| B2 | Screen shell: header, entry column, tabs, footer, pre-roll on open, BEGIN rules | 3 h | Integration test: open, then BEGIN after typing only a name. |
| B3 | CALLING tiles + hover cards | 2 h | Test: tiles match `KitPreview`; the card text is `summary()`. |
| B4 | ORIGIN / MEASURES / NAME: port the existing leaf widgets into tabs, ROLL THIS TAB | 2 h | Port `test_character_creation.gd`; RANDOMIZE/QUICK START tests stay green. |
| B5 | Captures (1920×1080, each tab plus a hover card), full tree | 1 h | `docs/qa/chargen-overhaul-2026-11-02/`. |

Boundaries: the build does not change `ChargenBuild` fields, save data, `GameFlow` travel, the
randomizer's rules, or any combat behaviour beyond extracting the shared gate helper. All
styling goes through theme type variations and DS tokens.

## As built (2026-11-02)

What changed from the plan above while building, and why:

1. **The name field heads the entry column**, so it is visible from every tab. The NAME tab
   holds the likeness, epithet, and flaw. BEGIN with a blank name focuses that field and does
   not switch tabs.
2. **Picking a class applies its suggested Major and Minor.** Before, the Elements step
   pre-filled them only when blank. After a pre-roll they were never blank, so browsing the
   class tiles kept the rolled tones. The tones can still be changed afterwards.
3. **Rolled skill points are re-spent when browsing classes.** `select_class` refunds creation
   buys, so browsing showed "12 PTS" unspent. While the purchases are rolled ones, the screen
   re-spends them with the randomizer's own rule. Once the player buys or refunds a point by
   hand, nothing is re-spent.
4. **The class tiles show the name and the tone emblem.** The role moved to the tooltip and the
   detail heading, so all ten tiles fit one row at 1080p. "Every body can" lists the whole
   common kit (no "+N more"), because it fits.
5. **Tier locks are on the card, not the tile.** Whether a chord or triad working can be cast
   depends on Var Harmony in battle, so the tile stays open. The card reads "A chord working:
   Var Harmony N or higher in battle." Only signature commands without their perk are dimmed.

Still deferred: the "In a fight" hotbar row (it needs #556's fill on `main`).

Code: `globals/combat/kit_gate.gd` (the shared gate), `globals/chargen/kit_preview.gd`,
`ChargenSteps.TABS`, `ChargenBuild.copy()`, `ChargenRandomizer.roll_tab()` and
`spend_creation_points()`, the `Chargen*` theme types in `ui/theme/theme_builder.gd`, and
`ui/screens/character_creation.gd`. Tests: `test_kit_preview.gd` (5),
`test_character_creation.gd` (13, rewritten), `test_chargen_quick_start.gd` (3),
`test_chargen_randomizer.gd` (6). Captures: `docs/qa/chargen-overhaul-2026-11-02/`.

## New player-facing strings (for approval with the build)

Tabs and buttons: `ORIGIN`, `CALLING`, `MEASURES`, `NAME`, `ROLL THIS TAB`, `RANDOMIZE ALL`,
`BEGIN`, `  ·  %d PTS` (on the MEASURES tab).

Entry column: `Name this person`, `The one thing never rolled.`, `HP %d  ·  BREATH %d`,
`%s of %s` (class of patron), `ENTRY READY`, `ENTRY PENDING`.

CALLING: `PATRON  ·  CLASS`, `%s  ·  PATRON %s  ·  %s`, `%s — retired pairing with %s.`,
`KIT  ·  TRAINS %s`, `KIT  ·  CHOOSE THE ARMS SKILL IT TRAINS`, `RESOURCE  ·  %s`,
`SIGNATURE  ·  %s`, `TONES  ·  MAJOR AND MINOR BEGIN TRAINED`, `Root Note Mastery`,
`DISCIPLINE  ·  HOW THE BODY MOVES`, `%s  %s  Favours %s.`, `WHAT %s ADDS`, `YOUR TONES`,
`YOUR TONES  ·  %s` (joined with ` AND `), `EVERY BODY CAN`, `No actions of its own yet.`,
`No %s spells yet.`, `+%d spells in other tones — every class can cast them today.`

Hover card: `%d AP`, `Tone %s`, `Area %s`, `A %s working: Var Harmony %d or higher in battle.`
(`chord` or `triad`).

ORIGIN, MEASURES, NAME: `PEOPLE`, `BACKGROUND  ·  TWO TRADES TRAINED, THE ROOT NOTE MASTERED`,
`%s\n%s\nLeanings: %s`, `THE SEVEN MEASURES  ·  FIXED AT CREATION`, `%d MEASURE POINTS UNSPENT`,
`EVERY MEASURE POINT PLACED`, `SKILLS  ·  THE CREATION POOL`, `Each +5% step costs 1 point up
to 50%, 2 to 75%, 3 to 95%. ◆ marks a Trained tag. Unspent points carry into play.`,
`LIKENESS OF RECORD`, `THE PUBLIC RECORD`, `The name sits at the top of the entry, on every tab.`

Status line: `Name the entry to begin`, `%d skill point(s) unspent — they carry into play`,
`Entry ready — BEGIN when you are`.
