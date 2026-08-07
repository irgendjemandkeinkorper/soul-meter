# Kenney assets — attribution & license

Art, UI, and fonts under `assets/kenney/` are by **Kenney** (https://kenney.nl),
from the *Kenney Game Assets All-in-1* collection.

**License: Creative Commons Zero (CC0 1.0)** — public domain. You may use, modify, and
distribute these commercially without attribution required. Crediting Kenney is appreciated
and is the right thing to do; this file provides it.

Only a curated subset was imported (top-down tiles, characters, UI, fonts) — not the full pack.

Layout:
- `tiles/`      — tiny-* and roguelike-* top-down tilesets (tilesheets + individual tiles)
- `characters/` — roguelike character spritesheets
- `ui/`         — UI panels, buttons, borders, cursors (PNG + 9-slice-ready)
- `fonts/`      — Kenney TTF fonts (Kenney Pixel, Mini, Blocks, Future, …)

Vector/source files (SVG/AI/EPS) and Tiled files were pruned to keep the project lean.

## Usage audit — 2026-08-07

The current runtime reference audit found the following direct legacy sprite
asset under this tree:

- `characters/roguelike-characters/Spritesheet/roguelikeChar_transparent.png` —
  shared by the player, NPC, enemy, and party-follower presentation scenes.

Town buildings, props, ground tiles, and generated townsfolk are rendered from
the separate `assets/kenney3d/` source kits. They are covered by
[`assets/kenney3d/ATTRIBUTION.md`](../kenney3d/ATTRIBUTION.md) and should not be
counted as direct `assets/kenney/` references. The generated sprite manifest
retains each source model path for traceability.

This is a collection-level attribution: unused files inside the curated Kenney
folders are not individually listed because the collection license and source
pack are the attribution unit. Re-run the audit when a new asset family is
imported or a source directory changes.
