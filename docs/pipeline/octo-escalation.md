# `/octo:` escalation policy — when multi-model consensus earns its cost

**Status:** the working rule for this repo. Closes #41.
**Related:** [maker-checker.md](maker-checker.md) (#40).

Verified against the live install on 2026-08-06: `octo` 9.56.1, config at
`~/.claude-octopus/config/providers.json`.

## Default: stay Claude-native

Claude-native is the default for essentially all work in this repo. Escalation to `/octo:`
multi-model consensus is the exception, and it must be justified by the *kind* of question, not
by the size of the task. A large refactor is still Claude-native. A one-line change that resolves
a canon question is not.

The reason is narrow: a second model is only worth its cost when the failure mode is **being
confidently wrong in a way another mind would catch** — not when the failure mode is effort.

## Escalate when

**1. The decision writes canon.** Anything touching `[CANON]` in the design doc, the lore vault's
`canon/` or `cosmology/`, or an entry in `canon/open-questions.md`. These are expensive to
reverse because content gets authored on top of them. The combat-identity ratification and the
#133 target-relation gamble curve are the precedents.

**2. Numbers that a sweep can contradict.** Balance magnitudes, curves, thresholds. The #133
curve was ratified and then *failed its own simulation sweep* — it was a ramp, not a gamble.
An independent model asked to attack the numbers is cheap next to authoring content against a
broken curve.

**3. An architectural seam that is hard to unwind.** Choices that many callers will bind to:
the FR-105 grid-swap seam, the `TurnScheduler` seam, the save schema. Not "which file does this
function live in."

**4. A ratified plan and its implementation have diverged** and it is unclear which is wrong.
This is the case where Claude-native review is structurally weakest, because the same reasoning
that produced the divergence reviews it.

**5. Security judgement on untrusted input.** Save/payload deserialization especially. PR #130
is the standing example of a plausible-sounding hardening change that broke loading.

## Do not escalate for

- Routine implementation with clear acceptance criteria — that is Codex's job as a Maker, which
  is delegation, not consensus.
- Test writing, boilerplate, docs, mechanical refactors.
- Anything where the objective gate (the gdUnit4 suite) already settles the question. If a
  command can answer it, run the command; a panel of models is a worse oracle than a test.
- Bug triage where the root cause is reachable by reading the code. Consensus on a guess is
  still a guess.

## What is actually available here

The premise in #41 — *"only Claude+Codex are live providers (no Gemini/Copilot/etc. credentials)"* —
**is out of date.** Seven providers are configured:

| Provider | Configured | Notes |
|---|---|---|
| `codex` | yes | `gpt-5.6-sol`. Pinned for `deliver`, `review`, and `security:reasoning` phases. |
| `claude` | yes | native. |
| `gemini` | yes | `GEMINI_API_KEY` set, CLI present. **See reliability warning.** |
| `agy` | yes | Gemini-family; pinned for the `research` phase. |
| `perplexity` | yes | pinned for the `researcher` role. |
| `opencode` | yes | tiered budget/standard/premium. |
| `openai-compatible-agent` | yes | `OPENAI_COMPAT_*` env is populated. |

Current routing, verbatim from `providers.json`:

```
phases: deliver→codex:default  review→codex:default  security→codex:reasoning  research→agy
roles:  researcher→perplexity
```

The last smoke test recorded `gpt-5.6-sol:gemini-3.1-pro-preview:grok-4-20`.

### Reliability warning — this is the part that constrains the policy

`~/.claude-octopus/provider-fallbacks.log` tallies, across all logged runs:

```
  8  provider=gemini   status=fallback   "Round 1 agent did not complete successfully"
  2  provider=claude   status=fallback
  0  provider=codex
```

Gemini has fallen back on **every logged attempt**. So while more than two providers are
*configured*, the only dependable second opinion in practice is **Codex**, which is also what the
routing already pins for `deliver`/`review`/`security`.

The practical consequence for this policy: **treat escalation as "Claude + Codex adversarial,"
and treat any Gemini/agy leg as best-effort.** Do not design a workflow whose correctness depends
on a third independent voice arriving — it usually will not. If a decision genuinely needs three
independent minds, the third is the human, not a provider.

DeepSeek is a special case: it is reachable only via OpenRouter
(`deepseek/deepseek-r1-0528`), and `OPENROUTER_API_KEY` is **not** set. `DEEPSEEK_API_KEY` alone
does nothing for octopus. `config/deepseek-routing.sh` exists to cut implementation work over to
DeepSeek, but it is not active.

## How to escalate

- `/octo:council` — advice and decision support on a specific question.
- `/octo:debate` — structured adversarial argument; the right tool for triggers 1, 2, and 4.
- `/octo:review` / `/octo:security` — escalation past the Claude-native `/code-review` and
  `/security-review` when the change matches trigger 5.
- `/octo:preflight` — check provider health *before* relying on a multi-provider run, given the
  Gemini record above.

## Recording the outcome

An escalated decision is only worth its cost if the result is durable. Per the working agreement:
the ruling goes to the vault (or the design doc / `docs/` if it is canon), and the stable,
evidence-backed standard goes to MuninnDB. A consensus that lives only in a chat transcript will
be re-litigated in a month.
