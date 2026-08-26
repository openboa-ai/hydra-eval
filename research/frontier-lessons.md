# Frontier-lab evaluation lessons

This note uses official OpenAI and Anthropic sources. Numeric results reported
by a vendor are labeled as vendor claims rather than general rules.

## Evaluate the system, not only the final answer

**Documented fact.** [OpenAI agent evals](https://developers.openai.com/api/docs/guides/agent-evals)
and [trace grading](https://developers.openai.com/api/docs/guides/trace-grading)
cover tool calls, handoffs, and other execution events in addition to final
output. [Anthropic's agent-eval guide](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
separates task, trial, transcript or trajectory, verified outcome, grader, and harness.

**Inference.** An evaluation result describes a tested configuration: model,
agent scaffold, instructions and skills, tools, task, environment, and grader.
It should not be presented as a property of one component in isolation.

## Outcome and trajectory answer different questions

**Documented fact.** Anthropic advises grading what changed in the environment
rather than trusting an agent's self-report. It also recommends transcript
graders for behavior that the final state cannot reveal. OpenAI trace grading
likewise evaluates the execution path.

**Inference.** Outcome evidence asks whether the job was done. Trajectory
evidence asks whether it was done safely, within scope, and through a path that
can be trusted and improved. Neither replaces the other.

## Use the simplest suitable grader

OpenAI's [evaluation best practices](https://developers.openai.com/api/docs/guides/evaluation-best-practices)
and Anthropic's [test guidance](https://platform.claude.com/docs/en/test-and-evaluate/develop-tests)
favor deterministic checks for objective properties and model or human judgment
for semantic qualities. Both sources warn that model judges need clear rubrics
and calibration. OpenAI also notes position and verbosity bias.

**Inference.** A model grader is another measured component, not ground truth.
Its prompt, model, order, and agreement with human labels belong in provenance.

## Repeated trials and suite purpose

Anthropic distinguishes a challenging capability suite from a near-perfect
regression suite. It recommends multiple trials because agent behavior is
non-deterministic and distinguishes `pass@k` from repeat-reliability measures
such as `pass^k`.

**Inference.** A release regression question and an exploratory “can this ever
work?” question need different interpretations even when they share tasks.

## Quality, tokens, time, and cost

The Anthropic guide lists task outcomes alongside turns, tool calls, tokens, and
latency. The Agent Skills guidance stores total tokens and duration per run.
[OpenAI model guidance](https://developers.openai.com/api/docs/guides/latest-model)
recommends benchmarking quality, token use, and end-to-end latency while changing
one instruction or tool group at a time.

**Vendor claim.** OpenAI reports that leaner prompts improved scores and reduced
tokens and cost in one internal coding-agent sample. The same page says these
ranges are directional and should be validated on representative local tasks.

**Inference.** Efficiency is meaningful only relative to an accepted outcome.
Quality and safety should remain visible rather than being averaged away by low
token use or short duration.

## Infrastructure is an experimental variable

**Vendor observation.** Anthropic reports in
[Infrastructure noise](https://www.anthropic.com/engineering/infrastructure-noise)
that CPU and memory limits changed Terminal-Bench scores in its experiments.
It also identifies concurrency, timeout, network, and execution time as possible
confounders.

**Inference.** Small score changes are not credible without resource and runtime
provenance, repetitions, and uncertainty. Wall time should not be compared
without controlling or reporting queueing, retries, and provider load.

## Baseline before optimization

OpenAI's current [Codex eval use case](https://learn.chatgpt.com/use-cases/ai-app-evals)
recommends a committed Promptfoo suite that exercises the application path users
hit, establishes a baseline before changing production behavior, and turns
repeated manual checks into regression cases.

OpenAI's hosted Evals dashboard and related hosted workflow are now listed in
[OpenAI deprecations](https://developers.openai.com/api/docs/deprecations), with
Promptfoo identified as the migration path.

**Inference.** Long-lived evidence should be portable task cases, rubrics,
artifacts, trajectories, and result records rather than dependence on one hosted
dashboard.

## Security and disclosure

**Documented risk.** The
[Terminal-Bench paper](https://arxiv.org/pdf/2601.11868) identifies contamination
and reward-hacking risks for public, internet-enabled tasks. The
[Harbor trajectory format](https://www.harborframework.com/docs/agents/trajectory-format)
and [Inspect log schema](https://inspect.aisi.org.uk/reference/inspect_ai.log.html)
can retain messages, tool calls, tool results, and artifacts; those fields can
contain sensitive material depending on the task.

**Inference.** Public traces need disclosure review, and publishing tasks or
graders can weaken their value as unseen tests.

**Open question.** Hydra Eval needs a later, explicit decision about what can be
public, what must be redacted, and whether a private holdout suite is needed.
