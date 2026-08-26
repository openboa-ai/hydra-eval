# Evaluating and optimizing Agent Skills

This note summarizes the official Agent Skills guidance and related benchmark
evidence. It does not define Hydra Eval's final method.

## Two different problems

**Documented fact.** The Agent Skills guidance treats these as separate tests:

1. Does the description cause the skill to load for the right requests and stay
   out of unrelated requests?
2. Once loaded, does the skill improve the result?

The distinction matters because Codex first sees skill metadata and reads the
full skill only after selection. OpenAI describes this as progressive
disclosure in [Build skills](https://learn.chatgpt.com/docs/build-skills).

## Description triggering

[Optimizing skill descriptions](https://agentskills.io/skill-creation/optimizing-descriptions)
recommends realistic positive and negative queries, including near misses that
share keywords. Its example process starts around 20 queries, balances
should-trigger and should-not-trigger cases, repeats each query, and keeps a
fixed training/validation split.

**Inference.** A description change cannot be evaluated only by reading the
description. Trigger recall, false positives, phrasing variation, language, and
confusion with adjacent skills are observable behaviors.

## Outcome comparison

[Evaluating skills](https://agentskills.io/skill-creation/evaluating-skills)
recommends:

- realistic prompts and edge cases;
- a clean context for each run;
- the same prompt with the skill and without it, or against a previous version;
- deterministic assertions where possible;
- model grading or blind human comparison for qualities that code cannot judge;
- saved outputs, grading, token totals, duration, and aggregate results;
- multiple runs and standard deviation as the suite matures;
- inspection of failed assertions, outliers, and trajectories rather than only averages.

The guidance suggests beginning with two or three cases to learn quickly. This
is a starting point, not evidence that a mature suite needs only three cases.

## Context and script efficiency

[Agent Skills best practices](https://agentskills.io/skill-creation/best-practices)
states that every skill token competes with the task, conversation, and other
context. It favors non-obvious project knowledge, progressive disclosure, and
procedures grounded in real failures over generic advice.

[Using scripts in skills](https://agentskills.io/skill-creation/using-scripts)
recommends moving repeated, deterministic work into tested scripts. It also
calls for pinned dependencies, non-interactive interfaces, concise help,
structured output, actionable errors, idempotency, dry runs, safe defaults,
bounded output, and meaningful exit codes.

**Inference.** A script is an optimization only when evidence shows that it
replaces repeated reasoning, tool calls, or retries without reducing outcome
quality or portability.

## SkillsBench evidence

[SkillsBench](https://www.skillsbench.ai/) uses paired runs with and without
skills inside reproducible task environments. Its launch analysis reports that
skill benefit varies by task, model, and harness, and that some skills reduce
performance. These are benchmark observations, not universal laws.

Useful lessons to investigate further:

- measure marginal benefit against a no-skill or stable-skill baseline;
- keep tasks, graders, and environments versioned;
- test the same skill across more than one model or harness before claiming portability;
- preserve failed runs rather than reporting only a favorable aggregate.

## Open questions for Hydra

- What are realistic should-trigger and near-miss requests for the SDLC skill?
- Which requests require the whole plugin rather than only a `SKILL.md` bundle?
- What represents a true accepted outcome for planning, review, implementation,
  recovery, and GitHub workflow tasks?
- How should reference loading be observed without exposing private prompts or
  relying on unavailable hidden reasoning?
- Which repeated work in the current traces, if any, is a proven candidate for a script?
- How much variance comes from the skill versus the model, Codex, repository,
  and execution environment?
