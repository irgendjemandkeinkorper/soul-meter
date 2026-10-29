# World-map route authoring

`<hub>/routes/<origin_id>-<destination_id>.json` uses `weftlumin.route.v1`.
The origin's location document determines the hub directory. Generate the shared location
index with `tools/generate_locations.gd`; do not edit the generated index.

The #342 move preserves all existing numbers. These remain **PROVISIONAL**:

- `dom-dorthkor_road` reputation-band weights: Neutral keeps the base weights; Allied's zero
  override disables that encounter. Base encounter weights must be positive; overrides may be zero.

C1 (`dom-kesselford`), C2 (`kesselford-ashlaren`), C3 (`dom-long_verge`, `long_verge-kesselford`)
and C4 (`dorthkor_road-hollowmere`) route numbers were **ratified as authored on 2026-10-22** (owner
item 4). They stay tunable in the balance pass after encounter-frequency playtests.

- Location `fast_travel.base_cost_gp`: Dom 25, Kesselford 40, Ashlaren 60. Adding these facets
  does not change the fast-travel registry in PR 1.
