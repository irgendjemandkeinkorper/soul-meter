extends RefCounted
## Live-state verbs for the headless CLI (E7.1, architecture §4.4, §4.13): the console vocabulary,
## run against the live autoloads through the console panel's own interpreter, so the `[debug] `
## cause prefix and the `dev_console_used` marker apply exactly as in the panel. It lives with the
## panels because it is export-excluded with them; the shipped adapter loads it by path and runs
## nothing when it is absent.

const CONSOLE_MODEL_SCRIPT := "res://weftlumin/panels/models/dev_console.gd"


## `{handled, ok, output}` for `{"op": "execute", "params": {"command": "<console line>"}}`.
func run_console(entry: Dictionary) -> Dictionary:
	var tree := Engine.get_main_loop() as SceneTree
	var script := load(CONSOLE_MODEL_SCRIPT) as GDScript
	if tree == null or script == null:
		return {"handled": true, "ok": false, "output": ["The console model is unavailable."]}
	var console: Node = script.new()
	tree.root.add_child(console)
	var output: Array[String] = []
	var ok: bool = false
	if bool(console.call("host_in_panel")):
		var params: Dictionary = entry.get("params", {}) as Dictionary if entry.get("params") is Dictionary else {}
		ok = bool(console.call("execute_command", str(params.get("command", ""))))
		for line: Dictionary in console.call("log_entries"):
			output.append(str(line.get("text", "")))
	else:
		output.append("The console refuses to host outside a debug build.")
	tree.root.remove_child(console)
	console.free()
	return {"handled": true, "ok": ok, "output": output}
