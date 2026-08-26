# Evaluation-tool landscape

No tool has been selected. This comparison records what official documentation
says the tools can do and where OpenBoa-specific evaluation would still require
work.

| Tool or benchmark | Documented strengths | Documented limits or research gaps | Current status |
| --- | --- | --- | --- |
| [Harbor](https://www.harborframework.com/docs/core-concepts) | Container tasks combine instruction, environment, and verifier; jobs run trials; adapters include Codex CLI and other coding agents; artifacts, rewards, timing, tokens, and trajectories can be retained. | Score validity comes from the task and verifier. Networking defaults to public when omitted, verification shares the agent container unless separate mode is selected, and whole-plugin behavior may need a custom adapter. | Candidate to study; not selected. |
| [Inspect AI](https://inspect.aisi.org.uk/) | Composable datasets, agents, scorers, epochs, sandboxes, limits, logs, confidence metrics, and dataframe analysis; bridges include external coding agents. | Host-side Python is outside the sample sandbox unless explicitly delegated. Custom Compose can restore outbound networking. No first-party paired-difference statistical test was found in the reviewed docs. | Candidate to study; not selected. |
| [Promptfoo coding-agent evals](https://www.promptfoo.dev/docs/guides/evaluate-coding-agents/) | Provider and app-path regression suites, assertions, repeats, latency and cost checks, and integrations for coding agents. OpenAI currently points to Promptfoo for committed app evals. | A provider adapter and application-specific graders are still required; it does not define OpenBoa's outcome, authority, or evidence semantics. | Candidate to study; not selected. |
| [SkillsBench](https://www.skillsbench.ai/) | Paired skill/no-skill tasks, reproducible environments, deterministic verifiers, repeated trials, and skill-focused comparison. | Public benchmark tasks do not cover OpenBoa's specific workflow, authority, GitHub, or product outcomes. Reported results are tied to tested model/harness combinations. | External reference slice; not an OpenBoa benchmark. |
| [Terminal-Bench](https://arxiv.org/pdf/2601.11868) | Executable terminal tasks through Harbor, outcome-oriented verification, repeated runs, and confidence intervals. | Public tasks face contamination and reward-hacking risk; terminal problem solving is only one slice of an SDLC collaborator. | External-validity reference; not a direct plugin eval. |
| [SWE-bench](https://github.com/SWE-bench/SWE-bench/blob/main/docs/guides/evaluation.md) | Reproducible repository bug-fix tasks and deterministic patch grading. | Native grading sees the final patch, not complete tokens, time, trajectory, routing, authority, or external effects. | Coding-outcome reference; not sufficient alone. |
| [LangSmith](https://docs.langchain.com/langsmith/evaluate-llm-application) | Datasets, experiments, comparative evaluation, traces, latency, tokens, and production feedback for LangSmith applications. | Hosted platform and application integration introduce data-governance and portability questions. | Adjacent hosted option; not selected. |
| [Braintrust](https://www.braintrust.dev/docs/evaluate/run-evaluations) | Versioned experiments, dataset/scorer comparisons, logs, and CI-oriented evaluation. | Hosted service and SDK adoption introduce the same evidence-export, cost, and lock-in questions. | Adjacent hosted option; not selected. |

## Harbor: facts that matter

- A Harbor task contains an instruction, an environment, and a verifier; a trial
  is one attempt and a job runs one or more trials. See
  [core concepts](https://www.harborframework.com/docs/core-concepts).
- Local or Git-hosted skills can be injected, and the job lock records source
  provenance and content digests. See
  [skills](https://www.harborframework.com/docs/run-jobs/skills).
- The [ATIF trajectory format](https://www.harborframework.com/docs/agents/trajectory-format)
  can record messages, tool calls and results, token and cost fields, and
  subagent structure when the adapter supplies them.
- Verifiers emit scalar or named rewards, while a dataset can provide a custom
  aggregation function. See [metrics](https://www.harborframework.com/docs/datasets/metrics).
- [Regrading](https://www.harborframework.com/docs/run-jobs/regrade) can apply a
  changed verifier to retained artifacts without rerunning the agent; it does
  not evaluate a changed skill.

**Inference.** Harbor is an execution and evidence substrate, not an independent
definition of quality.

## Inspect AI: facts that matter

- Inspect records per-sample model usage, configured cost, total and working
  time, retries, messages, events, state, and scores. See its
  [log reference](https://inspect.aisi.org.uk/reference/inspect_ai.log.html) and
  [dataframe support](https://inspect.aisi.org.uk/dataframe.html).
- Built-in metrics include means, variance, standard error, confidence intervals,
  frequency, and inter-rater agreement. See
  [metrics](https://inspect.aisi.org.uk/metrics.html).
- Generated Docker configurations disable networking, but a custom Compose file
  replaces that secure default. See
  [sandboxing](https://inspect.aisi.org.uk/sandboxing.html).
- Exported run configuration, source revision, package versions, task versions,
  and seeds improve reproducibility, but changing remote models and services
  remain outside the frozen record.

**Inference.** Inspect offers rich experiment analysis, but the evaluator still
has to define paired comparisons and OpenBoa-specific outcome semantics.

## Questions the tools do not answer for us

- What is the accepted outcome for each OpenBoa task family?
- Which authority violations are hard failures even if the artifact is correct?
- How is a full Codex plugin, including manifest, hooks, rules, and connectors,
  compared rather than only a skill folder?
- Which traces can safely be public?
- What is the minimum public suite and what remains a private holdout?
- What statistical difference is large enough to justify a plugin change?
- Which tool remains simplest once the actual task suite exists?
