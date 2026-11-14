# Soul Meter — item/loot draft packet — 2026-10-31

**DRAFT FOR OWNER APPROVAL — P1.2 / #531, slice D. Every proposed item, description, number, loot row, and container assignment below is a draft. Nothing in this packet ships until the owner approves it.** This file changes documentation only; acceptance requires a separately authorized implementation.

**PROVISIONAL count gap:** loot tables **2 → 8** (+6 proposed); items **22 → 40** (+18 proposed). The current game remains at **2 tables / 22 items**. Baselines: [item tree][items] and [loot registry][registry].

## Proposed items — 18 DRAFT rows

Descriptions are mundane extensions of the cited objects and trades, not quotations or additions to vault canon. The register follows existing short item descriptions and the worn, practical tone of [rulings 7–9 and 10][identity] and [art bible Part I][art]. No new equippable weapons or armour, equipment stats, use effects, skill bonuses, or progression rules are proposed; equipment remains blocked on owner item 29 per the assignment.

Existing category bounds, computed from all 22 entries: **consumables** `base_price` 5–14 / `weight` 0.2–0.4; **materials** 6–24 / 0.1–0.5; **tools** 9–60 / 0.1–0.8. Values below use the same units. **— in `equip_slot` means omit the property**, matching existing non-equipment entries; the tools are non-equippable inventory goods. Grounding keys **I, V1–V5** resolve to exact sources in **Canon check**; each citation states the fact being extended, not a claim that the proposed item already exists.

| Proposed id | Name | One-line description | Category | equip_slot | base_price | weight | Grounding |
|---|---|---|---|---|---:|---:|---|
| `materials/forge_coal` | Forge Coal | A small sack of coal chips, black dust worked into the seams. | materials | — | 8 | 0.5 | V1 §Geography & Environment: local coal seams; I `materials/iron_rivets`: company forges. |
| `materials/leather_offcuts` | Leather Offcuts | Trimmed leather scraps bundled for straps and small repairs. | materials | — | 6 | 0.2 | V1 §Economy & Trade: leather imports; I `materials/binding_thread`: repairs. |
| `tools/rivet_punch` | Rivet Punch | A short iron punch with a head flattened by repeated blows. | tools | — | 13 | 0.3 | I `materials/iron_rivets` and `weapons/forge_hammer`: existing riveting and smithing stock; tool only. |
| `materials/grain_meal` | Grain Meal | A paper packet of coarsely ground grain, dust caught in every fold. | materials | — | 6 | 0.5 | V2 §Overview / §Detail: milling town and grain grinding; ordinary stock, no certification claim. |
| `materials/sackcloth` | Sackcloth | A folded square of coarse sacking with the old seam picked out. | materials | — | 6 | 0.2 | V2 §Detail / §Notes & Open Threads: stored grain sacks; I `materials/binding_thread`: repairs. |
| `tools/grain_scoop` | Grain Scoop | A small wooden scoop, its lip worn smooth by grain. | tools | — | 10 | 0.3 | V2 §Detail: harvests weighed, blended and sent on; mundane handling tool. |
| `materials/ferry_line` | Ferry Line | A short coil of rough cord with both ends tightly bound. | materials | — | 8 | 0.4 | V3 §Overview / §Detail: ferry and chandlery work; I `materials/binding_thread`: binding cordage. |
| `materials/lamp_wicks` | Lamp Wicks | A bundle of trimmed wicks wrapped against the damp. | materials | — | 6 | 0.1 | I `materials/lamp_oil`: road lanterns; existing `ford-chandlery` vendor stocks that oil. |
| `materials/stopper_wax` | Stopper Wax | A small cake of plain wax for sealing the necks of flasks. | materials | — | 6 | 0.1 | I `materials/binding_thread`: wax; I `materials/lamp_oil`: stoppered flask; mundane sealing use. |
| `consumables/road_crusts` | Road Crusts | Dry brown loaf ends wrapped for a long walk. | consumables | — | 5 | 0.2 | I `consumables/hearthloaf`: brown market loaf; V4 §Overview: marching camps. |
| `tools/tent_pegs` | Tent Pegs | A pair of short wooden pegs with old cord marks below the heads. | tools | — | 9 | 0.3 | V4 §Overview: camps; V1 §Economy & Trade: timber; ordinary camp hardware. |
| `tools/map_case` | Map Case | A narrow leather case with a rubbed flap and a dry lining. | tools | — | 13 | 0.2 | V4 §Detail: carried road maps; V1 §Economy & Trade: leather; I `materials/scribes_vellum`: field notes. |
| `materials/cut_reeds` | Cut Reeds | A hand-sized bundle of dried reeds, trimmed and tied at the butt. | materials | — | 6 | 0.3 | V5 §Overview / §Detail: former reed-cutting camps; stored remnants, not a new harvest claim. |
| `materials/net_cord` | Net Cord | A short hank of fine cord with the old knots worked loose. | materials | — | 6 | 0.2 | V5 §Overview / §Detail: former fishing camps; I `materials/binding_thread`: repair stock. |
| `tools/netting_needle` | Netting Needle | A flat wooden needle with a slot for carrying net cord. | tools | — | 13 | 0.1 | V5 §Detail: fishing camps; I `tools/field_needle`: a precedent for a specialized repair needle. |
| `consumables/cloth_bandage` | Cloth Bandage | A clean strip of cloth rolled tightly for binding a small wound. | consumables | — | 10 | 0.2 | I `consumables/bitterleaf_poultice`: binding small field wounds; I `materials/binding_thread`: field stitching. |
| `materials/repair_splints` | Repair Splints | Thin wooden strips bundled for patching cracked handles and cases. | materials | — | 6 | 0.2 | V1 §Economy & Trade: timber; I `tools/field_needle`: wooden case; I `materials/binding_thread`: repairs. |
| `tools/stitching_thimble` | Stitching Thimble | A small metal finger cap, its crown pitted by a heavy needle. | tools | — | 9 | 0.1 | I `tools/field_needle` and `materials/binding_thread`: heavy-needle field stitching. |

