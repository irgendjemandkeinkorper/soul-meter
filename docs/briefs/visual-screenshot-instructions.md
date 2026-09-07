# Soul-Meter — development screenshot concepts and Codex instructions

Working material for discussion. This brief requests proposed visual targets, not captures from the current build. It does not rename the project, approve new lore, change gameplay, or replace the ratified art direction. Use the Loam Lantern document as a model for the presentation's clarity and specificity, not its cozy setting, third-person camera, or 3D style.

## Task for Codex

Draft a coherent set of concept screenshots that helps developers answer: what should a playable Soul-Meter screen look like, what should the player notice first, and how should the cost of their decisions remain visible?

1. Read the grounding documents below. `docs/game-identity.md` takes precedence over older gameplay descriptions; `docs/art-aesthetics-bible.md` governs visual style. Inspect the approved calibration artwork and any supplied current screenshots before using them as references. Do not claim to have inspected a missing image.
2. Generate four separate landscape 16:9 concept screenshots using the shared prompt and the four scene briefs below. Aim for 1920×1080 or higher where supported; record actual dimensions. Separate images preserve enough space to evaluate gameplay and interface readability.
3. Generate a matching 2-by-2 overview with narrow neutral gutters and a modest **Soul-Meter** header. Preserve the cast, camera, materials, and interface between individual views and the overview. Label it **Development concept — not a build capture** outside the gameplay area.
4. Save outputs under `design/concepts/soul-meter-screens/`, with descriptive filenames and a short `README.md` recording each prompt, references actually used, proposed UI decisions, and visible generation defects. Keep existing assets intact. Use the image-generation tool available in the session; these are concept images, not production sprite exports.
5. Review the results against the acceptance checks below. Return links to the images and notes, with one recommended screenshot to review first. Do not implement UI, replace game art, edit scenes, or turn mockup wording into quest data as part of this task.

If the image tool cannot save directly to the requested folder, preserve its returned artifact and record that location. Do not report a file as saved until it exists.

## Working identity

**Soul-Meter** — a mature fantasy isometric RPG set in Dramgid. Its ratified hook is **soul as currency**: meaningful acts spend something of the self, and the world keeps a ledger. Frequent tactical combat, field skills, companions, and consequential dialogue make those costs personal.

Optional presentation line: **Every promise leaves a mark.** This is proposed mockup copy, not an approved tagline or new rule that every promise automatically deducts Soul.

The tone is elegiac and wry. Civilization still functions inside a metaphysical emergency: roads are maintained, institutions keep records, companions have dry humor, and the world is slowly becoming less dependable. Loss should feel consequential without turning the game into a punishment screen.

## Copyable shared image-generation prompt

Create a polished gameplay concept screenshot for **Soul-Meter**, an existing mature fantasy 2D isometric RPG set in the original world of Dramgid. This is a development target, not a screenshot of the current build. Follow the scene brief appended below.

Use a consistent elevated isometric field camera and semi-realistic painterly digital illustration. The image should plausibly be assembled from richly painted terrain, props, and character sprites. Keep a coherent ground plane, character footprints, scale, occlusion, and light direction. Favor readable game composition over a cinematic painting with tiny unusable controls. Do not introduce a third-person follow camera or turn the world into a clean 3D asset kit.

VISUAL DIRECTION

Use charcoal and blue-black masonry, wet dark iron, damp peat brown, deep moss and algae green, patched timber, worn cloth, and restrained tarnished bronze for important institutional or ceremonial details. Magic and the Wound use violet, cyan, and pale bone-white only as small local accents. Occasional ember red-orange may punctuate the palette. Keep the overall image desaturated, with deliberate highlights and enough midtone separation to read the paths and actors.

Use atmospheric directional light, wet sheen, rust, moss, and paint-like surface shading. Darkness must not hide navigation or interactions. Avoid pure-black sticker outlines, broad neon glow, heavy bloom, flat lighting, and indiscriminate fog. Characters and terrain must look painted in the same world.

CHARACTERS AND CONTINUITY

Use Vex the Unbowed as the consistent example protagonist: an adult Ash-Bound Kes'reth with a dense, combat-trained silhouette, swept horns, practical repaired dark road armor, layered ash cloth, iron fittings, and restrained cinder-ink markings. Keep the sealed cinder-ink line near the throat, collar, or sternum consistent where visible. Vex looks controlled, skeptical, and worn by experience. Use the approved Vex artwork as the identity reference when available. This example does not imply that character creation is locked to Vex.

