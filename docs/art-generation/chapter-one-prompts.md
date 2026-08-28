# Chapter One image-generation prompts

Generated with OpenAI image generation on 2026-08-27, following
`docs/art-aesthetics-bible.md`. Keep these prompts with the production assets so
later expression and environment variants can preserve their visual families.

## Dorthkor Road combat battlefield

- Production asset: `res://assets/generated/backgrounds/combat/dorthkor-road-battlefield-v1.png`
- Full-resolution source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-1f7030c5-a150-45db-9ecd-129b8bc2270a.png`

```text
Use case: stylized-concept
Asset type: 2D CRPG combat battlefield background for Soul Meter
Primary request: Dorthkor Road, a broken military road across storm-dark highland ground, prepared as a reusable tactical-combat backdrop
Scene/backdrop: cracked wet iron-and-stone road crossing a bleak chasm-side worksite; damaged muster posts, a silent road drum, chain anchors, sparse wind-bent scrub, distant broken escarpment and rain haze
Subject: environment only, with a broad uncluttered central fighting area large enough for an isometric tactical grid; environmental landmarks remain toward the outer edges
Style/medium: semi-realistic painterly digital dark-fantasy game art, rich worn materials and readable silhouettes, matching hand-painted CRPG sprites rather than pixel art, vector art, or clean 3D-kit rendering
Composition/framing: wide 16:9 landscape, elevated three-quarter/isometric-adjacent view; open center; foreground and side framing; no baked grid
Lighting/mood: dramatic cold directional storm light, restrained warm bronze accents at one damaged road signal, dark vignette, damp and militarized rather than generic wilderness
Color palette: charcoal stone, blue-black iron, damp peat brown, desaturated moss green, tarnished bronze, very restrained violet-cyan Wound accents
Materials/textures: wet stone, rust, scarred timber, heavy chain, moss, shallow puddles, eroded road edges
Constraints: environment only; no people, creatures, UI, text, labels, logos, trademarks, or watermark; no bright all-over magic glow; no obvious central focal object; preserve clear contrast behind overlaid combat units and grid lines
```

## Marshal Branek Coiljaw neutral dialogue portrait

- Production asset: `res://assets/generated/portraits/marshal_coiljaw_portrait_neutral.png`
- Full-resolution source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-15b2c608-8296-4ff0-9cdd-9cc6b23371ed.png`
- Style references: `res://assets/generated/sprites/units/vex/vex--idle--se--f00.png` and `res://assets/generated/sprites/units/gnaal-breach-hound/gnaal-breach-hound--idle--se--f00.png`

```text
Use case: stylized-concept
Asset type: transparent-background dialogue portrait for the 2D dark-fantasy CRPG Soul Meter
Primary request: Marshal Branek Coiljaw, neutral/listening expression, Chapter One's Dom road marshal and East Arm bench-holder
Character: clearly adult, early 50s visual target; broad, heavy, square, stable silhouette; weathered face; powerful distinctive jawline crossed by a functional old iron-and-bone jaw brace over one cheek and lower jaw; subtle old road-breach scar through one brow; ancestry intentionally visually noncommittal and near-human because canon has not ratified a race
Costume and props: storm-port military coat, layered worn iron plates, weathered bronze fasteners; rolled road-commission papers tucked at the chest; short drum marshal's baton visible near one shoulder as an authority symbol
Expression and read: blunt, watchful, command-fatigued; capable of grief without losing military control; neutral/listening, mouth closed, direct but not aggressive
Style/medium: semi-realistic painterly digital dark-fantasy game portrait, rich worn-material rendering, restrained brushwork matching a premium classic CRPG talking-head portrait; not pixel art, not flat vector, not clean 3D rendering
Composition/framing: square 1:1 bust or upper torso, three-quarter view, face and jaw brace fully readable; entire face and signature props inside a safe central 80% crop; transparent background with only a very subtle dark painterly edge vignette attached to the silhouette
Lighting/mood: one cold directional storm key light from upper left, dark falloff, restrained warm bronze bounce on fasteners; sober institutional authority
Palette: charcoal, blue-black iron, damp leather brown, bone-white paper, tarnished bronze, restrained muted red-brown; no bright generic fantasy saturation
Constraints: one character only; transparent background; no text, letters, insignia words, UI, frame, logo, trademark, or watermark; no large spell effects; no steampunk goggles or machinery; no crown; no cartoon/chibi proportions; no pure-black outline; avoid locking in non-human ancestry traits
Output intent: production-ready 512×512 dialogue portrait named marshal_coiljaw_portrait_neutral.png
```

