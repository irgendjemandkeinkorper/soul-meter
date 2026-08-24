# The Ten Patrons — aesthetic style guide

Working draft. Ground truth for names/kits is `data.pandora` / `tools/seed_pandora.gd`; the
house style baseline every god bends is `design/DESIGN_PILLARS.md` §5: *"carved, ledgered, and
slightly wrong — an instrument made by an exacting civilization that understands horror
administratively."* Every god below should still read as belonging to that civilization. None of
them should look like a different game. What changes is which part of that civilization built the
instrument, and what it's lying about.

Each entry: **Concept** (one line) · **Material world** · **Structural language** · **Motion &
mood** · **Iconographic motifs** · **Typography feel** · **The wrongness** · **Avoid**.

These are written as creative-direction prose, ready to compress into Claude Design system prompts
once you've reacted to them. Push back on anything — these are strong first drafts, not final.

---

## 1. Mirrorblade — Maiiam
*Balance · paired daggers · reflected footwork*

**Concept.** A goddess defined entirely by symmetry, and the one god in the pantheon who is
currently missing. Her aesthetic is the house style's bilateral instinct taken to its logical,
obsessive extreme — then cracked, because she isn't whole right now.

**Material world.** Polished silver and quicksilver glass — not gold, not warm. Surfaces you can
almost see yourself in but not quite; the reflection is a half-second delayed, the way a mirror
looks when the coating has started to flake. Cold-forged steel with a mirror grind, not a matte
one. Where other gods' stone is carved, hers is *ground and polished* — the labor is abrasion, not
addition.

**Structural language.** Perfect bilateral symmetry as the default grammar — panels, borders, and
layouts mirror themselves across a vertical axis — but with one deliberate asymmetric intrusion per
composition: a crack, a missing panel, a reflection that doesn't match its source. The symmetry
should feel load-bearing, like removing it would be structurally wrong, which is exactly why the
one broken instance should be unsettling rather than decorative.

**Motion & mood.** Two motions in alternation, never one continuous flow — strike, guard, strike,
guard. Anything animated in her theme should feel like it's counting a beat it can't stop counting.
Overall mood: composed, exact, and quietly grieving under the composure — a duelist's stillness
that is actually restraint, not calm.

**Iconographic motifs.** The paired blade as a closed circle (two crescents forming a ring, not
crossed swords). A mirror-line/seam running through every symbol. Reflection-pairs of any creature
or figure used in her iconography — never a single figure alone.

**Typography feel.** A face with strict bilateral letterforms — geometric, monospaced-leaning,
built for a civilization that trusts measurement. Set centered, mirrored margins, never ragged.

**The wrongness.** The symmetry is a promise of fairness and balance that the plot actively
betrays — she is the victim of the entire conspiracy, not its arbiter. Her UI should feel like it's
promising even-handedness while the story around her is anything but. Consider a slow, almost
imperceptible desync over time (asset states, if you want to get fancy) — the reflection drifting a
few pixels further from true the longer you're in her theme, never enough to name, always enough to
half-notice.

**Avoid.** Don't let this become "elegant fencing academy" — it should feel colder and more
administrative than romantic. No flowing ribbons, no soft light.

---

## 2. River-Mother — Haeren
*The Name-Ledger · net-and-whip · recovers Gauge by naming the dead and saved*

**Concept.** Water is the *subject*, not the *style*. The actual visual motif is the ledger of
names — she is a bureaucrat of mourning before she is a river goddess. Grief processed through
paperwork, not through waves.

**Material world.** Wet vellum and waterlogged paper that has been dried and re-used — cockled,
rippled pages, ink that has run and been re-inscribed over the bleed. Rope and net cordage, tarred
and salt-stiffened. Wood swollen and shrunk by repeated soaking — joints slightly proud of true.
Brass fittings green with verdigris from river air, never bright.

