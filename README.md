# Hydra Eval

Hydra Eval is the independent evaluation repository for Hydra. It turns the product's intent into realistic tasks, runs the same task with and without a Hydra candidate, and keeps the evidence needed to decide what should improve next.

## Why

Hydra is meant to increase an agent's useful responsibility without losing authority boundaries or outcome visibility. That is a claim to test, not a claim to assume. Hydra Eval keeps the product and the judge separate so a plausible response, a green process, or a vendor claim cannot become the product's evidence by itself.

## What this repository owns

- realistic task definitions and their environments;
- baseline and candidate runs for a named Hydra revision, client, model, and environment;
- deterministic tests and other verifiers;
- reviewed trajectories, artifacts, timing, token use, cost, quality, and safety evidence;
- append-only result records and explicit invalidation notes.

Hydra owns its package and product meaning. The OpenBoa Plugins marketplace owns discovery and installation metadata. Hydra Eval owns what was tested, how it was tested, and what the evidence supports.

## How the evaluation loop works

```text
task (instruction + environment)
  -> baseline agent run
  -> Hydra candidate agent run
  -> trajectory, files, actions, and outcome evidence
  -> deterministic verifier and optional review
  -> separate success/quality, time, token, cost, and safety measures
  -> keep, reject, or change the next candidate
```

The first execution client is Codex. Other clients remain visible as `not tested` until a real run exists. Harbor is the first whole-agent job harness; its task and job structure is reused rather than replaced with a Hydra-specific schema. OpenAI and Agent Skills evaluation guidance informs test-case and assertion design, and LangSmith may be used later as a trace projection. None of those tools changes the ownership boundary.

## Current status

This repository starts at `0.0.0`. It contains the evaluation foundation and file layout only. There is no runner, benchmark score, model grader, or claim that a Hydra version has passed. No result is created until a real task run has been reviewed and its provenance is complete.

## Repository map

```text
EVALUATION.md       # evaluation purpose, loop, vocabulary, and first-run policy
tasks/README.md     # Harbor-compatible task layout and task authoring boundary
results/README.md   # reviewed evidence layout and retention rules
VERSION             # repository foundation version: 0.0.0
AGENTS.md           # contributor contract
SECURITY.md         # safe handling of traces and inputs
```

The generated Harbor `jobs/` directory is local run output and is ignored by Git. Reviewed, sanitized evidence may be copied into `results/` only after a real run.

Reference material: [Harbor tasks](https://www.harborframework.com/docs/tasks), [Harbor eval jobs](https://www.harborframework.com/docs/run-jobs/run-evals), [Agent Skills evaluation](https://agentskills.io/skill-creation/evaluating-skills), [OpenAI eval skills](https://developers.openai.com/blog/eval-skills), and [LangChain's unified agent evaluation stack](https://www.langchain.com/blog/unified-stack-for-evaluating-agents).
