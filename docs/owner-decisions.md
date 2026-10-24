# Owner decisions — running list

The one place for everything that is waiting on Adam: rulings, approvals, and things only the
owner can provide. Agents add to it and never resolve an item silently. Started 2026-10-19.

**How to answer:** reply in chat with the item number and your answer (`3: B`), or edit the
item in place. When an item is done, an agent strikes it through with the date and moves it to
§5. One line is enough; the packet linked from an item has the detail if you want it.

**Effort column** is your time, not the agent's.

---

## 1. Rule now — blocks agent work

Nothing is blocking agent work as of 2026-10-22; that day's eight rulings are in §5.

## 2. Rule when you can — content and tuning

| # | Decision | How to answer | Your effort |
|---|---|---|---|
| 5 | **Breath / Soul economy numbers** — `docs/casting-economy.md` §(b). Every number there is PROVISIONAL: Breath costs per magnitude, `breath_max` by class tier, Luth restore, Mozh conversion, Soul overreach rate. | `5: ratify as proposed` or edit the tables in place | 15 min |
| 6 | **Class-resource numbers (B11)** — `docs/class-resources-numbers.md`. Four proposed values (three caps to 3, one tailed table), each flagged in place. Nothing is applied until you say so. | `6: ratify B11` or per-line changes | 10 min |
| 7 | **DRAMGID leftovers** — `docs/architecture-dramgid.md` §5. Open: (1) ratify the 22-skill table (RFC-0005) in the mono repo; (8) Fame raw vs Decorum-scaled, folded into item 1; (9) fizzle attribute canon-doc edit. Items 2–7 were implemented as recommended; say so and they close. | `7: 2–7 confirmed, 1 ratified` | 5 min |
| 8 | **Companion canon packets** — `docs/canon-review/`: Packet A (Wyneth and the Hospice chain), Packet B (Grumbrand and Pozor's reading institutions), Packet C (naming collisions), trust-language redlines, and the Serai-Lun +3 vs +6 Renown asymmetry (recommend +6). | One line per packet, e.g. `8A: as recommended` | 30 min |
| 9 | **Provisional prose review.** Files carrying `PROVISIONAL — CANON REVIEW REQUIRED`: `dialogue/council_elder.dialogue`, `dialogue/lower_trial_hall.dialogue`, `dialogue/main/unanswered_roar.dialogue`, `dialogue/dom_townsfolk.dialogue`. Added 2026-10-19 and unreviewed: Gaath's two "charge is finished" lines (`council_elder.dialogue`), Toma's two "left a word" lines (`toma_reedhand.dialogue`), the Marshal's "how will the roll record" line (`marshal_coiljaw.dialogue`). Added 2026-10-20 and unreviewed: the three Hollowmere NPC documents (`canon/hollowmere/characters/*.json`, lines and hook summaries) and the three Hollowmere district greeting/farewell pairs in `tools/seed_town_npcs.gd` (The Watch Stilt, The Reed Landing, The Approach), all generated into `dialogue/hollowmere_townsfolk.dialogue`. Also added 2026-10-20 (C25 / #262): the authored ambient dialogue for the four new locations in `dialogue/locations/{kesselford,ashlaren,long_verge,hollowmere}.dialogue` (20 NPCs, drafted from the approved proposals only). Added 2026-10-22 and unreviewed (item 10b): the Marshal's four "what did the field proof buy" read-back lines (`marshal_coiljaw.dialogue`) and Iris's three "how are the sprigs" read-back lines (`iris_illepah.dialogue`); the 20 NPC entities promoted into the Dramgid vault (`characters/{kesselford,ashlaren,long-verge,hollowmere}-*.md`) carry the same hook text. Also 2026-10-22 (item 1, option B): `dialogue/dom_fame_reactions.dialogue`, four Fame routes (Gerren Pike, Orrik Cinderjaw, Dorran Rask, Edda Broadmark). | Edit in place, or `9: approved` | 45 min |
| 11 | **Game-identity open questions** (`docs/game-identity.md`). (a) Minimum skill set for Chapter 1: content checks 10 of 22 today — undertone, unweave, sway, slip, recall, wayfinding, varum, strain, sounding, beastbond. Bellow is never checked although Karma feeds it. (c) Loot density target for a field game with a Mirror Shop. ~~(b) fleeing ambient fights~~ ruled 2026-10-22: yes, by leaving the alert radius. — filed as #506 (ratify the shipped D7 rule, drop the PROVISIONAL prefixes, strike the open question, set-piece regression test); PR #510 open 2026-10-24.| `11a: the 10` or add names; `11c: a number or defer` | 5 min |
| 12 | **Steam.** Price $9.99 vs $19.99, release date, and whether the Steamworks partner account exists (30-day first-release wait after the fee clears). | `12: $X, date, account yes/no` | 5 min |

## 3. Provide — things only you can do

| # | Item | What to do | Your effort |
|---|---|---|---|
| 13 | **Playtesters for Gate T-6 (#93, #301).** 6–8 outside testers; kit and protocol in `docs/playtest-recruitment.md` and `docs/playtest-protocol.md`; results go in `docs/playtest-packet.md`. The only human-gated ship criterion. | Recruit, run, paste the filled packet | Hours, spread out |
| 14 | **FR-904 reference-hardware run (#175).** Headless reports 0 draw calls, so the 60 fps floor is unverified. Run the runbook on the real machine with a display and paste the frame times. | Follow `docs/testing.md` FR-904 section | 30 min |
| 19 | **GitHub clicks** (the agent's `gh` writes are blocked by the permission classifier). Merge PR #504 (sweep reads every hub) and PR #505 (today's rulings and code); then the #342 stack in order: #507 (world map from canon), #508 (fast-travel hubs), #509 (doors), retargeting each to `main` after the one below merges, then close #342; merge PR #510 (flee by distance ratified, closes #506 on merge); then draft PR #511 (#285 perks slice 1, stacked on #505: retarget to `main` after #505 merges); close #353 (runbook landed in #503) and #298 (Gemini pipeline dropped for gold, item 15; the PR #457 icons stay under your art review). Also merge `dramgid-vault` PR #34 (it carries the four promoted locations and 20 NPC entities). `gh issue create` is allowed from the session (#506 was filed this way); only closes and merges need the owner. Editor step: regenerate `locale/project.pot` (new player-facing strings in `dialogue/dom_fame_reactions.dialogue`, the Marshal's and Iris's read-back lines); the import already added the new file to `project.godot`'s POT source list. | Four clicks | 3 min |

## 4. Housekeeping — say the word

| # | Item | How to answer |
|---|---|---|

## 5. Answered (log, newest first)

- 2026-10-24 — Item 23: names ok — "Wilds", "Dorthkor Road", "Wound Lip" stay as written in canon by PR #507.
- 2026-10-24 — Item 22: `perks: approved`, `perks karma gate: wait` — the four Karma-gated capstones ship ungated and gain their gate when Karma is wired. Unblocks #285 (Claude implements; no Codex per the 2026-10-23 instruction).
- 2026-10-24 — Item 21: `karma acts: approved`, `karma theft cap: 25` — `docs/karma-acts-draft.md` is the table to wire.
- 2026-10-24 — Item 20: as recommended — Fame raw (not Decorum-scaled), keep the RFC tier floors, keep +3 per won group.
- 2026-10-22 — Item 18 (#342): A1 + B1 — optional facets on the location document plus a `weftlumin.route.v1` document per route; the location id wins, one v9 → v10 save migration. Codex handoff follows.
- 2026-10-22 — Item 17: 56 merged, clean worktrees removed; 12 merged-but-dirty refused without `--force` (`soul-meter-wt/{a5,b0b,bw,bw2,c3,c4,c5,c6,c8,ct-hang,integrate,perf-282}`) and 20 unmerged kept; 33 registered now.
- 2026-10-22 — Item 15: Gemini art pipeline dropped for gold; #298 post-launch (close under item 19); PR #457 icons stay under art review.
- 2026-10-22 — Item 11b: yes, a wild same-map fight ends when the party leaves the alert radius; set pieces stay committed. Filed as #506 (ratification of the shipped D7 rule).
- 2026-10-22 — Item 10: (a) `bellhouse_repair` keeps one ending; (b) go — read-back lines for `field_debt` and `loamroot_sprigs`, PROVISIONAL under item 9.
- 2026-10-22 — Item 4: Kesselford, Ashlaren, The Long Verge and Hollowmere ratified as authored, names and values (balance pass may tune). Vault entities for the 20 NPCs follow; #500–#503 merged 2026-10-21.
- 2026-10-22 — Item 2: as ruled 2026-10-16 — cap **6**, perks at 2/4/6, suspended stubs pay no quest XP. `CHAPTER_LEVEL_CAP` and `QuestRegistry.turn_in` changed in PR #505.
- 2026-10-22 — Item 1: **B** (tier gates on existing surfaces) plus `karma acts: yes` (table drafted for review). Packet §4.1–4.3 sub-rulings moved to item 20.
- 2026-10-22 — Item 3 struck (D9 decision time, #282): already ruled on 2026-10-16 with the FR-904 gate: frame-time p95 is the gate, the 2 ms per-decision line is an advisory regression signal, not a budget to hold or lift (issue #282, `docs/ship-plan-2026-10.md` §7). The item was re-asked on 2026-10-20 without that ruling in view.
- 2026-10-20 — Item 16: the 2026-10-19 batch committed on `feat/c3-long-verge` (journal/standing backdrop, quest-audit fixes, three dialogue read-backs, Yothmeru tier gates, owner docs).
- 2026-10-16 — Four location rulings recorded in `docs/ship-plan-2026-10.md` §Owner decisions 5–8 (PR #500).
- 2026-10-09 — Chapter 1 level cap 7, kill XP scaled by level gap (`docs/progression-bound-packet.md`).
- 2026-10-06 — Enemy curves and ±15 % wild variation (#412, `docs/enemy-curve-packet.md`).
- 2026-09-08 — "Roll with it": enemy stats vary in the wild; the question stays unsolved on purpose.
- 2026-09-04 — Ship plan intake: episodic Chapter 1 first; stubs visible in-world; Gemini for images.
