# Handoff — branching-consequence reader brief (Codex, read-only research)

**Objective:** produce `docs/briefs/branching-brief.md` — a compact, fully cited fact base Claude will use to
architect main-quest branching with early closures ("an outcome in an early town removes side quests or
content in later towns") and chapter-end state slates. Facts only. No recommendations, no design, no code.

**Worker:** Codex. **Scope:** write ONLY `docs/briefs/branching-brief.md`. Read anything under
`~/projects/soul-meter` and `~/projects/dramgid-vault` (`index.json` first; open only entity files a fact
needs). Do not edit any other file. Do not run the game or the suite. **Hard cap 300 lines; every factual
line cited `path:line` or `path:range`; tables preferred; disagreements go to §8 unresolved.**

## Required sections

1. **Ratified rulings that constrain branching** — short verbatim quotes with citations from
   `docs/game-identity.md` (consequence-first, hollowing not death, acts of Agreement, tone), the Chapter 1
   PRD `docs/prd-chapter-one.md` (every FR about quests, outcomes, ledger writes, read-backs, main quest,
   chapter end, NG+), `docs/phase-0-ratification.md` (anything on endings, branches, Maiiam, the Front),
   `soul-meter-crpg-design-doc.md` §10 open canon questions that touch endings or main-quest structure,
   `docs/fleet-roadmap.md` C9/C10–C19/C20 rows, and the vault `canon/open-questions.md` items about the
   Front, Maiiam, or the chapter's end.
2. **The consequence machinery as built** — for each, file, public API (signatures), and what it gates today:
   `globals/game_state.gd` flags API + the flag grammar enforced by `tools/quest_audit.gd`
   (`flag_grammar_violations` and the exact regex); `globals/reputation.gd` (bands, thresholds, `why`);
   `globals/renown.gd`; `globals/quest_registry.gd` (quest resource fields, phases, outcomes,
   `dialogue_route_for_actor`, registration, runtime quests); the quest `.tres` schema and
   `globals/campaign_quest_loader.gd` JSON shape; `globals/npc_reactions.gd`; `globals/consequence_timeline.gd`
   (what it records); `ui/screens/chapter_complete.gd` (inputs it displays); `globals/ng_plus.gd` (what
   carries over, the echo lines); `ui/flow/game_flow.gd` guards that read `rep_<faction>` or flags;
   `LocationRegistry` arrival flags/checkpoints; band/flag gates in `actors/building_door`,
   `globals/vendor_registry.gd`, `globals/travel/encounter_director.gd`, `WorldMapRegistry` routes.
3. **Every check `tools/quest_audit.gd` runs today** — name, what it asserts, severity, and the
   `docs/templates/{location,encounter}.md` + side-quest template fields it validates (read-back coverage,
   distinct outcomes, phase reachability, softlocks, orphaned flags, template conformance, anything else).
4. **Content inventory** — table of every quest (main and side) in `quests/` or the registry: id, giver,
   scene, outcomes, flags written, ledger writes, flags read back and where. Then every flag name in the
   repo with writer(s) and reader(s) (`rg` over `.dialogue`, `.gd`, `.tres`, `.json`); mark flags with no
   reader and readers with no writer.
5. **Main quest today** — what exists of Act I "The Front Is Coming": issue #246 body (`gh issue view 246`),
   any chain skeleton in code/quests, the chapter-end trigger (`chapter_complete` conditions), and the
   ten side-quest issue bodies #247–#256 (one line each: what they demand).
6. **Locations and order** — the shipped and planned macro locations (`LocationRegistry.ALL`, fleet C1–C8,
   `docs/templates/location.md`), travel graph edges (`WorldMapRegistry`), and which are reachable when.
7. **Numbers** — ledger deltas used by shipped content (`Reputation.record(..., delta, ...)` values),
   band thresholds, Renown thresholds used by recruits, count of quests/flags/outcomes.
8. **Contradictions and gaps** — spec vs spec, spec vs code, undefined pieces (e.g. no chapter-end state
   model, closures not expressible, audit blind spots). Bullets, cited.

## Acceptance (self-check)
- ≤ 300 lines, sections 1–8 present, every factual line cited, no recommendations.
- `git status --short` shows only `docs/briefs/branching-brief.md`.
- Final message: line count, number of §8 items, any source not found.
