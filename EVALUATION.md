# Evaluation design

## Why

The question is not whether an agent can produce a convincing answer. The question is whether Hydra helps an external agent complete meaningful organizational work with more useful autonomy and no unacceptable loss of safety, authority, or outcome quality.

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

## First evaluation

Start with two or three small but realistic tasks that cover different trigger/input/output shapes. Run the same external client and model in two conditions:

1. **Baseline:** no Hydra candidate is installed.
2. **Candidate:** one exact Hydra revision is installed in the same kind of environment.

Use a temporary catalog source for the candidate; marketplace publication is not a prerequisite for evaluation. Freeze the task set, verifier, client version, model, and environment for a comparison. Change one candidate at a time when possible.

Begin with deterministic checks. Add assertions after seeing the first real outputs, so checks describe meaningful intended outcomes instead of imagined formatting. Use a model grader or human review only where a deterministic check cannot answer the question, and preserve its rubric and reviewer context.

## Evidence and measures

Every reviewed result should identify the Hydra revision, evaluation revision, task/dataset, client and version, model, environment, run/job, and source of truth for each claim. Preserve the Harbor-native `config.json`, `result.json`, trajectory, and artifacts where permitted.

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

## Out of scope for `0.0.0`

This foundation does not implement a runner, scheduler, model grader, dashboard, benchmark score, or automatic release gate. Harbor's job view and the Codex task surface are sufficient projections for the first feasibility run. Add automation only when a measured evaluation need makes it worth the cost.
