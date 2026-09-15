# Elemental reaction matrix: what a later cast finds

**2026-09-14 · Proposed design, not ratified.** This expands the nine sequential
interactions in [elemental-magic-systems.md](elemental-magic-systems.md) §"Initial
reaction rules" into a complete table: for every element cast *later*, what happens
to every state an *earlier* element can leave behind. It uses only the established
Impositions and Rule-Bends from the vault's Elements & Music spec and the statuses,
fields and materials already defined in the [shared card rules](spell-card-rules.md)
and the [Khash packet](khash-prototype-spell-cards.md). Numbers are playtest proposals.

## What this is and is not

| This document | Not this document |
|---|---|
| Sequential interactions: cast A leaves a state, cast B meets it later. | Composition: which elements can be sounded together. The Wheel, strain and Triads are unchanged. |
| Reactions on creature statuses, Notes/Aftertones, magical fields and physical materials. | The attunement damage matrix in `element_matrix.gd` (#133). Nothing here changes target-relation multipliers, fizzle or Soul-on-failure. |
| A default of **no reaction** with a short list of authored ones. | Tile charge, Clash detonation, Weather or Hush. Those stay on their existing rules; the cross-element residue overwrite in `tile_state.gd` stays a flagged placeholder. |

**Design law for reactions:** the five opposed pairs are the counters; adjacent
elements compound; everything else reacts only where the table says so. A reaction
never fires on a rejected cast, never charges a second fizzle, and never applies a
status the card did not name.

## The states an earlier cast can leave

| Left by | Creature status | Magical state | Physical state |
|---|---|---|---|
| Sul | Exposed | Revelation window (Witness Light) | — |
| Vel | Overgrown | Growth cells (Rootwork); an extended owned buff | — |
| Luth | Soaked | — | Wet object or surface |
| Khor | — | Held Note (one sustain slot) | — |
| Tham | Weighted | Raised Cover construct; Anchored Aftertone | — |
| Vekh | Blinded | Veiled signature; Shroud area | — |
| Mozh | Decaying | — | Rotted brace; consumed source (gone) |
| Khash | Burning | Fire line (Firebreak); an Aftertone consumed (gone) | Burning, then ruined, material |
| Zhem | Muted | — (removal leaves nothing) | — |
| Zhur | Shocked | — (a conduction route is transient) | — |

Unanchored Aftertones and eligible Notes can be left by any damage-bearing or
support working; they are listed under the element whose Rule-Bend acts on them.

## The matrix

Rows are the **later** cast's element. Columns are the element that left the state.
`—` means no authored reaction: the later working resolves on its own card and the
earlier state is untouched. A code points to the reaction table below.

| Later ↓ / Earlier → | Sul | Vel | Luth | Khor | Tham | Vekh | Mozh | Khash | Zhem | Zhur |
|---|---|---|---|---|---|---|---|---|---|---|
| **Sul** | — | — | — | S1 | S2 | **S3** | — | — | — | — |
| **Vel** | — | V1 | V2 | — | V3 | — | **—** | V4 | — | — |
| **Luth** | — | L1 | — | — | — | — | — | **L2** | — | L3 |
| **Khor** | K1 | K2 | — | — | K3 | — | — | K4 | **—** | — |
| **Tham** | — | T1 | — | T2 | — | — | — | T3 | — | **T4** |
| **Vekh** | **X1** | — | — | X2 | X3 | — | — | X4 | — | — |
| **Mozh** | — | **M1** | M2 | — | M3 | — | — | M4 | — | — |
| **Khash** | — | H1 | **H2** | H3 | H4 | H5 | H6 | — | — | — |
| **Zhem** | Z1 | Z2 | — | **Z3** | Z4 | Z5 | — | Z6 | — | Z7 |
| **Zhur** | — | R1 | R2 | — | **R3** | — | — | — | — | — |

Bold cells are the opposed pairs. Three of the ten are deliberately empty:
Vel does not undo Decaying, Khor cannot re-hold what Zhem has severed, and Vekh's
answer to Sul is only concealment of what is not yet Exposed. The counter in those
pairs lives in the other row.

## Reaction table

Each reaction states the trigger, the result, what the player can do about it, and
what the preview must show before commitment. "Checkpoint" means a round checkpoint
under the Khash packet's ordering.

### Sul, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| S1 | Unveil or Witness Light covers a Held Note | The holder, owner and remaining duration become visible to the caster's side. No effect on the hold itself. | Zhem or Khash still need their own eligible target. | Show the hold as an inspectable item, not as a damage target. |
| S2 | Revelation covers an Anchored Aftertone | The anchor and its remaining protection are revealed. Anchoring is not concealment; nothing is broken. | — | Mark the anchor with the same anchored symbol the owner sees. |
| **S3** | Unveil or Witness Light meets a Veiled signature or a Shroud area | Eligible concealed signatures inside the window are revealed for the window's duration. A Shroud is not ended; it stops working where the window overlaps it. A creature Exposed this way cannot be re-veiled until Exposed expires. | Vekh can re-shroud cells outside the window. | Show the overlap as revealed cells; cells outside stay concealed in the preview. |

Sul never reveals physical fire, ruins or rubble. Those are visible to everyone already.

### Vel, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| V1 | Cultivate on an owned buff already extended once | Rejected before costs: one extension per buff instance, capped at original duration +1. | Cast a fresh buff instead. | Show "already extended" on the buff. |
| V2 | Rootwork into a Wet eligible substrate | Growth cells are created and start **Wet**: non-combustible for the Wet duration that remains on the substrate. No growth bonus. | Khash waits out Wet or burns a dry cell instead. | Wet growth uses the wet material tint plus the growth outline. |
| V3 | Rootwork footprint overlaps a Raised Cover construct | The overlapping cell is ineligible; the cast is rejected unless the remaining footprint is still legal by its card. | Choose another footprint. | Reject before payment with the cover cell marked. |
| V4 | Rootwork footprint overlaps a burning cell or an active fire line | Rejected: growth cannot be created on a burning cell. Growth may be created on a ruined, unlit footprint. | Douse first, or wait for the line to expire. | Reject before payment with the burning cells marked. |

Vel does not cleanse Decaying and does not repair a rotted brace. Vel/Mozh is the
one opposed pair whose counter runs only one way: Mozh eats growth (M1); growth
cannot eat decay.

### Luth, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| L1 | Douse on combustible growth cells | The cells become Wet for two checkpoints: non-ignitable, and any physical fire on them ends. Their remaining fuel is unchanged. | Khash targets creatures instead, or a cell outside the doused footprint. | Wet tint on the chosen cells only; Douse is single-target, so one cell per cast. |
| **L2** | Douse on a Burning creature, burning material or a Firebreak cell | Creature: Burning removed, Soaked applied. Material: fire ends, Wet applied, integrity already lost stays. Firebreak cell: the physical fire on that cell ends and the cell's material is Wet, but the magical line continues and can reignite after Wet expires. | Khash cannot reapply Burning through Soaked; Zhem's Unmake ends the line itself. | Show three distinct outcomes: quenched creature, quenched object, still-active line. |
| L3 | Douse on a Shocked creature | Soaked applies normally. Shocked is not removed and not extended. A Soaked creature is a valid conduction target (R2). | The player chooses whether wetting an ally is worth the Zhur risk. | Show the Soaked target as conductive if any Zhur caster is visible. |

Second Breath has no reaction row: restored Breath is not a state anything else acts on.

### Khor, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| K1 | Hold Note on an owned revelation window | Eligible: the window's remaining duration is frozen while upkeep is paid (Witness Thread does this in one cast). | Zhem severs the held window (Z3). | Show the upkeep price on the window before the first cast. |
| K2 | Hold Note on owned growth cells | Eligible as one Note: all cells of one Rootwork instance share the hold. Wet or burning state on those cells is physical and is not frozen. | Mozh or Khash still act on the cells. | Show that fire and Wet keep counting while duration is frozen. |
| K3 | Hold Note on an owned Anchored Aftertone | Eligible. Holding and anchoring stack: time is frozen and Khash cannot consume it. Zhem can still end it (Z3, Z4). | Zhem. | Show both the anchor symbol and the hold symbol. |
| K4 | Hold Note on an owned Firebreak | Eligible (Furnace Choir does it in one cast). The line's hazard limits are unchanged. | Douse cells, Unmake the line, or walk around it. | Show upkeep and remaining hazard events per creature. |

Khor cannot hold a hostile imposition, physical fire, Wet, a rotted brace or a
consumed source. Khor/Zhem is the pair where the counter is entirely Zhem's (Z3).

### Tham, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| T1 | Raise Cover footprint overlaps growth cells | Rejected on the overlapping cells; cover and growth never share a cell. | Choose another footprint. | Reject before payment. |
| T2 | Anchor on a Held Note that is an eligible Aftertone | Allowed. Anchoring protects it from Khash consumption (H3); the hold keeps its time. Anchoring a Note that is not an Aftertone is rejected before costs. | Zhem. | Show "anchored" only on eligible Aftertones. |
| T3 | Raise Cover on a Firebreak cell or a burning cell | Allowed. The construct is noncombustible and blocks the cell; the line still exists underneath and reapplies its hazard to the cell when the cover expires. Cover on burning material does not extinguish it. | Zhem's Unmake removes the cover early. | Show the cover cell as blocked with the line still drawn beneath. |
| **T4** | Raise Cover on a cell in a wet conductive surface | The cover cell is non-conductive and breaks connectivity through it. A Zhur route previewed across that cell is no longer legal. | Zhur routes around it if the surface still connects. | Recompute the conduction preview when cover is placed. |

Weighted has no reaction of its own. It never taxes a creature already committed to
a move (status contract), so it does not interact with Overgrown beyond both applying.

### Vekh, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| **X1** | Veil or Shroud on an Exposed creature or a revelation window | Rejected on Exposed properties until Exposed ends; Shroud cells inside an active window are concealed only after the window expires. Outside the window, Shroud works normally. | Sul extends the window with Khor (K1). | Show which cells the Shroud will actually conceal now. |
| X2 | Shroud covers a Held Note | The hold's signature is concealed from the other side; the holder still pays upkeep and the effect still works. | Sul (S1). | Concealed-hold symbol for the owner's side only. |
| X3 | Shroud covers an Anchored Aftertone | Concealed like X2. Concealment does not make it consumable or unconsumable. | Sul (S2). | Same as X2. |
| X4 | Shroud covers physical fire or a Firebreak | Physical fire and the line are **not** concealed: fire is light. Signatures of other workings inside the Shroud are still concealed. | — | Draw fire at full visibility inside the Shroud. |

Blinded does not reduce hazard damage from a fire line, a burn tick or a decay tick.
Those are not attacks and never roll to hit.

### Mozh, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| **M1** | Wither or Reclaim on growth cells | Wither: the targeted cell rots away at once; the obstruction is gone and leaves nothing. Reclaim: the targeted cell is consumed for **3 Breath**, at most one cell per cast, and the Rootwork instance shrinks. Neither yields Breath from Wet or burning cells. | Vel recasts Rootwork; Khor's hold does not protect against removal. | Show Breath yield per cell and that the cell is a finite source. |
| M2 | Rot the Brace on a Wet susceptible brace | Rot applies its full integrity damage; Wet only prevents ignition, not decay. | Tham cover routes around the brace. | Standard integrity preview. |
| M3 | Wither or Reclaim on a Raised Cover construct | Rejected: a magical construct is not susceptible material and not a source. | Zhem's Unmake. | Reject before payment. |
| M4 | Reclaim on burning or ruined material | Burning material is **ineligible** until it collapses; ruined material is an eligible source once, for the Khash packet's ruined-object yield. Rot the Brace on burning material applies in its own channel and can hasten collapse. | Douse to stop the fire and keep the source ineligible longer; Tham to protect a route. | Show "burning: not yet a source" and the eventual yield after collapse. |

Decaying and Burning coexist with separate owners and separate ticks (status
contract). No corpse policy changes: downed hostiles despawn on scene exit as ruled.

### Khash, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| H1 | Kindle or a fire line meets combustible growth cells | The cell ignites with the Khash packet's 3-integrity burn tick against the growth's smaller fuel. Wet growth (V2, L1) does not ignite. A growth buff on a creature is not flammable terrain. | Luth (L1); Vel accepts the loss. | Show fuel remaining per cell and the collapse checkpoint. |
| **H2** | Any Burning application on a Soaked creature, or ignition on Wet material | Burning is not applied; ignition does not occur. The working's direct creature power or direct integrity damage still applies. | Wait out Soaked or Wet (two checkpoints). | Show "no Burning: Soaked" and the direct damage that still lands. |
| H3 | Consume Aftertone on a Held Note | If the Note is an eligible **unanchored** Aftertone, it is consumed and the hold ends with it; the holder's upkeep stops. Holding is not anchoring. If it is anchored (T2, K3), consumption is rejected. | Tham anchors before Khash reaches it. | Show consumable vs anchored on every visible Aftertone. |
| H4 | Fire meets a Raised Cover construct or an Anchored Aftertone | Cover: noncombustible, no integrity channel. Anchored Aftertone: cannot be consumed. Neither blocks the working's other effects. | — | Mark both as inert to fire. |
| H5 | Kindle on a Veiled or Shrouded target | Targeting requires a visible surface or creature, so a fully concealed *signature* is not a valid Consume target; the creature itself is still attackable if visible. | Sul first. | Show the creature as attackable, its signature as unknown. |
| H6 | Burning applied to a Decaying creature | Both persist with separate ticks and owners: 6 fixed HP per checkpoint while both run. No merge and no bonus. | Douse removes only Burning. | Two status icons, two tick amounts. |

### Zhem, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| Z1 | Unmake on a revelation window | The window ends; already-revealed Exposed properties stay Exposed until their own expiry. | Sul recasts. | Show which Exposed statuses survive the cancel. |
| Z2 | Unmake on growth cells | The Rootwork instance ends; any physical fire on those cells ends with the fuel. Wet state is irrelevant afterward. | Vel recasts. | Show the cleared footprint. |
| **Z3** | Sever on a Held Note | The Note ends despite the hold. The holder's sustain slot is freed and upkeep stops. No refund. | Vekh conceals the hold (X2) so it is harder to target; Tham's anchor does not stop this. | Show the hold as severable. |
| Z4 | Sever on an Anchored Aftertone | The Aftertone ends. Anchoring guards against consumption, not cancellation. Inside a Vault Triad's Sealed Ground the Triad rule wins and Sever is rejected there. | Vault. | Show "anchored: still severable" outside Sealed Ground. |
| Z5 | Unmake on a Shroud | The Shroud ends; Veiled signatures inside are exposed to ordinary sight, not Exposed. | Vekh recasts. | Show revealed cells without the Exposed icon. |
| Z6 | Unmake on a Firebreak | The magical line ends. Physical fire already burning on material continues on its own fuel. | Douse the material separately. | Show "line ends; material still burning" on affected cells. |
| Z7 | Quiet on a Shocked creature | Tempo resets. Shocked is not removed: it is a status, not a buff or Aftertone. | — | Both effects listed. |

Zhem never restores a consumed source, a collapsed object or lost integrity.

### Zhur, later

| Code | Trigger | Result | Counterplay | Preview |
|---|---|---|---|---|
| R1 | Conduct route through growth cells | Growth is non-conductive, wet or not. The route stops at the first growth cell. | Vel places growth to cut a route. | Route preview stops at growth. |
| R2 | Conduct through a connected Wet surface, or Arc at a Soaked creature standing on it | Route follows explicit Wet-cell connectivity up to the card's range and target cap. Every creature on the route, allies included, is a target; each takes the working's power once. Soaked creatures on dry cells are not connected by their status alone. | Tham cover (T4); step off the wet surface; let Wet expire. | Show the exact route, every affected creature and the cap before commitment. |
| **R3** | Conduct meets a Raised Cover cell or a Weighted creature | Cover breaks the route (T4). Weighted does nothing to Zhur: no bonus, no resistance. | — | Route recompute only. |

Sure Current has no reaction row. It changes the caster's own Instability die, not
anything left on the board.

## Creature status pairs

Statuses from different elements coexist unless a row above says otherwise. The
combinations that matter for a turn decision:

| Pair | Result |
|---|---|
| Overgrown + Weighted | Both apply: the move is limited to one cell and the first move pays the surcharge. |
| Blinded + Shocked | One committed attack consumes both: −10 hit and the +1 AP / +10 CT surcharge on the same action. |
| Burning + Decaying | Separate ticks and owners; 6 fixed HP per checkpoint while both run (H6). |
| Soaked + Burning | Cannot coexist: Douse removes Burning and Soaked blocks its return (L2, H2). |
| Exposed + Blinded | Coexist: Exposed is information about the target; Blinded taxes the target's own attack. |
| Muted + anything | Muted is instantaneous and leaves no status to pair with. |

## Checkpoint order for chains

1. Existing fields expire or receive their final protection (Wet, Soaked, holds).
2. Continuing ticks: creature Burning, Decaying, physical burn ticks, fire-line hazard.
3. Collapse: any material reaching zero integrity becomes ruined; its fire ends.
4. New eligibility: ruined material becomes a Mozh source; a cell whose Wet expired
   becomes ignitable again if a fire line still covers it.

Effects created at a checkpoint neither age nor tick at that checkpoint (card rules).
A chain the player cannot predict from these tables is shown as **uncertain** in
the forecast; the game never prints an exact number it will not honor.

## Worked chains

| Chain | Outcome under these rules |
|---|---|
| Vel Rootwork (3 cells) → Khash Kindle one cell → Luth Douse that cell | Cell ignites (H1) and takes 3 integrity; Douse ends the fire and wets it (L1); the other two cells were never burning. Rootwork instance survives with one damaged cell. |
| Luth Douse a wet stone floor cell → ally walks onto it → enemy Zhur Conduct | Route runs through every connected Wet cell; the ally is hit (R2) because the route was shown before commitment and the player accepted it. |
| Khor holds an attack Aftertone → enemy Khash Consume | Consumed; hold ends, upkeep stops (H3). Had Tham anchored it first, Consume is rejected (T2). Had Zhem severed it instead, gone either way (Z3). |
| Vekh Shroud an area → Khash Firebreak inside it → Sul Witness Light over half | Fire is visible throughout (X4). Other signatures are revealed only in the lit half (S3); the Shroud keeps working in the dark half. |
| Khash Kindle timber → Mozh Reclaim it next turn | Rejected: burning material is not a source (M4). After collapse it yields once. Douse first if the goal is to keep the barricade rather than harvest it. |
| Tham Raise Cover on a Firebreak cell → cover expires | Blocked cell for the cover's life; the line reapplies its hazard to that cell afterward (T3). |

## Open tuning and owner decisions

1. **Reclaim yield from growth (M1):** 3 Breath per cell is a placeholder below the
   Khash packet's ruined-object yield; confirm it cannot beat casting Rootwork's price.
2. **Anchored vs Sever (Z4):** the proposal is that Tone-level anchoring stops
   consumption only, and only the Vault Triad stops severing. If anchoring should
   also resist Zhem, the Vault's Sealed Ground loses part of its unique verb.
3. **Wet growth (V2):** creating growth already Wet is a small free benefit of a
   Luth/Vel pairing. Keep or drop after the yard playtest.
4. **Conduction and allies (R2):** allies on the route are targets. A "friendly
   current" exception is a future card, not a matrix default.

## Runtime handoff

Implement in this order, each through forecast and commit together:

1. Material reactions in the isolated yard: L2, H2, M4, Z6 on the existing Khash
   slice (timber, stone control, Firebreak, Douse).
2. Hold/anchor/consume/sever ownership: K3, T2, H3, Z3, Z4.
3. Growth and cover footprints: V3, V4, T1, T3, H1, L1, M1, Z2.
4. Concealment and revelation windows: S3, X1, X2, X4, Z1, Z5.
5. Conduction: R2 with T4 and R1 as its route breakers.

Acceptance for each step: the preview shown before commitment matches the committed
result for every cell listed here, rejected casts spend nothing, and no reaction
fires that is not in this table. Sources: [elemental design](elemental-magic-systems.md),
[shared card rules](spell-card-rules.md), [Khash packet](khash-prototype-spell-cards.md),
[Triad cards](triad-spell-cards.md), the vault's `systems/elements-and-music.md`, and
`globals/combat/tile_state.gd` for the untouched charge rules.

### Step 1 runtime (2026-09-15)

Material reactions on a new physical substrate, `globals/combat/material_field.gd`
(`CombatController.material`). Test suite: `test/unit/test_reaction_matrix_step1.gd`.

| Piece | Where | Notes |
|---|---|---|
| Objects | `CombatController.place_material(id, cell, kind, label)` after `start()` | Timber: integrity 30, nine fuel ticks, combustible. Stone: noncombustible, immune to thermal damage. An object's cell is impassable (grid cliff) until ruined. Saved under `__materials__`; published in `snapshot().materials`. No scene bridge yet: the yard has to call `place_material` itself. |
| Object casts | `options.object_id` on Kindle, Douse, Reclaim, Rot the Brace; `options.line_id` on Sever | Routed through `_query_object_action` / `_apply_object_action`: range and line of sight to the object's cell, eligibility before payment, costs and fizzle through the cell-cast path. The `object` preview in the query is the committed result. The HUD pointer does not pick objects yet. |
| Kindle / Crown / Firebreak | `object_damage` payload (3 / 9); `_thermal_hit_object()` | Direct integrity damage, then eligible ignition. A fire line and a Crown mark may sit on a timber cell (never stone); the line ignites timber at creation and reignites it at a checkpoint once its Wet ran out. Cinder Spear is not built. |
| L2 | `MaterialField.douse()` | Object: fire ends, Wet two checkpoints, lost integrity stays. Creature half unchanged. Under a Firebreak the line continues. |
| H2 | `MaterialField.ignition_refusal()` = `wet` | The hit lands, no ignition, `ignition_refused` event. Soaked creature half already refused Burning. |
| M4 | `64_reclaim.tres`, `MaterialField.reclaim_refusal()` | Burning: `not_a_source` (reason `burning`) before payment. Ruined timber yields 9 Breath once, capacity-clamped (`already_claimed` after). Intact timber and stone are not sources. `65_rot_the_brace.tres` (M2) ignores Wet and rejects stone. |
| Z6 | `63_sever.tres` (`line_id` within 4) | The line is removed; timber already burning keeps ticking on its own fuel. Sever's other targets (Aftertones, held Notes) are step 2. |
| Checkpoint | `_material_checkpoint()` after `_fire_checkpoint()` | Burn ticks (3 integrity, 1 fuel) on what burned at entry, collapse (fire ends, footprint opens), fuel exhaustion, Wet countdown, then reignition under a surviving line. |

Open: yard scene bridge and HUD object picking; Cinder Spear; the out-of-combat WorldClock
burn rule in the Khash packet is not wired (combat-only substrate).