## Iris Illepah neutral dialogue portrait

- Production asset: `res://assets/generated/portraits/iris_illepah_portrait_neutral.png`
- Initial full-resolution source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-9c83153b-6544-4463-ba41-d40a55fb3269.png`
- First background-extraction source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-199d110b-da3d-4628-8439-6546ca8ec3ff.png`
- Final background-extraction source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-f8c71488-f22b-40e3-9d0a-d90de91df956.png`
- Style references: `res://assets/generated/portraits/marshal_coiljaw_portrait_neutral.png` and `res://assets/generated/sprites/units/bog-wight/bog-wight--idle--se--f00.png`
- Alpha note: all three generated sources contained a painted checkerboard rather than
  real alpha. The production asset was therefore isolated from the final source with an
  edge-connected neutral-background mask in Godot, resized to 512×512, and verified with
  `Image.detect_alpha() == Image.ALPHA_BLEND`.

Initial generation prompt:

```text
Use case: stylized-concept
Asset type: transparent-background dialogue portrait for the 2D dark-fantasy CRPG Soul Meter
Primary request: Iris Illepah, neutral/listening expression, Loamgate Ssae-Seeder cultivator and keeper of the grove overhang
Input images: Image 1 is the approved Soul Meter dialogue-portrait style reference; Image 2 is an approved organic-corruption unit-art palette reference
Character: clearly adult, late-40s to early-50s visual target; canonical Weftkin (Sporeborn) and Husk-bearer, presented as a lean near-human woman with restrained sporeborn traits rather than invented anatomy; grounded posture, slightly stooped from years of tending living growth; capable hands partially visible
Face and hair: one side of the face carries fine pale yellow-green root-like tracery, beautiful at first glance but subtly invasive; a few loamroot fibers braided into dark weathered hair; no flowers, antlers, elf ears, or mushroom-cap head
Costume and props: layered practical field robes, weatherproof moss-green wrap, damp repaired hems, plant-fiber stitching, woven pouches holding roots, seed, bread, and one small hand tool
Expression and read: patient and faintly amused, never entirely reassuring; neutral/listening, mouth closed, attentive eyes
Style/medium: semi-realistic painterly digital dark-fantasy game portrait, rich worn-material rendering and restrained brushwork matching the provided approved CRPG portrait reference; not pixel art, flat vector, anime, or clean 3D rendering
Composition/framing: square 1:1 bust or upper torso, three-quarter view; face, hands, tracery, and one seed pouch readable; all important features inside a safe central 80% crop for a compact dialogue frame
Scene/backdrop: genuinely transparent background with only a subtle dark painterly edge falloff attached to the silhouette
Lighting/mood: one cold directional key light from upper left with dark falloff; muted living yellow-green reflected light along the root tracery; damp, intimate, and slightly uncanny
Color palette: charcoal and wet-loam brown, bruised gray, weathered moss green, plant-fiber beige, muted Molm yellow-green accents; no broad bright color
Materials/textures: damp woven cloth, repaired plant fiber, weathered skin, fine roots, seed husks
Constraints: one character only; preserve transparent alpha; no text, letters, UI frame, logo, trademark, or watermark; no large magical aura; no steampunk machinery; no generic druid glamour; no crown; no cartoon/chibi proportions; no pure-black outline; do not invent additional Weftkin anatomy or ancestry lore
Output intent: production-ready neutral Iris Illepah dialogue portrait, later resized to 512×512 as iris_illepah_portrait_neutral.png
```

First background-extraction prompt:

```text
Use case: background-extraction
Asset type: production game dialogue portrait cutout
Input images: Image 1 is the edit target
Primary request: remove only the gray-and-white checkerboard background and replace it with genuine transparent alpha
Subject invariants: preserve Iris Illepah exactly as shown—same face, age, expression, gaze, hair, root tracery, clothing, hands, seed-and-bread pouch, hand tool, pose, scale, crop, painterly detail, colors, and lighting
Edge treatment: retain the existing soft painterly silhouette edge and all fine hair/root fibers; no white halo, gray fringe, checker pattern, matte rectangle, shadow plane, or replacement backdrop
Constraints: change only the background pixels; output a genuinely transparent PNG with alpha; do not redraw, restyle, recolor, crop, resize, add, remove, or reposition the character; no text, UI, frame, logo, or watermark
```

Final background-extraction prompt:

