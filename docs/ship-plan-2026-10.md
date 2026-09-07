# Ship plan — Steam PC, gold build 2026-10-02

Status: DRAFT for owner ratification (2026-09-04). Author: Claude (acting lead).
Supersedes the sequencing in `docs/fleet-roadmap.md` for the next four weeks; the roadmap's
issues and worker roles stay in force.

## Intake (owner answers, 2026-09-04)

| Question | Answer |
|---|---|
| Scope | Full Soul Meter CRPG; Chapter 1 complete first, later chapters gated on lore the owner writes |
| Combat | Fallout-style, same-map combat (ruling 6); some combat-free zones (camp, home base) |
| Playtime | ~20 h target; main story complete; side quests may ship as stubs |
| Platform | PC first; console later if ever |
| Distribution | Paid Steam release |
| Owner time | ~40 h/week on playtest, lore, QA, oversight; little coding |
| Fleet | Codex, Gemini/Jules, DeepSeek, Kimi K3, Qwen3, local Ollama (all keyed, `ai-worker list`) |
| Art | Custom assets generated via the Gemini image API (key already on the dev box), style-referenced to `design/reference/tactical-ui-style-board.png` |

## Lead's assessment (read this first)

1. **20 h is the dream goal, not a gate (owner, 2026-09-04).** The gold build is a complete,
   polished Chapter 1 of roughly 6–8 hours sold as a paid episodic release; later chapters and
   the remaining side quests arrive as free updates.
