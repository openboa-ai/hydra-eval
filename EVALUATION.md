# Evaluation design

## Why

The question is not whether an agent can produce a convincing answer. The question is whether Hydra helps an external agent complete meaningful project work with more useful autonomy and no unacceptable loss of safety, authority, or outcome quality.

Evaluation is therefore an independent loop. Hydra changes are candidates; Hydra Eval supplies the work, the comparison, and the evidence.

## What is evaluated

The runtime shape is the same one Hydra describes:

```text
Trigger -> Input -> Agent + candidate -> Output -> Observation
```

- A **trigger** may be a request, situation, event, or alert.
- **Input** is the task instruction plus the managed environment: files, repository state, constraints, context, permissions, and available tools.
- **Output** may be text, files, tool actions, a handoff, a blocked decision, or another observable outcome.
- **Observation** is the verifier, review, or operating check that tells us what actually happened.

The evaluation does not require every candidate to use the same internal workflow. It tests the outcome and the relevant safety properties.

## Harbor vocabulary and layout

The first whole-agent harness is Harbor. Use its terms and native job output:

| Term | Meaning here |
| --- | --- |
| Task | One realistic piece of work with an instruction, environment, and tests |
| Dataset | A named collection of tasks for one evaluation question |
| Trial | One agent attempt on one task |
| Job | A Harbor execution that records configuration, trials, trajectories, and verifier results |
| Verifier | A deterministic test, assertion, or reviewed check of the outcome |
| Result | The reviewed evidence for a candidate, not just a model response |

New tasks should follow Harbor's standard shape:

```text
tasks/<task-name>/
├── README.md
├── instruction.md
├── task.toml
├── environment/
├── tests/test.sh
└── solution/              # optional reference material
```

`instruction.md` expresses the work; `environment/` supplies the managed input and state; `tests/test.sh` checks the result; `task.toml` carries Harbor task metadata and resource settings. Do not add a Hydra-specific task schema while the standard structure is sufficient.

This choice follows the published Harbor task/job model and the practical evaluation guidance from [Agent Skills](https://agentskills.io/skill-creation/evaluating-skills) and [OpenAI](https://developers.openai.com/blog/eval-skills): start with a few realistic cases, capture the run and artifacts, add deterministic checks after seeing real outputs, and keep time and token use visible. [LangChain's unified stack](https://www.langchain.com/blog/unified-stack-for-evaluating-agents) is a useful reference for projecting Harbor runs into trace analysis; it is not a second source of task truth.

## Evaluator smoke before product evaluation

Before comparing Hydra candidates, prove that the evaluator itself can complete one bounded run. The `smoke-question-answer` task is intentionally too easy to measure Hydra: it checks that Harbor can start the agent, preserve its output and ATIF trajectory, run a deterministic verifier, invoke a separate structured Codex judge, record time and token use, and produce sanitized evidence.

The smoke result belongs under `results/smoke/<harbor-job-id>/`. It must always say that it is evaluator plumbing evidence rather than a Hydra score. A failed or partial run remains raw local job output and is not published as a passing result.

The runner uses a ChatGPT-authenticated Codex session. Harbor's `cost_usd`, when present, is recorded as an API-equivalent estimate rather than actual billed cost; actual subscription billing remains `unknown`.

## First Hydra evaluation

Only after the evaluator smoke succeeds, start with two or three small but realistic project tasks that cover different trigger/input/output shapes. Run the same external client and model in two conditions:

1. **Baseline:** no Hydra candidate is installed.
2. **Candidate:** one exact Hydra revision is installed in the same kind of environment.

Use a temporary catalog source for the candidate; marketplace publication is not a prerequisite for evaluation. Freeze the task set, verifier, client version, model, and environment for a comparison. Change one candidate at a time when possible.

Begin with deterministic checks. Add assertions after seeing the first real outputs, so checks describe meaningful intended outcomes instead of imagined formatting. Use a model grader or human review only where a deterministic check cannot answer the question, and preserve its rubric and reviewer context.

## Evidence and measures

Every reviewed result should identify the Hydra revision, evaluation revision, task/dataset, client and version, model, environment, run/job, verifier, and source of truth for each claim. Evaluator smoke results also record the pinned Harbor Python version, dependency-constraints checksum, host runtime platform, container platform, and resolved child-image manifest digest. Preserve the exact evaluation source as a verified Git bundle when ordinary commit ancestry may be lost to squash merging. Preserve Harbor-native results, trajectory, artifacts, and sanitized judge timing/usage evidence where permitted.

Keep these dimensions visible separately:

- task success and output quality;
- elapsed time and retry/recovery time;
- input/output token use;
- model and infrastructure cost;
- safety, authority, and unwanted-action outcomes.

Do not hide a decision behind one composite score at this stage. A later aggregate is only useful if its weights and tradeoffs are explicit and supported by repeated evidence.

## Results and invalidation

Reviewed results belong under `results/hydra/<version>/<result-id>/`. Each result directory may contain the sanitized scorecard and the native artifacts needed to reproduce the claim. It must not contain credentials, private holdout inputs, or unreviewed sensitive traces.

Results are append-only. If a task, verifier, provenance field, or run is wrong, keep the original record and add an invalidation note that explains what no longer supports a claim. Never overwrite a result to make a later candidate look better.

## Client matrix

Codex is the first execution client. Claude Code, Cursor, OpenCode, Hermes, and other clients are future rows in the matrix, not assumed support. A client is tested by a real install and run at a named version; an account login alone is not evidence.

## Out of scope for `0.1.0`

This version does not implement a scheduler, dashboard, benchmark suite, Hydra candidate comparison, RewardKit integration, or automatic release gate. Harbor's job view and the Codex task surface remain the first projections. Add automation only when a measured evaluation need makes it worth the cost.
