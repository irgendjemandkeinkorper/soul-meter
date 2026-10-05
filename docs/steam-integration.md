# Steam integration (issue #299)

What is in the repository, and what only the owner can do. Nothing here contains an app id,
depot id or credential — those never enter the repository.

## What ships in the repo

| Piece | File |
|---|---|
| Steam seam (autoload `SteamService`) | `globals/steam_service.gd` |
| Achievement table (the only place ids and triggers live) | `globals/steam_achievements.gd` |
| Depot upload script | `tools/steam_upload.sh` |
| steamcmd build templates | `tools/steam/app_build.vdf.template`, `tools/steam/depot_build.vdf.template` |
| Tests (fake Steam backend) | `test/unit/test_steam_service.gd` |

`SteamService` sits in the Systems layer. It subscribes read-only to
`Reputation.reputation_changed`, `Renown.renown_changed` and `QuestSystem.quest_completed`,
and re-checks every row on `SaveGame.loaded`. It never writes to a ledger, a quest or a save.

GodotSteam is **not vendored**. `SteamService` looks up the `Steam` engine singleton at runtime
and calls it only through `Object.call()`. Without the addon — CI, Linux development, a build
launched outside Steam — the service holds no backend and every method is a no-op.

## App id

There is no Steamworks app yet (ship plan, 2026-09-04: "No Steamworks account yet"), so no app
id exists and none is committed. `globals/steam_service.gd` carries
`PROVISIONAL_APP_ID := 0`: at 0 the service calls `steamInitEx()` with no arguments and Steam
takes the id from the launching client or from `steam_appid.txt` (git-ignored). When the owner
has an id there are two places it can go:

| Where | When |
|---|---|
| `steam_appid.txt` next to `project.godot` / the exported `.exe` | development and local test builds; never committed, excluded from the depot |
| `PROVISIONAL_APP_ID` in `globals/steam_service.gd` | only if the owner wants the id baked into the build; confirm the installed GodotSteam's `steamInitEx` signature first (4.12+ takes `app_id` as the first argument) |

`tools/steam_upload.sh` always takes the id from `STEAM_APP_ID` in the environment.

## Achievements

API ids are neutral on purpose. Display names, descriptions and icons are set on the partner
site and are the owner's decision; they can change without a code change.

**PROVISIONAL.** Issue #299 reserves achievement names for the owner and asks for the list to
be posted as an issue comment. The five triggers below are the agent's proposal, chosen so
each is reachable within Chapter One; none has been ruled on. The pasteable proposal is in the
next section.

| API id | Unlocks when | Source signal |
|---|---|---|
| `ACH_01` | *The Broken Muster* (`quests/dorthkor_road.tres`) is completed — the Chapter One ruling | `QuestSystem.quest_completed` |
| `ACH_02` | *The Unanswered Roar* (`quests/main/the_unanswered_roar.tres`) is completed — Act I closes | `QuestSystem.quest_completed` |
| `ACH_03` | Any one of the six companion personal quests is completed | `QuestSystem.quest_completed` |
| `ACH_04` | Any faction's standing reaches the **Warm** band (`Reputation.BAND_WARM`) | `Reputation.reputation_changed` |
| `ACH_05` | Fame reaches tier index 1, **Whispered** (`Renown.FAME_TIER_FLOORS[1]`) | `Renown.renown_changed` |

Each unlock is idempotent: the service asks Steam whether the achievement is already set,
writes it at most once, and remembers the answer for the session. To change a condition, edit
its row in `globals/steam_achievements.gd`.

### Proposed achievements (for owner ruling)

Post this on #299 (a worker may not comment on the issue without lead authorisation). Display
names and descriptions are deliberately blank; the API names are placeholders the owner may
rename as long as `globals/steam_achievements.gd` is changed to match.

```
Proposed Steam achievements (5) — please rule on triggers and supply names

| # | API name (placeholder) | Trigger (as implemented) | Display name | Description |
|---|---|---|---|---|
| 1 | ACH_01 | The Broken Muster ruling is made (dorthkor_road quest completed) | — | — |
| 2 | ACH_02 | The Unanswered Roar is completed (Act I closes) | — | — |
| 3 | ACH_03 | Any one companion personal quest is completed (6 qualify) | — | — |
| 4 | ACH_04 | Any faction's standing first reaches the Warm band | — | — |
| 5 | ACH_05 | Fame first reaches the Whispered tier | — | — |

Alternatives considered and not chosen (any can replace a row): a faction reaching
Allied; a faction reaching Hostile; three manual saves; a first Zhavar rung change.
```

## Steam Cloud (Auto-Cloud)

Auto-Cloud is configured on the partner site; it needs no code. The issue text says
`user://saves`, but `SaveGame` (`globals/save_game.gd`) writes directly in the root of
`user://`, and moving the files would break existing saves — so the paths below describe what
the game writes today.

Files to sync:

| File | Meaning |
|---|---|
| `chapter_one.save` | autosave / Continue slot |
| `chapter_one.slot1.save` … `chapter_one.slot3.save` | manual slots |
| the same names with `.bak` appended | last-known-good backup of each slot |

Not synced, deliberately: `*.tmp` (in-flight atomic writes), `settings.cfg` (display and audio
settings are per machine), and the debug folders (`combat_lab/`, `playtest/`, `layout_*/`,
`campaigns/`).

The two patterns are mirrored in code as `SteamService.CLOUD_SAVE_PATTERNS`, and
`test/unit/test_steam_service.gd` checks them against the paths `SaveGame` really writes. If a
save file is ever renamed or moved, that test fails first; update the partner-site rows in the
same change.

`project.godot` sets `config/name="SoulMeter"` and no custom user directory, so `user://` is
Godot's default location. Partner site → **Steamworks Settings → Cloud → Steam Auto-Cloud
Configuration**, two root paths:

| Root | Subdirectory | Pattern | OS | Recursive |
|---|---|---|---|---|
| `WinAppDataRoaming` | `Godot/app_userdata/SoulMeter` | `chapter_one*.save` | Windows | No |
| `WinAppDataRoaming` | `Godot/app_userdata/SoulMeter` | `chapter_one*.save.bak` | Windows | No |

If a Linux depot ships (the repo has a `Linux/X11` export preset), add a **root override** on
each row: OS `Linux`, new root `LinuxXdgDataHome`, replace path `Godot` → `godot` (the Linux
directory is `~/.local/share/godot/app_userdata/SoulMeter`).

Also on that page: enable Cloud, and set the byte and file quotas. Eight small files are
synced; measure real save sizes before choosing the byte quota.

Changing `config/name` or enabling `application/config/use_custom_user_dir` later moves
`user://` and silently orphans both local and cloud saves. Do not change either without a
migration.

## Owner steps

1. **Partner site — app.** Create the app and its depot; note the app id and depot id.
2. **Install GodotSteam** on the Windows machine: the GDExtension build that matches the
   project's Godot version (4.7.x), unpacked under `addons/godotsteam/`. Whether to commit it
   is the owner's call; if committed, record the pin in `DEPENDENCIES.md` and
   `scripts/verify_addon_pins.sh` like the other addons.
3. **`steam_appid.txt`** — one line, the app id, next to `project.godot` (for editor runs) and
   next to the exported `.exe` when running a build outside the Steam client. It is
   git-ignored and excluded from the depot; Steam supplies the id for installed copies.
4. **Achievements.** Partner site → Stats & Achievements: create five achievements whose API
   names are exactly `ACH_01` … `ACH_05`, with the approved display names, descriptions and
   icons. **Publish** the Steamworks changes — unpublished achievements cannot be set.
5. **Cloud.** Enter the Auto-Cloud rows above and publish.
6. **Verify on Windows** with the Steam client running: start the game from the editor, check
   the log has no `SteamService: Steam unavailable` line, trigger one achievement, and confirm
   the overlay toast. Save, then confirm the files appear under the app's Cloud file list.
7. **Upload a build** (below).

## Uploading a build

Export first (`README.md`, "Windows build"), then:

```bash
export STEAM_APP_ID=...        # from the partner site
export STEAM_DEPOT_ID=...
export STEAM_USERNAME=...      # a dedicated build account, not a personal one
tools/steam_upload.sh --preview    # dry run: nothing is uploaded
tools/steam_upload.sh
```

Optional: `STEAM_CONTENT_ROOT` (default `build/windows`), `STEAM_BUILD_DESC` (default: the git
commit), `STEAM_SET_LIVE` (a beta branch name; the script refuses `default` — promote the
public branch on the partner site), `STEAMCMD_BIN`, `STEAM_PASSWORD`.

Prefer logging in to steamcmd once by hand (`steamcmd +login <user> +quit`, with Steam Guard)
and leaving `STEAM_PASSWORD` unset so the cached login is reused: a password passed to
steamcmd is visible in the process list. The script exits with a clear message when a required
variable, steamcmd, or the build directory is missing.

## Not verified

- The service has only been exercised against a fake backend. The GodotSteam calls it makes —
  `steamInitEx()` with no arguments returning `{status, verbal}`, `run_callbacks()`,
  `getAchievement()`, `setAchievement()`, `storeStats()` — follow GodotSteam's documented 4.x
  API and must be confirmed against the installed version in step 6.
- `tools/steam_upload.sh` has been dry-run only against a stub `STEAMCMD_BIN` (environment
  validation, the `default`-branch refusal, and VDF rendering); it has never talked to a real
  steamcmd, because no app, depot or build account exists yet.
- The five triggers and the `ACH_0N` API names are provisional until the owner rules on them.
- The Windows export preset has no GodotSteam library handling. Once the addon is installed,
  re-verify that the export includes `steam_api64.dll` beside the executable.