2. **Two XL migrations (same-map combat #281, DRAMGID #283) are both mandatory** per the
   ratified identity. They go first, in week 1, in parallel, because every content task
   downstream depends on their contracts. Nothing else touches `GameFlow`, combat, or stats
   until they merge.
3. **Content lock is day 18.** After that only bugs, balance numbers, and asset swaps merge.
4. **The reference board is a style target, not a layout target.** It shows a separate battle
   map, deployment phase, and gamepad prompts. We ship same-map combat, keyboard+mouse first.
   What we take from it: dark carved stone, tarnished bronze chrome, ember (Khash) and cold
   blue (Luth/Zhur) as the two accent temperatures, Cinzel-style tracked caps, thin brass
   rules, hex-and-diamond tile glyphs. This already matches the DS ("carved, ledgered, and
   slightly wrong"). No new tokens are needed; the DS wins on any conflict.
5. **The Codex asset agent drives two pipelines.** Direct: 9-patch `StyleBoxTexture`s, SVG
   icons, shaders, tile tints, procedural props, Blender scripts for the 3D-to-iso render
   pipeline. Generated: a script that calls the Gemini image API with the style board as
   reference plus the prompt bible (#296), then palette-clamps, crops, and resizes output into
   `assets/`. Portraits, key art, and the Steam capsule come from the generated pipeline;
   the owner approves every batch before it merges.

## Cut line (Ch1 gold vs free updates)

| Ships in gold | Post-launch (free update) |
|---|---|
| Chapter 1 main quest (C9 chain), 3 hubs, 8 macro locations | Macro locations 9–12 (#242–#245) |
| Same-map combat, ~100-mob floor, DRAMGID, field verbs, progression, hollowing | NG+ deepening, per-class canon pages (#235) |
| 4 of 10 side quests complete, 6 as stubs with a visible "to be continued" | Side quests 5–10 (#251–#256) |
| Custom UI chrome, icons, tile set, 6 companion portraits, Steam capsule | Full portrait set for all 20 recruits |
| Windows export, Steam achievements (5), cloud saves | Controller support, Steam Deck verification, localization |

## Weekly plan

### Week 1 (Sep 4 – Sep 10): freeze, foundations, pipeline

Owner: ratify this doc; close or merge the four stale PRs; start the Steamworks app.

| Task | Worker | Gate |
|---|---|---|
| F0 same-map architecture note (#280) | Claude | Day 1 |
| F3 DRAMGID design note (#283, design half) | Claude | Day 2 |
| F1 same-map combat implementation (#281) | Codex | Day 7, suite green |
| F3 DRAMGID implementation (#283, impl half) | Codex | Day 7, save schema 7 |
| Windows export preset + headless export CI job (new) | Jules | Day 3 |
| Asset style bible + prompt bible from the reference board (new) | Claude | Day 2 |
| UI chrome pass: 9-patch panels, brass rules, command-rail buttons (new) | Codex (asset agent) | Day 7 |
| D7 flaky-suite triage (#264, PR #266) | merge | Day 1 |

### Week 2 (Sep 11 – Sep 17): systems complete, content in flight

| Task | Worker | Gate |
|---|---|---|
| F2 100-mob scale floor (#282) | Codex + DeepSeek profile | Day 14, #175 numbers |
| F4 field verbs (#284) | Codex | Day 12 |
| F5 progression (#285) | Codex; DeepSeek curve | Day 14 |
| F6 hollowing band (#286); F7 canon (#287) | Codex; Ollama→Kimi | Day 14 |
| C9 main quest chain (#246); hubs 2–3 (#238, #239); locations 7–8 (#240, #241) | Codex, Qwen | Day 14 |
| Icon set (command rail, elements, items) as SVG→PNG; tile set tints | Codex (asset agent) | Day 14 |
| Companion portraits ×6 via the Gemini pipeline (#298), owner approves batch | Codex asset agent + Owner | Day 14 |
| Playtest round 1 build (`docs/playtest-packet.md`), 3 testers | Owner | Day 14 |

### Week 3 (Sep 18 – Sep 24): content lock, playtest, store

| Task | Worker | Gate |
|---|---|---|
| Side quests 1–4 complete (#247–#250); 5–10 stubbed with signposts | Codex | Day 18 CONTENT LOCK |
| C20–C22 reactions, thinning gradient, Zhavar (#257–#259) | Qwen, DeepSeek, Codex | Day 18 |
| Playtest round 1 triage → bug issues; round 2 build | Owner + Claude | Day 21 |
| FR-904 performance runbook on real hardware | Owner | Day 21 |
| Steam store page, capsule art, 5 screenshots, trailer cut (optional) | Owner + Claude copy | Day 21 |
| Steamworks: achievements ×5, cloud save paths, build depot upload | Codex | Day 21 |
| Save-integrity sweep across schema 6→7 migrations | Kimi test backfill | Day 21 |

### Week 4 (Sep 25 – Oct 2): bug fix only, gold

| Task | Worker | Gate |
|---|---|---|
| Playtest round 2 (5 testers), P0/P1 fixes only | Owner + Codex | Day 26 |
| Full suite green, zero orphans, export builds on CI | Claude review | Day 27 |
| Steam review submission (allow 3–5 business days) | Owner | Day 25 at the latest |
| Steamworks partner signup + $100 fee (30-day first-release wait) | Owner | **Sep 4, today** |
| Gold build tag `v1.0.0-ch1`, depot set live, release date set | Owner | Oct 2 |

## Standing rules for the month

- Every worker task is a GitHub issue on milestone **Steam PC launch (Ch1) — 2026-10-02**.
- Worker PRs need a `submit_action`-path or equivalent live-consumer test for any new state.
- Nothing under `addons/`, no `change_scene_to_file()`, Pandora never written back.
- After content lock (Sep 21): bug, balance, asset-swap PRs only. Claude rejects the rest.
- Owner rulings needed this month are listed in `## Owner decisions pending` and answered in
  this file, never resolved silently.

## Owner decisions pending

1. ~~Cut line~~ RESOLVED 2026-09-04: episodic Ch1 first, 20 h is a dream goal.
2. Price: owner leaning $9.99 or $19.99 (2026-09-04), undecided. Release date open.
   **No Steamworks account yet.** Steam requires a new partner account to wait ~30 days after
   the $100 fee clears before its first release, and the store page must be public ~2 weeks
   before launch. Signing up on 2026-09-04 is the critical path for an early-October date.
3. ~~Stub visibility~~ RESOLVED 2026-09-04: visible in-world, signposted.
4. ~~Image model~~ RESOLVED 2026-09-04: Gemini image API, style board as reference.
