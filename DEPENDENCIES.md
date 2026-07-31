# Dependencies

Every addon pinned per the architecture handoff (`docs/godot-architecture.md`). Upgrade Godot
deliberately, not eagerly; when bumping an addon, update its pin here in the same commit.

**Engine:** Godot **4.7.1-stable** (handoff floor is 4.6; all addons below verified importing
clean on 4.7.1 headless, Linux).

## Installed (addons/)

| Addon | Version / pin | Source | Breaks if removed |
|---|---|---|---|
| Maaack's Game Template | `93e66a0` | github.com/Maaack/Godot-Game-Template | AppConfig/SceneLoader/music+UI-sound autoloads; scene loading w/ loading screen; future menus/save/input-remap. **Setup wizard not yet run — run it in the editor (Project → Tools) to copy example menus out of addons/.** |
| Godot State Charts | `76d226a` (user zip, `plugins/`) | github.com/derkork/godot-statecharts | The entire game/menu flow (`ui/flow/game_flow.tscn`). |
| Pandora | `d78b99e` | github.com/bitbrain/pandora | Canonical game data (items, combatants, encounters, spells, factions, NPCs, and lore-facing IDs). ⚠ pre-1.0; verify stability before deep dependence. |
| Dialogue Manager | `09b82d6` (v4, needs 4.6+) | github.com/nathanhoad/godot_dialogue_manager | Branching dialogue; `DialogueManager` autoload (registered manually). |
| QuestSystem | `853276e` | github.com/shomykohai/quest-system | Quest lifecycle; `QuestSystem` autoload. |
| GLoot | `6b09b87` | github.com/peter-kish/gloot | Inventory backend. Fully wired to GameState and ui/screens/inventory.gd. |
| Phantom Camera | `dbf15ee` | github.com/ramokz/phantom-camera | Camera behaviors; `PhantomCameraManager` autoload (registered manually). |
| Anima | `f28a1be` | github.com/ceceppa/anima | UI/menu motion; `ANIMA` autoload. |
| Juicee | `eb66d35` | github.com/Kelpekk/Juicee | Game-feel FX; `Juicee` autoload. |
| SmartShape2D | `b52ea53` (ss2d 3.3.1) | github.com/SirRamEsq/SmartShape2D | 2D organic terrain authoring. |
| PixelPen | v1.1.4 release | github.com/pixelpen-dev/pixelpen | Pixel-art authoring. **Parked with a `.gdignore` on Linux/WSL (prebuilt .so needs glibc ≥2.38). On Windows: delete `addons/net.yarvis.pixel_pen/.gdignore` and re-enable the plugin.** |
| gdUnit4 | `v6.1.3` (`1579130`) | github.com/godot-gdunit-labs/gdUnit4 | Test framework — see `docs/testing.md`. Requires Godot 4.5+; editor plugin only (no autoload). Run via `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh -a test`. |

## Pending / deferred

- **GodotGAS** — abilities/attributes/effects. **No public repo**; distributed via
  store.godotengine.org (login-walled). → Download from the store and drop the zip in
  `plugins/`; read the source before depending on it (per handoff). ⚠ Co-op multiplayer is
  now a live maybe — GodotGAS is single-player-scoped today (networking is roadmap); wrap it
  behind our own ability seam so it can be replaced if co-op lands.
- **LimboAI** — NPC/enemy behavior trees. Deferred until the first agent exists. The
  `plugins/limboai-master.zip` on the Desktop copy is *engine source*; when the time comes,
  fetch a **GDExtension release** instead (no engine build).
- **Godot Shaders** — not a plugin; copy shaders in per-need, checking each shader's license.
- **CI and Windows packaging** — `.github/workflows/test.yml` imports with the pinned engine,
  runs the full suite under Xvfb, fails on Pandora artifact drift, then exports and uploads a
  zipped Windows x64 Compatibility build.

## Local quirks

- Maaack/DialogueManager/PhantomCamera autoloads were registered manually in `project.godot`
  (their enable-hooks ran headless where parts of the setup can't). Harmless "remove
  unregistered singleton" editor-log lines from Phantom Camera are known.
- The template's audio-bus install was auto-disabled headless
  (`disable_install_audio_busses=true`); `Music`/`SFX` buses are created at runtime by
  `GameState._ensure_audio_buses()`.

## Pandora data

- `data.pandora` is the committed Pandora database (install-order step 4 done). Seeded by
  `tools/seed_pandora.gd` (idempotent — aborts if roots exist; to re-seed from scratch,
  delete `data.pandora`, register the script as a temp autoload, run headless once).
- Trees: the handoff's six (Items+Weapons/Relics/Tools/Consumables/Materials · Spells ·
  Effects · Factions · NPCs · Lore), four lore-driven roots (Elements · Classes · Peoples ·
  Locations), and the runtime combat roots **Combatants** and **Encounters**.
- `Lore`/`Factions`/`Locations`/`Peoples`/`Classes` entities carry a **`Vault Id`** property
  bridging to `~/projects/dramgid-vault` — Pandora owns *game data*, the vault owns *lore
  prose*. Spells/Effects are `Placeholder = true` mechanics sketches, not canon.
- `tools/seed_chapter_one.gd` is the idempotent migration for chapter-one factions, NPCs,
  combatants, and encounters. `tools/generate_gloot.gd` emits the committed artifacts in
  `data/generated/`: GLoot prototypes, item/faction/NPC/encounter ID constants, item gettext,
  and expanded encounter JSON. Runtime scenes reference an `EncounterIds` value; they do not
  duplicate enemy stats.
- Release exports use Godot's `--recovery-mode` and the preset explicitly includes raw
  `data.pandora`. This bypasses Pandora's editor-only ASCII compression hook, which cannot
  preserve the Unicode sigils and names in the canonical database.

## Dialogue Manager quirks

- Response conditions use the SELF-CLOSING bracket form: `[if expression /]` — a plain
  `[if expression]` is silently ignored (WRAPPED_CONDITION_REGEX requires the ` /]`).
- Choice metadata rides on response tags: `[#tag=X] [#cost=-6 soul] [#consequence=...]`
  (no commas inside a tag value — commas split tags). The balloon parses these.
- Autoloads (GameState, Reputation) are callable from conditions/mutations with no setup.
- Our balloon: `ui/dialogue/dialogue_balloon.tscn` via `dialogue_manager/runtime/balloon_path`.
