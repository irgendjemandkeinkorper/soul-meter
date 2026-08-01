# Sentinel Security Journal

## 2026-08-01 - [Arbitrary Resource Deserialization / Loading Vulnerability]
**Vulnerability:** In `PartyMember.from_dict()`, the save game deserialization loaded portrait texture paths using the built-in `load()` function without any validation or sanitization. If a user supplied a maliciously crafted save file, they could specify paths to script (`.gd`), scene (`.tscn`), or other active resource files. Calling `load()` on these paths could execute arbitrary code within the game process context.
**Learning:** In Godot, the `load()` function is highly powerful but does not automatically restrict loaded resources to safe visual types like textures. Standard save data from user files is untrusted input, and anything extracted from them (especially resource paths) must be strictly validated before being loaded. Querying resource types dynamically with `ResourceLoader.get_resource_type()` or ClassDB can sometimes lead to platform/build compile-time class errors or singleton availability issues in headless/export modes.
**Prevention:** Before calling `load()` on paths deserialized from user-controlled data, enforce strict path and extension validation (Defense in Depth):
1. Ensure the path has a safe prefix (e.g. starts with `res://`).
2. Deny directory traversal patterns (e.g. containing `..`).
3. Restrict file extensions strictly to safe, known texture/image extensions (e.g., `png`, `jpg`, `jpeg`, `svg`, `webp`, `tga`, `import`, `ctex`). This completely prevents the engine from parsing them as script, scene, or text resource files.
4. Ensure the file actually exists using `FileAccess.file_exists()`.
5. Finally, verify that the loaded resource is of type `Texture2D` using the `is` keyword before assignment.