**Structural language.** Long vertical registers, like scroll columns or tally sheets, stacked
top-to-bottom rather than the mirrored horizontal panels of Mirrorblade. Line-ruled backgrounds —
actual ledger rules — under everything, even environment art (riverbank strata reading like ruled
lines in cross-section). Net/lattice patterning at a much finer, denser grain than Threadwalker's
knotwork (see #10) — hers is functional mesh, not decorative rope-work.

**Motion & mood.** Slow tidal push-pull — things drift in, hold, drift out, on a longer period than
anything else in the pantheon. No sharp cuts. The mood is elegiac and administrative at once: a
harbor-master's ledger for the drowned.

**Iconographic motifs.** The name as glyph — treat "a name written down" as her primary symbol
rather than water itself. Net diamonds. A harp string doubling as a ruled line. Tally marks that
resolve into names when you look closely (a nice diegetic UI trick: illegible at a glance, legible
on focus).

**Typography feel.** A humanist, slightly worn serif — letterforms with visible ink bleed/feathering
at small sizes, as if actually written in damp conditions. Long line-height, ledger-column setting.

**The wrongness.** She's the recovery/support patron — the "safe," nurturing one — but her power
source is literally the dead. Every act of comfort in her theme is also an entry in an accounts
book. Consider making her "positive" UI states (heals, saves, recoveries) visually indistinguishable
in weight from her negative ones — a name added to the ledger looks the same whether the name is a
save or a loss, until you read it.

**Avoid.** Don't go generic-aquatic (waves, foam, blue gradients). If it could illustrate "beach
vacation," it's wrong. The water should always be working water — flood, harbor, drowning, not
tourism.

---

## 3. Ironbrand — Kero
*Scars · greatsword · branded wardens who hold the line*

**Concept.** Scars are the literal currency of this class, so the design system should treat marks
of injury as a *ledger*, not a wound aesthetic — heraldic, counted, displayed with pride rather
than horror, closer to service medals than gore.

**Material world.** Cauterized and welded metal — seams that were broken and rejoined, visibly, on
purpose. Branding-iron burns on leather and wood as an intentional decorative technique, not
damage. Riveted plate, hammer-scale texture on steel (the dark oxide left by forging, not rust).
Heavy, load-bearing materials throughout — nothing here should read as light.

**Structural language.** Dense heraldic registers — shields, bars, and charges arranged like a
coat-of-arms system, where every scar/mark has a fixed position and meaning, the way military
service ribbons stack in a known order. Thick borders, doubled or tripled framing lines (the visual
equivalent of "holding the line" — the frame itself is the fortification).

**Motion & mood.** Minimal, weighty motion — things land with impact and stay put; nothing drifts
or floats. If UI elements animate in, they should slam or clamp rather than fade or slide. Mood:
stoic, plainspoken, proud of damage sustained rather than damage dealt.

**Iconographic motifs.** The brand-mark (a single burned sigil, repeatable and stackable — literally
designed to be reused as a counter/tally UI element for the Scars resource). Welded seams as
border ornament. A held gate or shut door as the recurring silhouette (vanguard, blocking).

**Typography feel.** Heavy slab serif or stencil-adjacent — letterforms that look stamped or
branded into the surface rather than printed on it. Wide letterspacing, all-caps for headers,
like unit designations.

**The wrongness.** "Holds the line" reads as loyal and defensive — but Dom's Ironbrand Sentinels
include the *dead muster*, wardens who are still standing watch after death (per the reputation
ledger content: "the empty guard still holds the first gate"). The devotion is admirable and also
mindless/undead in the game's own text. Consider letting his UI occasionally imply duty continuing
past the point it should have stopped — a counter that keeps incrementing, a watch that never
rotates out.

**Avoid.** Don't tip into "gore/horror" — the scars are proud and ledgered, not grisly. Keep it
closer to a regimental museum than a slaughterhouse.

---

## 4. Lensbearer — Stuid
*Fading / Sacred Clarity · quarterstaff · a salvager reading Age-of-Stars machines*

**Concept.** The one god whose domain is explicitly pre-spore relic-tech sitting inside a fantasy
pantheon. Lean into that seam rather than smoothing it over — this should look like devotional
worship of something the worshippers don't fully understand, an ancient instrument panel treated as
scripture.

**Material world.** Ground and polished optical glass, brass instrument casings gone dull with
handling but still precise where it matters (bearings, hinges, sight-lines). Etched schematic
diagrams on metal plates — actual technical-drawing linework repurposed as religious icon. Worn
analog dials, verniers, and readouts that no longer fully function but are maintained anyway.

**Structural language.** Concentric circles and radial graduations — the literal geometry of a
lens or a dial face — used as the base grid for everything, panels arranged like instrument
clusters rather than mirrored or ledgered pages. Cutaway/exploded-diagram framing: things shown in
cross-section, annotated, labeled with parts nobody currently alive can name.

**Motion & mood.** A slow focus-pull — elements sharpen from blur rather than sliding or fading
flat-on. Mood: reverent, myopic, quietly tragic — clarity as something perpetually almost-in-reach.
This is the one god whose theme should feel intellectually exciting rather than solemn; curiosity as
devotion.

**Iconographic motifs.** The lens/aperture as primary glyph (an iris shape, literally — nice
resonance with "Iris Illepah" if that's intentional, worth flagging either way). Annotated
schematic call-out lines (thin leader lines to labels) used decoratively even where nothing needs
labeling. A single unblinking eye-like dial as her signature mark.

**Typography feel.** A technical/engineering face — think drafting-table lettering, uniform stroke
width, numerals that look stenciled from an instrument's dial. Small caps for annotation text,
larger geometric sans for headers.

**The wrongness.** "Sacred Clarity" as a power name is a small lie — Fading is her other keyword,
and salvage-reading is inherently *incomplete* understanding dressed as revelation. Her UI could
present information with the confident precision of an instrument reading while quietly leaving
gaps — redacted or illegible fields presented with the same formatting authority as legible ones, so
players trust the whole panel including the parts that are guesses.

**Avoid.** Don't make this steampunk-decorative (gears-as-jewelry, brass-for-brass's-sake). Every
mechanical element should look like it was built to be *used*, then read as scripture later — form
follows forgotten function.

---

## 5. Husk-bearer — Vhorr
*The Table · cleaver · Ssae-Seeder cultivator, damage-over-time as the mechanic*

**Concept.** Not wild decay — "The Table" as the signature name means *ritual, portioned, deliberate*.
This is a harvest god run like a formal service: courses, settings, a host who keeps serving whether
or not you're still hungry.

**Material world.** Groves and overhangs, cultivated rather than feral — pruned, trellised, swept
(per the lore: "keeps the overhang swept"). Root-bound wood, woven plant fiber, unglazed ceramic
with a matte, absorbent surface. Where things rot, they rot *tended* — composted on schedule, not
left to sprawl.

**Structural language.** Place-setting geometry — repeating modular units laid out like servings at
a table, evenly spaced, each one identical in form and only differing in content (a visual metaphor
for DoT stacks as "courses"). Woven/latticed borders that look grown rather than built, but still
disciplined — pleached hedges, not jungle.

**Motion & mood.** A slow accumulating rhythm — things arrive one at a time, at even intervals, and
persist once seated, echoing damage-over-time as literal course-service pacing. Mood: hospitable on
the surface, faintly menacing underneath — a host whose politeness never breaks even as the meal
gets uncomfortable.

**Iconographic motifs. ** The empty place-setting as glyph (a bowl, a seat, a portion-mark). Root
and vine used as connective tissue between UI elements rather than decorative filigree. A tally of
"servings" as the visible DoT-stack counter, styled like a place count at a table.

**Typography feel.** A warm, slightly rustic serif with organic stroke variation — but set with
formal, even spacing, like an engraved menu rather than a handwritten note. The warmth is in the
letterforms; the discipline is in the setting.

**The wrongness.** Hospitality that never asks if you're still hungry. Her theme should never
signal "this is now too much" — the table simply keeps setting more places, formally and without
malice, which is worse than if it were hostile on its face.

**Avoid.** Don't slide into horror-rot (mushrooms bursting from corpses, viscera). This is a
cultivated harvest-ritual aesthetic, closer to a formal dinner service or a temple offering table
than a swamp.

---

## 6. Flamebinder — Vicoar
*Instructive Failure · deployable kinetic-sculpture constructs · an engineer's stance*

**Concept.** Your other tech-coded god, and the deliberate foil to Lensbearer: where Lensbearer is
optical/precision/backward-looking (reading old instruments), Flamebinder is combustive/kinetic/
forward-building — a working foundry, not a museum piece. The "instructive" half of his signature
matters as much as the "failure" half: this is a god who treats mistakes as data.

**Material world.** Cast iron and soot-blackened steel, still warm — heat-treated color bands
(straw to blue) visible on tempered metal. Refractory brick, forge-scale, quenching-tank water
stained orange with rust. Where Ironbrand's metal is finished and heraldic, Flamebinder's is
mid-process — half-cast, still cooling, tool-marked.

**Structural language.** Diagrammatic and modular, like an engineer's assembly drawing — exploded
views, numbered build-steps, construct silhouettes shown mid-deployment (unfolding, not static).
Panels should feel like they're *built*, with visible fasteners, hinges, and load paths, versus
Lensbearer's etched-and-sealed instrument casings.

**Motion & mood.** Percussive and combustive — things ignite, unfold, and lock into place with a
visible mechanical sequence, not a smooth tween. A spark or ember-shower accent on state changes.
Mood: confident, didactic, faintly reckless — an inventor narrating his own experiment out loud,
including the parts that are about to go wrong.

**Iconographic motifs.** The kinetic-sculpture construct itself as a recurring silhouette family —
these should look like a specific, recognizable machine language (jointed limbs, articulated
plates), not generic robots. Ember/spark motifs used sparingly as accents, not fields. A "failed
attempt" ledger-mark that looks proud rather than crossed-out — failure logged as instructive, per
his name.

**Typography feel.** A condensed industrial sans, stenciled or die-stamped in character — think
foundry-stamp numerals, part-number labeling conventions.

**The wrongness.** "Instructive" implies control and learning, but the compatibility sheet itself
flags his constructs as **static emplacements** — a god of building things that, once deployed,
can't move with you. There's a tension between his forward-looking, experimental *voice* and the
actually quite rigid, immobile things he leaves behind. Worth letting the UI hint that his
confidence outpaces his flexibility.

**Avoid.** Don't converge with Lensbearer on "brass and gears" — keep Flamebinder in blackened iron,
active heat, and combustion; keep Lensbearer in cool glass, dormant brass, and optics. If a single
asset could belong to either god without a caption, it's failed the brief.

---

## 7. Stormbearer — Ofshütje
*Attribution (random) · greatclub · doctrinally about the storm being* heard

**Concept.** The one god whose theme is allowed to break the "restrained motion" house rule on
purpose, in a controlled way — chosen unpredictability, not chaos for its own sake. Loud and
doctrinal at once: this is a *religion of noise*, with its own liturgy, not just weather.

**Material world.** Weathered timber, salt-scoured and lightning-scarred wood with visible burn-
branch fractals. Raw, unrefined metal — meteoric iron, pitted and irregular rather than polished.
Rope and canvas, storm-battered. Nothing here should look freshly made; everything should look like
it survived something.

**Structural language.** A layout system with one controlled variable per composition — most of the
frame should hold the house style's discipline (grid, hierarchy, restraint), but one element per
screen is allowed to break scale, rotation, or alignment, standing in for the storm's single random
strike. This should read as *intentional irregularity*, generated within rules, not sloppiness.

**Motion & mood.** Sudden, discrete jolts rather than continuous chaos — long stillness, then one
sharp unpredictable strike, then stillness again (mirrors "Attribution" as a random-proc mechanic).
Mood: exultant and a little frightening — worship as standing in an open field daring the sky.

**Iconographic motifs.** The lightning-fork as a *chosen path* glyph (a branching line where one
branch is emphasized, representing attribution/random selection). A closed fist around a bolt
(the greatclub). Sound-wave/thunderclap rings used as a UI "impact" motif for random-proc feedback.

**Typography feel.** A rough-hewn, slightly irregular display face for headers — hand-cut woodblock
character, uneven baseline by design — paired with a completely disciplined, quiet body text, so
the loudness is contained to specific moments, not everywhere at once.

**The wrongness.** The compatibility sheet already tells you this god is canonically opposed to
Terrashaper/held-ground play — Stormbearer punishes stillness. A subtle UI tell: any element that
sits static too long in his theme could visibly "charge up" as if inviting a strike, training the
player to feel unsafe standing still even outside combat.

**Avoid.** Don't let the controlled randomness become actual unreadability — this still has to
function as a UI. One deliberate irregular element per composition is a feature; five is a bug.

---

## 8. Oathclock — Pazzah
*The Ledger · halberd + metronome · the hidden antagonist, the order-god secretly manufacturing chaos*

**Concept.** The most important design problem in the whole set. This is the villain, and the
brief is explicit: encode a lie that only reads as a lie in hindsight. First impression must be
"the most trustworthy, orderly god in the pantheon." Replay impression, after the reveal, should be
"how did I not see it."

**Material world.** The most refined, expensive-looking materials in the pantheon on first read —
black lacquer, brass clockwork under glass, vellum ledgers bound in tooled leather, everything
dust-free and perfectly maintained. No wear, no patina, no tool-marks — which, once you know what
he is, should retroactively feel less like "well-kept" and more like "nothing here is old enough to
have earned this condition," or "someone erased the evidence of use."

**Structural language.** The most rigid grid in the entire pantheon — true modular geometry, every
element on a strict measured interval, zero deviation, zero asymmetry, zero "wrongness" visible
anywhere in the frame. This is the point: every other god in this document gets one deliberate
crack. **Oathclock gets none, and that absence is itself the tell**, once players know to look for
it. Consider actually documenting this as a rule for artists: no glitch, no crack, no asymmetry,
ever, in his assets — ban the house style's signature imperfection specifically here.

**Motion & mood.** A literal, audible-feeling metronome tick underlying everything — steady,
unhurried, inevitable. Nothing rushes, nothing hesitates. Mood on first encounter: the most reassuring
god in the game, calm competence, "someone is finally in charge." Mood on replay: the same calm
now reads as clinical detachment from consequences he's causing.

**Iconographic motifs.** The ledger-line and the clock-hand as a single combined glyph — a ruled
line that is also a sweeping second-hand. A halberd rendered as a straight vertical, doubling as a
plumb-line/measuring instrument rather than a weapon in his iconography. Perfect concentric rings
(a clock face) as his primary mark, deliberately closer to Lensbearer's dial-language than any other
god — a visual cousin worth leaning into, since he's a false "clarity," too, just a colder one.

**Typography feel.** The most legible, neutral, well-kerned face in the entire set — almost
suspiciously well-designed, closer to a prestige institutional typeface than anything hand-marked or
worn. Nothing about it should draw attention to itself. That neutrality is the disguise.

**The wrongness — this is the whole brief.** Every other god's "wrongness" is a visible crack in an
otherwise coherent aesthetic. Oathclock's wrongness is the *absence* of one. He should be the
"safest," most polished, most administratively competent-feeling god in the pantheon, in a game
whose entire design pillar #5 says the interface should feel "slightly wrong" — Oathclock is the one
place it doesn't, and that's the horror. If you want a single late-game reveal beat: something in his
theme (a ledger entry, a clock hand) finally shows the crack everyone else has had all along, timed
to the story reveal.

**Avoid.** Don't make him look sinister early — hooded, dark, ominous imagery defeats the entire
point. He should be the god players are *least* suspicious of on first sight, by design.

---

## 9. Locksmirk — Fickah
*Jammed Gears · blowgun · lockpicking-as-combat*

**Concept.** Trickster-engineer, closer to a con artist with a toolkit than a saboteur with a bomb.
The compatibility sheet's own language — "trap poetry," "Jam the Gears" — suggests wit and
craftsmanship over brute sabotage. This should feel clever, not destructive.

**Material world.** Small, precise brass and steel mechanisms — tumblers, springs, tension wrenches
— but scaled miniature and portable, in contrast to Flamebinder's large industrial forge-work. Worn
leather tool-rolls, forged picks with personal wear-marks, a working kit rather than a display
collection. Cheap, false-fronted materials used deliberately for misdirection (veneer over
substrate, paint over base metal) — a visual vocabulary of things that aren't what they present as.

**Structural language.** Interlocking, off-grid mechanisms — gear teeth, tumbler pins, and puzzle-
box joinery used as the base geometry, deliberately slightly askew from the pantheon's otherwise
disciplined grids, as if the whole layout is a lock that hasn't been picked straight yet. False
panels: an apparent border or frame that, on close inspection, isn't structural — decoration that
turns out to be a hidden seam or trap door.

**Motion & mood.** Quick, small, precise gestures — a click, a click, a click, then a sudden
release (the tension-and-release rhythm of picking a lock), versus Stormbearer's single big jolt.
Mood: sly, competent, amused with itself — this god's followers should come across as pleased by
their own cleverness rather than menacing.

**Iconographic motifs.** The tumbler/pin-stack as glyph. A key that doesn't match its lock, shown
deliberately (a visual pun on misdirection). Gear-teeth used as a border ornament that occasionally
"jams" — one tooth visibly broken or skipped, referencing Jammed Gears directly.

**Typography feel.** A sharp, slightly compressed sans with mechanical precision but a wink of
asymmetry — uneven kerning used as intentional character, like hand-set type from a printer who
enjoys being slightly imprecise on purpose.

**The wrongness.** Combat framed as puzzle-solving makes violence feel like a game to this god's
followers — there's something a little unsettling about a trickster who treats a fight, or a
person's locked secrets, with the same cheerful curiosity as a puzzle box. The charm is real and so
is the callousness underneath it.

**Avoid.** Don't make this steampunk-whimsical (goggles, top hats, brass jewelry). Keep it
functional-tool-kit, not costume — a working thief's kit, not a costume-shop inventor.

---

## 10. Threadwalker — Izhakel
*Threads · whip-dagger · hidden contracts, "you agree first, the veil is doctrine"*

**Concept.** Contractual secrecy, not textile craft — the thread motif should read as *binding
agreement* first, weaving-and-cloth second. This is a legal/occult register: consent obtained before
disclosure, obligations you didn't know you signed up for.

**Material world.** Wax seals, ribbon, fine cord — but treated as legal/ritual instruments rather
than decorative fiber. Redacted or veiled text: pages with sections physically covered, sewn shut,
or crossed through with actual thread stitched across the paper. Dark, matte fabric — velvet or
heavy weave that absorbs light rather than River-Mother's wet, reflective cordage (important
distinction from #2, since both classes touch "rope/thread" — keep hers wet/functional/nautical and
his dry/ceremonial/legal).

