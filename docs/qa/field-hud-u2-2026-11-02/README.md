# U2 field HUD: before and after (2026-11-02)

Rendered under Xvfb at 1920×1080 by `test/manual/ui_audit_capture.gd`
(`test_field_hud_with_a_party_of_six`). The scene is Dom on the opening stage, with a party of six;
the second member is at a third of HP and a quarter of Breath. Plan and rulings:
`docs/design/ui-rework-plan-2026-11-01.md`.

| File | What it shows |
|---|---|
| `before-dom-party-of-six.jpg` | Eight key hints in the engine's sans. Objective on two lines, with "GO TO The Four Arms in Dom" while standing in Dom. The party as mono text; the sixth member is cut off ("BREATH 1…"). World labels in the engine's sans. |
| `after-dom-party-of-six.jpg` | Key hints in the eyebrow face; each leaves after its key's first use. One objective line, with no GO TO in Dom. Six party cards, each with a bust, an HP meter and a Breath meter. World labels in Cinzel with an outline. |
| `after-party-strip-2x.jpg` | The bar enlarged 2×. Serai-Lun's low HP and Breath read at a glance. Sprite-only companions get a bust cut from their sprite. |

Hovering a card swaps its name for `HP 10/30 · BR 3/15`. That isn't captured here; it is covered by
`test/integration/test_field_hud_u2.gd`.
