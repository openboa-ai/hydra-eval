# Hydra evaluation: current-state audit

This is a read-only observation of the Hydra v0.2 candidate checkout at commit
[`baf0ba3e2cb6b9fe5f90cb3580566f0372aa9597`](https://github.com/openboa-ai/hydra/tree/baf0ba3e2cb6b9fe5f90cb3580566f0372aa9597),
inspected on 2026-08-26. Observations are pinned to the named commit; working-tree
changes were excluded. No Hydra file or GitHub state was changed during this audit.

The v0.2 candidate is not treated here as a released or accepted version.

## What exists

### Decision-policy behavior evaluation

**Observed fact.** The candidate contains 21 fixed behavior cases. The runner
checks skill attribution, human-gate choice, required and forbidden actions,
observations, unknowns, and zero tool calls. Playbook and headline decision
matching are kept as separate telemetry. See the
[runner](https://github.com/openboa-ai/hydra/blob/baf0ba3e2cb6b9fe5f90cb3580566f0372aa9597/scripts/run_behavior_evals.py)
and [evaluation scope](https://github.com/openboa-ai/hydra/blob/baf0ba3e2cb6b9fe5f90cb3580566f0372aa9597/evals/README.md).

The runner prepends an explicit skill invocation to every live behavior trial.
The checked-in case inputs therefore do not test description-based triggering.

### Append-only behavior evidence

**Observed fact.** The runner retains candidate revision and fingerprints,
runner and case fingerprints, Codex launcher identity, timestamps, per-case
token fields, tool-call count, raw criteria, and discovery evidence.

The latest complete result is the v0.1
[`r13` ledger](https://github.com/openboa-ai/hydra/blob/baf0ba3e2cb6b9fe5f90cb3580566f0372aa9597/evals/results/2026-08-25-codex-0.144.5-v2-direct-r13.json):

- 12 of 12 core cases passed;
- 7 of 12 playbook/method values matched exactly;
- behavior cases used 165,207 input tokens and 2,972 output tokens;
- the two discovery controls add 24,267 input and 32 output tokens;
- the full recorded wall-clock interval is about 126.5 seconds;
- model cost and external GitHub, deployment, release, and human-decision effects are unmeasured.

These are historical observations for the named v0.1 candidate, Codex CLI, and
host. They are not a v0.2 baseline.

The latest v0.2 `r14` attempt installed attributable candidate bytes but failed
closed as 21 `unmeasured` cases when model transport was unavailable. See the
[results index](https://github.com/openboa-ai/hydra/blob/baf0ba3e2cb6b9fe5f90cb3580566f0372aa9597/evals/results/README.md).

### Outcome canary foundation

**Observed fact.** Hydra defines one JSONL-to-Markdown CLI scenario, six
acceptance criteria, deterministic commands, exact-head CI and review evidence,
and collaboration observations such as elapsed time, interventions, escalation,
review rounds, and recovery. See the
[scenario](https://github.com/openboa-ai/hydra/blob/baf0ba3e2cb6b9fe5f90cb3580566f0372aa9597/evals/outcome-canary/scenarios/01-jsonl-handoff-cli.json)
and [run schema](https://github.com/openboa-ai/hydra/blob/baf0ba3e2cb6b9fe5f90cb3580566f0372aa9597/evals/outcome-canary/canary-run.schema.json).

No accepted canary run ledger exists in the inspected snapshot. The structure
is evidence of a proposed evaluator, not evidence that the plugin completed the
canary successfully.

### Repository validation and CI

**Observed fact.** Hydra CI runs repository validation and unit tests through
[`validate.yml`](https://github.com/openboa-ai/hydra/blob/baf0ba3e2cb6b9fe5f90cb3580566f0372aa9597/.github/workflows/validate.yml).
It does not run paid live-model comparisons or enforce performance-regression
budgets.

## What is not measured yet

- implicit positive and near-miss negative skill triggering;
- plugin-off versus stable versus candidate paired trials;
- repeated trials, variance, confidence, or flake rate;
- representative outcomes beyond one small CLI scenario;
- v0.2 outcome quality, tokens, time, or cost;
- per-stage time such as model work, tools, CI wait, and review wait;
- cost with model, price snapshot, tool, and CI provenance;
- which loaded instructions or references caused the observed context size;
- model, effort, Codex-version, language, paraphrase, and context-order robustness;
- a common result schema across behavior, outcome, readiness, and future evals;
- automatic comparison against a named baseline.

## Audit conclusion

**Inference.** Hydra already has strong safeguards for attributable,
append-only decision-policy evidence. It does not yet answer the optimization
question: which plugin configuration preserves or improves accepted outcomes
while using fewer tokens and less time?

This conclusion identifies a research gap. It does not select the missing
system's design.
