## 2026-07-31 - Add Interaction Cues to Dynamic UI
**Learning:** Runtime-instantiated custom Godot UI controls like `Button.new()` and `CheckButton.new()` default to the arrow cursor, failing to provide the interactive cues (pointing hand) that users expect from web standards, particularly on narrative/dialogue interfaces and nested menus.
**Action:** When dynamically instantiating UI controls in Godot, explicitly set `mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND` to bridge the gap between engine defaults and web-standard interaction expectations.
