# Soul Meter — Art Request Handoff

This document is the art-production brief for the current playable prototype. It is
intentionally tied to the scenes, dialogue, party roster, encounters, and item data that
already exist in the project. The current build uses colored rectangles, initials, a
graybox isometric atlas, and a Kenney placeholder spritesheet. These requests replace
those placeholders without changing the gameplay data model.

## Creative direction

Soul Meter is a mature-fantasy, dialogue-and-consequence-first 2D RPG set in Dramgid.
The visual language should feel carved, ledgered, and slightly wrong: old stone,
tarnished bronze, damp organic growth, institutional markings, and small impossible
details caused by the Waning. Avoid bright generic high fantasy, clean medieval
storybook shapes, or steampunk machinery as the dominant read.

The game is viewed from a top-down/isometric field camera, while dialogue uses close
portrait busts. The world should communicate that civilization is still functioning
inside a metaphysical emergency: roads are maintained, uniforms have rules, ledgers and
signs are practical, but moss grows through masonry and empty armor can remember names.

### Palette and material cues

- Base surfaces: charcoal void, blue-black stone, bruised gray, wet loam, and ash.
- Institutional metal: iron and tarnished bronze; bronze is reserved for important
  ceremonial or ledger elements.
- Magic and the Wound: restrained violet, cyan, and pale bone-white, used as local
  accents rather than an all-over glow.
- Organic life: deep moss, yellow-green Bloom growth, river blue, peat brown, and
  occasional red-orange demon heat.
- Keep highlights readable against the dark field. Avoid pure black outlines that make
  every asset look like a cartoon sticker.

### Technical delivery defaults

Unless a request below overrides it, deliver:

- layered source file in the artist's native format;
- transparent PNG export with the requested naming convention;
- sRGB color profile;
- no baked text, names, faction labels, or UI frames in character art;
- clean silhouette at the final in-game size, with a larger export for future scaling;
- a one-line content note for anything that depicts body horror, death, or demonic
  transformation.

The existing world code uses 64×32 isometric cells (`world/isometric_blockout.gd`) and
currently samples 16×16 regions from a placeholder character sheet, scaled up in the
field. A replacement field set can use a more expressive native resolution, but the
final atlas must preserve a stable 64×32 ground-cell seam and the character sprite
footprints must remain legible when displayed at roughly 3–4× pixel scale.

## Priority summary

| Priority | Deliverable | Why it is needed |
| --- | --- | --- |
| P0 | Dialogue portraits for Iris Illepah and Marshal Coiljaw | These are the two named speakers in the current field dialogue loop. |
| P0 | Vex and core companion portraits | The tavern, party, chapter-complete, and dialogue-adjacent UI need a consistent cast identity. |
| P0 | Field character/enemy sprite replacement set | Every current world scene still shows placeholder sprites or colored blocks. |
| P1 | Dom, Dorthkor Road, Loamroot Grove, and Jawbrace environment sets | These are the four playable locations in the current chapter path. |
| P1 | Core item icons | Inventory currently contains seven authored item types and needs readable visual identity. |
| P1 | Dialogue presentation accents and title mark | These replace the remaining blockout treatment in the UI without changing layout code. |
| P2 | Combat backgrounds, effect frames, and extended NPC/environment set | Useful for polish and the next content pass; not required to validate the current loop. |

## 1. Named character portraits

### Portrait format

Request one portrait per person at **512×512 px**, transparent background, bust or upper
torso, 3/4 view, face and one signature prop visible. Keep the face inside a safe 400×400
center crop because the dialogue balloon can display portraits in a compact square frame.
Provide these expression variants for each named dialogue speaker: neutral/listening,
speaking, concerned or angry. For companions, neutral plus one class-defining expression
is sufficient for the first pass.

The project has not canonically fixed numeric ages for most characters. The age ranges
below are visual targets for the art brief, not a request to add new lore. Keep the
characters clearly adult, with age communicated through face, posture, and wear rather
than exaggerated wrinkles.