## Proposed loot tables — 6 DRAFT tables

**Split:** workshop stock, milling supplies, ferry stores, march kit, abandoned reed-camp supplies, and field repairs give six existing container groups distinct ordinary goods.

All six follow [the registry][registry]: **`rolls: 2`**, weighted draws **without replacement**, then one independent **Sounding** bonus row (`skill: "sounding"`, `modifier: -10.0`), copying the existing `road-cache` check. Ungated rows contain only `{item_id, quantity, weight}`; gated rows contain only `{item_id, quantity, skill, modifier}`. **— means the key is absent**, not zero or an empty string. There is no table-wide search-skill field. The 30/25/20/15 weights follow `road-cache`; every quantity below is one inventory unit. All tuning remains DRAFT.

### DRAFT container assignments

All paths include the scene root and were checked against current scene text as well as [B1][b1] / [B2][b2]. Each listed node currently has `loot_table_id = &"road-cache"` and no fixed `loot` override. The proposed change is its table id only; existing container ids, locks, ownership, and access gates remain the implementation baseline.

| Proposed table id | Existing scene | Node paths that would switch from `road-cache` |
|---|---|---|
| `dom-workshop-stores` | `world/interiors/item_shop.tscn` | `ItemShopInterior/LatchCrate` |
| `dom-workshop-stores` | `world/interiors/cask_warehouse.tscn` | `CaskWarehouseInterior/LockedStockCrate` |
| `dom-workshop-stores` | `world/interiors/equipment_forge.tscn` | `EquipmentForgeInterior/BracedStockCrate` |
| `dom-workshop-stores` | `world/interiors/iron_companies.tscn` | `IronCompaniesInterior/LockedSupplyCrate` |
| `ashlaren-mill-stores` | `world/interiors/ashlaren_millhouse.tscn` | `AshlarenMillhouseInterior/LockedSupplyCrate`, `AshlarenMillhouseInterior/BracedSupplyCrate` |
| `ashlaren-mill-stores` | `world/interiors/ashlaren_weighing_hall.tscn` | `AshlarenWeighingHallInterior/LockedSupplyCrate`, `AshlarenWeighingHallInterior/BracedSupplyCrate` |
| `kesselford-ferry-stores` | `world/interiors/kesselford_chandlery.tscn` | `KesselfordChandleryInterior/LockedSupplyCrate`, `KesselfordChandleryInterior/BracedSupplyCrate` |
| `kesselford-ferry-stores` | `world/interiors/kesselford_wayhouse.tscn` | `KesselfordWayhouseInterior/LockedSupplyCrate`, `KesselfordWayhouseInterior/BracedSupplyCrate` |
| `verge-march-kit` | `world/long_verge.tscn` | `LongVerge/WestCache`, `LongVerge/CampCache` |
| `hollowmere-reed-kit` | `world/hollowmere.tscn` | `Hollowmere/TrackCache`, `Hollowmere/LandingCache` |
| `wilds-repair-cache` | `world/test_room.tscn` | `TestRoom/WestCache`, `TestRoom/GladeCache` |

