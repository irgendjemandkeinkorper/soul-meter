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
| Pandora | `d78b99e` | github.com/bitbrain/pandora | Canonical game data (items/spells/factions/NPCs/lore) — category trees not yet defined. ⚠ pre-1.0; verify stability before deep dependence. |
| Dialogue Manager | `09b82d6` (v4, needs 4.6+) | github.com/nathanhoad/godot_dialogue_manager | Branching dialogue; `DialogueManager` autoload (registered manually). |
| QuestSystem | `853276e` | github.com/shomykohai/quest-system | Quest lifecycle; `QuestSystem` autoload. |
| GLoot | `6b09b87` | github.com/peter-kish/gloot | Inventory backend. **Do not author item prototypes by hand — blocked on the Pandora→GLoot sync tool.** |
| Phantom Camera | `dbf15ee` | github.com/ramokz/phantom-camera | Camera behaviors; `PhantomCameraManager` autoload (registered manually). |
| Anima | `f28a1be` | github.com/ceceppa/anima | UI/menu motion; `ANIMA` autoload. |
| Juicee | `eb66d35` | github.com/Kelpekk/Juicee | Game-feel FX; `Juicee` autoload. |
| SmartShape2D | `b52ea53` (ss2d 3.3.1) | github.com/SirRamEsq/SmartShape2D | 2D organic terrain authoring. |
| PixelPen | v1.1.4 release | github.com/pixelpen-dev/pixelpen | Pixel-art authoring. **Parked with a `.gdignore` on Linux/WSL (prebuilt .so needs glibc ≥2.38). On Windows: delete `addons/net.yarvis.pixel_pen/.gdignore` and re-enable the plugin.** |

## Pending / deferred

- **GodotGAS** — abilities/attributes/effects. **No public repo**; distributed via
  store.godotengine.org (login-walled). → Download from the store and drop the zip in
  `plugins/`; read the source before depending on it (per handoff).
- **LimboAI** — NPC/enemy behavior trees. Deferred until the first agent exists. The
  `plugins/limboai-master.zip` on the Desktop copy is *engine source*; when the time comes,
  fetch a **GDExtension release** instead (no engine build).
- **gdUnit4 / GUT** — test framework; flagged in the handoff as the riskiest omission
  (combinatorial magic system). Human call pending.
- **Godot Shaders** — not a plugin; copy shaders in per-need, checking each shader's license.

## Local quirks

- Maaack/DialogueManager/PhantomCamera autoloads were registered manually in `project.godot`
  (their enable-hooks ran headless where parts of the setup can't). Harmless "remove
  unregistered singleton" editor-log lines from Phantom Camera are known.
- The template's audio-bus install was auto-disabled headless
  (`disable_install_audio_busses=true`); `Music`/`SFX` buses are created at runtime by
  `GameState._ensure_audio_buses()`.