### Vex the Unbowed — protagonist

- **Race:** Ash-Bound Kes'reth.
- **Age target:** late 30s to early 40s.
- **Role:** Ironbrand (Kero), horned reaver and player character.
- **Build and silhouette:** tall, dense, combat-trained; swept horns and a strong
  shoulder silhouette. Do not make the horns ornamental deer antlers; they should feel
  like part of a living, heat-scarred anatomy.
- **Clothing:** practical dark road armor, layered ash cloth, iron fittings, and visible
  cinder-ink markings. The kit should look repaired repeatedly rather than pristine.
- **Unique trait:** a sealed line of cinder-ink across the throat, collar, or sternum;
  it visibly resists fading and is the first clue that Vex's soul is unusually held.
- **Expression:** controlled, skeptical, tired without looking passive. Vex should read as
  someone who measures every promise before accepting it.
- **Attunement cue:** restrained ember/bronze; avoid a large magical aura.
- **Files:** `vex_portrait_neutral.png`, `vex_portrait_speaking.png`,
  `vex_field_sheet.png`.

### Iris Illepah — Loamroot Grove speaker

- **Race:** source text names Iris but does not specify a race; proposed visual target is
  a **Bloom-touched human or near-human**, pending narrative confirmation.
- **Age target:** late 40s to early 50s.
- **Role:** Ssae-Seeder of the Groves; caretaker of the Loamroot Grove.
- **Build and silhouette:** lean, grounded, and slightly stooped from years of tending
  living growth. Hands should be prominent and capable.
- **Clothing:** layered field robes and a weatherproof moss-green wrap; pockets or woven
  pouches for roots, seed, bread, and small tools. The garments should be damp at the
  hem and repaired with plant fiber.
- **Unique trait:** one side of the face carries fine root-like pale-green tracery that
  is beautiful at first glance but clearly invasive on closer inspection. A few loamroot
  fibers should be braided into her hair.
- **Expression:** patient, amused, and never entirely reassuring. Speaking variant may
  show a small smile that does not reach the eyes.
- **Attunement cue:** Molm, using the coded muted yellow-green ring language.
- **Files:** `iris_illepah_portrait_neutral.png`, `iris_illepah_portrait_speaking.png`,
  `iris_illepah_portrait_concerned.png`, `iris_illepah_field_sheet.png`.

### Marshal Coiljaw — Dom speaker

- **Race:** source text names Coiljaw but does not specify a race; proposed visual target
  is a **broad, adult Kaan or Kes'reth military officer**, pending narrative confirmation.
- **Age target:** early 50s.
- **Role:** Marshal of Dom; the official who assigns the Dorthkor road commission.
- **Build and silhouette:** heavy, square, and stable. The jawline should be the most
  recognizable feature, with an old metal or bone jaw brace that gives him his epithet.
- **Clothing:** storm-port military coat, layered iron plates, weathered bronze fasteners,
  road commission papers, and a drum or baton carried as an authority symbol.
- **Unique trait:** a visible jaw brace crossing one cheek or lower jaw, functional rather
  than decorative. One eye or brow may show old road-breach scarring.
- **Expression:** blunt, watchful, and carrying the fatigue of command. He should look
  capable of grief without losing military control.
- **Attunement cue:** neutral iron/bronze; no large spell effect.
- **Files:** `marshal_coiljaw_portrait_neutral.png`,
  `marshal_coiljaw_portrait_speaking.png`, `marshal_coiljaw_portrait_concerned.png`,
  `marshal_coiljaw_field_sheet.png`.

## 2. Tavern and party roster portraits

Use the same 512×512 portrait specification. These people appear in `ui/screens/tavern.gd`
and `ui/screens/party.gd`; their portraits should remain readable at a small card size.
Each needs a neutral portrait, one class-defining portrait, and a transparent field sprite.

### Serai-Lun

- **Race:** Mirror-Veil Kes'reth.
- **Age target:** late 20s to early 30s.
- **Role:** Mirrorblade (Maiiam); precise duelist.
- **Unique trait:** a narrow mirror shard or polished veil over one eye, reflecting a
  slightly different expression than the visible face. Keep this subtle and unsettling.
