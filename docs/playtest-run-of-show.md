# Gate T-6 (#93) — Facilitator run-of-show

One page per session. Print or split-screen this next to
[`playtest-packet.md`](playtest-packet.md) (the fillable evidence record) and
[`playtest-protocol.md`](playtest-protocol.md) (the gate authority).

> **Alignment note (2026-08-28).** The packet, protocol, and this run-of-show now use the
> same ratified Gate T chassis and four-question scoring rule. Do not substitute an older
> Phase 1.5 packet from a prior build or session.

## 0. Before any tester (once per build)

1. **Get the build.** Latest green `main` run of `.github/workflows/test.yml` →
   artifact `SoulMeter-windows-x86_64` (~170 MB zip). CLI:
   `gh run list --branch main --workflow test.yml` (pick newest with conclusion `success`),
   then `gh run download <run-id> -n SoulMeter-windows-x86_64`.
   Contents: `SoulMeter/SoulMeter.exe` + `SoulMeter.pck` + `liblimboai...dll` + READMEs.
   Unzip whole folder; run `SoulMeter.exe` (exe and pck must stay side by side).
   Verified 2026-08-24 on run 31963864373 / commit `53a738f`; artifacts expire ~90 days.
2. Fill the packet's **Build and session record** table (artifact, SHA, date, Godot 4.7.1).
   If the build changes mid-gate, start a new packet.
3. Smoke-run it yourself once on the target machine: New Game boots into Dom, tavern opens,
   travel works, a battle starts. (You playing is not tester evidence; it's build QA.)
4. Print/copy one **observation form** (packet section) per tester.

## 1. Per session (45–90 min play + ~15 min wrap)

| Step | You do | You say (verbatim) |
|---|---|---|
| Setup | Fresh save, default settings, timer ready, consent asked for any recording | — |
| Brief | Hand over control | Packet's facilitator script, verbatim |
| Play | Observe silently; record stalls/questions; NEVER hint, point, or confirm | — |
| First failed cast | Ask once, immediately | **"Why did that cast fail?"** |
| Gauge visibly moves | Ask once, immediately | **"What does this gauge do?"** |
| Mid/late battle (≥3 combatants queued) | Ask once | **"Who acts next, and why?"** |
| After a charge/residue/detonation resolves on a tile | Ask once | **"Explain what just happened on that tile."** |
| Mid-slice | Ask only | "Please save, then load that save, and continue." |
| Slice end | Mock NG+ rollover per packet §6 | — |
| Same sitting | The §5.1 meter-count re-score question | per amendment §5.1 |

Record all four answers **verbatim**. Do not rephrase, probe, or re-ask. A tester saying
"I can't read that text" is a contrast/legibility note (protocol H3), not a comprehension fail —
log it separately.

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
