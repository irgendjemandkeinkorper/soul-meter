# U3 pilot batch — Phase A, 2026-11-09

**Ready for owner review; unapproved. Estimated batch cost: 60 Meshy credits.**
Issue #632 authorizes preparation only in this run. The batch has no `approval`
object. Phase B remains gated on the owner's review and handwritten approval.

Batch: [`assets/generated/models/races/u3-pilot-batch.json`](../../../assets/generated/models/races/u3-pilot-batch.json).
Batch ID: `soul-meter-u3-pilot-2026-11-09`.

## Requests, caps and estimate

| Base / asset ID | Model ID | Kind | Requests in this batch | Target triangles | Target texture edge | Credits |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| Vael / `vael-base` | `meshy-7.1` | image-to-3D | 1 | 6,000 | 1024 px | 30 |
| Ghorr / `ghorr-base` | `meshy-7.1` | image-to-3D | 1 | 6,000 | 1024 px | 30 |
| **Total** | | | **2** | | | **60** |

- **Used this run:** Vael 0/2; Ghorr 0/2; total **0/4**. No image or Meshy
  generation, including rejects, was attempted. Credits spent: **0**.
- **Planned:** one initial request per base, two total. The second allowed
  attempt per base is not included in this batch. Rejected attempts count
  toward the cap; there are no automatic retries.
- **Maximum allowance:** two generations per base, four total. At the pinned
  local estimate of 30 credits each, using all four would cost **120 credits**.
  Any additional attempt needs a separately reviewed batch/approval and must
  preserve the cumulative per-base count. The current batch covers only 60.
- Prices come from asset-forge's local `config/meshy_pricing.json`, verified
  2026-10-31. This is an offline estimate, not a live quote or a balance check;
  it includes only the image generation stage, not other paid services.

The explicit `meshy-7.1` ID pins the README's standard-model default. Both
assets use the existing `character` role and its shared 6,000-triangle cleanup
ceiling, below Soul Meter's 12,000-triangle composed-unit maximum. The 1024 px
texture target follows [handoff §5](../../handoff-art-units-codex.md#5-contracts-do-not-relax).
These are output targets: P1 requests standard geometry with 2K textures and
does not send the triangle or texture targets to Meshy. Phase B must enforce
the targets during cleanup; no new game policy or tooling override is added.

## Approved reference inputs

Paths in the batch resolve relative to its directory. Both PNGs and their
sidecars were read; both images were visually inspected and decoded with PIL.
The sheets are 1774 × 887 RGB with no alpha channel; the crops keep the sheets' grey background. Inputs are unchanged.

| Base | Reference and sidecar | Pixels | `reference_sha256` |
| --- | --- | ---: | --- |
| Vael | [front crop](../../../assets/generated/models/races/vael/u3-reference-front.png) of the [sheet](../../../assets/generated/models/races/vael/identity-sheet.png) · [sidecar](../../../assets/generated/models/races/vael/identity-sheet.md) | 344 × 887 | `da7cea14b6a0ea0706307b78154aadc6ce71b04b10d95506738740e906a6cc42` |
| Ghorr | [front crop](../../../assets/generated/models/races/ghorr/u3-reference-front.png) of the [sheet](../../../assets/generated/models/races/ghorr/identity-sheet.png) · [sidecar](../../../assets/generated/models/races/ghorr/identity-sheet.md) | 412 × 710 | `8d0e08945f252eb66ed37ca4879cbcbe4740fabd983412128b1c285caf367c3a` |

The sidecar titles retain their U1 draft wording. Their acceptance is supplied
by the issue's approved-input contract and the 2026-10-31 item 28 ruling in
[`docs/owner-decisions.md`](../../owner-decisions.md); this preparation does not
revise those rulings. Ghorr's **1.15× Vael, PROVISIONAL** factor is retained for
Phase B, as directed by the issue. No weapon arm pair, class kit, population
mix, additional race or lore decision is made.


**Reference crops (Claude, 2026-11-09).** Each identity sheet shows five figures: front, three-quarter, back, the Waning study and the dressed worker, plus a scale inset. Sent whole, Meshy would try to build one model from all five. The batch therefore sends only the healthy front view, cropped from the approved sheet. Nothing is drawn or recoloured. The one edit: on the Ghorr crop, a 22 px strip at the right edge (rows 160–350) is covered with mirrored background from the left edge. It hid a sliver of the neighbouring three-quarter figure. The sheets themselves are unchanged. Limitation 1 below is resolved by this crop; limitation 2 stands.

## Exact offline command evidence

Working directory for both commands:
`/home/adamjroder/projects/asset-forge-wt/p5`, branch `codex/p5-godot-handoff`.
Schema and pricing source: that checkout's `README.md` (§§ Batch format,
Offline credit model, Seeded role limits), `asset_forge/batch.py` and
`config/meshy_pricing.json`.

