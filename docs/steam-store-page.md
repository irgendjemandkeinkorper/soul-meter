# Steam store page — Soul Meter: Chapter One

**Status: DRAFT, copy only (#303, ship milestone).** Voice is `docs/game-identity.md` ruling 10 —
**elegiac and wry**: a dying world, gallows humour, loss felt rather than punished. Nothing here is
final until the owner has read it aloud; store copy is the one artifact where the writing *is* the
product.

Two parts of S9 are not in this document because they need a build or a person:

- **Capsule art** — the owner generates it from `docs/art-aesthetics-bible.md` Part II's Steam
  capsule template (#296). §7 below gives the scene brief that template takes.
- **Screenshots** — five, from the round-1 playtest build. §6 is the shot list, written so the
  capture session is mechanical rather than a judgement call.

> ### ⚑ Read §8 before publishing
>
> Four claims below describe work that is real but **not yet merged**. Publishing them early is a
> false claim on a paid store page, and Steam treats that as a refund liability. §8 lists them with
> the issue each one waits on.

---

## 1. Store metadata

| Field | Value |
|---|---|
| Name | **Soul Meter: Chapter One** |
| Developer | *(owner's chosen studio name — not decided in-repo)* |
| Publisher | same |
| Franchise | Soul Meter |
| Release date | 2026-10-02 target (gold build), store page public ~2 weeks earlier |
| Price | *(owner)* |
| Early Access | **No.** Chapter One is a finished chapter, not an unfinished game. Selling a complete first chapter is a different promise than Early Access, and the copy makes that promise explicitly (§3, closing line). |
| Primary genre | RPG |
| Secondary genre | Strategy |
| Player support | Single-player |
| Platform | Windows |

### Tags (ordered — Steam weights the first few most)

`RPG` · `Turn-Based Tactics` · `Story Rich` · `Dark Fantasy` · `Isometric` · `Choices Matter` ·
`Party-Based RPG` · `Tactical RPG` · `Singleplayer` · `Atmospheric` · `Grid-Based Movement` ·
`Character Customization` · `Magic` · `Difficult` · `Great Soundtrack`

**Deliberately absent:** `Roguelike`, `Souls-like`. "Soul" in the title will draw the second
suggestion from Steam's tag wizard and from players. It is the wrong genre and the wrong promise,
and a mistagged store page is corrected slowly and expensively. If the tag appears, remove it.

---

## 2. Short description (Steam limit: 300 characters)

> A dying world keeps a ledger of everything you spend. Every promise, every mercy, every working
> of magic costs a piece of your soul — and the world remembers what you paid for. A turn-based
> tactical RPG about the price of doing the right thing, and about what is left of you afterward.

*(285 characters. Steam truncates hard at 300 and shows this under the capsule in search, in
recommendations, and on wishlists — it does more work than any other sentence on the page.)*

---

## 3. About This Game

**[h2]The ledger is honest. That is the problem.[/h2]**

In Dom, the City of the Four Arms, a soul is not a metaphor. It is a quantity. It can be measured,
spent, borrowed against, and run out of — and the world keeps a running account of every
transaction, in the mouths of the people who were standing there when you made it.

You arrive in the last decent city of a world that is quietly finishing its leave-taking. You will
be asked to help. Helping costs.

**[h2]Spend your soul. Watch the world notice.[/h2]**

Every meaningful act — a promise kept, a lie told well, a working of magic, a mercy nobody asked
for — draws on the Soul Gauge. It does not refill with rest. It does not refill with potions. It
returns only through **acts of Agreement**: promises actually kept, companions actually helped,
broken places actually put back.

So the meter trends downward across a chapter, and the question stops being *can I afford this* and
becomes *what am I willing to be, by the end.*

Run it to empty and you do not die. You **hollow**. Conversations close. Companions get quiet in a
new way. Strangers read you as Waning-touched before you open your mouth. It is recoverable, at a
price, and it is never a game over — a hollowed run is a run, played by someone the world has
started to talk about differently.

**[h2]Tactical combat that respects your time and your reading[/h2]**

Fights are frequent and they are the centrepiece, not the tax. A grid with real elevation and
facing. Charge-time turn order rather than rounds — speed buys you turns, and you can see exactly
when. Ten elements on a Wheel that clash in fixed pairs, weather that changes what the ground will
carry, and tiles that hold a charge after the spell that made it has ended.

The forecast you are shown before you commit is the same calculation the game runs when you do.
Not an estimate. The number.

**[h2]A party you chose, who did not choose each other[/h2]**

Twenty recruits drink in the tavern at the Four Arms — two for each of the ten patron classes. Some
will not come with you until you have a reputation. Some will not come until you have the *wrong*
reputation. Six of them have a personal matter they will eventually raise, and resolving one well
is one of the few things that gives soul back.

**[h2]Class is who you are. What you can do is up to you.[/h2]**

Your patron class grants abilities nobody else gets. Everything else — seven attributes, twenty-two
skills, points spent where you like — decides what you actually do with them. A brawler who reads
old script is a legitimate build. So is a scholar who has learned exactly one violent thing and
does it very well.

**[h2]Two ledgers, and neither of them forgives[/h2]**

Sixty factions keep their own accounts of you. Separately, the world at large keeps track of how
known you are, and how badly. Doors open on one and close on the other, and no screen ever tells
you which is which until you are standing in front of it.

---

Chapter One is a **complete chapter** — a finished region, an act-complete main quest, and an
ending you reach on purpose. It is not Early Access, and it is not a demo. It ends where the next
chapter starts, and it means it.

---

## 4. Feature bullets (for the short-form module and press use)

- **Soul as currency.** Every meaningful act spends soul. It returns only through kept promises.
- **Hollowing, not dying.** Empty is a state you play through, not a screen you restart from.
- **Charge-time tactical combat** on a grid with elevation, facing, ten elements, and live weather.
- **A forecast that cannot lie** — the pre-commit numbers are the resolution numbers.
- **Twenty recruits, ten patron classes**, some of them gated on reputation you may not want.
- **Two independent consequence ledgers** — sixty factions, plus the world's opinion of you at large.
- **Seven attributes, twenty-two skills**, spent freely against a class you chose at creation.
- **New Game+** that carries something forward and deliberately withholds something else.

---

## 5. System requirements

Godot 4.7, Forward+, 2D. Draft — replace with measured figures from the FR-904 performance runbook
(`docs/fr-904-runbook.md`) once it has been run on real hardware. **Do not publish estimates**: a
minimum spec is a support promise, and this one has not been measured.

| | Minimum | Recommended |
|---|---|---|
| OS | Windows 10 64-bit | Windows 11 64-bit |
| Processor | *(runbook)* | *(runbook)* |
| Memory | *(runbook)* | *(runbook)* |
| Graphics | Vulkan 1.0 capable | *(runbook)* |
| Storage | *(measured from the export)* | — |

---

## 6. Screenshot shot list (five, from the round-1 build)

Steam shows the first two everywhere. Order matters more than count.

1. **Combat, mid-forecast.** The grid with elevation visible, a target highlighted, the forecast
   panel open with real numbers. This is the one screenshot that has to carry the whole tactical
   promise, and the forecast panel is the proof — capture it with the numbers legible at
   thumbnail size, which usually means moving the camera closer than feels natural.
2. **A dialogue at a real cost.** A choice on screen that shows its soul price, with the Soul Gauge
   in frame. The tagged cost is the hook; a dialogue screenshot without a visible price is just a
   conversation.
3. **Dom, wide.** The Four Arms and the painterly facades, mid-afternoon phase, with NPCs actually
   in the street. Sells the world and the art tier in one frame.
4. **The party screen or the tavern picker**, showing several recruits including at least one
   locked with its reason visible. Communicates "party-based RPG" and "choices matter" at once.
5. **A consequence read back** — the journal, timeline, or a faction standing screen showing
   events the player caused, with causes in plain language. This is the pillar nobody else's
   screenshot shows, so it is worth one of only five slots.

Capture rules: 1920×1080, no debug overlays, no placeholder art in frame, no untranslated
developer strings, and the same world phase across 1 and 3 so the set reads as one build.

---

## 7. Capsule brief (feeds the S2 prompt bible)

For `docs/art-aesthetics-bible.md` Part II's **Steam capsule** template, `{SCENE}` is:

> A lone armoured figure seen from behind at the mouth of a rain-wet stone street, facing a vast
> dim city of four converging arms; one warm brazier burns at the near edge and everything beyond
> it is blue-black and failing. The figure is small in the frame.

Negative space in the **upper third** for the wordmark. Generate the widest ratio first and let the
layout crop the rest — re-prompting per size gets four different paintings.

The wordmark itself is composited in a layout tool afterwards, never generated: Part II's rule is
that a generated asset never bakes text, and the capsule's title treatment has to be a real,
kerned, reusable asset anyway.

---

## 8. ⚑ Claims that are not shippable yet

Each of these is real work in flight, and each would be a false statement on a paid store page
today. Cut the line or delay the page — do not publish and fix later.

| Claim in the copy | Waits on |
|---|---|
| "off-screen mobs join when alerted" / any same-map framing beyond what §3 already says | **#281** (f1: same-map combat). §3 above is written to be true of the current overlay build *and* of same-map, so it needs no edit either way — but do not add same-map language until #281 merges. |
| Any specific mob-count or scale claim ("hundreds of enemies", "~100 mobs") | **#282** (f2: 100-mob scale floor). **Not currently claimed anywhere above — keep it that way** until the floor holds. |
| "Seven attributes, twenty-two skills" (§4 bullet, §3 class section) | **#283** (DRAMGID). The build still runs the old six-stat system. This is the single most load-bearing unmerged claim on the page. |
| Playtime figures of any kind | **#93** (comprehension gate). No playtime claim appears above on purpose; the ship plan is explicit that 20 hours is a goal, not a measurement. |
| Minimum/recommended specs | **FR-904 runbook** on real hardware. §5 is deliberately unfilled rather than estimated. |

Two more that are true today and worth protecting: the forecast==resolution claim in §3 is a real
architectural property (`Resolution.resolve()` is pure and the forecast calls it), and "six
companion personal quests" is authored and canon-reviewed. Both are unusually specific for store
copy, which is exactly why they are worth keeping — and why they must not be loosened into vaguer
marketing language that would stop being checkable.
