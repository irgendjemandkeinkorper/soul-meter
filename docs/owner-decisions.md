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
| 7 | **DRAMGID leftovers** — `docs/architecture-dramgid.md` §5. Open: (1) ratify the 22-skill table (RFC-0005) in the mono repo; (8) Fame raw vs Decorum-scaled, folded into item 1; (9) fizzle attribute canon-doc edit. Items 2–7 were implemented as recommended; say so and they close. | `7: 2–7 confirmed, 1 ratified` | 5 min |
| 8 | **Companion canon packets** — `docs/canon-review/`: Packet A (Wyneth and the Hospice chain), Packet B (Grumbrand and Pozor's reading institutions), Packet C (naming collisions), trust-language redlines, and the Serai-Lun +3 vs +6 Renown asymmetry (recommend +6). | One line per packet, e.g. `8A: as recommended` | 30 min |
| 9 | **Provisional prose review.** Files carrying `PROVISIONAL — CANON REVIEW REQUIRED`: `dialogue/council_elder.dialogue`, `dialogue/lower_trial_hall.dialogue`, `dialogue/main/unanswered_roar.dialogue`, `dialogue/dom_townsfolk.dialogue`. Added 2026-10-19 and unreviewed: Gaath's two "charge is finished" lines (`council_elder.dialogue`), Toma's two "left a word" lines (`toma_reedhand.dialogue`), the Marshal's "how will the roll record" line (`marshal_coiljaw.dialogue`). Added 2026-10-20 and unreviewed: the three Hollowmere NPC documents (`canon/hollowmere/characters/*.json`, lines and hook summaries) and the three Hollowmere district greeting/farewell pairs in `tools/seed_town_npcs.gd` (The Watch Stilt, The Reed Landing, The Approach), all generated into `dialogue/hollowmere_townsfolk.dialogue`. Also added 2026-10-20 (C25 / #262): the authored ambient dialogue for the four new locations in `dialogue/locations/{kesselford,ashlaren,long_verge,hollowmere}.dialogue` (20 NPCs, drafted from the approved proposals only). Added 2026-10-22 and unreviewed (item 10b): the Marshal's four "what did the field proof buy" read-back lines (`marshal_coiljaw.dialogue`) and Iris's three "how are the sprigs" read-back lines (`iris_illepah.dialogue`); the 20 NPC entities promoted into the Dramgid vault (`characters/{kesselford,ashlaren,long-verge,hollowmere}-*.md`) carry the same hook text. Also 2026-10-22 (item 1, option B): `dialogue/dom_fame_reactions.dialogue`, four Fame routes (Gerren Pike, Orrik Cinderjaw, Dorran Rask, Edda Broadmark). Added 2026-10-29 (PR #518): the Sacred Clarity and Read Aloud blurbs, the Sacred Clarity button description (`data/combat/actions/73_sacred_clarity.tres`), and its line-of-sight (`ranged`) targeting, agent wording and reading of the 2026-10-29 rulings. Added 2026-10-26 (PR #516): the seven signature blurbs (Reflection, Last Washing, Debt of Arms, Second Casting, Tuned Thunder, Sequenced Verdict, The Unspoken Term) and five button descriptions (`data/combat/actions/68`–`72`), agent wording of the 2026-10-26 rulings. Added 2026-10-26 (PR #515, agent reading): the Slow Rot perk blurb reworded to "A Hunger tick that is Jammed still lands one round later." (no cure exists; a Jam names the DoT's source). Added 2026-10-25 (PR #513): three Karma routes in the same file (`dom_gerren_pike_troubled`, `dom_orrik_cinderjaw_troubled`, `dom_holst_brinevein_upright`). | Edit in place, or `9: approved` | 45 min |
| 11 | **Game-identity open questions** (`docs/game-identity.md`). (a) Minimum skill set for Chapter 1: content checks 10 of 22 today — undertone, unweave, sway, slip, recall, wayfinding, varum, strain, sounding, beastbond. Bellow is never checked although Karma feeds it. (c) Loot density target for a field game with a Mirror Shop. ~~(b) fleeing ambient fights~~ ruled 2026-10-22: yes, by leaving the alert radius. — filed as #506 (ratify the shipped D7 rule, drop the PROVISIONAL prefixes, strike the open question, set-piece regression test); PR #510 open 2026-10-24.| `11a: the 10` or add names; `11c: a number or defer` | 5 min |
| 12 | **Steam.** Price $9.99 vs $19.99, release date, and whether the Steamworks partner account exists (30-day first-release wait after the fee clears). | `12: $X, date, account yes/no` | 5 min |
| 25 | **Which place is re-Agreed (#520).** The mechanic shipped without content (your R4, 2026-10-29): an `AccordZone` with an `agreement_id`, restored by a quest outcome's `restores_agreement`, +8 Soul. No Chapter 1 place uses it yet. Choosing the place (Hollowmere sits at accord 55, where Mender Corrin Vell files the Agreement reading) and the in-world act is canon. | `25: <place>, <quest/outcome>` or `25: propose candidates` | 10 min |

## 3. Provide — things only you can do

| # | Item | What to do | Your effort |
|---|---|---|---|
| 13 | **Playtesters for Gate T-6 (#93, #301).** 6–8 outside testers; kit and protocol in `docs/playtest-recruitment.md` and `docs/playtest-protocol.md`; results go in `docs/playtest-packet.md`. The only human-gated ship criterion. | Recruit, run, paste the filled packet | Hours, spread out |
| 14 | **FR-904 reference-hardware run (#175).** Headless reports 0 draw calls, so the 60 fps floor is unverified. Run the runbook on the real machine with a display and paste the frame times. | Follow `docs/testing.md` FR-904 section | 30 min |
| 19 | **GitHub clicks** (the agent's `gh` writes are blocked by the permission classifier). Merge PR #504 (sweep reads every hub) and PR #505 (today's rulings and code); then the #342 stack in order: #507 (world map from canon), #508 (fast-travel hubs), #509 (doors), retargeting each to `main` after the one below merges, then close #342; merge PR #510 (flee by distance ratified, closes #506 on merge); then PR #512 (B11 numbers, item 6; merge before #511), then draft PR #511 (#285 perks slice 1, stacked on #505: retarget to `main` after #505 merges), then draft PR #513 (Karma acts wired, stacked on #511: retarget after #511 merges), then draft PR #514 (#285 slice 2, level-2 perk effects, stacked on #513), then draft PR #515 (#285 slice 3, capstones, stacked on #514); then draft PR #516 (#285 slice 4, signatures, stacked on #515); then draft PR #518 (#285 slice 5, enemy intents: Sacred Clarity and Read Aloud, stacked on #516; closes #517); close #353 (runbook landed in #503) and #298 (Gemini pipeline dropped for gold, item 15; the PR #457 icons stay under your art review). Also merge `dramgid-vault` PR #34 (it carries the four promoted locations and 20 NPC entities). `gh issue create` is allowed from the session (#506 was filed this way); only closes and merges need the owner. Editor step: regenerate `locale/project.pot` (new player-facing strings in `dialogue/dom_fame_reactions.dialogue`, the Marshal's and Iris's read-back lines, and PR #513's three Karma routes); the import already added the new file to `project.godot`'s POT source list. | Four clicks | 3 min |

## 4. Housekeeping — say the word

| # | Item | How to answer |
|---|---|---|

## 5. Answered (log, newest first)

- 2026-10-29 — Places re-Agreed (#520, asked in session; packet `docs/places-reagreed-packet.md`): R1 `AccordZone + agreement_id`; R2 `quest outcome` (`restores_agreement`, field verb later); R3 `full lift, +8` (the negative delta lifts permanently; +8 is PROVISIONAL, item 5); R4 `mechanic only for now` → item 25. Built on `design/520-places-reagreed`.
- 2026-10-29 — Acts of Agreement (#519, asked in session): scope `side + companion quests` (places re-Agreed → #520); `+8 each` (PROVISIONAL, item 5); Dom outcomes Rainbound `restore-the-entry`, Unclaimed Bed `return-the-name`, Cold Bowl `bring-them-home` (plus living-tag's `restore-the-name`); companion quests `either answer` returns +8 once per companion. Also: ship gates #93/#301/#175/#282/#106 `keep open`; #299 and #242–#245 `close as deferred post-gold`; #112/#115 `owner exports the design files`.
- 2026-10-29 — #285 slice 5, enemy intents (asked in session): Sacred Clarity `1 Clarity, 1 AP` (Fading = Clarity per the vault); binding `locked` (target and aim held for the enemy's next turn; re-plans only if they close); telegraph `action, target, aim, odds`; Read Aloud `shared reveal, this round`. Packet `docs/enemy-intents-draft.md`; issue #517; wired in draft PR #518.
- 2026-10-26 — #285 slice 4 (asked in session): Reflection `arm it, reflect next attack` (once per battle, 50/50, "spell" became "attack"); Last Washing `auto, strikes the name`; Debt of Arms `pay 6 HP: +6 damage`; Second Casting `auto on a fizzle`; Tuned Thunder `top storm row = crit`; Sequenced Verdict `18 dmg in 3 rounds, 1/battle`; The Unspoken Term `Cash In + cast condition` (a cast contract cannot trigger until enemies cast); Sacred Clarity and Read Aloud `defer to an intents slice`. Wired in draft PR #516.
- 2026-10-26 — #285 slice 3 (asked in session): Pocketed Gear `next Jam is free` (a waiver; the Gauge never rises, ruling 3 holds); Even Hand `fizzle steadies you` (first fizzle each battle returns to Balance); Spectacular Failure `ally within 2 tiles`. Wired in draft PR #515.
- 2026-10-26 — #285 slice 2 (asked in session): Steadier Hand `auto-redraw lowest` (once per battle a lowest-row Attribution draw is drawn again; no new UI); Second Footing `forgive once, reword` (once per battle the unbalancing repeat is forgiven; blurb drops "a third time"). Wired in draft PR #514.
- 2026-10-25 — Karma (`karma`): scale `Doctrine 5 = 1.0×` (Karma lands as base × Doctrine / 5; Upright reachable from Doctrine 3); perk Karma gates `on` (item 22's `wait` lifted now that Karma has writers); Dom Karma routes `yes, provisional prose` (Gerren, Orrik at Troubled; Holst at Upright; under item 9). Wired in draft PR #513.
- 2026-10-25 — Item 24: `24: as proposed` — +1 on each level-2 resource perk (Scars, Hunger, Failure Tokens, Sentences, contracts, Clarity start and cap), Feed the Husk refunds 1 Hunger, the three delay perks are 20 CT. Flag B: Longer Ledger becomes "the first name to pay each battle pays twice". Flag C: Named Storm becomes "draw twice, keep the higher" (item 6 adopted the tailed table). `docs/perks-draft-285.md` §6.
- 2026-10-25 — Item 6: `6: ratify B11` — `MAX_SCARS` 5 → 3, `VhorrHunger.MAX_HUNGER` 5 → 3, both Breath refunds (Vhorr, Haeren) 1 → 3, Attribution table → tailed `[1, 1, 2, 2, 3, 6]`; the other eight constants stay as shipped. The B11 flags (Dom-inert Instructive Failure, Locksmirk's unreachable upside, the 95 % clamp) stay open design questions.
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