- **Costume and prop:** light duelist layers, segmented reflective plates, thin blade,
  and a sash that catches light like broken glass.
- **Read:** exact, elegant, dangerous, never bulky.

### Old Grumbrand

- **Race:** Kaan Deepkin.
- **Age target:** late 60s to early 70s.
- **Role:** Lensbearer (Stuid); salvage veteran and defensive anchor.
- **Unique trait:** a soot-stained salvage lens mounted over one eye with a faint internal
  cyan light. His hands and cuffs should carry years of machine grease and ash.
- **Costume and prop:** heavy patched coat, riveted harness, tool satchel, pry bar or
  compact salvage instrument.
- **Read:** durable, practical, kind only after checking whether something is trapped.

### Wyneth Hallow-Tide

- **Race:** Ghorr.
- **Age target:** mid 30s to early 40s.
- **Role:** River-Mother (Haeren); field healer.
- **Unique trait:** a pale tide-line birthmark or scar rising from the wrist to the neck,
  plus a small vial of living river water worn at the throat. The healer's hands should
  look deliberately steady.
- **Costume and prop:** layered blue-gray river coat, waxed cloth, reed or shell charms,
  bandage roll, bone needle, and a practical healer's satchel. Avoid a generic white
  fantasy cleric robe.
- **Expression:** calm, observant, quietly stubborn; compassionate without looking soft.
- **Attunement cue:** Aqua, suggested through river-blue glass and wet highlights.
- **Read:** the requested “river healer” identity should be instantly visible even in a
  small tavern card.

### Ressa Quickfingers

- **Race:** Vael.
- **Age target:** mid 20s.
- **Role:** Locksmirk (Fickah); fast opportunist and infiltrator.
- **Unique trait:** one hand is always palming a lockpick or coin, while a small split
  grin reveals a chipped tooth. Do not pose her as a generic assassin.
- **Costume and prop:** cropped travel jacket, many hidden pockets, soft boots, compact
  tool roll, and a ring of mismatched keys.
- **Read:** quick, fragile, alert to exits and other people's pockets.

### Korrath Ninefold

- **Race:** Orthos.
- **Age target:** early to mid 40s.
- **Role:** Ironbrand (Kero); renowned Steel Day bruiser.
- **Unique trait:** nine small ritual scars or metal studs arranged in a deliberate line
  across the brow or cheek, earned during the Steel Day tradition.
- **Costume and prop:** broad ironbrand harness, worn gauntlet, heavy striking weapon,
  and a ceremonial strip of red-black cloth.
- **Read:** physically imposing, disciplined, and proud rather than savage.

### Maura Greyfen

- **Race:** Snarlin.
- **Age target:** late 30s to late 40s.
- **Role:** Husk-bearer (Vhorr); Deep Salvage veteran.
- **Unique trait:** a grayfen-colored patch of fur or skin that has gone permanently pale
  around an old salvage wound; she wears a small sealed husk container as a trust token.
- **Costume and prop:** weatherproof salvage coat, rope harness, hooked tool, and sealed
  relic case. The clothing should look suited to climbing and extraction.
- **Read:** guarded, notorious, and competent enough to survive without an audience.

## 3. Field character and enemy sprite set

Deliver a unified **32×48 px or 48×64 px native sprite footprint**, transparent PNG, with
an atlas containing four cardinal directions, idle plus three walk frames per direction.
Keep a consistent ground contact point at the bottom center. Provide a 2× export if the
source is painted at a larger resolution. Small encounter art can use a larger 48×64 or
64×64 combat silhouette if it still reads next to the player.

### Friendly field sprites

- Vex: horned silhouette, cinder-ink chest/neck mark, heavy road stance, axe or sealed
  soul-weapon visible in profile.
