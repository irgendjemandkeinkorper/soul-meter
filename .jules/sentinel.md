# Sentinel Security Journal

## 2026-08-01 - [Arbitrary Resource Deserialization / Loading Vulnerability]
**Vulnerability:** In `PartyMember.from_dict()`, the save game deserialization loaded portrait texture paths using the built-in `load()` function without any validation or sanitization. If a user supplied a maliciously crafted save file, they could specify paths to script (`.gd`), scene (`.tscn`), or other active resource files. Calling `load()` on these paths could execute arbitrary code within the game process context.
**Learning:** In Godot, the `load()` function is highly powerful but does not automatically restrict loaded resources to safe visual types like textures. Furthermore, default save data from user files is untrusted input, and anything extracted from them (especially resource paths) must be strictly validated before being loaded.
**Prevention:** Before calling `load()` on paths deserialized from user-controlled data, enforce strict path and type validation:
1. Ensure the path has a safe prefix (e.g. starts with `res://`).
2. Deny directory traversal patterns (e.g. containing `..`).
3. Ensure the resource exists with `ResourceLoader.exists()`.
4. Inspect the resource type *before* loading using `ResourceLoader.get_resource_type()` and checking that it inherits from safe classes (such as `Texture2D` via `ClassDB.is_parent_class()`).
