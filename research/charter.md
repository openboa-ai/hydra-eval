# Research charter

## Purpose

Determine what a trustworthy, useful, and efficient evaluation practice would
need to measure before optimizing Hydra and `openboa-ai-native-sdlc`.

This phase does not select an evaluation framework or define the final
benchmark. Its output is a public evidence base that makes the later design
reviewable.

## Why this research exists

A skill can look correct in prose and still fail in use. It can trigger on the
wrong request, miss the right request, choose an unsafe action, produce a weak
artifact, consume excessive context, or work only under one model and harness.
Optimizing without a baseline and a stable comparison unit can spend more time
and tokens while making the actual outcome worse.

## Primary research questions

1. What does “better” mean for an AI-native SDLC collaborator: task outcome,
   process safety, reviewer judgment, or some combination?
2. How should outcome quality, token use, elapsed time, and cost be observed
   without hiding trade-offs in an arbitrary combined score?
3. How do we test both skill triggering and behavior after the skill is loaded?
4. What must be fixed or recorded about the model, Codex version, reasoning
   effort, plugin bytes, repository revision, sandbox, resources, network,
   concurrency, grader, and task version?
5. Which evidence should come from deterministic tests, model graders, human
   review, trajectories, and real end-state inspection?
6. How many trials are needed to distinguish a real improvement from stochastic
   or infrastructure noise?
7. Which parts can be public, and which tasks, graders, or traces must remain
   private to protect security, privacy, and benchmark validity?
8. What can current tools execute and record, and which OpenBoa-specific needs
   remain outside them?
9. How should an evaluation result remain attributable and comparable after the
   plugin, model, harness, task, or grader changes?

## In scope

- official Agent Skills creation and evaluation guidance;
- frontier-lab guidance on agent evaluation, prompting, tools, and infrastructure noise;
- open evaluation runners, task formats, sandboxes, trajectories, and graders;
- paired baseline/candidate experiments and repeated trials;
- skill description triggering and post-trigger outcome quality;
- quality, safety, tokens, time, cost, and human-attention evidence;
- read-only inventory of existing Hydra evaluation artifacts;
- public evidence hygiene and reproducibility limits.

## Out of scope for this phase

- selecting Harbor, Inspect, Promptfoo, or another runner;
- defining a single Hydra Eval score;
- setting pass thresholds or release gates;
- moving or rewriting Hydra's current evaluators;
- running a paid live-model benchmark;
- creating a private canary or storing private task content here;
- changing the Hydra plugin, CI, rulesets, or releases.

## Comparison discipline

Research notes use the following provisional vocabulary because it is already
common in the cited literature:

- **Task:** the instruction, starting state, and success criteria.
- **Trial:** one agent attempt at one task under one named configuration.
- **Suite:** a group of tasks serving a stated evaluation purpose.
- **Outcome:** the verified final state or artifact, not the agent's claim of completion.
- **Trajectory:** the messages, reasoning summaries where available, tool calls,
  events, and intermediate state observed during a trial.
- **Grader:** code, model, or human judgment that turns evidence into a finding or score.
- **Harness:** the runtime that presents tasks, executes the agent, captures evidence,
  and invokes graders.

These terms do not imply that any one vendor's hosted product will be adopted.

## Completion conditions for the research phase

The research phase is ready for a design review when:

- every major finding is supported by at least two independent primary sources
  or is explicitly marked as a single-source observation;
- marketing claims are separated from documented behavior and local observations;
- the existing Hydra baseline and its unmeasured areas are recorded without
  rewriting historical evidence;
- tool capabilities and limitations are compared without selecting a winner;
- conflicts and unknowns are visible, including public/private evidence boundaries;
- the later design choices that require human judgment are listed explicitly.