The local CLI has an unconditional environment-key lookup before dispatching
`plan`/`hash` (`asset_forge/cli.py:98`). Both commands therefore ran with an
empty child environment using `env -i`; no actual key was inherited or read,
and the owner's shell environment was untouched. `PYTHONDONTWRITEBYTECODE=1`
prevents Python cache writes into the read-only tooling checkout. No tooling
files were edited.

```sh
env -i PATH=/usr/bin:/bin PYTHONDONTWRITEBYTECODE=1 python3 -m asset_forge plan /home/adamjroder/projects/soul-meter-wt/codex-u3-pilot/assets/generated/models/races/u3-pilot-batch.json
```

Exit **0**. Exact output:

```text
Batch soul-meter-u3-pilot-2026-11-09; prices verified 2026-10-31
vael-base (meshy-7.1): image 30 = 30 credits
ghorr-base (meshy-7.1): image 30 = 30 credits
Total: 60 credits
Assets SHA-256: 48e46829ab1e714f38a0a2981be240dc1e421c3ae87f35bbda820979bb242c40
Offline estimate; no requests sent.
```

```sh
env -i PATH=/usr/bin:/bin PYTHONDONTWRITEBYTECODE=1 python3 -m asset_forge hash /home/adamjroder/projects/soul-meter-wt/codex-u3-pilot/assets/generated/models/races/u3-pilot-batch.json
```

Exit **0**. Exact output:

```text
48e46829ab1e714f38a0a2981be240dc1e421c3ae87f35bbda820979bb242c40
```

This is the canonical **assets-array hash**, not the batch file's byte hash.
It binds both image digests, paths, models and target budgets. The owner must
use this value for `approval.batch_sha256`; changing any asset requires a new
plan/hash and owner review.

## Phase A completion and later checks

The two CLI checks passed schema validation and verified the reference hashes.
No network call was made; no credential was set, accessed or written to a file
or log. Neither `asset_forge run` nor its dry-run mode was invoked. No Blender
or Godot process, import or runtime test was needed for this JSON/documentation
change, per [`docs/agent-verification.md`](../../agent-verification.md).
No Git writes or GitHub operations were performed.

**Capture paths: none. Contact-sheet path: none.** Those are Phase B outputs;
this run produced only the batch JSON and this document.

Open questions: none blocking Phase A. Two limitations remain for Phase B:

1. **Resolved by the front crops above.** Each required reference is a sheet with healthy turnaround views, a Waning
   study, a worker study and a scale inset. P1 sends the entire unchanged image
   and accepts no image prompt. Plan validation cannot establish that Meshy will
   return one healthy base without the other studies, inset or lettering.
   Inspect the generated result against U3's single-subject contract; any
   proposed reference change requires direction and a new approved hash.
2. Generation alone does not establish skeleton compatibility, four-arm
   readability, height, topology, texture compliance or the owner's visual
   acceptance. Those remain the later U3 build and review gates.

**Stop point:** owner reads this plan, adds the approval object by hand and
supplies the key in their own shell before a separately authorized Phase B run.
