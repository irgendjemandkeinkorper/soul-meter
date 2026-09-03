# Fleet roadmap — Chapter 1 to fully playable

Status: RATIFIED 2026-09-02 (owner). Issues filed the same day; see the issue list for `wave-*` title prefixes.
Owner decisions this roadmap encodes (2026-09-02):

- Target = fully playable Chapter 1. Weeks of work is acceptable.
- Region content is prepped NOW on branches; merged into `LocationRegistry.ALL` only after the
  Phase 1.5 playtest sign-off (`docs/playtest-packet.md`). Tweak later.
- Ollama produces canon documents for owner approval. They land in
  `dramgid-vault/proposals/` (new section) via PRs that require owner approval. Nothing Ollama
  writes is canon until merged.
- DeepSeek owns numeric tuning: fizzle table, element matrix, to-hit constants, CT wait
  refund, weather charge rates, Breath economy.
- Every worker task is a GitHub issue (#215–#265, titles prefixed `[wave-X] <key>:`). Labels:
  `delegated-to-codex`, `delegated-to-claude`, `deepseek`, `kimi`, `qwen`, `jules`, `ollama`.
- Breath is a real mechanic (canon: per-scene pool; overreach past empty spends Soul).
- All ten patron-class signature resources are in scope.
- Task size cap for cheap workers: ~4 files + tests, ≤ ~1200 lines changed.
- Workers run the suite themselves before handoff; CI re-runs on PR.
- Spend uncapped for now.

## Worker roles

| Worker | Takes | Never takes |
|---|---|---|
| **Opus (Claude)** | Architecture, seams, anything touching GameFlow/UIManager contracts, review of every merge, GitHub triage | Bulk content |
| **Codex** | Core implementation once the seam is fixed: controllers, resolvers, save schema, UI wiring | Design decisions, canon |
| **DeepSeek** | Math: tables, curves, balance sweeps, deterministic tests over numeric surfaces | UI, narrative |
| **Kimi** | Low-hanging fruit needing long context: cross-file refactors, doc sync, test backfill over whole modules | New mechanics |
| **Qwen** | Boilerplate: `.tres` authoring from templates, test scaffolds, translations of existing patterns to new locations | Design, math |
| **Jules** | Isolated repo tasks from a labelled issue: tests, tooling, doc generation | Anything needing the vault |
| **Ollama** | Canon proposals and clarification docs from the vault, offline | Any repo code |

## Waves

Each wave is a set of issues that can run in parallel. A wave merges before the next starts
(review capacity is the bottleneck, per PRD §7 fleet-reality clause).

### Wave A — Magic combat completion (in flight)

| # | Task | Worker | Size |
|---|---|---|---|
| A1 | Tactical casting slice (CAST verb, composition, gate, residue). First octopus run (`octopus/run/1788368745-19359/integration`) timed out after writing only tests — those tests are the salvaged contract. Rulings: extend `AbilityDefinition` (no new SpellDefinition), add `Kind.CAST`, Breath spent first then Soul overreach, fizzle also spends Soul via `ElementMatrix.soul_on_failure()`, fizzle from `SkillCheck.fizzle_percent` seeded so forecast==resolution, **a fizzled cast deposits residue of the Wheel-opposite element, not the intended one** (owner ruling 2026-09-02, PROVISIONAL until written to the vault) | Codex | L |
| A2 | **Breath pool**: `GameState.breath` per-scene, refill on scene enter, casting spends Breath first, overreach spends Soul; save schema bump to 7 | Codex | M |
| A3 | Fizzle wired into `Resolution` via `SkillCheck.fizzle_percent` with location Agreement Integrity as input; forecast shows true fizzle % | Codex | M |
| A4 | Fizzle/Breath economy sweep: verify ratified sanity readings, propose Breath sizes per magnitude, Aqua/Molm restore amounts | DeepSeek | M |
| A5 | Aftertone + Tempo runtime state on `BattleActor` (Terra anchors, Scor consumes, Nul zeroes, Khor holds) | Codex | L |
| A6 | Ten Triad-unique effects as data-driven effect pipelines (vault `elements-and-music.md` §Triads is the spec) | Codex | L |
| A7 | Test backfill: every Triad, every Strained span, Clash > 2 span, Vär gating — unit suite headless | Kimi | M |
| A8 | Canon doc: "Why did that cast fail?" plain-language explainer per block reason, for FR-606 UI copy | Ollama | S |

### Wave B — Patron-class signature resources (all ten)

Seam first (Opus), then one issue per class.

| # | Task | Worker | Size |
|---|---|---|---|
| B0 | `ClassResource` seam: abstract per-actor resource with hooks `on_action`, `on_damage`, `on_fizzle`, `on_kill`, `on_turn`, serializable; wired into `CombatController` events | Opus | M |
| B1 | Mirrorblade Balance (alternation tracker → fizzle mod) | Codex | M |
| B2 | Flamebinder Instructive Failure (fizzle banks token, spend for guaranteed cast) | Codex | M |
| B3 | Ironbrand Scars (damage banks, spend for guaranteed hit/crit) | Codex | M |
| B4 | Husk-bearer Hunger (DoT stacks, DoT kills refund Gauge) | Codex | M |
| B5 | River-Mother Name-Ledger (record ally name → Gauge refund) | Codex | M |
| B6 | Lensbearer Clarity (burn for true fizzle %, hidden resistances) | Codex | M |
| B7 | Oathclock Ledger (queued effect resolves N turns later) | Codex | M |
| B8 | Locksmirk: floor > 0% fizzle at Mastery + Jam the Gears (break enemy Song) | Codex | M |
| B9 | Stormbearer Attribution (hidden table, semi-random big effects) | Codex + DeepSeek table | M |
| B10 | Threadwalker Threads (hidden Contract on target, delayed payoff) | Codex | M |
| B11 | Numeric pass across all ten: refund sizes, token caps, variance floors | DeepSeek | M |
| B12 | Canon proposals: one page per class describing the resource in-fiction, for battle barks and tooltip copy | Ollama | M |
| B13 | Per-class `.tres` action authoring from B0 template (10 files) | Qwen | M |

### Wave C — Region content prep (branch-held until #93 passes)

| # | Task | Worker | Size |
|---|---|---|---|
| C0 | Location template + side-quest template + encounter template docs, with schema checked by `quest_audit.gd` | Opus | S |
| C1–C8 | Eight macro locations (to reach 12): each a `LocationDefinition` .tres, interior scenes, 2–3 NPCs with routines, 1 encounter table. Two of them hubs (2 and 3) | Codex (hubs), Qwen (non-hub dressing) | L each |
| C9 | Main quest Act I "The Front Is Coming" quest chain skeleton, Act II hook | Opus design, Codex impl | L |
| C10–C19 | Ten side quests, each ≥ 2 outcomes + ≥ 1 ledger write + read-back | Codex | M each |
| C20 | Band-gated reactions: ≥ 3 per hub | Qwen | M |
| C21 | Thinning gradient: per-location Agreement Integrity values along the wilds→front axis | DeepSeek | S |
| C22 | Zhavar telegraphing + one scripted tolling event | Codex | M |
| C23 | Canon proposals per new location (name, faction, what the fading did there) | Ollama | M |
| C24 | Quest-audit tightening: read-back coverage report per quest | Jules | S |
| C25 | Dialogue drafts per location (marked PROVISIONAL) from C23 docs | Kimi | M |

### Wave D — Human gates + polish (runs alongside C)

| # | Task | Worker | Size |
|---|---|---|---|
| D1 | Phase 1.5 playtest execution (`docs/playtest-packet.md`) | Owner | — |
| D2 | FR-904 runbook on real hardware | Owner | — |
| D3 | Battle stage presentation (#211) | Codex | L |
| D4 | Full-screen unification of `battle.gd` into six regions | Codex | L |
| D5 | Performance floor on populated grid (#175) | Codex + DeepSeek profile | M |
| D6 | Windows chores: Maaack wizard, PixelPen, GodotGAS, #112/#115 assets | Owner | — |
| D7 | Test flake triage: the 3–4 headless-flaky suites | Jules | S |
| D8 | Doc sync: CLAUDE.md status addenda collapsed into one current section | Kimi | S |

### Wave F — Identity consequences (ratified 2026-09-02, `docs/game-identity.md`)

Owner rulings that re-scope the build. Architecture first (Opus), then Codex. Runs after Wave B
merges; F1 and F2 gate D3/D4.

| # | Task | Worker | Size |
|---|---|---|---|
| F0 | Architecture note: same-map combat — field scene tiles as the battle grid, combat-mode toggle in GameFlow (Active ↔ Battle without scene swap), alert radius admits actors to the CT order, deployment only for set-pieces; re-scope #211/D4 | Opus | M |
| F1 | Same-map combat implementation per F0 | Codex | XL |
| F2 | Scale floor: 100 hostile mobs on one map — AI turn batching, off-screen actor skipping, per-tick budget; #175 becomes a hard gate | Codex + DeepSeek profile | L |
| F3 | DRAMGID migration: seven attributes + 22 skills replace the six-stat build (save schema bump, chargen wizard, Pandora columns, `SkillCheck` service, dialogue conditions); Yothmeru Karma/Fame mapped onto `Renown` with Doctrine/Decorum scaling | Opus design, Codex impl | XL |
| F4 | Fallout-full field verbs: locked container, pickpocket, barter screen, loot tables; Loom-sensitive skills degrade in Hush/Waning zones | Codex | L |
| F5 | Progression: XP from combat + quests, skill points per level, perk lists per patron class as Pandora data, Karma/Fame-gated perks | Codex; DeepSeek curve | L |
| F6 | Hollowing band: Soul-zero state with dialogue conditions and companion barks; "acts of Agreement" as a tagged quest outcome crediting the gauge | Codex; Kimi dialogue drafts | M |
| F7 | Canon proposals: hollowing in-fiction, what an act of Agreement looks like per faction | Ollama → Kimi rewrite | S |

### Wave E — Acceptance

4-archetype full playthroughs, §3 metrics gate (#106). Owner-led with Codex fixes.

## Issue template (every worker issue)

```
Objective:
Worker: <label>
Branch: feat/<slug>
Allowed scope: <files/dirs>
Deliverables:
Acceptance checks: suite green (run it), quest audit 0 errors, no addons/ edits
Do not decide: <list>
Handoff: changed files, test evidence, risks, open questions
```

## Sequencing

1. Wave A (magic) and Wave B0 seam first. B1–B13 after B0 merges.
2. Wave C starts as soon as C0 templates exist; runs on `feat/region-*` branches, held.
3. Wave D runs whenever the owner has time; D3/D4 are Codex-parallel to B.
4. Wave F (identity consequences) after B; F0/F3 design notes can start now.
5. Wave E last.

Rough effort: A ≈ 1 week, B ≈ 2 weeks, C ≈ 3–4 weeks, D ≈ 1–2 weeks, E ≈ 1 week. Wall time
is bounded by Opus review, not worker throughput.
