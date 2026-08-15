---
milestone: "1"
---

# Soul Meter Maintenance Goal

Assess Soul Meter's first-chapter release readiness and create small, evidence-backed issues for
maintenance gaps that are not already tracked. Prioritize regressions in game flow, save/load,
localization, accessibility, dependency drift, and deterministic Godot 4.7 behavior.

## Tools
- Import: `~/.local/bin/godot --headless --path . --import --quit`
- Acceptance gate: `GODOT_BIN=~/.local/bin/godot bash scripts/acceptance_gate.sh`
- Test suite: `GODOT_BIN=~/.local/bin/godot bash addons/gdUnit4/runtest.sh -a test`
- Addon-pin report: `bash scripts/verify_addon_pins.sh`

## Assessment Hints
- Trace player-facing flows through `GameFlow`; game code must never change scenes directly.
- Check save/load behavior at gameplay-scene boundaries and after party or ledger mutations.
- Distinguish new failures from the documented headless rendering/navigation flakes.
- Treat Pandora and `data/generated/` as canonical input and generated output respectively.

## Insight Hints
- Include the exact command and observed output supporting every proposed issue.
- Identify whether a finding is automated, headless-only, or requires a manual Godot editor run.
- Call out dependency and localization drift separately from gameplay defects.

## Constraints
- Do NOT propose changes already covered by open issues
- Do NOT propose changes rejected in recently closed issues
- Keep tasks small and isolated — one logical change per issue
- Do NOT edit vendored addons or hand-edit files under `data/generated/`
- Do NOT invent lore, regions, mechanics, or product behavior
- Preserve append-only reputation and renown ledgers
