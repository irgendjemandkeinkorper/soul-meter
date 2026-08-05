# PRD — Soul Meter: Chapter 1 Complete ("Finished State" v1)

**Status:** **RATIFIED 2026-08-03** — Phase 0 gate passed, zero ⚑ remaining (see
`docs/phase-0-ratification.md`; Appendix A below is the closure record) · **Owner:** Adam (solo
dev) · **Date:** 2026-08-02
**Scope decision (user, 2026-08-02):** Chapter 1 complete — a polished, shippable first chapter.
**Combat decision (user, 2026-08-02):** Evolve within design-doc §6 chassis (field → battle scene → turn-based); Fallout 2 is vibe and reference, not blueprint. §6's Defining Strikes ARE the called-shot system; §6's Balance Gauge IS the balance pillar.
**Elements decision (user, 2026-08-02):** The Elements & Music spec (below, §FR-300 block) is the updated canonical magic-mechanics layer, grounded in the vault's Wheel/ten-patron-classes lore. It supersedes prior mechanical sketches where they conflict; lore prose in the vault remains source of truth for fiction.

**Tactical-layer decision (user, 2026-08-04; RATIFIED 2026-08-05):** adopt the `Elemental
Architecture` design — grid with elevation and facing, charge-time turn order, per-tile element
charge, global weather. **See [`prd-amendment-tactical-layer.md`](prd-amendment-tactical-layer.md),
which supersedes parts of §6.1 below.**

