# The Deep Trial — extended-content smoke test

**Scope:** Internal follow-up content after The Broken Muster. It remains disabled in the
external playtest build.

Launch the project with the internal content flag:

```bash
godot --path . -- extended-content
```

## Chapter handoff

- Complete The Broken Muster and choose any Coiljaw ruling → the external-playtest recap is
  skipped and the HUD asks what follows the broken muster.
- Speak to Marshal Coiljaw again → accept **The Deep Trial**; the HUD changes to the new quest
  title, an autosave appears, and the Jawbrace exit unlocks.

## First ledge

- Travel to the Wound lip → the arrival objective advances and the cleaned Jawbrace guard is
  present at its old post.
- Fight the guard → its Pandora-authored affinity, actions, and outcome apply through the
  Balance Gauge; victory records `defeated_cleaned_jawbrace_guard` exactly once.
- Return to Dom → the HUD points back to Coiljaw and save/continue restores that step.

## Ruling

- Choose the Sentinel descent → Sentinels gain standing, Companies lose standing, and the
  consequence ledger records `sentinel-descent`.
- On a fresh run, seal the ledge → Companies gain standing and the ledger records
  `seal-the-ledge`.
- On a fresh centered-Soul run, send both groups → both factions gain standing and the ledger
  records `witnessed-descent`.
- After any ruling → the journal/HUD show The Deep Trial complete and the choice cannot award
  reputation or Renown a second time.
