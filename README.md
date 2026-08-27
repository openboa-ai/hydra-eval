# Hydra Eval

Hydra Eval is the independent evaluation repository for Hydra. It turns the product's intent into project tasks, runs agents in controlled environments, and keeps the evidence needed to decide what should improve next.

## Why

Hydra is meant to help external agents contribute to a project with useful autonomy without losing authority boundaries or outcome visibility. That is a claim to test, not a claim to assume. Hydra Eval keeps the product and the judge separate so a plausible response, a green process, or a vendor claim cannot become the product's evidence by itself.

## What this repository owns

- realistic task definitions and their environments;
- baseline and candidate runs for a named Hydra revision, client, model, and environment;
- deterministic tests and other verifiers;
- reviewed trajectories, artifacts, timing, token use, cost, quality, and safety evidence;
- append-only result records and explicit invalidation notes.

Hydra owns its package and product meaning. The OpenBoa Plugins marketplace owns discovery and installation metadata. Hydra Eval owns what was tested, how it was tested, and what the evidence supports.

## How the evaluation loop works

```text
task (instruction + project environment)
  -> agent run
  -> trajectory, files, actions, and outcome evidence
  -> deterministic verifier and independent review
  -> separate success/quality, time, token, cost, and safety measures
  -> improve the task data, evaluator, or Hydra candidate
```

The first execution client is Codex. Other clients remain visible as `not tested` until a real run exists. Harbor is the first whole-agent job harness; its task and job structure is reused rather than replaced with a Hydra-specific schema. OpenAI and Agent Skills evaluation guidance informs test-case and assertion design, and LangSmith may be used later as a trace projection. None of those tools changes the ownership boundary.

## Current status

Version `0.1.0` adds one deliberately trivial evaluator smoke loop. It runs a Harbor Oracle reference, one Harbor Codex solver trial, a deterministic verifier, and one separate read-only Codex judge. Passing it proves only that the evaluation plumbing works. It is not a Hydra benchmark, a support claim, or evidence that Hydra improves an agent.

Run it from a clean commit with no non-ignored untracked files:

```bash
./scripts/run-smoke.sh
```

The host needs `uv`, Codex CLI with an existing subscription login, and a Docker-compatible daemon with Docker Compose. On macOS the runner can start an installed Docker Desktop or Colima instance, but it does not install host dependencies. When Homebrew Compose exists outside Docker's configured plugin path, the runner exposes it through a temporary Docker configuration instead of changing the user's global Docker settings.

The runner pins Harbor, the Python patch version used to run it, Harbor's resolved dependency constraints, the Codex agent runtime, model, supported low reasoning effort, attempts, concurrency, and retry count. It explicitly sets Docker's runtime platform to the current Docker server platform and records the host OS/architecture, Python platform, container platform, and resolved child-image manifest digest. It also preserves the exact evaluation commit in a small Git bundle and emits sanitized judge timing/usage evidence, so provenance survives a squash merge and measures remain reviewable. The current Luna route rejected `minimal`, so this smoke pins the lowest accepted value, `low`, and never switches models or reasoning levels automatically. The public scorecard also records the constraints checksum and the host `uv` version. The runner uses the existing Codex subscription session without copying credentials into the repository.

## Repository map

```text
EVALUATION.md       # evaluation purpose, loop, vocabulary, and first-run policy
tasks/README.md     # Harbor-compatible task layout and task authoring boundary
results/README.md   # reviewed evidence layout and retention rules
scripts/            # thin smoke runner and evidence validation
judges/             # the smoke judge prompt and structured output schema
VERSION             # evaluator version
AGENTS.md           # contributor contract
SECURITY.md         # safe handling of traces and inputs
```

The generated Harbor `jobs/` directory is local run output and is ignored by Git. Reviewed, sanitized evidence may be copied into `results/` only after a real run.

Reference material: [Harbor tasks](https://www.harborframework.com/docs/tasks), [Harbor eval jobs](https://www.harborframework.com/docs/run-jobs/run-evals), [Agent Skills evaluation](https://agentskills.io/skill-creation/evaluating-skills), [OpenAI eval skills](https://developers.openai.com/blog/eval-skills), and [LangChain's unified agent evaluation stack](https://www.langchain.com/blog/unified-stack-for-evaluating-agents).
