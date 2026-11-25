# Gate T-6 (#93) — Facilitator run-of-show

One page per session. Print or split-screen this next to
[`playtest-packet.md`](playtest-packet.md) (the fillable evidence record) and
[`playtest-protocol.md`](playtest-protocol.md) (the gate authority).

> **Refreshed 2026-11-20 against `main` `be4f0b6e`.** The packet, protocol, and this run-of-show
> use the same ratified Gate T chassis and four-question scoring rule. Do not substitute an older
> Phase 1.5 packet from a prior build or session.

> **Not runnable yet.** #652's five gaps are closed on `main` (`21ca5a08`, 2026-11-21), and
> region-map journeys work from the pause menu (#650, #651). Two of #652's checks remain: one
> full rendered run of the slice that shows every protocol §2 item on a single fresh save, and a
> Windows kit whose manifest says `valid_for_gate_t=yes`. **Do not book testers until #652
> closes.**
>
> The owner set how each gap is met on 2026-11-20 (owner item 48), and `main` now plays it:
> - **Routes and combat speech:** the Bloodbellow's "Speak Its Muster-Name" and "Release the
>   Bound Soldier" are its routes and also count as the session's combat speech (48e; #654).
> - **CT:** every fight runs CT (#655).
> - **Height:** Dorthkor Road's three rock outcrops are climbable high ground (48d; #660).
> - **Mock NG+:** **Begin Mock NG+** on the chapter-complete screen, and on the pause menu once
>   the chapter is in free roam (48c; #656).
> - **Company:** Themka Gaath's charge requires two companions, as Coiljaw's commission does (48b;
>   #659).

## 0. Before any tester (once per build)

1. **Build the kit** from a clean checkout of `main`, on the Linux/WSL machine that has Godot 4.7.1
   and its export templates:
   `scripts/build_playtest.sh --target windows` (about 5 minutes plus the full acceptance run).
   It runs strict acceptance, exports, proves every dialogue loads from the pack, smoke-boots it,
   and writes `build/playtest/windows/SoulMeter-windows-x86_64.zip` (~215 MB) with
   `BUILD-MANIFEST.txt` and `SHA256SUMS` inside and the zip's own `.sha256` beside it.
   Use `--target linux` for a Linux tester.
   Do not use the CI `SoulMeter-windows-x86_64` artifact for the gate: it has no manifest.
   Every CI Windows artifact up to `be4f0b6e` also shipped with **no dialogue at all**.
2. **Check the manifest.** `valid_for_gate_t=yes`, `worktree=clean`, `acceptance=strict`,
   `pack_probe=30/30` (or the current dialogue count). Anything else is not a gate build.
3. **Move the zip to the test machine** and check it there:
   `certutil -hashfile SoulMeter-windows-x86_64.zip SHA256` in a Windows command prompt must match
   the `.sha256` file. Unzip the whole folder; `SoulMeter.exe` and `SoulMeter.pck` stay side by side.
4. Fill the packet's **Build and session record** table (zip name, commit SHA, date, Godot 4.7.1).
   If the build changes mid-gate, start a new packet.
5. **Smoke-run it yourself once on the target machine.** That is build QA, not tester evidence.
   - New Game → character creation → intro → the Lower Trial Hall.
   - Leave the Hall for Dom → enter the Four Arms → recruit two companions.
   - Take the North Road → fight the demon vanguard on Dorthkor Road.
   - Save from the pause menu, quit to the main menu, and load it with **Load Game**.
6. Print/copy one **observation form** (packet section) per tester.

## 1. Per session (45–90 min play + ~15 min wrap)

| Step | You do | You say (verbatim) |
|---|---|---|
| Setup | Fresh save: delete `%APPDATA%\Godot\app_userdata\SoulMeter` left by an earlier tester. Default settings, timer ready, consent asked for any recording | — |
| Brief | Hand over control | Packet's facilitator script, verbatim |
| Play | Observe silently; record stalls/questions; NEVER hint, point, or confirm | — |
| First failed cast | Ask once, immediately | **"Why did that cast fail?"** |
| Gauge visibly moves | Ask once, immediately | **"What does this gauge do?"** |
| Mid/late battle (≥3 combatants queued) | Ask once | **"Who acts next, and why?"** |
| After a charge/residue/detonation resolves on a tile | Ask once | **"Explain what just happened on that tile."** |
| Mid-slice, out of combat | Ask only | "Please save, then load that save, and continue." |
| Chapter-complete screen before 45 min | Nothing else: the tester keeps playing in free roam (Continue Exploring) until 45 min (owner item 48a) | **"Keep playing as you like."** |
| Slice end (45 min reached, or the chapter-complete screen after 45 min) | Ask for the mock NG+ rollover: **Begin Mock NG+** is on the chapter-complete screen, and on the pause menu once the chapter is in free roam. Then fill the packet's **Mock NG+ comparison** table | **"Please begin the mock NG+ now."** |
| Same sitting | The §5.1 meter-count re-score question | per amendment §5.1 |

Record all four answers **verbatim**. Do not rephrase, probe, or re-ask. A tester saying
"I can't read that text" is a contrast/legibility note (protocol H3), not a comprehension fail —
log it separately.

Control fact you may give only when asked, because the build does not show it: loading is
**Main Menu → Load Game**; the pause menu only saves.

## 2. Scoring (per #93, ratified)

- Per question, **not averaged**: a majority of testers must answer each of the four
  questions correctly. Averaging is explicitly disallowed.
- 3–5 outside testers total (recruit 6–8 to net that). None may be a project contributor or
  prior slice viewer.
- Session invalid if <45 min, >90 min, a required subsystem never appeared, or you helped.
- G6 save/load and G7 mock-rollover checks stay as the packet records them.

## 3. Scoring sheet (copy per tester)

Tester ID: T__  Date: ____  Build SHA: ________

| # | Question | Verbatim answer | Correct in-game reason | PASS / FAIL |
|---|---|---|---|---|
| 1 | Why did that cast fail? | | | |
| 2 | What does this gauge do? | | | |
| 3 | Who acts next, and why? | | | |
| 4 | Explain what just happened on that tile | | | |

Majority tally (fill after final session): Q1 _/_ · Q2 _/_ · Q3 _/_ · Q4 _/_ →
Gate T-6: **PASS / FAIL**

Sign-off lives in `playtest-packet.md` — its authorization line is what unlocks
region-content merging. This sheet is working paper feeding that record.
