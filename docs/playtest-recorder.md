# Playtest evidence recorder

The playtest evidence recorder is an opt-in helper for Gate T criterion 6 sessions.
It works in exported playtest builds and is not limited to debug builds.

## Enablement

Enable the recorder before starting the game with either method:

```bash
SOUL_METER_PLAYTEST=1 ./SoulMeter.x86_64
```

```bash
./SoulMeter.x86_64 --playtest-record
```

Without the environment variable or command-line argument, the recorder is inert: it
does not create a session directory, connect gameplay signals, process hotkeys, or add
nodes. Recording remains disabled unless the tester explicitly opts in.

## Captured gameplay evidence

The recorder writes gameplay telemetry for:

- scene entry, exit, and elapsed time per scene;
- dialogue start and end, limited to the dialogue resource path and resource title;
- Reputation and Renown ledger writes, plus Soul Meter spends;
- quest offers and resolutions;
- battle start, end, result, and tactical events used to assess cast refusal, CT order,
  Balance/weather, and tile charge, residue, hush, or detonation comprehension;
- successful save and load operations;
- WorldClock phase changes; and
- application of an active mock-NG+ block through the existing rollover seam.

If a requested signal is unavailable in a build, the `session_started` event lists its
category under `uncaptured_categories`; the session continues.

## Facilitator controls

- **F8 — observation note:** pauses the game and opens a note field. Save records the
  timestamped note and attempts to save a PNG screenshot. In a headless session, or if
  screenshot capture fails, the note is still recorded and the build emits a warning.
- **F9 — export now:** refreshes the facilitator markdown record immediately.

The recorder also exports when the window receives a close request and when the
autoload exits.

## Output and evidence handoff

Each enabled run creates a timestamped directory:

```text
user://playtest/<yyyy-mm-dd_hhmmss>/events.jsonl
user://playtest/<yyyy-mm-dd_hhmmss>/T_.md
user://playtest/<yyyy-mm-dd_hhmmss>/note_<timestamp>.png
```

`events.jsonl` is flushed after every event. `T_.md` contains build information from
`BUILD-MANIFEST.txt` beside the executable when present, session duration, observed
subsystem coverage, timestamped notes, and the blank human-answer sections from the
ratified playtest packet.

After the session, the facilitator completes the blank fields and copies the markdown
record into the evidence directory with the assigned anonymous tester number:

```bash
cp "/path/to/session/T_.md" test/manual/gate-t/T1.md
```

Use `T2.md`, `T3.md`, and so on for later valid sessions. Follow
`docs/playtest-protocol.md` and `docs/playtest-packet.md` when validating and
summarizing the evidence.

## Privacy

Record gameplay telemetry only. Never record an OS username, machine name, IP address,
real name, email address, account handle, contact detail, or other personal data. Notes
must describe gameplay behavior and tester comments without identifying the tester.