Show a four-person example party in the exploration and combat views, within the ratified 4–6 party direction. Use existing companion reference art and identities from the art brief; preserve their proportions, silhouettes, equipment, and portrait order. Do not invent named companions or new species. Unfixed appearances remain concept proposals.

INTERFACE AND PRESENTATION

Propose a restrained interface that belongs to a world of stone, iron, records, and worn ceremonial bronze. Use dark slate surfaces, pale readable lettering, fine bronze separators, clear focus states, and small functional icons. Keep decorative texture behind text subdued. This interface treatment is a proposal within the existing aesthetic, not a newly ratified layout.

Keep party portraits and the Soul indicator in consistent positions across gameplay views. Clearly distinguish Soul from health, action points, and the combat Order–Chaos Balance Gauge. Use text or shape as well as color for selection, costs, and warnings. Short labels must read at ordinary screen size. Avoid paragraphs of generated text; put longer explanatory notes in the accompanying document.

The world should occupy most of each frame. Reserve useful screen space for movement, targets, and dialogue. No operating-system chrome, debug panels, implementation terminology, or ornamental frames that overpower the scene. Any displayed amounts, costs, or dialogue lines are illustrative mockup values, not approved balance or script changes.

## Screen 1 — Dom: a functioning city under strain

**Filename:** `01-dom-exploration.png`

Show the party entering a maintained storm-port neighborhood in Dom, the City of the Four Arms. Use dark stone paving, shallow drainage channels, wet iron, repaired timber, puddles, and occasional worn bronze inlay. Include the Four Arms tavern's recognizable four-limbed sign, a road commission board or marshal's post, and a route deeper into the neighborhood. Keep signage symbolic rather than filling the world with floating text.

Place an official at a practical work station and residents carrying out ordinary tasks. Institutional order and encroaching moss should coexist. Give the party, doorways, and paths breathing room; do not fill the street with crates to manufacture detail.

Show a compact party strip, a clearly labeled **Soul** gauge, a small objective card reading **Road commission**, and a contextual **Inspect** prompt near the board. A nearby interactable object may suggest field skills without inventing an unconfirmed skill name, lock difficulty, or loot reward. Keep the exploration grid hidden.

**Development question:** Can the player identify their party, the immediate interaction, and the onward route at a glance?

## Screen 2 — Loamroot Grove: a conversation with consequences

**Filename:** `02-loamroot-dialogue.png`

Show Vex speaking with Iris Illepah beside her overgrown work shelter in Loamroot Grove. Retain the isometric playable world behind the dialogue interface; use a close portrait bust within the panel rather than changing the whole scene to a cinematic camera.

Use wet loam, root-split ground, pale loamroot beds, shallow water, and a low moss overhang. Iris's proposed art-brief appearance includes a moss-green wrap, capable hands, and root-braided hair. Her exact race is not established; do not add species labels. The grove feels fertile and quietly sentient, not like a cheerful flower-farming village.

Show Iris's name, a readable portrait, and three brief illustrative responses: **Tell me what happened**, **I'll help**, and **Not yet**. Keep the Soul gauge visible. Do not mark these invented lines with exact deductions or skill requirements. Let the player's pause, Iris's expression, and the surrounding decay convey the weight of agreement.

**Development question:** Can the player read the speaker, choices, and Soul state while still understanding where the conversation is happening?

## Screen 3 — Dorthkor Road: tactical combat in the same place

**Filename:** `03-dorthkor-same-map-combat.png`

Show turn-based combat on Dorthkor Memorial Road: maintained military paving, memorial stones with repeated company marks, wet shoulders, a broken road drum, and localized breach damage. Use existing encounter identities or supplied enemy references; do not invent named enemies or faction combinations as canon.

The fight takes place directly on the traversable field map. Preserve the exploration camera and party scale. Show a local isometric movement overlay conforming to the 64×32 ground-cell geometry, a selected actor, a short movement preview, reachable cells, a clear target, and physically believable obstacles. Avoid a separate floating arena or an ambient-fight deployment screen.

Keep the visible encounter small enough to assess. The ratified large-map hostile population target does not require showing approximately 100 enemies in this frame.

Use a compact turn-order strip, selected-actor health and AP, and short action labels such as **Move**, **Attack**, **Speak**, and **End turn**. Give the **Order — Chaos** Balance Gauge its own identity and location, visibly separate from **Soul**. A selected Definition or Paradox action may show an illustrative Soul-cost preview and a restrained directional Balance preview; label those values as examples in the accompanying notes. Do not imply that every mundane action spends Soul.