- Iris: moss-green wrap, root-braided hair, root basket, deliberate slow posture.
- Marshal Coiljaw: broad coat, jaw brace, marshal's baton or road drum.
- Serai-Lun: reflective veil, thin blade, fast narrow silhouette.
- Old Grumbrand: large salvage lens, pack and tool, broad slow silhouette.
- Wyneth: river-blue coat, healer's satchel, small water vial.
- Ressa: cropped jacket, key ring, low quick stance.
- Korrath: heavy ironbrand harness, wide shoulders, striking weapon.
- Maura: grayfen salvage coat, rope harness, sealed husk case.

### Hostile and supernatural sprites

- **Bog Wight:** current scene `world/test_room.tscn`, encounter ID `bog-wight`. A drowned
  humanoid wrapped in peat and reed, with green bog-light behind a face that is not quite
  attached. Pose should feel waterlogged and resistant to gravity.
- **Loam-Maddened Boar:** current scene `world/test_room.tscn`, encounter ID `loam-boar`.
  Mud-caked boar with pale root growth erupting from the shoulders and jaw; the roots
  should look hungry, not like decorative vines.
- **Gnaal Breach-Hound:** current scene `world/dorthkor_road.tscn`, encounter ID
  `dorthkor-vanguard`. Lean demon hound built for a breach: asymmetrical limbs, hot
  red-orange fissures, and a mouth that opens too far. Avoid a familiar wolf silhouette.
- **Gnaal Rift-Scavenger:** used by the same Dorthkor vanguard encounter. Smaller,
  crouched demon scavenger with hooked limbs, scrap-like bone plates, and a cyan/violet
  rift glint in the ribs.
- **Mustered Bloodbellow / Dorthkor Dead Muster:** current scene
  `world/dorthkor_road.tscn`, encounter ID `dorthkor-muster`. Empty or partly occupied
  military armor, drum-bellows, and a dead-company cadence implied by repeated insignia.
  The silhouette must support both “destroyed by force” and “released soldier” outcomes.
- **Cleaned Jawbrace Guard / The Empty Post:** current scene `world/wound_lip.tscn`,
  encounter ID `jawbrace-empty-post`. Upright armor with no visible occupant, clean enough
  to suggest something has recently scrubbed the corruption away; a faint inward-facing
  seam is the only supernatural clue.

For each enemy, provide: idle, attack anticipation, hit, defeated/broken, and a compact
portrait or bust crop for the battle screen. The battle UI currently renders text only,
so these can be delivered in P1 as a staged combat-art pass.

## 4. Location and environment art

The world scenes currently generate an isometric graybox atlas through
`world/isometric_blockout.gd`. Replace it with a project-owned 64×32 isometric tile atlas
and modular prop sprites. Deliver terrain tiles with clean edges and no baked scene text.
Each location needs a playable base set plus a small landmark set so the player can
orient without relying only on labels.

### Dom — Starting Town / City of the Four Arms

- **Mood:** storm-port city that has made bureaucracy into survival equipment.
- **Base tiles:** dark stone paving, wet iron road, patched timber, drainage channels,
  muddy edge tiles, shallow puddle variants, and worn bronze inlay.
- **Landmarks:** the Four Arms tavern exterior with a readable four-limbed sign; Marshal's
  post or road commission board; Trial Council Hall exterior with a stern geometric roof;
  stacked crates, rope, barrels, rain gutters, brazier, market awning, and a gate toward
  the north road.
- **Palette:** blue-black stone, storm gray, tarnished bronze, restrained window amber.
- **Must read in play:** a lived-in settlement with defenses and paperwork, not a generic
  medieval village.
- **Deliverables:** 64×32 tile atlas, 6–8 prop sprites, tavern exterior, council-hall
  exterior, 1280×720 background composition for menus or establishing shot.

### Dorthkor Memorial Road

- **Mood:** a maintained military road where the dead have been catalogued but not laid
  to rest.
- **Base tiles:** dark packed road, stone shoulder, wet grass, memorial markers, broken
  road sections, demon-burned earth, and small breach cracks.
