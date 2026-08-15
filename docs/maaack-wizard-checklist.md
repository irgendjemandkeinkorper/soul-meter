# Maaack's setup-wizard checklist (issue #56)

**Status: DRAFTED, NOT EXECUTED.** The wizard is editor-interactive; run this on the
Windows machine in the Godot editor. Nothing below has been run — check items off as
you go. Source: `addons/maaacks_game_template/docs/BasicSetup.md` (vendored, pin
`93e66a0`), tailored to what Soul Meter already wired manually.

## What is already done (do NOT redo in the wizard)

- [x] — already true: the four autoloads (`AppConfig`, `SceneLoader`,
  `ProjectMusicController`, `ProjectUISoundController`) are registered manually in
  `project.godot` (see `DEPENDENCIES.md`). If the wizard's **Update Autoload Paths**
  step shows them green, leave it alone.
- [x] — already true: `run/main_scene` is OUR menu, `res://ui/screens/main_menu.tscn`.

## Hard skips — wizard steps that would damage the project

- [ ] **SKIP "Set Main Scene."** It points `run/main_scene` at Maaack's
  `opening_with_logo.tscn`/menu flow. Ours must stay `ui/screens/main_menu.tscn`
  (the Flow chart boots from it). If you click it by accident, fix
  `Project Settings → Application → Run → Main Scene` back.
- [ ] **SKIP any step that edits files under `addons/`** — repo policy. The wizard's
  copy step writes OUTSIDE `addons/` (that's its purpose) and is fine.
- [ ] **SKIP "Delete Example Files"** until the copied examples have been mined
  (below); it deletes the in-addon example sources the wizard copies from.

## Run these, in order

1. [ ] Editor: `Project → Tools → Run Maaack's Game Template Setup...`
2. [ ] **Using Latest Version** — verify only. We are pinned at `93e66a0`; do NOT
   upgrade from the wizard (pins live in `DEPENDENCIES.md`, upgrades are a separate,
   reviewed task).
3. [ ] **Copy Example Files** — accept. Note the destination directory it reports
   (typically a project-root folder such as `res://overlaid/` or the name you give it).
   This is the only reason we're running the wizard at all: it materializes the
   options menus (audio/visual/input/game), input-remap UI, credits scene, and loading
   screen as project-owned scenes we may legally edit.
4. [ ] Commit the copied files as-is first (one clean "vendor drop" commit), THEN
   adapt: re-theme via `ui/theme/theme_builder.gd` type variations only — no per-node
   style overrides (FR-605 rules apply to these scenes too).
5. [ ] **Update Autoload Paths** — should already show complete; only re-run if the
   copy step changed a path. Confirm afterwards that `project.godot`'s four Maaack
   autoload lines are unchanged (`git diff project.godot`).
6. [ ] Wire what we actually keep: the wizard's copied `*_options_menu.tscn` panels
   are candidates to replace the hand-rolled parts of `ui/screens/settings.gd` —
   evaluate, don't auto-adopt; `UIManager`/`GameFlow` remain the only screen/flow
   mechanisms (`SceneLoader` stays mechanism-only under `GameFlow`).
7. [ ] Only after 4–6 are settled: optionally **Delete Example Files** from the
   wizard to slim the addon copy, or leave it (it ships in `addons/` either way).

## Verify (headless, after committing on Windows)

- [ ] `godot --headless --path . --import` then
  `GODOT_BIN=... bash addons/gdUnit4/runtest.sh -a test` — judge output, not exit
  code (exit 134 teardown flake; gdUnit exit 100 is normal-with-failures).
- [ ] `git diff project.godot` shows no autoload or main-scene drift.

Close #56 by checking every box above and pasting the copy-step destination path into
the issue.