**Development question:** Can the player distinguish movement, turn resources, personal Soul expenditure, and battlefield Balance without opening a tooltip?

## Screen 4 — Jawbrace: hollowing without a game-over

**Filename:** `04-jawbrace-hollowing.png`

Show the same party paused at the first ledge of the Jawbrace, a wound in reality treated like a military worksite. Include retaining braces, fractured dark stone, warning plates, ash markings, a chain or hammer post, and a distant sealed descent. Keep the void localized and navigable edges unmistakable; avoid making the whole view a glowing portal.

Show Vex standing and controllable with **Soul 0** and a clear **Hollowed** state label. Keep health distinct and nonempty. Communicate diminished presence with restrained changes in posture, reflected light, and companion attention, not a corpse, ghost transformation, or invented new anatomy.

A compact interaction panel may contain one unavailable response labeled **Unavailable while hollowed** and an ordinary usable response labeled **Continue**. This is proposed state-display copy, not a new dialogue branch. Leave the route and other interactions visible. No defeat banner, forced reload, rest-to-refill prompt, or Soul potion.

The accompanying note must explain the ratified rule: empty Soul is recoverable hollowing, not death; Soul returns only through acts of Agreement, not resting or drinking potions. Do not invent the specific recovery quest or price.

**Development question:** Does the frame communicate a serious, playable consequence instead of game-over or ordinary low health?

## Optional follow-up — the Mirror Shop

After the core four views, a separate `05-mirror-shop.png` may explore the chapter-end carry-over screen. Use a restrained mirror-and-ledger presentation, a **Style Points** balance, and a short set of documented carry-over options such as retaining a signature item. Make the transaction currency unmistakably different from Soul. Use no invented prices or finalized multipliers. The Mirror Shop is a documented progression concept; this brief does not certify its current implementation or promote it into a normal town merchant.

## Exclude from every image

Cozy farming-game aesthetics, copied franchise characters or interfaces, chibi proportions, photorealistic faces, pixel-art treatment, flat vector assets, pristine medieval storybook towns, dominant steampunk machinery, third-person 3D exploration, strategic hex maps, empire dashboards, separate arenas for ambient combat, giant glowing Soul orbs, excessive particles, gore used as the main selling point, and illegible walls of invented lore.

Do not reproduce the Loam Lantern image composition as Soul-Meter's art direction. Do not depict Soul zero as death, Soul recovery through rest or consumables, old six-stat/SPECIAL character sheets as the current target, or the Mirror Shop spending Soul. Do not interpret this screenshot task as permission to produce or import production sprites. The art bible's transparent 256×256 single-asset delivery rules apply to asset production, not these full-screen concepts.

## Acceptance checks

1. **One game:** the four views share cast identity, scale, painterly materials, lighting logic, and interface language; the overview preserves that continuity.
2. **Playable composition:** paths, selected actors, interactions, and targets remain readable; interface panels leave meaningful world space. Check each full image and a 50% preview.
3. **Correct mechanics:** same-map tactical combat; distinct Soul, health, AP, and Balance; hollowing at zero without death; no unsupported recovery mechanic.
4. **Honest presentation:** every image is identified as a concept in its caption or filename context; invented UI copy, values, and appearance details are marked as proposals. No claims of runtime verification.
5. **Useful handoff:** output files, actual prompts, references used, and visible defects are recorded. Each screen's note answers its development question and names one implementation implication without creating new requirements.

## Grounding and precedence

- [Game identity](../game-identity.md) — ratified 2026-09-02; controlling gameplay direction, including soul-as-currency, hollowing, Agreement-only recovery, party scale, same-map combat, and DRAMGID. Takes precedence over conflicting older descriptions.
- [Art aesthetics bible](../art-aesthetics-bible.md) — ratified painterly style, palette, approved Vex/Bog Wight/Dom calibration references, and readable field dressing.
- [Art request](../../art-request.md) — character and location briefs, including Vex, Iris, Dom, Dorthkor Road, Loamroot Grove, and Jawbrace. Historical placeholder-status claims are not evidence of the current build.
- [Chapter-one PRD](../prd-chapter-one.md) — Balance Gauge, speech in combat, permanent consequences, and Mirror Shop/Style Points. Its older zones-only combat description is superseded by the game identity rulings.
- [Core design document](../../soul-meter-crpg-design-doc.md) — broader fiction and gameplay context, subordinate to newer ratified rulings where they conflict.

This instruction sheet was grounded in repository documents. No game runtime or concept image was generated or tested while drafting it. Approval of a concept image remains separate from approval to implement a layout or change the game's design.
