extends SceneTree
## Weftlumin headless CLI (E7.1, `docs/architecture-in-game-editor.md` §4.13, ruling 9).
##
##   godot --headless --path . --script addons/weftlumin/tools/weftlumin.gd -- <subcommand> [args]
##     validate  <package_dir>                        all kinds, attributed errors, exit 0/1
##     apply     <package_dir> <commands.jsonl>       replay onto fresh out-of-tree instances; write scratch
##     bake      <package_dir> [--write] [--force]    weftlumin.bake.v1 report; writes only with --write
##     regen     [--write]                            drift checks; seeds and regenerates only with --write
##     lint      <package_dir>                        [if /] lint, quest_audit statics, flag grammar, POT delta
##     pr        <package_dir> [--issue N] [--draft] [--force] [--execute]
##                                                    dry run unless --execute (see pr.gd)
##   Every subcommand also takes `--report <path>` (the report JSON, written atomically).
##
## Exit codes: 0 ok, 1 errors, 2 usage, 3 `refused_overlap`. Godot can abort at teardown in this
## environment, so judge the printed `WEFTLUMIN:` status line or the `--report` file, never the
## raw exit code.
##
## This entry stays thin on purpose: the body is `cli.gd`, loaded at runtime inside
## `_initialize()`. The `--script` main script is compiled before the project's autoloads exist,
## and several scripts the bake reaches (Dom's scene scripts, the Soul Meter kinds) name autoloads;
## loading them from here, after autoload setup, is what makes them compile. The subcommand runs
## on the first frame: `_initialize()` comes before the root enters the tree, so the autoloads
## exist but have not run `_ready()` yet (Pandora loads its data there; the console needs
## GameState).

const CLI_PATH := "res://addons/weftlumin/tools/cli.gd"

var _cli: RefCounted = null
var _started: bool = false


func _initialize() -> void:
	var script := load(CLI_PATH) as GDScript
	if script == null:
		printerr("WEFTLUMIN: cannot load %s" % CLI_PATH)
		quit(2)
		return
	_cli = script.new()


func _process(_delta: float) -> bool:
	if _started or _cli == null:
		return false
	_started = true
	var result: Dictionary = _cli.call("run", OS.get_cmdline_user_args())
	quit(int(result.get("exit_code", 1)))
	return false
