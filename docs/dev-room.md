# Dev room

Run the project in the Godot 4.7.1 editor and select **DEV ROOM** on the title menu.
The button sends a flow event; the chart bootstraps the preset and calls
`GameFlow.travel()` through the normal loading state and SceneLoader.

The debug-only session uses the existing runtime sandbox. It remains armed when
leaving through a door, and returning through **Esc → Main Menu** restores the
previous runtime state. Starting the scene directly bypasses that bootstrap;
use the title button for playtesting.

## Edit the preset

Edit [`dev/dev_room_preset.tres`](../dev/dev_room_preset.tres), or open it in the
Godot Inspector. Each launch reloads the resource.

1. Set the protagonist's chargen choices and attributes. They use `ChargenBuild`,
   the same construction and creation-ledger path as character creation.
2. Add optional `companion_ids` from `GameState.recruitable_candidates()` (for
   example `ressa-quickfingers`). Their existing data is reused.
3. Set `items` to ItemIds values and positive counts. Large counts split into
   legal stacks. Set `silver`, `level`, `xp`, `soul`, and the list of true `flags`.

`level` applies to the protagonist. XP first pays the normal curve to reach that
level; `xp` adds more afterward and can advance further, up to the existing cap.
Companions retain their authored levels. Empty Major/Minor choices use the
class's suggestions. Invalid choices refuse entry and leave the prior state intact.

The shipped preset has a level-1 Vael Chordblade/Mirrorblade, Dom Storm-Coast
background, no companions, 500 silver, 50 Soul, zero XP, and no extra flags.
It contains all three current weapons (Forge Hammer, Roadwarden Spear,
Taubstummer Axe), five each of Bitterleaf Poultice, Hearthloaf, and Loam Bread,
plus Field Needle, Lockpick Roll, Soul Gauge, and Surveyor's Chalk.

## Showcase objects

The room reuses the existing player, followers, field HUD, generated isometric
ground, chests, Toma Reedhand actor/data, interactables, and travel exits.
Use **E** for interactions and **F** for the pocket. The six examples exercise
Slip on a locked chest, pickpocketing, the `road-cache` loot table, the equipment
shop, a Strain check, and the existing `bog-wight` encounter with deployment and
same-map combat. Checks retain the game's normal success/failure rules.

Add instances of those existing actors in `dev/dev_room.tscn`. Give every new
container, pocket, lock, and test flag a unique `dev-` prefix. Keep related
scripts, resources, and scenes inside `dev/`; reuse existing data and art.
For a combat station, attach `dev_combat_trigger.gd` to an interactable and set
an existing `EncounterCatalog` ID.

The door board has Dom, Ashlaren, Kesselford, Long Verge, Hollowmere, Wilds,
Dorthkor Road, and Wound Lip. `dev_room.gd` resolves existing GameFlow constants
and LocationRegistry definitions before the TravelExit nodes initialize.

## Export boundary and save protection

Both shipping presets exclude `dev/*`. The title button checks
`OS.is_debug_build()`; the chart guard also checks that the dev resources exist.
The flow contains only string paths and loads the bootstrap inside a debug guard.
No dev script registers a global `class_name`.

The fixed exclusion applies to debug exports made with these shipping presets,
too: their debug title button remains visible, but the guarded route is inert
because its assets are absent. Editor play is the supported launch path with
the checked-in presets. A separate local debug preset would need to include
`dev/` to make exported dev-room play available.

The existing sandbox suppresses arrival and interaction autosaves. Manual-save
containment is pending the requested scope exception for the shared save writer;
until that is approved and verified, manual saves are an unresolved risk.

Acceptance coverage: `test/integration/test_dev_room.gd` and
`test/integration/test_dev_room_inert.gd`. Rendered runs can write screenshots
when `SOUL_METER_DEV_CAPTURE_DIR` names an existing output directory.