**Structural language.** A veil as a literal UI device — information partially obscured behind a
sheer overlay until "agreed to" or revealed by an interaction, echoing "you agree first." Knotwork
used sparingly and specifically as *binding* geometry (a knot literally closing off a section of
the frame), not decorative Celtic-style filigree covering everything.

**Motion & mood.** A tightening motion — things draw taut and cinch closed rather than sliding or
fading, echoing a knot pulling tight on a contract. Mood: intimate, conspiratorial, quietly
dangerous — a whispered agreement in a back room, not a dramatic confrontation.

**Iconographic motifs.** The wax seal as primary glyph (unbroken = binding still active; broken =
term cashed in — nice direct mapping to "the Signature cashes in Threads bound earlier, one at a
time"). A single taut thread connecting two points, always drawn straight and tensioned, never
slack. The veil/curtain as a recurring compositional frame.

**Typography feel.** A fine, high-contrast serif suited to legal documents and old contracts — small
caps for binding clauses, with certain words or lines rendered as if stitched or partially covered,
deliberately withholding some of what's written.

**The wrongness.** "You agree first, the veil is doctrine" is consent theater — technically opt-in,
practically coerced, since you can't know what you're agreeing to until after you've agreed. His
UI should always present choices as clean, symmetrical, consensual-looking, while withholding the
actual stakes until it's too late to back out cleanly — the interface itself performing the god's
whole ethical trick.

**Avoid.** Don't drift into generic "shadowy rogue" (daggers-and-cloaks, dark alleys). This is
closer to a notary's office at midnight than a thieves' guild — the horror is procedural and
contractual, not violent.

---

## Cross-god differentiation checklist

A few pairs sit close enough in raw materials that it's worth naming the fault line explicitly, so
nothing collapses into "reskinned version of another god":

- **Lensbearer vs. Flamebinder** — both tech-coded. Lensbearer: cool, optical, dormant,
  backward-looking (relic salvage). Flamebinder: hot, kinetic, active, forward-building (live
  construction).
- **River-Mother vs. Threadwalker** — both touch rope/thread/cordage. River-Mother: wet, nautical,
  functional net-work, text-as-name. Threadwalker: dry, ceremonial, binding knotwork, text-as-
  contract.
- **Ironbrand vs. Oathclock** — both read as "order/discipline" at a glance. Ironbrand: earned,
  scarred, proudly imperfect, heraldic. Oathclock: unearned-looking perfection, zero wear, the one
  god banned from the house style's signature crack.
- **Mirrorblade vs. Oathclock** — both use strict symmetry as their base grammar. Mirrorblade's
  symmetry is *broken once, visibly* (she's the victim). Oathclock's symmetry is *never broken*
  (he's the perpetrator). This contrast is probably worth calling out to any artist working across
  both.

## Suggested next step

Once you've reacted to these (react to as many or as few as you like — even "flip Locksmirk's and
Oathclock's wrongness" is a useful note), I'll compress each entry into a tight Claude Design system
prompt: one paragraph of visual-language direction plus explicit token guidance (palette role,
typography pairing, corner/edge treatment, motion character) sized to seed a `/design-sync`-ready
project per god, tagged for temple environments, god-specific UI skins, and character/portrait
direction as you specified.