- **Landmarks:** memorial stones with repeated company marks, a broken road drum, a breach
  warning post, abandoned supply cart, and the road return gate to Dom.
- **Palette:** iron gray, desaturated red-brown, bone white, and demon heat only around
  the breach.
- **Must read in play:** the road is still strategically important and maintained, but
  every object suggests a missing unit or interrupted order.
- **Deliverables:** tile atlas additions, 8 prop sprites, memorial marker variants,
  road-drum prop, breach decal/effect layer, 1280×720 establishing background.

### Loamroot Grove / the Wilds

- **Mood:** fertile, old, and actively thinking about the people who walk through it.
- **Base tiles:** wet loam, moss, root-split earth, shallow water, pale loamroot beds,
  green pulse patches, and dark tree-shadow tiles.
- **Landmarks:** Iris's overgrown work shelter, a low moss overhang, root shrine, three
  distinct wrong-rooted loamroot sprig clusters, fallen trunk, mushroom/loam shelf, and
  a path back toward Dom.
- **Palette:** deep green and peat brown, yellow-green Bloom growth, pale root flesh,
  small cyan moisture highlights.
- **Must read in play:** the grove is not a pleasant generic forest; life is intelligent,
  hungry, and only partly cooperative.
- **Deliverables:** tile atlas additions, 10 organic prop sprites, three loamroot pickup
  variants, Iris shelter, grove overhang, subtle animated green-pulse overlay.

### The Jawbrace — First Ledge

- **Mood:** the first clean edge of a wound in reality, treated like a military worksite.
- **Base tiles:** fractured ledge, black void cuts, gray brace metal, chalk/ash markings,
  damp stone, and thin violet/cyan seams.
- **Landmarks:** Jawbrace retaining structure, chain or hammer post, empty guard station,
  warning plate, collapsed ledge fragment, and a visible descent sealed behind the first
  line.
- **Palette:** nearly black blue-gray, cold metal, bone, and very restrained Wound color.
- **Must read in play:** the silence and negative space are part of the asset; do not fill
  the scene with decorative clutter.
- **Deliverables:** tile atlas additions, 6 architectural props, empty guard post, wound
  seam overlay, warning plate as texture-only art, 1280×720 establishing background.

## 5. Item icons

Deliver **64×64 px transparent PNG icons**, with a 2× source/export where useful. Icons
must remain recognizable in an inventory slot on the dark inset UI and must not include
item names. Each icon needs a neutral version plus a selected/highlight-safe silhouette.

- **Loam bread:** dense compost-city loaf, dark crust, greenish interior crumb, wrapped in
  rough paper or leaf; it should look nutritious and a little strange.
- **Cinder-ink vial:** squat glass vial with black-red ash ink, sealed with a bronze cap;
  one cinder filament visible inside.
- **Loamroot sprig:** pale warm root cutting with three wrong-direction root fingers and
  a small living green tip; should look recently pulled from the grove.
- **Captured reflection:** obsidian shard showing a room lit by a nonexistent sky;
  reflection must be visibly impossible without requiring text.
- **Quine shard:** fragment of pre-Bloom machinery, cyan indicator light still alive,
  layered with ancient industrial geometry.
- **Soul Gauge:** brass-and-glass dial, exact needle, faint inner ring suggesting a soul
  pattern rather than a health potion; this is the iconic mechanic item.
- **Taubstummer axe:** sealed soul-weapon from the Last Great War, broad quiet edge,
  dark haft, and a surface that appears to remember what it unmade.

## 6. UI and presentation assets

The current UI already has a functioning dark stone/bronze/violet design system. Art
should extend it, not replace it with a separate visual language.

- **Soul Meter wordmark:** transparent SVG and 1024 px transparent PNG, “SOUL METER” in
  the established carved/ledgered mood. Include a compact mark based on a held line,
  gauge needle, or sealed seam; avoid a generic eye or gear.
- **Dialogue portrait frame texture:** 9-slice-safe bronze/iron trim, square corners,
  transparent center, minimum 128 px source; must work around both portrait art and the
  initial-monogram fallback.
