# UI rework: audit and plan (2026-11-01)

Status: **APPROVED by the owner, 2026-11-01.** U1 (conversation) is built, awaiting owner
review; see "U1 as built" below. U2 and U3 follow as separate PRs.

Owner, 2026-11-01: *"we also need to do a heavy rework of all the UI buttons and info — it's so
busy and doesn't really convey information we need, especially in conversations."* (Asked in a
session that routed it to Site K by mistake; the owner confirmed the same day it was meant for
Soul Meter.)

Captures: `docs/qa/ui-audit-2026-11-01/`, rendered from `main` (`9e1ee0f9`) under Xvfb at
1920×1080. The conversation menus come from `test/manual/ui_audit_capture.gd`, because the
screenshot sweep photographs only each conversation's opening line. The rest comes from
`test/manual/screenshot_sweep.gd`.

Out of scope here: the combat bar was just reworked by #552 and #556 (one bar, eight-slot
hotbar). Chargen is out too, apart from the summary bug noted under panels.

## The test every screen has to pass

A screen earns its pixels if it answers the player's question at that moment, in this order:

1. **Conversation.** Who is speaking, and what did they say? What can I say back? What does
   each answer *cost* (Soul), *change* (which faction or ledger, which way, by how much) and
   *risk* (which skill check, at what chance)? If I can't say something, why not, and what
   would unlock it?
2. **Field.** Where am I going next, and how is my party holding up?
3. **Panels.** The state of one thing (a character, the quests, my standing, my pack) with at
   most a few verbs to change it.

Anything that answers none of these is noise. The Soul gauge is the exception: it is the
title mechanic, and the design system wants it on every screen. That means **one** gauge,
not two.

## Findings

### Conversation: the worst offender

| # | What the player sees | Evidence |
|---|---|---|
| C1 | **Every authored branch is offered**, including quest bookkeeping that can never apply right now. Iris's hub lists **15 choices, 10 of them locked**, among them "How are the sprigs?" three times. The Council elder lists **8, 6 locked**, with "The Dorthkor charge is finished." and "About the count I brought you." twice each. The real choices sink below the fold, and the list scrolls. | `01`, `03` |
| C2 | **Locked choices never say why.** The Undertone check at the Council is dim with no reason or remedy. That breaks FR-606 ("a refusal must name its system and its remedy"). | `03` |
| C3 | **Effects are hidden behind prose.** "This grove is unregistered" runs Ssae-Seeders −6, Registry +4 and Infamy +5. The choice shows `[REGISTRY]` and "The Ledger will hold your name." Only Soul costs show as numbers (`-6 SOUL`). Every unfocused choice also prints its italic promise line, which doubles the menu's height. | `01` |
| C4 | **A skill check doesn't show its odds.** The tag reads `[UNDERTONE]`; the commit is a percentile roll against your skill, but the chance never appears. | `03` |
| C5 | **Nothing confirms a choice landed.** Reputation and Renown notices are held while the conversation pauses the tree and only appear after it closes, cut off from the line that caused them. | `02`, `ui/hud/consequence_notices.gd` |
| C6 | **The field HUD stays up under the conversation.** That means the key-hint strip, the objective lines, the party line and a **second Soul gauge**. The choice list runs under the HUD bar at the bottom edge. World labels ("Loamroot Sprig", a half-cut "RETURN TO DOM") show through the scrim. | `01`–`03` |
| C7 | **The layout floats.** A small portrait card, then dead space, then the gauge. The scrim's hard edge at 34 % height cuts across the world. | `01` |

### Field HUD

| # | Finding | Evidence |
|---|---|---|
| F1 | **A permanent key-hint strip** of eight bindings sits top-left and never fades. | `04` |
| F2 | **The bottom bar is three lines of small text.** Objective, then GO TO, then every member's `HP 44/44 BREATH 15/15` in mono. There are no bars or portraits, and at the ratified party size of 4–6 the line truncates. | `04` |
| F3 | **World labels use the engine's default sans font.** The design system says no sans. | `04` |

### Panels

| # | Finding | Evidence |
|---|---|---|
| P1 | **Two shells.** Inventory and the character sheet use the framed stone shell; Party, Journal and Standing use a bare page with a **full-width BACK bar**. `design/ui-shell-conventions.md` already names this (#149); it was never migrated. | `05`–`09` |
| P2 | **Party is nearly empty.** A portrait, one HP bar stretched across 1,270 px, one line of bio and a "Character Sheet" button. The character sheet repeats the same roster. | `05`, `06` |
| P3 | **The character sheet leads with 22 skill rows.** Each carries a dim `+5% (1 PT)` button, even with 0 points to spend. DRAMGID attributes are below the fold, and the roster truncates names ("Vex the Unbowed (L…"). | `06` |
| P4 | **The journal spends six lines per quest.** `ACTIVE` above the title and `STATE · Active` below it say the same thing. The next objective repeats the header, which also repeats the HUD. The back button sits below the fold. | `07` |
| P5 | **Standing's empty state** is a large empty box beside "No faction has entered your name". | `08` |
| P6 | **Inventory selection fills the tile solid bronze.** The design system says selection is a violet edge, and bronze is the screen's one accent. EQUIP and DROP show before anything is selected. | `09` |
| P7 | **The chargen summary can push its navigation row off-screen**, about 8 px when a long roll wraps the creation-points line. LIKENESS prints a raw id (`likeness_02`). | `docs/qa/chargen-quick-start-2026-11-01/03-summary-stamped.png` |

## The plan

Three passes, conversation first. Each is one PR with before/after captures from the same
harnesses. All of it is presentation only: no change to dialogue prose, ledgers, checks,
saves or flow. Styling stays in theme variations and DS tokens.

### U1: conversation (biggest win; about 4–6 hours of agent time)

1. **Offer only what can matter now.** A locked choice stays visible, dim with its reason,
   only when the player could *earn* it: a skill or attribute check, faction standing, Renown
   or Soul. A choice locked by quest state, flags, NG+ or patron is hidden. The balloon
   classifies by the response's `condition_as_text`, and an authored `[#lock=show]` /
   `[#lock=hide]` tag overrides it. Iris's hub drops from 15 rows to 5–6; the Council's to
   2–3. *(Owner decision 1: this refines the design system's "locked options must be seen"
   rule. Owner: only earnable locks.)*
2. **Every lock names its system and remedy** in one mono line, per FR-606. For example:
   `Undertone 40 — you have 12`, `Ssae-Seeders standing 15 — you have 8`.
3. **Each choice shows what it changes, compactly.** A row carries the line plus a strip of
   effect chips: Soul cost, faction ± and Renown or Infamy ±. The balloon reads these from the
   branch's own `do` mutations (`Reputation.record`, `Renown.gain_*`,
   `GameState.set_soul_meter`), so nothing is authored twice. The italic promise line shows
   only on the focused choice. *(Owner: exact numbers.)*
