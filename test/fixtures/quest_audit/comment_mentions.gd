extends RefCounted
## Fixture for test_quest_audit.gd: a flag call quoted in a comment is prose, not flag access.
# GameState.set_flag("commented_write", true)


func _touch() -> void:
	var text := "# not a comment"  # GameState.get_flag("trailing_comment_read")
	GameState.set_flag("live_write", "#value")  # GameState.set_flag("trailing_comment_write", 1)
	if GameState.get_flag("live_read") and text.is_empty():
		pass
