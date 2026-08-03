# Skill: regenerate Pandora-derived GLoot data

Use this workflow whenever a Pandora item, encounter, faction, NPC, or localization source
value changes. Pandora is canonical; generated files are outputs and must never be hand-edited.

## Inputs and outputs

- Source: `data.pandora`
- Generator: `tools/generate_gloot.gd`
- Generated artifacts: `data/generated/`, `data/generated/items.pot`, and the merged
  `locale/es.po` scaffold

The generator also emits typed ID constants. Runtime code should use those constants rather than
literal generated paths or IDs.

## Local regeneration

Run the generator from the Godot editor through **Project → Tools → Regenerate GLoot prototypes**
after editing Pandora data. For a headless environment, use the project's normal Godot tool
registration and run the generator once with the same Godot binary used by CI. Do not edit the
generated JSON, GDScript, or PO files to make a mismatch disappear.

## Verification

Run the drift guard, then the deterministic suite:

```bash
GODOT_BIN=~/.local/bin/godot bash scripts/check_generated_data.sh
GODOT_BIN=~/.local/bin/godot bash scripts/test.sh -a test
```

The drift guard runs `tools/generate_gloot.gd` in check-only mode and fails when the committed
artifacts differ from Pandora. If it reports drift, regenerate from Pandora, inspect the diff
for the generated-file header, and commit the source plus generated outputs together.

## Review checklist

1. Confirm the changed entity exists under the expected Pandora category.
2. Regenerate; never patch an output by hand.
3. Check generated IDs and localization rows for the intended change.
4. Run the drift guard and tests.
5. Include both `data.pandora` and its regenerated artifacts in the same change.