4. **Checks show their odds:** `[UNDERTONE 62%]`, your effective chance from
   `SkillCheck.preview`. *(Owner: show the chance.)*
5. **Effects land on the line.** When a choice records Reputation, Renown or Soul, a one-line
   ledger strip under the reply prints it (`Ssae-Seeders +8`). The post-conversation notices
   stop repeating what was already shown.
6. **Clear the stage.** While a conversation is open the field HUD hides, leaving one Soul
   gauge (the balloon's). World labels fade, and choices never run under a bar.
7. **Layout (design call, not an owner question):** keep the centred column the design
   system specifies, but make it one block anchored to the bottom: portrait and name beside
   the line, the gauge at the block's right, choices below without scrolling. The scrim
   becomes a soft gradient instead of a hard band.

#### U1 as built (2026-11-01)

Captures: `docs/qa/conversation-u1-2026-11-01/` (after), against `docs/qa/ui-audit-2026-11-01/`
(before), from the same harness.

- **Rows:** Iris's hub went from 15 rows (10 locked) to 6 (1 locked, with its reason). The
  Council went from 8 (6 locked) to 3 (1 locked).
- **Classification** reads the compiled condition tokens, not `condition_as_text`
  (`ui/dialogue/dialogue_choice_info.gd`). Guard parts are evaluated first, in authored order,
  so Dialogue Manager's `and` short-circuit still protects comparisons such as
  `get_flag("quest_1_resolution") == "returned"`.
- **Odds** render as the tag, then the chance (`[UNDERTONE] 62%`), on open checks only. A
  locked check shows its bar in the reason line instead.
- **Effect chips** are read from a branch's leading `do` lines. Karma is never shown, and it
  is not marked as shown, so its field notice still appears after the conversation.
- **Clearing the stage** hides the field HUD's children (not its layer, so combat's own hide
  is untouched) and fades every world-space label, including the building names Dom paints
  over its facades.

### U2: field HUD (about 2–3 hours)

1. **The key-hint strip shows until each key has been used once**, then hides. A Settings
   toggle brings it back.
2. **A party strip replaces the text line.** One small portrait per member with an HP bar and
   a Breath bar (mono numbers on hover or focus), sized for six.
3. **The objective is one line** (the quest step). "GO TO" appears only when the target is in
   another area.
4. **World labels move to a DS type variation** (Cinzel, small caps), not the default sans.

### U3: panels (about 4–6 hours)

1. **One shell for every panel** (`Screen._make_shell()`): header, body and HUD bar with the
   gauge rightmost, and BACK bottom-left at standard width. This closes #149.
2. **Party merges into the character sheet.** One roster column; the sheet opens on a summary
   page (portrait, HP/Breath, DRAMGID, equipped kit, perks). Skills move to their own tab, and
   their `+` buttons appear only when points are available.
3. **Journal:** title, one objective line and a one-line where/who row. The state badge
   appears only when it isn't ACTIVE. The duplicate header objective goes.
4. **Standing:** a compact empty state; once there are entries, the faction list and its
   detail.
5. **Inventory:** selection becomes a violet edge, and EQUIP/DROP appear on selection.
6. **Chargen summary:** the summary page scrolls instead of pushing its navigation row off
   screen, and LIKENESS shows the likeness label.

## Owner decisions

Asked inline on 2026-11-01. Answers are recorded below and in `docs/owner-decisions.md` §5.

| # | Question | Answer |
|---|---|---|
| 1 | Which locked choices stay visible? | **Only earnable locks.** A skill/attribute check, standing, Renown or Soul lock stays visible, dim with its reason. Quest-state, flag, NG+ and patron locks are hidden. An authored tag overrides either way. |
| 2 | What a choice shows about its effects | **Exact numbers.** Mono chips with the real deltas, read from the branch's own mutations. The prose promise shows on the focused choice only. |
| 3 | Show skill-check odds? | **Show your chance**, e.g. `[UNDERTONE 62%]`. A locked check names the bar. |
| 4 | Approve the plan, and build order | **Approved; U1 first**, with before/after captures and owner review; then U2 and U3 as separate PRs. |
| 5 | Showing odds and exact effects conflicts with the 2026-08-28 Wave 0 ruling 2 (`docs/fallout2-adoption-spec.md`: tagged checks, no numbers). Which wins? | **Today supersedes**, for conversations: odds and exact effect chips are shown. Ruling 2 is marked superseded. Field notices outside a conversation stay non-numeric, as built. |