- **Dialogue atmosphere overlays:** three subtle transparent 1280×720 layers: damp grove
  mote/pollen, road ash and rain, and Jawbrace particulate/quiet Wound distortion. Keep
  opacity low enough that text remains readable.
- **Chapter-complete seal:** small transparent bronze/violet emblem for the consequence
  ledger; no baked words.
- **Focus/choice accent:** optional 3–8 px bronze-to-violet edge texture that can sit
  behind the existing dialogue-choice left edge without adding a second border system.

## 7. Optional P2 content expansion

These are not required for the current prototype acceptance loop, but should be planned
if the art team is already building a reusable library:

- generic Dom residents in 4–6 silhouettes with faction-neutral clothing;
- Iron Companies and Ironbrand Sentinel uniform variants;
- Ssae-Seeder grove-tenders in two body types and three age ranges;
- Registry clerks and numbered specimen drawers;
- demon breach decals, small rift particles, and dead-muster insignia variants;
- combat action effect cards for Defining, Paradox, Stabilize, and context actions;
- title-screen atmospheric background with the world wound barely visible behind the
  ledger motif.

## 8. Dom civic district expansion

The first-area blockout now includes a denser civic and residential loop around the
Lower Market. These should feel like one storm-port neighborhood: practical buildings,
clear faction ownership, and repeated iron/bronze/blue-green material language. Deliver
exteriors first; interiors are not required for the current field-scene pass.

### Loam & Lantern item shop

- **Role:** everyday provisions and field consumables for travelers who cannot afford to
  leave Dom unprepared.
- **Exterior:** low market shop with a broad patched awning, open service window, stacked
  crates, hanging paper packets, a hand-painted lantern, and a counter crowded with
  wrapped food and small bottles.
- **Identity cues:** loam-brown wood, faded orange canvas, greenish bread cloth, and
  warm lantern amber; it should read as approachable and busy rather than wealthy.
- **Required props:** Loam Bread display, Cinder-Ink Vial rack, measuring scoop, chalk
  price board with no baked readable prices, three crate shapes, and a shop bell.
- **Game-facing deliverables:** 1 exterior building sprite or modular facade, 1 awning,
  3 crate variants, 2 hanging-sign variants, 1 counter display strip, and 1 64×64 shop
  emblem/icon.

### Iron & Thread equipment shop

- **Role:** repairs and sells practical weapons, tools, fittings, and protective gear for
  soul-bound parties.
- **Exterior:** taller dark-metal storefront with a reinforced door, roof rack, weapon
  silhouettes behind glass or grating, a repair bench, and a blue-gray canvas awning.
- **Identity cues:** iron gray, cold blue, worn leather, small brass fasteners; less forge
  fantasy and more military quartermaster than blacksmith theater.
- **Required props:** weapon rack, hanging axe silhouette, tool board, armor hook, repair
  hammer, spool of dark thread, and a small inspection lamp.
- **Game-facing deliverables:** 1 exterior building sprite or modular facade, 2 weapon
  rack variants, 1 repair bench, 1 hanging sign, 1 equipment-shop emblem/icon, and
  transparent item-display silhouettes that can sit behind a UI list.

### Iron Companies garrison

- **Role:** Dom's military checkpoint and the source of road rosters, patrol orders, and
  disciplined public space.
- **Exterior:** broad fortified barracks with a raised entry, narrow slit windows, a
  company standard, training-yard markings, stacked shields, and a visible muster board.
- **Identity cues:** blue-black stone, iron plate, desaturated red-brown cloth, and
  restrained bronze rank marks. It must look maintained and operational, not abandoned.
- **Required props:** company banner, roster board, weapon rack, practice post, shield
  stack, guard lantern, and two faction-neutral sentry silhouettes.
- **Game-facing deliverables:** 1 facade, 1 banner sheet with Iron Companies marks, 6
  garrison props, 2 sentry sprites, and 1 readable muster-board texture without baked
  names.

### Town Hall

