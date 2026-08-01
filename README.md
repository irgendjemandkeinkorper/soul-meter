# Soul Meter — external playtest prototype

Soul Meter is a lore-heavy isometric CRPG prototype built in Godot 4.7.1. This slice is a
20–30 minute Windows keyboard-and-mouse path through Dom and Dorthkor Road. Vex the Unbowed
leads a three-person company into a demon breach and a dead military muster; the ending
records how the signature encounter was resolved and how Dom responds.

## Play the critical path

1. Start a new game. Move with **WASD** and interact with **E**.
2. Enter the Four Arms and choose exactly two companions. Vex is always the lead.
3. Report to Marshal Coiljaw and accept **The Broken Muster** commission.
4. Take the north road, defeat the two-enemy demon vanguard, then confront the Mustered
   Bloodbellow.
5. Resolve the Bloodbellow by force, break its binding at Order +50 for 3 Soul, or survive an
   enemy round and release it while Balance is between -20 and +20.
6. Return to Coiljaw, report what happened, and choose Dom's ruling. The consequence screen
   offers a copyable playtest summary and unlocks the Loamroot grove for free roam.

The HUD always shows the current objective and party health. **I** opens inventory, **P** the
party, **Q** the journal, **R** standings, and **Esc** pause/manual save. Combat tooltips and
disabled contextual actions state their requirements.

## Run from source

Open `project.godot` in Godot **4.7.1**, let the initial import finish, and press Play. The
project uses the Compatibility renderer and a 1280×720 reference viewport.

Run all automated tests:

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh
```

Run the release-oriented, art-free gate (generated-data drift plus the deterministic suite):

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/acceptance_gate.sh
```

Run the external-playtest checklist in
[`test/manual/prototype_acceptance.md`](test/manual/prototype_acceptance.md) before sharing a
build.

## Windows build

Install Godot 4.7.1 export templates, then export the **Windows Desktop** preset from the
editor or run:

```bash
mkdir -p build/windows
godot --headless --recovery-mode --path . --export-release "Windows Desktop" build/windows/SoulMeter.exe
```

GitHub Actions runs the tests first, then uploads `SoulMeter-windows-x86_64.zip`. The archive
contains the `.exe`, `.pck`, this README, and dependency/license notes.

## Saves and feedback

The prototype uses one version-2 slot at `user://chapter_one.save`. Autosaves occur at the
initial spawn, party confirmation, commission, location/encounter checkpoints, ruling, and
free-roam unlock. Pause also provides a confirmed manual overwrite. Earlier experimental save
formats are intentionally unsupported.

No telemetry or network service is used. At the end, copy the generated summary and answer:

1. Where did the next objective become unclear?
2. Which combat choice felt most meaningful, and why?
3. What stopped this from feeling ready for another 20 minutes?

## Project boundaries

Pandora is canonical game data; `data/generated/` is regenerated, never hand-edited. Game
flow routes through the State Chart and `GameFlow`. The isometric graybox uses a project-owned
64×32 blockout atlas; character/UI sprites and sounds are CC0 Kenney assets. See
[`DEPENDENCIES.md`](DEPENDENCIES.md), [`assets/kenney/ATTRIBUTION.md`](assets/kenney/ATTRIBUTION.md),
[`design/DESIGN_PILLARS.md`](design/DESIGN_PILLARS.md), and
[`design/DESIGN_SYSTEM.md`](design/DESIGN_SYSTEM.md).
