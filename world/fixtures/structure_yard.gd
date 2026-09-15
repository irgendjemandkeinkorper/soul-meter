extends Node2D
## Standalone mechanical fixture. Autosaves are sandboxed; F5/F9 use a local
## runtime snapshot so experimenting never overwrites campaign save slots.

var _saved: Dictionary = {}
var _saved_player_position := Vector2.ZERO


func _enter_tree() -> void:
	SaveGame.begin_runtime_sandbox()


func _exit_tree() -> void:
	SaveGame.end_runtime_sandbox()


func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	match event.physical_keycode:
		KEY_F6:
			WorldClock.advance("structure-yard")
		KEY_F5:
			_saved = SaveGame.capture_runtime_state()
			_saved_player_position = $Player.global_position
			$Instructions.text = "Snapshot stored. F9 restores it.\n" + _instructions()
		KEY_F9:
			if not _saved.is_empty():
				$Player/ClickMoveController.cancel_path()
				# Fixture-only rewind: discard a keyboard step from the later timeline.
				$Player._has_keyboard_step_target = false
				$Player.velocity = Vector2.ZERO
				$Player.global_position = _saved_player_position
				SaveGame.restore_runtime_state(_saved)
		_:
			return
	get_viewport().set_input_as_handled()


func _instructions() -> String:
	return "STRUCTURE YARD\nMove: WASD / click | Nearby barricade: E to strike\nF6: advance one world phase | F5 / F9: snapshot / restore\nLeft: maintained (2 phases). Right: abandoned (no timer)."
