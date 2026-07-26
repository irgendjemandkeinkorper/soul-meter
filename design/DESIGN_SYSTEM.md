# Soul Meter design system

**Canonical source:** https://claude.ai/design/p/241acfb5-f8a3-4283-89c2-d5090b297c43?via=share
— keep this front of mind for every menu, screen, and entity built in Godot.

> ⚠ The share link is login-walled (returns 403 to non-browser fetchers), so the tokens
> below are **not yet imported**. Export the system from the Claude design page (copy the
> tokens/CSS, or paste the spec into chat) and fill this file in; then bake it into
> `ui/theme/` as a Godot `Theme` resource.

## To capture from the source (when exported)

- **Palette** — semantic colors (bg / surface / text / accents / danger), light & dark
- **Typography** — families, scale, weights (map onto the Kenney fonts or import the real ones)
- **Spacing & radius** — the spacing scale, corner radii, border weights
- **Components** — button/panel/input states (normal/hover/pressed/disabled/focus)

## How it lands in Godot (per the architecture guardrails)

- One shared `Theme` resource + **type variations** (`DangerButton`, `HUDLabel`, …) — never
  per-node theme overrides.
- Nine-patch via `StyleBoxTexture` for anything that must survive 4k → 640×360.
- Applies to: Maaack's template menus (extend the inherited copies), the custom screens
  (`ui/screens/`), the Soul Meter HUD, and dialogue UI.