- **Role:** public ledger, ward administration, road commissions, and the visible face of
  Dom's meritocratic bureaucracy.
- **Exterior:** formal stone civic hall with a stepped entry, bronze seal, high windows,
  public notice plinth, and a roofline that is distinct from the military buildings.
- **Identity cues:** storm gray stone, old bronze, parchment cream, and a small violet
  authority accent; it should feel imposing through order and maintenance, not scale.
- **Required props:** Dom civic seal, ledger lectern, public notice plinth, two column
  caps, brass rain gutter, and a removable blank plaque for localization.
- **Game-facing deliverables:** 1 formal facade, 1 civic-seal texture, 3 public-document
  props, 1 blank plaque texture, and 1 64×64 town-hall emblem/icon.

### Chef's House

- **Role:** a lived-in domestic kitchen that makes the Lower Ward feel inhabited and gives
  the player a warm, non-factional landmark.
- **Exterior:** compact attached house with a sloped roof, active chimney, herb boxes,
  firewood, a service window, and one bowl or pot visible near the door.
- **Identity cues:** clay red, soot gray, faded cream, and a single warm window; avoid a
  restaurant sign or fantasy tavern shorthand.
- **Required props:** chimney smoke layer, hanging ladle, herb bundle, stacked firewood,
  covered pot, bowl on a sill, and a handwritten note prop with no baked words.
- **Game-facing deliverables:** 1 house facade, 5 kitchen props, 2 smoke states, 1 herb
  box variant, and 1 small food/kitchen emblem/icon.

### Player's house

- **Role:** Vex's first stable address in Dom and the visual anchor for recovery, privacy,
  and the feeling that the player has a place to return to.
- **Exterior:** modest dry room above or beside a workshop-grade foundation, with a cyan
  lit window, personal door marker, small roof repair, and very little decoration.
- **Identity cues:** blue-green window light against iron-gray stone, one repaired panel,
  and a held-line motif that echoes the Soul Meter without becoming a logo.
- **Required props:** personal door plaque left blank for localization, narrow window,
  bedroll or folded blanket visible through the window, small storage chest, wall hook,
  and a tiny rain-catch basin.
- **Game-facing deliverables:** 1 facade, 5 domestic props, 2 window-light states, 1
  blank nameplate, and 1 64×64 home emblem/icon.

### Home save point

- **Role:** a clear, welcoming visual marker where the player can explicitly commit the
  current run to the save slot.
- **Exterior prop:** small household ledger stand or wall-mounted brass seal near the
  player's house door, with a protected cyan-green ember or steady indicator line.
- **Interaction read:** visible at field scale without obscuring the house; the art must
  communicate “safe record” rather than healing, treasure, or a quest objective.
- **Game-facing deliverables:** 1 save-point prop, 2 lit states (available and recently
  saved), 1 subtle activation effect, and 1 monochrome UI glyph for the save feedback.

## Acceptance checklist for art review

- [ ] Art is delivered in the requested dimensions and transparent where specified.
- [ ] Character identity reads at dialogue-card size and at field-sprite size.
- [ ] Every person has a distinct silhouette, age read, race cue, role cue, and one
      memorable trait; no two companions rely on the same prop or color block.
- [ ] Environment landmarks make Dom, Dorthkor Road, Loamroot Grove, and Jawbrace
      distinguishable in a screenshot with UI hidden.
- [ ] 64×32 isometric seams tile without visible gaps or half-pixel shimmer.
- [ ] Item icons remain identifiable at 32×32 and do not depend on text labels.
- [ ] The palette remains legible against the existing dark UI and does not turn every
      magical cue into a full-screen glow.
- [ ] Source layers and naming are included so assets can be revised without repainting
      the complete image.
- [ ] Any unresolved canon choices, especially Iris's and Coiljaw's races and numeric
      ages, are called out before final approval rather than silently established by art.
- [ ] The Dom civic-district additions have distinct silhouettes and can be identified
      without relying on the field labels: market, equipment, military, civic, kitchen,
      home, and save point.
