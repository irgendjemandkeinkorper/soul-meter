# Project context — Godot UI & game flow architecture

Handoff document. Drop this at the repo root (or rename to `CLAUDE.md`) so it's picked up as
standing context.

---

## Stack

- **Engine:** Godot 4.6 (`4.3+` is the compatibility floor, inherited from the game template)
- **Language:** GDScript
- **Dimension:** _unresolved — 2D or 3D. Affects nothing below, but resolve before level work._

---

## Architectural decisions

These are settled. Don't relitigate them mid-task; if something here turns out to be wrong,
surface it rather than silently working around it.

### 1. Maaack's Godot Game Template is the project base

- Source: `https://github.com/Maaack/Godot-Game-Template` (MIT)
- Asset Library: template `2703`, plugin `2709`
- Provides: main menu, options menus, pause menu, credits, loading screen, opening scene,
  persistent settings, overlay menus, keyboard/mouse + gamepad support, input remapping,
  UI sound + music controllers, markdown credits reader, basic save/load, global config autoload
- Extras used: level loaders, level progress manager, win/lose managers

**Critical constraint:** the template's examples are *inherited scenes* from `addons/maaacks_game_template/base/`
and `extras/`. Extend the inherited copies. Never edit anything under `addons/` — that directory is
upstream and gets overwritten on plugin update.

### 2. Godot State Charts owns game and menu flow

- Source: `https://github.com/derkork/godot-statecharts`
- Asset Library: `1778`
- Docs: `https://derkork.github.io/godot-statecharts/`

Chosen over a hand-rolled FSM and over LimboAI because it's statecharts rather than flat FSM
(hierarchy, parallel states, history states — avoids state explosion), it's node-and-signal
idiomatic, and integration surface is a single `StateChart` class with two methods. No base class
to extend, no interface to implement.

Features to actually use:

- **Compound states** — one child active at a time
- **Parallel states** — for genuinely independent concerns (mute status vs current screen).
  Do not model independent booleans as separate flat states.
- **History states** — returning from gameplay lands on the menu screen you left from
- **Guards** — conditions on transitions (e.g. Continue only enabled when a save exists)
- **Delayed transitions** — cooldowns, splash minimum duration
- **Debug view** — keep it wired up in dev builds
- **`StateChartSerializer`** — save/restore chart state; relevant to save games

### 3. LimboAI is deferred, not rejected

- Source: `https://github.com/limbonaut/limboai` (MIT-style)
- Behavior trees + hierarchical state machines, C++ plugin, supports Godot 4.6

**It is for agent AI — enemies, NPCs, creatures. It is not for menu flow.** Godot State Charts
handles application flow; LimboAI handles things that think.

There is currently no agent in the project for a behavior tree to drive, so building trees now
would be building against an imaginary spec. Install it when the first enemy exists.

One decision to make *before* installing, because it's structural:

- **GDExtension build** — drop-in, no engine compilation, somewhat fewer features
- **C++ module** — full features, requires building the engine and export templates from source

Default to GDExtension unless a missing feature forces otherwise. Projects stay compatible with
both and can switch later.

---

## The flow architecture

**The state chart is policy. The template's scene loader is mechanism.**

The chart decides *what* should happen. The loader decides *how* it happens.

```
StateChart
└── Game (compound)
    ├── Boot (atomic)          splash, config load
    ├── Menus (compound)       history state here
    │   ├── Title
    │   ├── Options
    │   └── Credits
    └── Playing (compound)
        ├── Active
        └── Paused
```

Flow of a level load:

1. Chart transitions toward `Playing`
2. The entering state's `state_entered` handler calls the template's loader
3. Loader does threaded load + progress screen
4. Loader emits its finished signal
5. Handler sends an event back into the chart (`send_event("level_ready")`)
6. Chart activates `Active`

Notes:

- `back` is declared once on `Menus`, not three times on its children
- Pause is a transition *between children of* `Playing`, so pausing cannot unload the level
- Pause itself uses `get_tree().paused` + per-node `process_mode`; it's an overlay, not a
  scene transition

---

## Conventions and guardrails

**Flow**

- No `change_scene_to_file()` anywhere in game code. All flow goes through the chart.
- UI elements send events (`state_chart.send_event("options_pressed")`). They never name a
  destination. A button that knows what comes next is a button that can't be reused.
- Put transition conditions in guards, not in `if` blocks inside button handlers.
- Every state gets paired enter/exit handling. If enter allocates or connects something,
  exit releases it.

**Theming**

- Use theme *type variations* (`DangerButton`, `HUDLabel`) rather than per-node theme overrides.
  Per-node overrides are the thing that makes UI unmaintainable at scale.
- Nine-patch via `StyleBoxTexture` for anything that must survive resolution changes.
  Target range is 4k down to 640x360.
- Consider ThemeGen if the theme grows past a handful of variants — defining themes in GDScript
  beats clicking through the theme editor once styles need reuse.

**Focus and input**

- Set `focus_mode` deliberately on every interactive control.
- Call `grab_focus()` on menu entry. Restore prior focus when popping back.
- Test every menu with gamepad only. Mouse-and-gamepad mixing is where this breaks.

---

## Setup task order

1. Create project from Maaack's template via Asset Library (`Asset Library Projects` tab →
   "Maaack's Game Template")
2. Run the setup wizard: `Project > Tools > Run Maaack's Game Template Setup...`
   — it copies example scenes out of `addons/` into the project root
3. Verify the copied scenes run: main menu → options → back → example game scene
4. Install Godot State Charts from the Asset Library, enable the plugin
5. Build the root chart per the tree above, with all states empty
6. Wire the existing template menu buttons to `send_event()` calls
7. Wire the loader's completion signal back into the chart
8. Add the state chart debugger scene to the main scene, dev builds only
9. Gamepad pass: focus modes, `grab_focus()` on entry, back-navigation
10. Commit before touching theming — theming is a separate concern and a separate branch

Do **not** start on LimboAI or behavior trees in this pass.

---

## Open questions for the human

- 2D or 3D? - 2d, isometric from 3d models. 
- Target platforms — does console/gamepad-only need to work at ship, or is it desktop-first?
- Any theme/art direction yet, or is placeholder fine for now?
- Is multiplayer anywhere on the roadmap? (Affects whether `StateChartSerializer` matters early.)

---

## Sources

- Maaack's Godot Game Template — https://github.com/Maaack/Godot-Game-Template
- Godot State Charts — https://github.com/derkork/godot-statecharts
- Godot State Charts manual — https://derkork.github.io/godot-statecharts/
- LimboAI — https://github.com/limbonaut/limboai
- LimboAI docs — https://limboai.readthedocs.io/

THis is the design system we should be keeping in mind when designing menus and screens and entities.  

https://claude.ai/design/p/241acfb5-f8a3-4283-89c2-d5090b297c43?via=share