The existing `road-cache` and `wight-hoard` definitions remain, yielding eight tables if all six drafts are later implemented. Dorthkor Road retains `DorthkorRoad/RoadsideCache` on `road-cache` and the fixed contents of `DorthkorRoad/CampCache`. Wound Lip retains the fixed contents of `WoundLip/LedgeCache` and `WoundLip/GuardKit`; this packet proposes no conversion of fixed loot.

### DRAFT `dom-workshop-stores`

| item_id | weight | quantity | skill | modifier |
|---|---:|---:|---|---:|
| `materials/forge_coal` | 30 | 1 | — | — |
| `materials/leather_offcuts` | 25 | 1 | — | — |
| `materials/iron_rivets` | 20 | 1 | — | — |
| `materials/lamp_oil` | 15 | 1 | — | — |
| `tools/rivet_punch` | — | 1 | `sounding` | -10.0 |

### DRAFT `ashlaren-mill-stores`

| item_id | weight | quantity | skill | modifier |
|---|---:|---:|---|---:|
| `materials/grain_meal` | 30 | 1 | — | — |
| `materials/sackcloth` | 25 | 1 | — | — |
| `consumables/hearthloaf` | 20 | 1 | — | — |
| `materials/scribes_vellum` | 15 | 1 | — | — |
| `tools/grain_scoop` | — | 1 | `sounding` | -10.0 |

### DRAFT `kesselford-ferry-stores`

| item_id | weight | quantity | skill | modifier |
|---|---:|---:|---|---:|
| `materials/ferry_line` | 30 | 1 | — | — |
| `materials/lamp_wicks` | 25 | 1 | — | — |
| `materials/lamp_oil` | 20 | 1 | — | — |
| `consumables/salted_riverfish` | 15 | 1 | — | — |
| `materials/stopper_wax` | — | 1 | `sounding` | -10.0 |

### DRAFT `verge-march-kit`

| item_id | weight | quantity | skill | modifier |
|---|---:|---:|---|---:|
| `consumables/road_crusts` | 30 | 1 | — | — |
| `tools/tent_pegs` | 25 | 1 | — | — |
| `consumables/loam_smoked_eel` | 20 | 1 | — | — |
| `materials/binding_thread` | 15 | 1 | — | — |
| `tools/map_case` | — | 1 | `sounding` | -10.0 |

### DRAFT `hollowmere-reed-kit`

| item_id | weight | quantity | skill | modifier |
|---|---:|---:|---|---:|
| `materials/cut_reeds` | 30 | 1 | — | — |
| `materials/net_cord` | 25 | 1 | — | — |
| `materials/scribes_vellum` | 20 | 1 | — | — |
| `materials/lamp_oil` | 15 | 1 | — | — |
| `tools/netting_needle` | — | 1 | `sounding` | -10.0 |

### DRAFT `wilds-repair-cache`

| item_id | weight | quantity | skill | modifier |
|---|---:|---:|---|---:|
| `materials/repair_splints` | 30 | 1 | — | — |
| `consumables/cloth_bandage` | 25 | 1 | — | — |
| `consumables/bitterleaf_poultice` | 20 | 1 | — | — |
| `materials/binding_thread` | 15 | 1 | — | — |
| `tools/stitching_thimble` | — | 1 | `sounding` | -10.0 |

## Canon check

The **Dramgid** vault owns lore prose. Its `index.json` was read before the five cited entities below; no other vault entities were opened. The requested `../dramgid-vault` sibling does not exist from this worktree; the vault used is **`/home/adamjroder/projects/dramgid-vault`**. Vault paths below are relative to that root. Repository location documents live under `canon/*/locations/`, with the template's resources under `world/locations/`, rather than `docs/locations/`.

