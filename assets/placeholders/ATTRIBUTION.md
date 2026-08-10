# Temporary placeholder art — provenance

Every asset in this directory is temporary and was drawn procedurally for Soul Meter. No
third-party character, logo, downloaded artwork, or file from the generator-owned
`assets/generated/sprites/` tree is included or modified here.

## Asset groups

| Logical IDs | Output files | Provenance | License |
|---|---|---|---|
| `tiles.ground.*` | `isometric/tiles/64x32/ground_*.png` | Project-authored procedural pixel shapes on the 64×32 isometric tile contract | procedural / project-owned |
| `tiles.elevation.*` | `isometric/tiles/64x32/elevation_step_*.png` | Project-authored procedural pixel shapes using the same 64×32 top-face contract | procedural / project-owned |
| `props.*` | `isometric/props/*.png` | Project-authored procedural isometric pixel shapes | procedural / project-owned |
| `actors.generic.*` | `actors/generic_actor_*.svg` | Project-authored procedural vector shapes; four cardinal directions | procedural / project-owned |
| `enemies.generic.*` | `enemies/generic_enemy_*.svg` | Project-authored procedural vector shapes; four cardinal directions | procedural / project-owned |
| `ui.frames.*` | `ui/frames/*_frame.png` | Project-authored procedural 9-patch frame textures | procedural / project-owned |

The exact file mapping, dimensions, pivots, direction contracts, 9-patch margins, and hashes
are recorded per asset in [`manifest.json`](manifest.json).

## Permitted vendored sources

The placeholder-art sourcing policy also permits derivatives of the vendored Kenney CC0
collections. Their attribution and CC0 1.0 terms are documented in
[`assets/kenney/ATTRIBUTION.md`](../kenney/ATTRIBUTION.md) and
[`assets/kenney3d/ATTRIBUTION.md`](../kenney3d/ATTRIBUTION.md). The current placeholder set
does not derive from either collection, so every manifest entry records `procedural` as its
source and source hash.
