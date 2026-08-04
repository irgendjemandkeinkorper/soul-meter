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

## 2026-08-02 - [Save File Object Deserialization & Type Confusion]
**Vulnerability:** Untrusted save game payload loading did not explicitly restrict Godot's built-in `FileAccess.get_var()` object deserialization. By default, standard `get_var()` can deserialize instantiated script objects/nodes, opening a door to remote code execution (RCE) via custom payload properties. In addition, nested dictionary/event serialization (like flags, reputation, and renown) lacked key length validation and strong type-safety checks, which could lead to type confusion, reference errors, or out-of-bounds/DoS behavior when parsed.
**Learning:** Defensive deserialization in Godot requires a multi-layered approach: (1) Explicitly passing `false` to `file.get_var(false)` blocks the parser from instantiating any objects or custom classes. (2) String length constraints on dynamic fields (e.g. `spawn_id`, `flags` keys) prevent memory exhaustion DoS. (3) Manual coercion using `str()`, `int()`, or `float()` on untrusted properties protects type-safe static variables from runtime crashes due to unexpected structure mismatch.
**Prevention:** Always use `get_var(false)` for loading user/network payloads, enforce max string lengths during payload validation, and coerce primitive types on load rather than trusting raw dictionary value layouts.