| Key / proper noun used | Exact source | What it establishes here |
|---|---|---|
| Soul Meter | [Game identity][identity]; [art bible Part I][art] | Project name, field-game remit, restrained practical register. |
| Dramgid | Vault `index.json`, `world` | Existing world name; no new world terminology. |
| V1 — Dom; Iron Companies | Vault `cities/dom.md`, id `dom`, §§Geography & Environment / Economy & Trade; [location document](../../canon/dom/locations/dom.json) | Coal, timber and leather supply, smithing and company stock. |
| V2 — Ashlaren | Vault `locations/ashlaren.md`, id `ashlaren`, §§Overview / Detail / Notes & Open Threads; [location document](../../canon/ashlaren/locations/ashlaren.json) | Milling, weighing and grain sacks; no resolution of the anomalous sack or rot. |
| V3 — Kesselford | Vault `locations/kesselford.md`, id `kesselford`, §§Overview / Detail; [location document](../../canon/kesselford/locations/kesselford.json) | Existing ferry and chandlery context; no new river custom. |
| V4 — The Long Verge / Long Verge | Vault `locations/the-long-verge.md`, id `the-long-verge`, §§Overview / Detail; [location document](../../canon/long_verge/locations/long_verge.json) | Marching camps and road maps; no new cairn or burial lore. |
| V5 — Hollowmere | Vault `locations/hollowmere.md`, id `hollowmere`, §§Overview / Detail; [location document](../../canon/hollowmere/locations/hollowmere.json) | Abandoned fishing and reed-cutting camps, ongoing written reports; no claim of a restored fishery. |
| Wilds | [Location document](../../canon/dom/locations/wilds.json); [B1][b1] | Existing region mapped to `world/test_room.tscn` and its two caches. |
| Dorthkor Road | [Location document](../../canon/dom/locations/dorthkor_road.json); [scene](../../world/dorthkor_road.tscn) | Existing roadside table and fixed camp cache. |
| Wound Lip | [Location document](../../canon/dom/locations/wound_lip.json); [scene](../../world/wound_lip.tscn); [location template](../templates/location.md) | Existing fixed ledge and guard supplies. |
| Sounding / `sounding` | [Loot registry][registry], `road-cache`; [B1][b1] / [B2][b2] | Existing search skill and -10.0 modifier, separate from opening a lock. |
| I — existing item identifiers in grounding and loot rows | [Item tree][items], exact keys quoted in each row | Existing materials, food and tools; none of their descriptions is extended into a new supernatural claim. |
| `ford-chandlery` and vendor context | [Vendor data][vendors], keys `ford-chandlery`, `flat-bell-provisions`, `iron-and-thread`, `rivet-and-spur` | Existing ferry oil/fish, milling provisions and workshop material stock; no vendor stock change is proposed. |
| All scene-root and container names in the assignment table | [B1][b1] / [B2][b2], §What now works and how to see it; the exact `.tscn` paths listed above | Verbatim existing technical identifiers, including the shop, warehouse, forge, company, millhouse, weighing-hall, chandlery and wayhouse roots. |

All 18 proposed display names are descriptive common-object labels grounded in their item rows, not new proper names. The six proposed table ids are technical labels built from existing regions or container uses. **Ungrounded rows: none.** Grounding supports plausibility only; every new description still needs owner approval.

## Review limits

The provisional targets and all proposed prices, weights and distributions still need owner judgment; category bounds alone do not establish economy balance. The existing [owner-decision list](../owner-decisions.md) leaves loot density open at item 11(c). The assignment identifies equipment as blocked on item 29, but that numbered item is absent from this checkout's list; this packet preserves the block and does not resolve or edit the list.

Changing pools would change new-container rewards, including the Sounding bonus; existing saved contents remain frozen under the registry's one-roll contract. Any later implementation must preserve that persistence. Food and tools here add no promised healing, crafting, equipment or skill effects. Static review checked counts, category ranges, item references, registry row shape, source paths and all 18 proposed container paths; gameplay behavior is unchanged and was not exercised for this document.

**How to answer:** `packet: accept all` / `packet: accept except <ids>` / `packet: rename <id> <name>` — use item ids or table ids above; acceptance approves the draft content for follow-up implementation, not the global provisional density targets.

[items]: ../../data/generated/gloot_prototree.json
[registry]: ../../globals/loot_table_registry.gd
[vendors]: ../../data/generated/vendors.json
[identity]: ../game-identity.md
[art]: ../art-aesthetics-bible.md
[b1]: field-density-b1-review-2026-10-31.md
[b2]: field-density-b2-review-2026-10-31.md