```text
Use case: background-extraction
Asset type: production game dialogue portrait cutout
Input images: Image 1 is the sole edit target
Primary request: isolate the existing character pixels from the visible light-gray checkerboard. Delete every checkerboard square and every background pixel to alpha 0. The output PNG must contain a real RGBA alpha channel, with transparent pixels around the silhouette—not a drawn transparency grid and not an opaque white, gray, black, or colored canvas.
Character lock: preserve Iris Illepah exactly as in Image 1—same face, age, expression, gaze, hair, root tracery, clothing, hands, pouch, hand tool, pose, scale, crop, painterly detail, colors, and lighting.
Edge treatment: keep fine hair and root fibers with antialiased partially transparent edge pixels; remove light-gray/white fringe and matte contamination.
Verification intent: when opened without a transparency-grid viewer, there must be no checkerboard pattern in the image data; corner pixels must have alpha 0.
Constraints: background removal only. Do not redraw, restyle, recolor, crop, resize, add, remove, or reposition the character. No backdrop, checkerboard, shadow plane, text, UI, frame, logo, or watermark.
```

## Sella Varn neutral dialogue portrait

- Production asset: `res://assets/generated/portraits/sella_varn_portrait_neutral.png`
- Full-resolution source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-13c21b7e-982f-4d8e-808e-3898f43afa6b.png`
- Alpha note: the generated source contained genuine alpha and was resized to 512×512
  with Lanczos interpolation. The production asset verifies as
  `Image.ALPHA_BLEND`.

```text
Use case: stylized-concept
Asset type: dialogue portrait for the 2D dark-fantasy CRPG Soul Meter
Primary request: Sella Varn, neutral/listening expression, Dom South Arm bell warden and Trial Council servant responsible for the district bell that has become warm and refuses its rope
Character: clearly adult woman, exact age and ancestry intentionally visually noncommittal because canon has not ratified them; compact, upright, work-hardened silhouette; steady harbor-road authority rather than aristocratic command
Face and hair: weathered from salt air and bronze dust; dark practical hair bound away from the bell rope; alert eyes; one small old rope-burn scar across a palm or wrist, no invented non-human anatomy
Costume and props: layered charcoal bell-warden coat over practical work clothes, tarnished bronze throat guard and fasteners, heavy leather rope gloves tucked at belt, short striker-key and one loop of dark bell cord; subtle Trial Council geometry without readable insignia or words
Expression and read: disciplined, suspicious of easy explanations, carrying embarrassment imposed by the Registry but refusing defeat; mouth closed, direct attentive gaze
Style/medium: semi-realistic painterly digital dark-fantasy game portrait, rich worn materials and restrained brushwork matching premium classic CRPG talking-head art; not pixel art, flat vector, anime, or clean 3D rendering
Composition/framing: square 1:1 bust or upper torso, three-quarter view; face, bronze guard, rope glove, and striker-key readable; all important features inside a safe central 80% crop for a compact dialogue frame
Scene/backdrop: flat uniform deep charcoal-gray background with no checkerboard, no pattern, no scenery, no halo, and no cast shadow; subject silhouette clearly separated for later background isolation
Lighting/mood: cold directional harbor light from upper left; restrained warm bronze bounce from the unseen silent bell; sober, institutional, rain-damp
Color palette: charcoal, blue-black iron, damp brown leather, tarnished bell bronze, muted storm gray, very restrained Strom blue-violet accent
Materials/textures: salt-stiff wool, worn leather, warm patinated bronze, dark rope fiber, weathered skin
Constraints: one character only; no text, letters, UI frame, logo, trademark, or watermark; no large magical aura; no steampunk machinery; no crown; no generic priest glamour; no cartoon/chibi proportions; no pure-black outline; do not invent ancestry traits or additional lore
Output intent: production-ready neutral Sella Varn dialogue portrait, later isolated and resized to 512×512 as sella_varn_portrait_neutral.png
```

## Hadrik Vale neutral dialogue portrait

- Production asset: `res://assets/generated/portraits/hadrik_vale_portrait_neutral.png`
- Initial full-resolution source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-e41f4d42-e70b-4bb6-9e58-7aeff6aaeff3.png`
- Background-extraction source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-b51b021e-f8a7-488f-ad15-b2fb55d97e62.png`
- Alpha note: the extraction source contained a painted checkerboard. The production
  asset was isolated with the same edge-connected neutral-background mask used for Iris,
  resized to 512×512, and verified as `Image.ALPHA_BLEND`.

Initial generation prompt:

```text
Use case: stylized-concept
Asset type: dialogue portrait for the 2D dark-fantasy CRPG Soul Meter
Primary request: Hadrik Vale, neutral/listening expression, Registry Archive clerk of Dom's North Arm who preserves disputed road records and investigates a sealed register that returned with rain inside it
Character: clearly adult man, exact age and ancestry intentionally visually noncommittal because canon has not ratified them; lean, contained posture shaped by years at tall archive desks; careful hands and a quiet civil servant's authority
Face and hair: narrow weathered face, observant tired eyes, dark hair threaded with restrained gray and tied back practically; faint ink stains on fingertips and one old paper-cut scar; no invented non-human anatomy
Costume and props: layered charcoal archive coat with waterproof shoulder cape, waxed seams, tarnished silver clasps, narrow leather document harness, one sealed rain-warped ledger held against the chest, small bundle of registration tags without readable text
Expression and read: precise, humane beneath institutional restraint, suspicious of clean closure; mouth closed, attentive gaze, the look of someone who knows that erased names still matter
Style/medium: semi-realistic painterly digital dark-fantasy game portrait, rich worn materials and restrained brushwork matching premium classic CRPG talking-head art; not pixel art, flat vector, anime, or clean 3D rendering
Composition/framing: square 1:1 bust or upper torso, three-quarter view; face, inked hand, warped ledger, wax seal, and clasps readable; all important features inside a safe central 80% crop for a compact dialogue frame
Scene/backdrop: flat uniform deep charcoal-gray background with no checkerboard, pattern, scenery, halo, or cast shadow; subject silhouette clearly separated for later background isolation
Lighting/mood: cool diffuse archive-window light from upper left; restrained pale Nul silver reflection along the wet ledger edge; dry room, impossible rain, subdued unease
Color palette: charcoal, rain-dark brown leather, bruised paper beige, tarnished silver, sealing-wax black-red, restrained Nul gray-white accents
Materials/textures: waxed wool, damp warped paper, cracked leather, oxidized silver, ink-stained skin
Constraints: one character only; no readable text, letters, UI frame, logo, trademark, or watermark; no large magical aura; no steampunk machinery; no crown; no generic wizard robes; no cartoon/chibi proportions; no pure-black outline; do not invent ancestry traits or additional lore
Output intent: production-ready neutral Hadrik Vale dialogue portrait, later isolated and resized to 512×512 as hadrik_vale_portrait_neutral.png
```

Background-extraction prompt:

```text
Use case: background-extraction
Asset type: production game dialogue portrait cutout
Input images: Image 1 is the sole edit target
Primary request: remove the entire charcoal-gray background from Image 1 and replace it with genuine transparent alpha
Subject invariants: preserve Hadrik Vale exactly as shown—same face, age, expression, gaze, hair, coat, wet ledger, seal, inked fingers, registration tags, pose, scale, crop, painterly detail, colors, and lighting
Edge treatment: retain fine hair, coat edges, paper fibers, and all antialiased silhouette detail; no gray halo, checkerboard pixels, matte rectangle, shadow plane, or replacement backdrop
Verification intent: corner pixels must have alpha 0 and the PNG must contain a real RGBA alpha channel, not an illustration of transparency
Constraints: background removal only; do not redraw, restyle, recolor, crop, resize, add, remove, or reposition Hadrik; no text, UI, frame, logo, or watermark
```

## Toma Reedhand neutral dialogue portrait