> ### ⚑ §6.1 IS PARTLY SUPERSEDED — read the amendment before implementing any FR-100
>
> **RETIRED:** **FR-102** (AP economy → charge time, now FR-102a) · **FR-105** (zones → grid with
> elevation and facing, now FR-105a).
> **KEPT but changed:** **FR-103** (repriced AP→CT) · **FR-104** (re-homed onto the weather/charge
> bias axis — note it is *not* cut: Stillpoint's `the_held_silence` depends on
> `apply_balance_effect`) · **FR-106** (needs a new CT-queue interrupt contract).
> **AMENDED:** **FR-601** (pips → CT) · **FR-603** (HUD) · **FR-606** (its blocking-system list
> names "AP" inline) · **FR-108** (zone layout → map/tile/elevation authoring).
> The original text of all of these is retained below as the historical record.
>
> This **pre-empted the Phase 2 gate rather than deferring it** — the zones-depth playtest §7
> below describes was never run. **Gate T** (amendment §5, 12 criteria) replaces it and inherits
> Phase 1.5's go/no-go authority.
>
> **Applied:** design frame is now **1920×1080** (#111). **Still open:** whether NEIGHBOUR/SAME
> enter canon as damage relations (§9.2, **#133**) — this blocks `element_matrix` authoring only.
> **Decided 2026-08-05:** the three tactical jobs become **combat disciplines**; Patron remains
> the class (§9.1, #132).

---

## 1. Executive Summary

Soul Meter is a dialogue-and-consequence-first CRPG (Godot 4.7, 2D isometric) set in Era 3 of the Dramgid Cycle. The vertical slice already closes the loop: lore vault → Pandora → reputation ledger → dialogue → visible consequence. This PRD defines what "finished" means for **Chapter 1**: one region (8–12 locations, 3 hubs, 15–25 hours), an act-complete main quest with the three ending-family setups seeded, 4–5 playable ancestries, Fallout-2-inspired tactical turn-based combat (AP economy, called shots via Defining Strikes, percentile skill checks), the Elements & Music casting system (10-element Wheel, Breadth × Magnitude, Vär harmony gate, Zhavar escalation), dual reputation ledgers driving real story consequences, a balance/mirror/eclipse UI language, and the NG+ scaffold (combat style points → carry-over shop).

**Key value:** every system feeds dialogue, consequence, or the Meter (design-doc §8 rule). The player literally manages balance — cosmologically (story), tactically (Balance Gauge), and visually (the UI itself is built on mirror-symmetry and eclipse motifs).

**Execution model:** solo human + AI agent fleet (up to 5 Codex + 5 DeepSeek concurrent, Gemini/Jules for bounded research/tests/boilerplate), Claude as architect/synthesizer. No hard deadline; milestone-ordered.

---

## 2. Problem Statement

| Segment | Pain today | Evidence |
|---|---|---|
| The developer (solo) | Vertical slice proves the loop but is not a game: 2 field scenes, 1 quest chain, scaffold combat (`globals/battle.gd`), no skill system, no elements, no NG+ | Repo state 2026-08-02 |
| Future players | CRPG fans get "choices matter" marketing that collapses to flavor text; combat in narrative RPGs is often filler | Genre-wide critique; design pillar "consequence-permanence" exists to answer it |
| The design itself | §6 combat identity (Balance Gauge, Defining Strikes) is decided on paper but unbuilt; the Elements & Music spec exists only as prose; drift risk grows every sprint that code and canon diverge | CLAUDE.md "still open" list |

The core problem: **the distance between "loop closed" and "Chapter 1 shippable" is unplanned.** Systems exist as [CANON]/[PROPOSAL] prose with no dependency-ordered build plan, no acceptance gates, and no agent-delegation strategy sized to a solo dev.

---

## 3. Goals & Success Metrics

### Goals (SMART, priority-tagged)

- **G1 (P0)** Ship Chapter 1: one region, act-complete main quest, playable start-to-chapter-end without debug tools. Playtime target: **8–12 dense hours minimum, 15–25h stretch** — external research flags 15–25h as aggressive for a solo dev; density beats duration, and the quest-count metrics below are the real bar. ⚑ Ratify the floor in Phase 0.
- **G2 (P0)** Combat identity live: Balance Gauge, Defining Strikes (called shots), AP turn economy, zone positioning, speech-as-combat-verb — all in the §6 chassis.
- **G3 (P0)** Percentile skill system live: skills resolve as d100 vs. skill% in dialogue, field, and combat; fizzle math implements Agreement-Integrity.
- **G4 (P0)** Elements & Music system live per spec: 10 elements × (Imposition + Rule-Bend), Breadth (Tone/Chord/Triad) × Magnitude (Note/Phrase/Song/Refrain), Vär gate, Strained Chords, Zhavar zone escalation.
- **G5 (P0)** Consequences provably real: ≥ 12 main-quest state branches; **every main-quest resolution** and **≥ 60% of side-quest resolutions** are read back visibly by later content (this is the single consequence bar — FR-403 uses these same numbers). Branch fan-out is managed by convergent design: branches reconverge into a bounded set of world-states rather than multiplying.
- **G6 (P1)** Balance UI language shipped: mirror-symmetric HUD, eclipse iconography, Balance Gauge as flagship diegetic element; theme via type variations only.
- **G7 (P1)** NG+ scaffold: combat style points accrue; end-of-chapter shop persists purchases into a fresh save.
- **G8 (P1)** 4–5 playable ancestries with mechanical inheritances (vault `peoples/` as source).
- **G9 (P2)** Living-world texture: flag- and reputation-keyed NPC state changes, rumors, and ambient reactions (no NPC schedules in v1 — see FR-504).

### Success metrics

| Metric | Target | Measured by |
|---|---|---|
| Chapter-1 critical path completable | 100%, zero blockers | e2e gdUnit4 journey test + manual checklist |
| Side quests shipped | ≥ 10, each with ≥ 2 outcomes | QuestRegistry audit script |
| Quests whose outcome is referenced later | ≥ 60% | Flag read-back audit (see FR-501) |
| Combat encounters using ≥ 3 verbs (attack/cast/speech/position) | ≥ 80% | Encounter data audit |
| Automated test suite | Green in CI; unit coverage on all resolution math | gdUnit4 headless run |
| Distinct viable builds through Chapter 1 | ≥ 4 archetypes playtested (martial, caster, talker, balanced/refusal) | Manual playtest checklists |
| Save/load integrity incl. NG+ carry-over | 0 known corruption paths | round-trip serialization tests |

---

## 4. Non-Goals (explicit boundaries)

- **No full tactics grid in v1.** §6 decided zones (front/back/flank). A grid is a flagged possible v2 upgrade; the combat layer must keep positioning behind an interface so this stays swappable (FR-201).
- **No Chapters 2–3 content.** Ending families are *seeded*, not built. Novel-era content appears only as archaeology (§8 guardrail).
- **No multiplayer.** Keep GameState serializable (co-op is a live maybe), build nothing else for it.
- **No new addons beyond the pinned 14** (+ GodotGAS if/when it lands; Maaack wizard on Windows box is unblocked separately).
- **No hand-rolled localization beyond PO/gettext** (decided).
- **No real-time or action combat.** Turn-based is [CANON direction].
- **No silent canon resolution.** §10 open questions and vault `canon/open-questions.md` stay open; any PRD item touching them is flagged ⚑.
- **No procedural/open-ended world generation.** Authored region only.

---

## 5. User Personas

1. **"The Archivist" — lore-first CRPG player** (Disco Elysium, Planescape). Reads everything, low combat appetite. Needs: speech-as-combat-verb, skill-gated dialogue that references their build, consequence read-backs that prove the world remembers. Failure mode to avoid: combat as toll-booth.
2. **"The Tactician" — Fallout 2/FFT player.** Wants AP decisions, called-shot gambles, build diversity, the Balance Gauge as a resource to exploit. Needs: percentile transparency (show the numbers), encounter variety, a reason positioning matters. Failure mode: combat that autopilots.
3. **"The Completionist re-runner" — Witcher 3/ToS player.** Plays side quests as the real game; replays on NG+ with a new build. Needs: side quests with weight, visible reputation bands, NG+ carry-over worth planning around. Failure mode: side content that is fetch-quest filler (the existing Loamroot Sprig quest must not be the ceiling).
4. **The developer + agent fleet** (secondary): every FR must be decomposable into bounded, non-recursive agent tasks with acceptance checks (see §8 delegation plan).

---

## 6. Functional Requirements

Format: `FR-xxx (Pn) — requirement. ⚑ = touches open canon; needs human ratification before build.`

### 6.1 Combat core (FR-100s)

- **FR-101 (P0)** Turn-based battle scene inside the §6 chassis: field encounter → `GameFlow` event → battle scene → return with consequences. No `change_scene_to_file()`; battle entry/exit are statechart transitions (Playing:Battle exists). **Architecture (research-backed):** three layers — authored Resources/Pandora data → runtime domain state → presentation scenes — with a command/event-driven `CombatController` FSM: the resolver computes outcomes and emits events; HUD/animation only consume them. Actions, zones, called shots, and checks are declarative data evaluated through fixed resolution pipelines, never hard-coded per ability.
- **FR-102 (P0)** **Action Point economy.** Each combatant gets AP per round from attributes; every verb (move zone, attack, cast, item, speech, defend) has an AP cost. UI shows AP as eclipse-phase pips (see FR-601).
- **FR-103 (P0)** **Defining Strikes = called shots.** Spend extra AP + a Lore/insight percentile check to *name* a weakness ("the knee", "the oath that binds it"). Success applies a targeted effect table per enemy archetype (cripple, disarm, bind-break, reveal). This is Fallout 2's called-shot *feel* in Dramgid fiction — no body-part menu UI unless playtests demand it; the naming interface is a short list of discovered weaknesses per enemy, expanded by Lore skill and prior encounters.
- **FR-104 (P0)** **Balance Gauge.** Per-battle order↔chaos axis, pushed by every action per §6 (demons chaosward, undead/devils orderward, Definition powers order, Paradox powers chaos, mundane actions centerward). Extremes impose global effects on *everyone*; thresholds and effects data-driven from Pandora. The refusal/stabilizer build (center-holding) must be mechanically rewarded.
- **FR-105 (P0)** **Zones, not grids.** Front/back/flank per side; zone determines valid targets, cover, flank bonuses, AoE shapes. Positioning API isolated behind a `BattlefieldModel` interface so a grid can replace it in v2 without rewriting actions.
- **FR-106 (P0)** **Speech as combat verb.** Dialogue checks mid-battle can end, split, or turn fights; wired through Dialogue Manager balloons inside the battle scene. Mandatory against Harem Stet-aligned encounters in this region.
- **FR-107 (P0)** **Consequence-permanence.** Flee/spare/slaughter each write Reputation/Renown events and flags; battle outcomes are quest outcomes. (Extends the existing battle→ledger wiring.)
- **FR-108 (P1)** Encounter authoring pipeline: encounters defined as Pandora entities (composition, zone layout, Balance bias, speech hooks), generated into runtime data like GLoot items.
- **FR-109 (P1)** In-house hitbox/hurtbox (Area2D pair, GDQuest pattern) for field-side telegraphs and battle VFX — per architecture doc.
- **FR-110 (P2)** Combat Style Points: per-battle scoring (verb variety, Balance management, no-damage turns, speech resolutions) feeding the NG+ economy (FR-801). Accrual in v1, spend at chapter end.

### 6.2 Percentile skill system (FR-200s)

- **FR-201 (P0)** Skills stored as 0–100+ percentages on `PartyMember`/player; resolution = d100 ≤ effective%. One shared `SkillCheck` service used by dialogue conditions, field interactions, Defining Strikes, and fizzle rolls — a single tuned/tested resolution path.
- **FR-202 (P0)** Skill list from the Ledger character-creation layer (vault `systems/character-creation.md`): attributes → derived skill bases; Backgrounds grant skill packages + one starting Mastery (a Note/Phrase at 0% base fizzle). ⚑ Exact skill taxonomy needs ratification against the vault's Skills table before implementation.
- **FR-203 (P0)** **Fizzle math is the casting-side percentile.** Base fizzle from local Agreement Integrity × tier multiplier − Mastery. The vault marks exact numbers as an expansion point ⚑ — this PRD mandates a tunable table in Pandora, playtested, then written back to the vault as ratified canon.
- **FR-204 (P0)** Advancement: use-based or point-buy on level ⚑ (design doc silent; decide before Phase 2). Either way, percentile costs scale so 100% is a commitment, not a default.
- **FR-205 (P1)** Checks surface their numbers (skill%, roll, modifiers) in a log/tooltip — Tactician persona requirement; toggleable for Archivists.
- **FR-206 (P1)** Dialogue Manager integration: `[if check("lore", 45) /]`-style conditions backed by the same `SkillCheck` service (remember the self-closing `[if /]` gotcha).

### 6.3 Elements & Music (FR-300s) — the user's 2026-08-02 spec, normative

- **FR-301 (P0)** **Two independent axes.** Breadth: Tone (1 element) / Chord (2) / Triad (3). Magnitude: Note / Phrase / Song / Refrain. Notation "Breadth · Magnitude" (e.g. *Triad · Song*). Hard cap: max 2-step Wheel span; attempting wider = internal **Clash** (self-inflicted Discord, no fizzle).
- **FR-302 (P0)** **Ten elements, each with fixed Imposition (status) + Rule-Bend:** Suul (Exposed / reveals Aftertones, signatures, illusions), Bloei (Overgrown / extends own buff duration), Aqua (Soaked / only element restoring Breath), Khor (— / *adds*: extends durations, holds Notes across rounds), Terra (Weighted / creates cover, anchors Aftertones), Daar (Blinded / conceals Discord signatures), Molm (Decaying / corpses & objects → Breath), Scor (Burning / consumes Aftertone for burst power), Nul (Muted / *subtracts*: cancels buffs, ends Aftertones, zeroes Tempo), Strom (Shocked / ignores Instability die). Khor and Nul deal no damage.
- **FR-303 (P0)** **Composition algebra:** Tone = full Imposition + its Rule-Bend. Chord = ONE Imposition (full) + BOTH Rule-Bends. Triad = center element's Imposition (amplified) + ALL THREE Rule-Bends + one unique Triad-only effect. Design rule: wider ≠ more damage; wider = structurally different capability.
- **FR-304 (P0)** **The ten Triads** (span → center): Dayspring (Strom–Suul–Bloei → Suul), Fruiting (Suul–Bloei–Aqua → Bloei), Rivermouth (Bloei–Aqua–Khor → Aqua), Founding (Aqua–Khor–Terra → Khor), Vault (Khor–Terra–Daar → Terra), Barrow (Terra–Daar–Molm → Daar), Pyre (Daar–Molm–Scor → Molm), Cinderfall (Molm–Scor–Nul → Scor), Stillpoint (Scor–Nul–Strom → Nul), Thunderhead (Nul–Strom–Suul → Strom). Every element rules exactly one Triad and wings two. Each Triad's unique effect: ⚑ ten designs needed, propose in Phase 2, ratify to vault.
- **FR-305 (P0)** **Strained Chords:** 2–4 steps apart = castable at penalty — raised fizzle, Galm/Vär cost equal to step distance, both Impositions land weakened.
- **FR-306 (P0)** **Vär (Harmony) gate**, −5 (kesh) … +5 (sēl): Tone at any Vär; Chord requires Vär ≥ 0 (or Solo with Mastery); Triad requires Vär ≥ +2 (or Solo with highest Mastery + Refrain-tier Breath cost). Vär shifts from actions/story — the personal-scale mirror of the Balance Gauge; the two gauges must read as one visual language (FR-602). **Anti-build-lock rule (adversarial-review fix):** Vär must be recoverable through *play* (combat and field actions that raise it), not only story alignment; the Solo-with-Mastery paths are the pressure valve so a Chord/Triad build is throttled, never disabled; Tone casting is never gated. When a cast is blocked, the UI states *which* system blocked it and what would unblock it (FR-606). ⚑ Rename "the Galm" → "the Vär" propagates to vault.
- **FR-307 (P0)** All element/Triad/Imposition data lives in Pandora entities with Vault Id bridges; runtime tables generated (one-way, like GLoot) — never hand-edited.
- **FR-308 (P1)** **The Zhavar** (zone-scale, replaces "Carry"/"Overtone" ⚑ vault rename): banking harmony raises local Integrity AND the Zhavar (how far the zone "can be heard"). Escalation ladder: low → rising → tolling (one Nul dragon) → ringing (regional delegation) → unprecedented. In Chapter 1: Zhavar is tracked and *telegraphed* (rumors, ambient VFX, one scripted tolling event); full dragon-response systemization is Chapter 2+.
- **FR-309 (P1)** Casting economy integration: Gauge/Breath split, Aftertones, Tempo per the Ledger expansion points ⚑ — stat the minimum needed for FR-302's Rule-Bends to function (Aftertones and Breath are load-bearing: Terra anchors them, Scor consumes them, Molm/Aqua restore Breath, Nul zeroes Tempo).
- **FR-310 (P2)** Patron-class Kits (always-on physical identity per §ten-patron-classes) for the 3–5 companions and player class options in this chapter; Kits work at full strength everywhere including low-Integrity zones.

### 6.4 Karma, reputation, consequence (FR-400s)

- **FR-401 (P0)** Keep the two-ledger architecture as-is: `Reputation` (per-faction, append-only, `record()` only write path) + `Renown` (global reputation/infamy). These ARE the karma system — no third ledger.
- **FR-402 (P0)** Faction standing bands gate content: prices, dialogue trees, area access, recruit availability, quest branches. Every hub has ≥ 3 band-gated reactions. GameFlow's `rep_<faction>` chart properties enable statechart guards — use them.
- **FR-403 (P0)** **Read-back mandate (aligned with G5):** every quest resolution writes ≥ 1 flag or ledger event; every **main-quest** resolution and ≥ 60% of **side-quest** resolutions are *visibly* read back later (dialogue line, price, encounter composition, NPC presence). Enforced by the audit tool (FR-501) — with the explicit caveat that structural audits prove wiring, not meaning; narrative coherence is verified by the per-wave human playtest pass (FR-906).
- **FR-404 (P1)** `why()` surfaces in-fiction: an NPC/mirror/journal that recites *the causes* of your standing (the ledgers already store cause + scene — this is the payoff UI).
- **FR-405 (P1)** Soul Meter ↔ consequence coupling per design doc §4.2: spending the Meter is visible in the world (temple/mirror scenes are the flagship diegetic readings).

### 6.5 World, quests, living region (FR-500s)

- **FR-501 (P0)** One region: 8–12 locations, 3 hubs (Dom is hub 1), 15–25h. Act-complete main quest implementing Act I (The Front Is Coming) with the Act II hook. A `quest_audit.gd` tool script validates: outcome count, flag writes, read-backs, orphaned flags.
- **FR-502 (P0)** ≥ 10 side quests, each: ≥ 2 genuinely different outcomes, ≥ 1 ledger write, no pure fetch (the fetch skeleton may carry a quest, but the *resolution* must involve a choice). Witcher-3 principle: side quests characterize the region and refract the main theme (balance, grief, the fading).
- **FR-503 (P0)** Travel graph: hubs + wilds connected via `TravelExit`/`GameFlow.travel()`; region map screen (P1 for fast-travel between discovered hubs ⚑ design doc silent on fast travel — decide).
- **FR-504 (P1)** Living-world texture tier 1: time-of-day-agnostic NPC state changes keyed to quest flags and rep bands (post-quest scene dressing, rumor lines, price shifts). No full NPC schedules in v1.
- **FR-505 (P1)** 3–5 companions (from the 20 tavern recruits, promote 3–5 to full companions): personal quest each, battle barks, Balance-Gauge-relevant abilities, at least one per ending-family temperament.
- **FR-506 (P2)** Thinning-zone gradient: wilds encounter tables + fizzle modifiers shift toward the front; the map itself is evidence (an attentive player reads the pattern).

### 6.6 UI — balance / mirrors / eclipse (FR-600s)

- **FR-601 (P0)** **Design language:** bilateral mirror symmetry as the compositional rule (HUD elements paired left/right around a center axis); eclipse motif (occlusion, corona, phase) for state display — AP as eclipse-phase pips, Soul Meter as a progressively occluded disc, Balance Gauge as twin mirrored arcs meeting at center. All via `ds.gd` tokens + theme type variations, zero per-node overrides. Extend `design/DESIGN_SYSTEM.md` first (design-system project is source of truth) — code follows the doc.
- **FR-602 (P0)** One visual grammar for the three gauges (Soul Meter = self, Vär = harmony, Balance Gauge = battle): same family, different scale — the player should *see* that the game is one thesis at three zooms.
- **FR-603 (P1)** Battle HUD: initiative, AP, zones, Gauge, discovered weaknesses (Defining Strikes list), check-math tooltip (FR-205). Mirror-symmetric layout.
- **FR-604 (P1)** Character sheet: percentile skills, element Wheel widget (10 spokes, span-arc preview showing legal Chords/Triads/Strained ranges from a hovered element), Vär dial, Background/Mastery display.
- **FR-605 (P2)** 9-patch StyleBoxTexture pass (tracked gap — corners currently sharp); eclipse-corner treatment.
- **FR-606 (P0)** **Blocked-action explanation.** Any greyed-out or failed-to-start action states inline which system blocked it (Vär, Breath, AP, span cap, Balance threshold) and the nearest unblock condition. Direct answer to the predicted first player complaint ("I don't understand why I can't use the ability I built around — or which meter caused it").
- **FR-607 (P1)** **Accessibility baseline:** input remapping, text scaling, color-independent gauge design (shape/position encode state, never hue alone — the eclipse/mirror motifs support this natively), reduced-motion toggle, dyslexia-friendly font option. Controller support ⚑ (gamepad-at-ship is the architecture doc's open question — resolve in Phase 0). Screen-reader support is out of scope for v1 (recorded, not forgotten).

### 6.7 Ancestries (FR-700s)

- **FR-701 (P0)** 4–5 playable ancestries from vault `peoples/` (fully custom races — no D&D stand-ins in *presentation*, even where lore names overlap legacy archetypes). Each: 1 mechanical inheritance (combat- or check-relevant), 1 dialogue-reactivity package (NPCs notice), 1 Wheel affinity nudge (never a hard lock). ⚑ Which 4–5 of the vault's peoples are playable is a canon-adjacent pick — propose, ratify.
- **FR-702 (P1)** Ancestry × faction reputation priors (e.g. starting band offsets) where the vault supports them.

### 6.8 New Game Plus (FR-800s)

- **FR-801 (P1)** ToS-GRADE-style: Combat Style Points (FR-110) accrue all chapter; at chapter end (and later, game end) a **Mirror Shop** offers carry-over purchases: keep skills%, keep Masteries, keep Renown, keep a signature item, ×EXP, cosmetic mirror-world palette. Priced so one strong run affords 2–3 picks.
- **FR-802 (P1)** NG+ save architecture NOW, shop LATER-is-fine: `SaveGame` must carry a **versioned save envelope** (`schema_version` + migration scaffold) and a `ng_plus` block (style points, purchased carry-overs, completion metadata) from Phase 1 onward — retrofitting save schemas is the expensive path. Stable ID schemas for actors, quests, skills, items, zones, world facts, and dialogue nodes underpin both saves and the consequence audit. Carry-over application = a transform on new-game initial state, unit-tested.
- **FR-803 (P2)** NG+-only reactivity: a handful of dialogue lines acknowledge the echo (mirror motif: the world half-remembers). Cheap, thematic, high delight.

### 6.9 Persistence & quality gates (FR-900s)

- **FR-901 (P0)** Everything above serializes: Balance Gauge mid-battle state may be transient, but skills, Vär, Zhavar per zone, ledgers, quest flags, NG+ block round-trip through `SaveGame`. Round-trip tests per system, in CI.
- **FR-902 (P0)** gdUnit4 gates per phase (see §7): unit tests for all resolution math (d100, fizzle, composition algebra, Balance thresholds, style scoring), integration tests per screen/system, one e2e chapter-journey test extending `test/e2e/test_field_debt_journey.gd`.
- **FR-903 (P0)** CI wiring for gdUnit4 headless (currently an open item) + the `SOUL_METER_DRIFT_CHECK=1` Pandora→generated drift gate.
- **FR-904 (P1)** Performance floor: field scenes at 60fps on the dev machine with full HUD; battle transitions < 2s.
- **FR-905 (P0)** **Failure-forward & no-soft-lock design.** Failed skill checks route to alternative content (different approach, cost, or consequence), never a dead-end wall; party defeat has a defined non-game-over path where fiction permits (capture, ransom, reputation cost) and a clean game-over otherwise; retreat from battle is always a costed option; quest-order conflicts and mutually-exclusive quests are declared in quest data and audited (FR-501 tool checks for unreachable states). Save policy: autosave on scene transition + on combat commit, ≥ 3 manual slots, corrupted-save detection with last-good fallback, older-schema saves migrate or fail loudly (never silently mangle). Commitment-before-roll on visible checks (the roll happens when you commit, autosave lands first) — accepts that determined save-scumming exists and makes the honest path the convenient one.
- **FR-906 (P0)** **Narrative-coherence QA (audits are necessary, not sufficient).** Each Phase-4 content wave ends with a human playtest pass against a world-state matrix doc (canonical list of reachable world-states per hub): chronology sense, dialogue coherence, encounter winnability per archetype, and consequences *feeling* meaningful. Combinatorial fan-out is capped by convergent branch design (G5).
- **FR-907 (P1)** **Day-2 & replay QoL:** journal recap of quest state and recent consequences (the `why()` UI, FR-404, doubles as this), seen-dialogue fast-forward, and a respec decision ⚑ (Phase 0: full respec, partial, or none — percentile systems punish early mistakes hard).

---

## 7. Implementation Phases (dependency-ordered)

Each phase ends at an acceptance gate (tests green + manual checklist + design-doc/vault write-back of anything ratified). Phases 2 and 3 can overlap once 2's data schemas freeze.

**Phase 0 — Ratification & canon sync (human-led, ~agent-light). ✅ COMPLETE 2026-08-03 —
gate passed; see `docs/phase-0-ratification.md`. Phase 1 may begin.**
Also produce a **person-hour estimate per phase** (solo capacity is currently unestimated — "no deadline" is not a plan; the estimate sizes the cut list) and ratify the added ⚑s: controller-at-ship (FR-607), respec (FR-907), playtime floor (G1). Resolve every ⚑ in this PRD: skill taxonomy (FR-202), advancement model (FR-204), fizzle table (FR-203), ten Triad-unique effects (FR-304), Vär/Zhavar renames + Elements & Music spec written INTO the vault (rerun `build_index.py`/`validate.py`), playable ancestries pick (FR-701), fast travel (FR-503). Amend design doc §4/§6/§7; mark this PRD's combat/element sections as the ratified spec. **Gate:** vault validates; design doc updated; zero ⚑ remaining.

**Phase 1 — Resolution spine (Codex-heavy).**
`SkillCheck` service (FR-201), fizzle math (FR-203), Elements & Music core engine as pure data-in/effects-out GDScript (FR-301–305 composition algebra, no UI), Vär store (FR-306), Pandora schemas + generators for elements/encounters (FR-307, FR-108 schema half), `SaveGame` NG+ block + serialization tests (FR-802, FR-901), CI wiring (FR-903). **Gate:** unit suite proves the algebra (every Triad, every Strained span, Clash on >2 span, Vär gating) headlessly.

**Phase 1.5 — Integrated slice: the go/no-go gate (research-mandated).**
Before region production begins, assemble a 45–90 minute slice exercising every subsystem end-to-end: exploration, one dialogue skill check, one consequence-bearing side quest, one full tactical encounter (AP + at least one Defining Strike + zone facing + Balance Gauge), save/load mid-slice, and a mock NG+ rollover. Built from Phase 1/2 parts as they land — this gate sits between Phase 2 and Phase 4 chronologically but is called out separately because passing it is the go/no-go for content production. **Gate:** 3–5 outside playtesters (not one) complete the slice unaided; the complexity budget is explicitly tested — each playtester must correctly answer "why did that cast fail?" and "what does this gauge do?" for the systems the slice exposes; every subsystem state survives save/load; NG+ mock applies carry-overs correctly. Onboarding is breadth-first (Tone-only opening) per the §8 risk plan.

**Phase 2 — Combat vertical (Codex + DeepSeek).**
Battle scene rebuild on the spine: AP economy (FR-102), zones behind `BattlefieldModel` (FR-105), Balance Gauge (FR-104), Defining Strikes (FR-103), speech-in-battle (FR-106), consequence writes (FR-107), battle HUD v1 (FR-603), style scoring accrual (FR-110). Encounter pipeline (FR-108). **Gate:** 5 archetype encounters (demon / undead / mixed whipsaw / speech-winnable / stabilizer-showcase) playable and integration-tested; the four build archetypes each clear them. **The zones-depth question is settled HERE, not deferred to v2:** the gate playtest must demonstrate real positional tradeoffs (cover, range/reach, flank pressure, movement cost); if zones can't produce them, the grid decision escalates to the human immediately, while `BattlefieldModel` keeps the swap cheap.

**Phase 3 — Character & UI systems (parallel with late Phase 2).**
Character creation (attributes/Backgrounds/Masteries, FR-202), ancestries (FR-701–702), advancement (FR-204), design-system extension then HUD/gauge unification (FR-601–602), character sheet + Wheel widget (FR-604), check-math surfacing (FR-205–206), `why()` payoff UI (FR-404). **Gate:** new character → creation → field → battle → level-up loop, all three gauges in one visual grammar, design-doc screenshot review.

**Phase 4 — Region production line (fleet-heavy: DeepSeek content passes, Codex systems support, Gemini/Jules test generation).**
Locations 2–12, hub 2–3, main quest Act I, ≥ 10 side quests, companions (FR-505), band-gated reactions (FR-402), living-texture tier 1 (FR-504), Zhavar telegraphing + tolling event (FR-308), thinning gradient (FR-506), quest audit tool (FR-501/403). Content templates first, then parallel authoring waves. **Gate:** audit tool green (outcomes/read-backs/orphans), main quest e2e test, per-location manual checklists.

**Phase 5 — NG+, polish, acceptance.**
Mirror Shop (FR-801), NG+ reactivity (FR-803), 9-patch pass (FR-605), performance (FR-904), full-suite CI, 4-archetype full playthroughs, chapter acceptance gate. **Gate:** the §3 metrics table, every row.

### Agent delegation plan (per global policy)

| Work | Fleet | Bounds |
|---|---|---|
| Resolution math, combat engine, serialization, generators | Codex (≤5) | Architecture fixed by Phase-0 spec; no design decisions; tests required per handoff |
| Content waves: encounters, quest scripts, dialogue drafts, location dressing | DeepSeek (≤5) | Template + canon excerpt in prompt; outputs are drafts — Claude reviews vs. vault before merge |
| Docs/API research, test generation/triage, first-pass UI mocks | Gemini / Jules | Bounded questions; compact evidence-backed handoffs |
| Architecture, canon, UX direction, review/synthesis, GitHub triage | Claude | Owns every merge; workers never mutate labels/assignees |

All handoffs: objective, branch, allowed scope, deliverables, acceptance checks, do-not-decide boundary. Non-recursive.

**Fleet-reality clauses (adversarial-review fix):** 10 concurrent agents ≠ 10× output — Claude's mandatory review is the bottleneck, so content waves are sized to review capacity (a wave ships only when reviewed, and wave N+1 doesn't start until N merges); template conformance (stable IDs, canon excerpts, schema-validated output) is checked mechanically *before* human review so review time goes to meaning, not format; integration debt that CI can't see (tone drift, balance drift) is caught by the FR-906 per-wave playtest pass.

---

## 8. Risks & Mitigations

| Risk | L | I | Mitigation |
|---|---|---|---|
| **Scope: "Chapter 1" balloons** (10 Triad effects × encounters × 12 locations) | H | H | §8 guardrails are law; audit tool counts, phases gate; cut list pre-agreed: FR-P2s first, then side quests 11+, never the consequence mandate |
| **Elements & Music complexity overwhelms players** (2 axes × 10 elements × Vär × Breath × Aftertones) | M | H | Onboard breadth-first: Chapter 1 opens Tone-only, Chords unlock via story beat, Triads late-chapter; Wheel widget teaches legality visually; playtest gate in Phase 3 |
| **Balance Gauge + Vär + Soul Meter read as gauge soup** | M | H | FR-602 single visual grammar; each gauge owns a distinct decision (battle tactic / casting legality / story spend); if playtests still confuse, Vär folds into the character sheet only |
| **Combat depth vs. zones ceiling** — AP+called shots may crave a grid | M | M | `BattlefieldModel` interface (FR-105) keeps grid swap possible in v2; playtest Phase 2 gate decides early |
| **Agent-fleet drift from canon** (10 parallel content agents inventing lore) | H | M | Canon excerpts in every prompt; Claude-only merge; vault `validate.py` in CI; DeepSeek output is always draft-status |
| **Save-schema churn** across 5 phases | M | H | NG+ block + versioned schema from Phase 1 (FR-802); migration test per schema bump |
| **Fizzle/percentile double-randomness frustration** (d100 skill + fizzle + Instability die) | M | M | One roll surface per action where possible; Strom's Rule-Bend and Masteries exist to delete dice; show the math (FR-205) |
| **Solo-dev burnout / no deadline = no finish** | M | H | Phase gates are the deadline substitute; each gate ships a playable increment; Obsidian/PM handoff docs track between sessions |
| **15–25h target is aggressive for solo scope** (research finding) | H | M | 8–12h dense floor ratified in Phase 0; quest-quality metrics, not hours, are the acceptance bar; repetition is the enemy, not brevity |
| **Transparency backfires** (visible % invites save-scumming/metagaming; gauge UI disrupts flow) | M | L | Commitment-before-roll + autosave-on-commit (FR-905); failure-forward design makes failed checks content, not reload bait; gauge deltas shown on hover, not as constant motion |
| **Combinatorially "green but broken"** — audits prove wiring, not that chronology/dialogue/balance make sense | H | H | FR-906 per-wave narrative-coherence playtests against a world-state matrix; convergent branch design caps reachable states; audits demoted to necessary-not-sufficient |
| **Claude-review bottleneck caps fleet throughput** | H | M | Waves sized to review capacity; mechanical conformance gates before human review; no wave N+1 until wave N merges |
| **Vault ↔ doc ↔ code triple-drift** | M | M | Phase 0 makes the write-backs; ⚑ discipline (nothing builds unratified); drift checks in CI |

---

## Appendix A — Open questions carried (⚑ ledger) — **CLOSED 2026-08-03**

Every ⚑ below was ratified in the Phase 0 session. The decisions, the reasoning, and the
proposals they generated live in **`docs/phase-0-ratification.md`**, which is normative.

| # | ⚑ item | Resolution |
|---|---|---|
| 1 | Skill taxonomy (FR-202) | ~~open~~ **Twelve skills, 4 per domain; Lore stays one tagged skill.** Percentile surface derived from the vault's Untrained/Trained/Expert tiers (`attr × 8 + tier_bonus + points`). |
| 2 | Advancement (FR-204) | ~~open~~ **Point-buy at level.** No use-based drift. Costs scale 1/2/3 points per +5% across the 50%/75% bands; Ch1 cap 95%. |
| 3 | Fizzle table (FR-203) | ~~open~~ **Ratified formula + starting table** (Integrity base × magnitude multiplier, breadth and strain adds, Pitch and Mastery reductions, Fickah's 5% floor). TUNABLE in Phase 2. |
| 4 | Ten Triad-unique effects (FR-304) | ~~open~~ **All ten designed and ratified** — every one structural, none damage; Stillpoint is the Balance-Gauge stabilizer payoff. |
| 5 | Playable ancestries (FR-701) | ~~open~~ **Vael, Kaan, Vaerin, Weftkin, Kes'reth.** Kes'reth's Voice/Anchor leaning + *Mirrored Scars* is new canon, written to the vault. |
| 6 | Fast travel (FR-503) | ~~open~~ **Yes — discovered hubs only, at a cost** (time passes / resource spent). |
| 7 | Vär/Zhavar (FR-306/308) | ~~open~~ **Additions, not renames** — neither "Galm" nor "Carry"/"Overtone" existed in the vault. Both written into the new `systems/elements-and-music.md`. |
| 8 | Design-doc §10 canon questions | **Remain open by design.** Nothing here resolves them. |

Three ⚑s added by the adversarial review are also closed: **controller-at-ship** (FR-607 —
keyboard/mouse first, gamepad post-Ch1; `docs/godot-architecture.md` Q3 now answered),
**respec** (FR-907 — partial, one Mirror Rewriting per chapter), and the **playtime floor**
(G1 — 8–12 dense hours is the acceptance bar; 15–25h is a stretch, never a requirement).

One conflict the PRD had not surfaced was also resolved: FR-302/309 assume a **Breath** pool,
which vault `magic-system.md` had declined as contradicting canon fact 8. Ratified as the
**boundary model** — Breath is per-scene; casting past empty Breath spends the Soul Meter
permanently, so "magic spends the Gauge and it mostly only goes down" stays literally true.

**Person-hour estimate (Phase 0 deliverable): ~350–510 person-hours total across Phases 1–5**
— 35–51 weeks at 10 h/week, 18–26 weeks at 20 h/week. Per-phase breakdown and the pre-agreed
cut list are in `docs/phase-0-ratification.md` §8.

## Appendix B — Traceability

- Design doc: §6 chassis/combat identity (FR-100s), §4.2 Meter (FR-405, 602), §8 guardrails (§4 non-goals, FR-501), §9 implementation notes (phase order)
- Vault: `systems/magic-system.md` (FR-203, 301–309), `systems/ten-patron-classes.md` (FR-310), `systems/character-creation.md` (FR-202), `peoples/` (FR-701)
- Repo: `globals/reputation.gd`/`renown.gd` (FR-401), `globals/battle.gd` (rebuilt in Phase 2), `globals/save_game.gd` (FR-802/901), `docs/testing.md` (FR-902)
- User spec 2026-08-02: Elements & Music (FR-300 block, normative)

---

## Appendix C — Stated assumptions (untested until their named gate)

1. Players will tolerate this system count *if* onboarded breadth-first — tested at the Phase 1.5 gate (3–5 playtesters, comprehension questions), not assumed.
2. Zones can deliver enough positional depth — tested at the Phase 2 gate; grid escalation path pre-wired.
3. The agent fleet nets positive after review overhead — measured per wave in Phase 4; if a wave's review cost exceeds authoring it solo, shrink the fleet.
4. A versioned save envelope makes evolving state *manageable*, not free — every schema bump ships with a migration test (FR-802/905).
5. 8–12 dense hours is achievable solo-plus-fleet — the Phase 0 person-hour estimate is the check; the pre-agreed cut list is the response.

---

*Adversarial review: applied (provider: codex, via orchestrate.sh spawn, 2026-08-02). Valid challenges incorporated: G5/FR-403 contradiction resolved; G9/FR-504 contradiction resolved; failure-forward/soft-lock/save-policy FR-905 added; accessibility FR-607 added; day-2/replay FR-907 added; Vär anti-build-lock rule added; blocked-action explanation FR-606 added; zones-depth decision pulled into Phase 2 gate; narrative-coherence QA FR-906 added; fleet-bottleneck clauses added; person-hour estimate mandated in Phase 0; single-playtester validation replaced with 3–5 + comprehension checks. Dismissed with rationale: screen-reader support (recorded as out of scope for v1, not silently dropped); "seeded rolls merely change scumming's shape" (accepted — FR-905 chooses commitment-before-roll + failure-forward instead of fighting determined scummers).*

*Research: orchestrate.sh multi-provider probe (codex + gemini + claude-sonnet, 2 complete / 3 partial, synthesized 2026-08-02). Key adopted findings: integrated-slice go/no-go gate, three-layer architecture + CombatController event pipeline, versioned save envelope + stable ID schemas, 8–12h dense floor, transparency-with-mitigation principle.*

*Self-score (100-pt framework): AI-Specific Optimization 22/25 (FR-numbered, priority-tagged, dependency-ordered phases, explicit do-not-decide boundaries and delegation bounds per agent fleet; loses points: no per-FR file-path targets yet — deliberately deferred to phase kickoff specs). Traditional PRD Core 23/25 (personas, quantified problem, SMART goals, metrics table, non-goals; loses: market sizing N/A for a solo art project). Implementation Clarity 27/30 (phases with acceptance gates, traceability appendix, risk table with mitigations, assumptions ledger; loses: person-hour estimates deferred to Phase 0 by design). Completeness 18/20 (failure states, accessibility, saves, NG+, QA strategy covered; loses: art/audio pipeline unaddressed — tracked as a known gap, see art-request.md workflow). **Total: 90/100.***
