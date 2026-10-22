# Owner decisions — running list

The one place for everything that is waiting on Adam: rulings, approvals, and things only the
owner can provide. Agents add to it and never resolve an item silently. Started 2026-10-19.

**How to answer:** reply in chat with the item number and your answer (`3: B`), or edit the
item in place. When an item is done, an agent strikes it through with the date and moves it to
§5. One line is enough; the packet linked from an item has the detail if you want it.

**Effort column** is your time, not the agent's.

---

## 1. Rule now — blocks agent work

| # | Decision | How to answer | Your effort |
|---|---|---|---|
| 1 | **Karma and Fame in the world** — `docs/yothmeru-world-effects-packet.md`. Two findings: nothing in the game ever writes Karma (it is always "Uncertain", so the Sway/Bellow Karma bonus never fires), and Fame/Karma tiers are read by nothing. Three options, B recommended. | `1: B` (or A/C), plus `karma acts: yes` if you want me to draft the Karma act table from existing quest outcomes for your review | 10 min read |
| 2 | **Perks and the level cap (#285) — one confirmation, because the records disagree.** On 2026-10-16 you ruled **cap 6, perks at levels 2/4/6** (issue #285, `docs/ship-plan-2026-10.md` §6). The code still carries the 2026-10-09 ruling, `CHAPTER_LEVEL_CAP := 7` (`globals/stats/xp_curve.gd`), and this item was re-asked on 2026-10-20 without the 10-16 ruling in view. The packet's own math (`docs/progression-bound-packet.md` §5.2) makes 6 the fitted cap only if suspended side-quest stubs stop paying quest XP; with stubs paying, a thorough run reaches L6 and the cap sits on it instead of one above. Recommended: confirm 10-16 as ruled — cap 6, perks 2/4/6, stubs stop paying. Then I change the constant, re-run the sweep, and draft per-class perk lists as Pandora data for your approval. | `2: as ruled 10-16` (cap 6, 2/4/6, stubs don't pay) or `2: keep cap 7` (2/4/6 still gives three perks; say whether stubs pay) | 2 min |
| 4 | **Ratify the four new locations.** ~~Merge #500 → #501 → #502 → #503~~ (merged 2026-10-21, `1758d88e`). Still yours: the PROVISIONAL names and values of Kesselford, Ashlaren, The Long Verge and Hollowmere (Hollowmere: thinning tier 3 / accord 55, the `dorthkor-road-hollowmere` route numbers, the Dorthkor Road ↔ mere exit labels, and the three posted NPCs — Watcher Ysolde Marrow, Envoy Brannoc Quell, Mender Corrin Vell). Also on GitHub: merge PR #504 (`tools/progression_sweep.gd` reads every hub; CI green, no game code), close #353 (the runbook and its §5 landed in #503), and #457 (icons) still waits on your art review. | `4: names ok` or list changes; merge #504 and close #353 on GitHub | 15 min |
| 18 | **Canon format and ids for the world map, fast travel and building transitions (#342)** — `docs/registries-data-driven-packet.md`. Three registries are still hand-typed, so every new location PR edits them beside its canon files. Two rulings: (A) where the data lives in canon — recommended: optional facets on the location document plus a `weftlumin.route.v1` document per route; (B) which spelling of three location ids wins — recommended: the location id, with one save migration (v9 → v10). No number, name or cost changes; route numbers and hub costs stay PROVISIONAL under item 4 and the balance pass. Post-gold work, but the only engineering issue not already waiting on you. | `18: as recommended` or `18: A<n> B<n>` | 5 min read |

## 2. Rule when you can — content and tuning

| # | Decision | How to answer | Your effort |
|---|---|---|---|
| 5 | **Breath / Soul economy numbers** — `docs/casting-economy.md` §(b). Every number there is PROVISIONAL: Breath costs per magnitude, `breath_max` by class tier, Luth restore, Mozh conversion, Soul overreach rate. | `5: ratify as proposed` or edit the tables in place | 15 min |
| 6 | **Class-resource numbers (B11)** — `docs/class-resources-numbers.md`. Four proposed values (three caps to 3, one tailed table), each flagged in place. Nothing is applied until you say so. | `6: ratify B11` or per-line changes | 10 min |
| 7 | **DRAMGID leftovers** — `docs/architecture-dramgid.md` §5. Open: (1) ratify the 22-skill table (RFC-0005) in the mono repo; (8) Fame raw vs Decorum-scaled, folded into item 1; (9) fizzle attribute canon-doc edit. Items 2–7 were implemented as recommended; say so and they close. | `7: 2–7 confirmed, 1 ratified` | 5 min |
| 8 | **Companion canon packets** — `docs/canon-review/`: Packet A (Wyneth and the Hospice chain), Packet B (Grumbrand and Pozor's reading institutions), Packet C (naming collisions), trust-language redlines, and the Serai-Lun +3 vs +6 Renown asymmetry (recommend +6). | One line per packet, e.g. `8A: as recommended` | 30 min |
| 9 | **Provisional prose review.** Files carrying `PROVISIONAL — CANON REVIEW REQUIRED`: `dialogue/council_elder.dialogue`, `dialogue/lower_trial_hall.dialogue`, `dialogue/main/unanswered_roar.dialogue`, `dialogue/dom_townsfolk.dialogue`. Added 2026-10-19 and unreviewed: Gaath's two "charge is finished" lines (`council_elder.dialogue`), Toma's two "left a word" lines (`toma_reedhand.dialogue`), the Marshal's "how will the roll record" line (`marshal_coiljaw.dialogue`). Added 2026-10-20 and unreviewed: the three Hollowmere NPC documents (`canon/hollowmere/characters/*.json`, lines and hook summaries) and the three Hollowmere district greeting/farewell pairs in `tools/seed_town_npcs.gd` (The Watch Stilt, The Reed Landing, The Approach), all generated into `dialogue/hollowmere_townsfolk.dialogue`. Also added 2026-10-20 (C25 / #262): the authored ambient dialogue for the four new locations in `dialogue/locations/{kesselford,ashlaren,long_verge,hollowmere}.dialogue` (20 NPCs, drafted from the approved proposals only). | Edit in place, or `9: approved` | 40 min |
| 10 | **Quest content calls from the audit.** (a) `bellhouse_repair` has one ending; the audit wants two. Give me a one-line premise for a second ending, or `10a: one ending is fine`. (b) `field_debt` (4 rulings) and `loamroot_sprigs` (3) resolutions are never heard back in the world; say `10b: go` and I write the read-back lines (reviewed under item 9). | `10a: …`, `10b: go` | 5 min |
| 11 | **Game-identity open questions** (`docs/game-identity.md`). (a) Minimum skill set for Chapter 1: content checks 10 of 22 today — undertone, unweave, sway, slip, recall, wayfinding, varum, strain, sounding, beastbond. Bellow is never checked although Karma feeds it. (b) Can ambient same-map fights be fled by leaving the alert radius (Fallout does)? (c) Loot density target for a field game with a Mirror Shop. | `11a: the 10` or add names; `11b: yes/no`; `11c: a number or defer` | 5 min |
| 12 | **Steam.** Price $9.99 vs $19.99, release date, and whether the Steamworks partner account exists (30-day first-release wait after the fee clears). | `12: $X, date, account yes/no` | 5 min |

## 3. Provide — things only you can do

| # | Item | What to do | Your effort |
|---|---|---|---|
| 13 | **Playtesters for Gate T-6 (#93, #301).** 6–8 outside testers; kit and protocol in `docs/playtest-recruitment.md` and `docs/playtest-protocol.md`; results go in `docs/playtest-packet.md`. The only human-gated ship criterion. | Recruit, run, paste the filled packet | Hours, spread out |
| 14 | **FR-904 reference-hardware run (#175).** Headless reports 0 draw calls, so the 60 fps floor is unverified. Run the runbook on the real machine with a display and paste the frame times. | Follow `docs/testing.md` FR-904 section | 30 min |
| 15 | **Gemini image quota (#298).** Enable quota on project 710589759725 if you still want the art pipeline; otherwise say `15: drop`. | Console toggle, or `15: drop` | 5 min |

## 4. Housekeeping — say the word

| # | Item | How to answer |
|---|---|---|
| 17 | **Stale worktrees.** 31 octopus `tangle/*` worktrees and about 50 `sm-*` / `soul-meter-wt/*` worktrees are still registered. I can list which branches are merged and remove only those, asking before touching anything unmerged. | `17: prune` |

## 5. Answered (log, newest first)

- 2026-10-22 — Item 3 struck (D9 decision time, #282): already ruled on 2026-10-16 with the FR-904 gate: frame-time p95 is the gate, the 2 ms per-decision line is an advisory regression signal, not a budget to hold or lift (issue #282, `docs/ship-plan-2026-10.md` §7). The item was re-asked on 2026-10-20 without that ruling in view.
- 2026-10-20 — Item 16: the 2026-10-19 batch committed on `feat/c3-long-verge` (journal/standing backdrop, quest-audit fixes, three dialogue read-backs, Yothmeru tier gates, owner docs).
- 2026-10-16 — Four location rulings recorded in `docs/ship-plan-2026-10.md` §Owner decisions 5–8 (PR #500).
- 2026-10-09 — Chapter 1 level cap 7, kill XP scaled by level gap (`docs/progression-bound-packet.md`).
- 2026-10-06 — Enemy curves and ±15 % wild variation (#412, `docs/enemy-curve-packet.md`).
- 2026-09-08 — "Roll with it": enemy stats vary in the wild; the question stays unsolved on purpose.
- 2026-09-04 — Ship plan intake: episodic Chapter 1 first; stubs visible in-world; Gemini for images.
