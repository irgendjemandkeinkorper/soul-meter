class_name WeftluminPanel
extends Control
## Panel contract from architecture §4.5.5. The shell owns hotkey bindings.

var title: String
var needs_sandbox: bool
var hotkey_hint: String


## Supply the shell host; the base panel retains no runtime ownership.
@warning_ignore("unused_parameter")
func configure(host: WeftluminShell) -> void:
	pass


## Refresh the panel from a host-provided payload.
@warning_ignore("unused_parameter")
func refresh(payload: Dictionary) -> void:
	pass


## Command constructors exposed to the shell and CLI help.
func commands() -> Array[Callable]:
	return []