- Production asset: `res://assets/generated/portraits/toma_reedhand_portrait_neutral.png`
- Full-resolution source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-2bed9481-d67d-4c06-9710-07d7bf74a43e.png`
- Alpha note: the generated source contained genuine alpha and was resized to 512×512
  with Lanczos interpolation. The production asset verifies as
  `Image.ALPHA_BLEND`.

```text
Use case: stylized-concept
Asset type: dialogue portrait for the 2D dark-fantasy CRPG Soul Meter
Primary request: Toma Reedhand, neutral/listening expression, Dom West Arm dockhand and keeper of the River Shrine who tracks missing Drownedmouth tide-chain offerings
Character: clearly adult with an androgynous, work-hardened presentation; exact age, gender identity, and ancestry intentionally visually noncommittal because canon has not ratified them; sturdy shoulders, grounded dockworker posture, capable hands
Face and hair: salt-weathered face, calm watchful eyes, dark cropped or tightly bound practical hair, rain and harbor spray on the skin; no invented non-human anatomy
Costume and props: layered dock coat of tar-dark canvas over shrine-keeper wraps, weathered rope belt, small river offering tokens, one heavy tide-chain link, and reed-fiber hand wraps that explain the Reedhand silhouette without implying transformed anatomy
Expression and read: dryly compassionate, respectful of the river without theatrical piety, accustomed to hard labor and other people's promises; mouth closed, attentive gaze
Style/medium: semi-realistic painterly digital dark-fantasy game portrait, rich worn materials and restrained brushwork matching premium classic CRPG talking-head art; not pixel art, flat vector, anime, or clean 3D rendering
Composition/framing: square 1:1 bust or upper torso, three-quarter view; face, wrapped hand, tide-chain link, and offering token readable; all important features inside a safe central 80% crop for a compact dialogue frame
Scene/backdrop: flat uniform deep charcoal-gray background with no checkerboard, pattern, scenery, halo, or cast shadow; subject silhouette clearly separated for later background isolation
Lighting/mood: cold river light from upper left with damp falloff; restrained Aqua blue-green reflection along the chain and wet canvas; harbor rain, quiet shrine, practical reverence
Color palette: charcoal, tar black, wet leather brown, river-stone gray, oxidized chain iron, reed beige, restrained Aqua blue-green accents
Materials/textures: salt-stiff canvas, wet rope, plant-fiber wraps, oxidized iron, smooth offering stone, weathered skin
Constraints: one character only; no readable text, letters, UI frame, logo, trademark, or watermark; no large magical aura; no steampunk machinery; no crown; no generic cleric vestments; no cartoon/chibi proportions; no pure-black outline; do not invent ancestry traits, transformed hands, or additional lore
Output intent: production-ready neutral Toma Reedhand dialogue portrait, later isolated and resized to 512×512 as toma_reedhand_portrait_neutral.png
```

## Loamroot Wilds full-map terrain

- Production asset: `res://assets/generated/backgrounds/world/loamroot-wilds-terrain-v1.png`
- Full-resolution source: `/home/adamjroder/.codex/generated_images/01a045c9-981b-7af0-a53a-c2eb19ac5ce7/exec-0cd3ddad-7595-4123-9b31-ea562e4d5aea.png`
- Runtime use: `res://world/test_room.tscn`, beneath the existing navigation,
  encounter, quest, NPC, pickup, and authored Loamroot prop nodes.
- Processing: resized to exactly 2000×1200 with Lanczos interpolation. The
  legacy 64×32 isometric blockout tile layer remains available but hidden.

```text
Use case: stylized-concept
Asset type: seamless full-map terrain backdrop for the 2D dark-fantasy CRPG Soul Meter
Primary request: Loamroot Wilds terrain plate, a damp overgrown field outside Dom that supports exploration, the Loamroot grove, a bog-wight encounter, and a small stone-circle site
Scene/backdrop: environment terrain only; broad traversable wet-loam clearing across the center; a worn diagonal footpath entering from the west and bending toward the eastern grove; darker root-veined soil and moss toward the east; shallow bog-dark ground toward the south; scattered flat stones and restrained dead grass toward the southwest; dense shadowed treeline suggested only along the far northern edge
Subject: ground plane and low terrain detail only, designed to sit underneath separate character, tree, root-arch, rock, mushroom, and encounter sprites
Style/medium: semi-realistic painterly digital dark-fantasy game environment, classic late-1990s isometric CRPG readability with richer modern material detail; hand-painted rather than pixel art, vector art, or clean 3D rendering
Composition/framing: wide 5:3 landscape, elevated near-isometric ground view; entire image reads as one continuous navigable map; open center and clear west-to-east route; terrain variation uses broad irregular patches rather than repeated tiles; no horizon and no sky
Lighting/mood: cold overcast daylight, rain-damp, low contrast beneath future character sprites, restrained green-gold bioluminescent hints only near the eastern root veins
Color palette: wet umber, dark peat, desaturated moss and lichen green, charcoal mud, muted reed beige, sparse sickly yellow-green root accents
Materials/textures: churned loam, wet moss, shallow puddles, embedded flat stone, root fibers, trampled grass, leaf litter
Gameplay readability: preserve clear walkable negative space around the central 65% of the map; avoid high-contrast detail behind future units; terrain patches should guide movement without looking like a baked tactical grid
Constraints: environment terrain only; no people, creatures, buildings, large trees, standing roots, large rocks, UI, text, labels, logos, trademarks, watermark, borders, checkerboard, grid lines, repeated diamond tiles, or obvious repeating pattern; no bright all-over magic glow
Output intent: production terrain plate later cropped/resized to exactly 2000×1200 as loamroot-wilds-terrain-v1.png, placed under existing Wilds props and gameplay nodes
```
