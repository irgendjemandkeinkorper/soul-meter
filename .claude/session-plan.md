# Session Plan — Soul Meter Roadmap Reset

**Created:** 2026-08-07
**Intent Contract:** `.claude/session-intent.md`
**Mandate:** Reset the roadmap, not the mechanics (D1 + D2)

---

## What You'll End Up With

Four committed artifacts that replace the stale planning brief with a roadmap derived from
the actual repo:

1. **`docs/roadmap-chapter-one.md`** — phased milestone map to ship one complete 15–25h
   region, with epics, dependency ordering, and a definition of done per milestone.
2. **`docs/architecture-tactical-and-navigation.md`** — concrete Godot scene/script
   architecture for the four named systems.
3. **`docs/prd-amendment-living-world.md`** — the FR-504 amendment D6 requires.
4. **`docs/eval-orchestrator.md`** — the addon evaluation, with a recommendation.
5. **GitHub milestones + issues** on `irgendjemandkeinkorper/soul-meter`, labelled per the
   codex / gemini / jules routing policy.

---

## The Four Named Systems — architecture scope

| System | Current state | What the doc must specify |
|---|---|---|
| **Global state / flag manager at scale** | `GameState` (flags, Soul Meter, party, inventory) + `Reputation` (append-only ledger) + `Renown`. Save schema 5 with migrations. | How this holds *hundreds* of quest variables: flag namespacing, stable ID schema, the `quest_audit.gd` orphan/read-back check, and the save-envelope contract (FR-802) that makes it survivable. |
| **Isometric world + navigation** | `IsometricBlockout : TileMapLayer`, 64×32, generated tileset. **No pathfinding at all.** | `AStarGrid2D` construction from the tile layer, obstacle baking from a collision layer, Y-sorting order for iso depth, click-to-move controller, and how the *same* `AStarGrid2D` serves tactical movement range. This is the largest genuinely-unbuilt overworld gap. |
| **Tactical combat (charge-time, not AP)** | `BattlefieldModel` interface + **only** `ZoneBattlefieldModel`. `charge_time_scheduler.gd` exists. | `GridBattlefieldModel` as a sibling behind `create_default()`. The interface must *widen* to express cells, elevation, facing, occupancy, LOS, and path cost — today it speaks only `StringName` zone ids. Consumers must never learn the concrete type. |
| **Soul Meter hooks** | `GameState.soul_meter`, `SoulGauge` HUD, dialogue `[#cost=-6 soul]` tags. | Downward-only economy (D5): cast cost, the zero-catastrophe path, slow/social recovery, dialogue gating via Dialogue Manager `[if /]`, and combat casting-gate integration. |

---

## Phase Weights

```
DISCOVER    ██████ 15%
Audit ratified FRs against verified code state; evaluate Orchestrator
against Godot 4.7 + Pandora-as-canonical.

DEFINE      ████████████ 30%
Author the roadmap doc and the FR-504 amendment. Every ratified FR gets an
explicit disposition: carried, amended, or retired. Nothing changes by silence.

DEVELOP     ████████████████ 40%
Author the architecture doc for the four systems. Create GitHub milestones
and self-contained, labelled issues.

DELIVER     ██████ 15%
Validate: no ratified FR silently dropped; gates present as blocking; issues
self-contained; boundaries in the intent contract respected.
```

---

## Blocking Gates (must appear as milestones, not checkpoints)

- **Phase 1.5 comprehension gate** — never run. Needs 3–5 outside human playtesters; an
  agent fleet cannot execute it. Region content must not merge into `world/locations/` or
  `LocationRegistry.ALL` until it passes. (`docs/playtest-protocol.md`)
- **Gate T** — the replacement gate installed by the tactical amendment §5. Grid + elevation
  + facing must demonstrably produce encounters that are meaningfully harder or unwinnable
  without exploiting height or facing. Grid map / encounter *production* must not start
  before Gate T passes (amendment §8.1 stop-loss).
- **FR-904 performance floor** — instrumented, not satisfied.

## Open Canon Questions — surface, never resolve

- **#132** three combat disciplines vs the Ten Patron Classes (advisory recommendation
  exists; not ratified)
- **FR-701** which 4–5 vault peoples are playable
- **FR-907** respec policy — full, partial, or none
- Gamepad-at-ship (`docs/godot-architecture.md`)

---

## Provider Availability

```
🔴 Codex CLI:        Available ✓
🟡 Gemini CLI:       Available ✓
🧭 Antigravity CLI:  Not installed ✗
🟤 OpenCode:         Not installed ✗
🟢 Copilot CLI:      Available ✓
🟠 Qwen CLI:         Not installed ✗
⚫ Ollama:           Not installed ✗
🔵 Claude:           Available ✓
🟣 Perplexity:       Not configured ✗
🐙 gh CLI:           Authed as irgendjemandkeinkorper ✓
```

Per the global role policy: Claude owns architecture, roadmap, scope, and GitHub triage.
Gemini is the candidate for the bounded Orchestrator research. Codex is the candidate for
`GridBattlefieldModel` and the navigation implementation once the architecture is ratified —
not before.

---

## Debate Checkpoints

- **After Define:** "Does the roadmap's sequencing survive the asymmetry the tactical
  amendment §2 identified — scheduler seam before grid production?"
- **After Develop:** "Does the widened `BattlefieldModel` interface express cells, elevation,
  facing, occupancy, LOS and path cost without any consumer learning the concrete type?"
  This is the amendment's own stop-loss criterion.

---

## Execution

```bash
/octo:embrace "Re-derive the Soul Meter Chapter One roadmap and architecture from verified repo state"
```

Or phase by phase: `/octo:define` → `/octo:develop` → `/octo:deliver`.

## Success Criteria

See `.claude/session-intent.md` § Success Criteria.
