# Findings, tensions, and open questions

## Patterns supported by the current sources

### 1. The measured object is a configuration

Across OpenAI, Anthropic, Harbor, Inspect, and SkillsBench, measured results are
shown to depend on combinations of model, harness, task, tools, environment,
and grader.

**Inference.** A result should name the complete tested configuration. “The
skill scored X” is too broad unless everything else is fixed and attributable.

### 2. Triggering and task performance are separate

The Agent Skills guidance explicitly evaluates whether a skill loads and whether
it improves output after loading. Hydra currently measures explicit invocation
but not description-trigger quality.

**Inference.** A strong skill that rarely loads and a weak skill that always
loads fail in different ways and need different experiments.

### 3. Outcome and trajectory are complementary

Final-state tests can prove that an artifact works. Trajectories can reveal
unsafe calls, unnecessary retries, ignored boundaries, or hidden grader gaming.

**Inference.** Neither a plausible transcript nor a passing process exit is
completion evidence by itself.

### 4. Quality, tokens, and time should remain visible

Multiple sources record outcome metrics alongside tokens and duration. None of
the reviewed primary sources establishes a universal weighted score for all
three.

**Inference.** The research should compare trade-offs openly. Whether quality
and safety become gates followed by a Pareto comparison is a design question,
not a settled rule.

### 5. Repetition and environment control matter

Anthropic, Terminal-Bench, SkillsBench, Harbor, and Inspect all support or
recommend repeated runs and environment provenance. Infrastructure itself can
change observed performance.

**Inference.** A one-run token or time improvement is an observation, not yet a
reliable optimization result.

### 6. Deterministic grading should carry objective claims

Frontier-lab guidance prefers code checks for objective state and model or human
judgment for qualities that cannot be encoded reliably.

**Inference.** A model judge should not replace tests that can directly inspect
the artifact, exact revision, permissions, or external effect.

### 7. Portable evidence is more durable than one hosted dashboard

Tools change, model aliases move, and OpenAI's hosted Evals workflow is being
retired. Open formats, committed cases, content digests, artifacts, and
trajectories can outlive one service.

**Inference.** Portability is a requirement to investigate, not proof that a
home-grown runner is better than every framework.

## Tensions in the evidence

### Small start versus representative suite

Agent Skills suggests two or three cases for an initial iteration. Anthropic
reports 20–50 tasks as a useful starting dataset for an agent eval. These are
not necessarily contradictory: one optimizes learning speed at the beginning,
while the other aims for broader coverage. Hydra Eval has not decided its suite
size.

### Final state versus prescribed path

Terminal-Bench emphasizes final container state, while trace grading evaluates
the path. Over-prescribing the path can reject valid agent strategies; ignoring
the path can accept unsafe or out-of-scope behavior. Which path properties are
true requirements remains open.

### Public reproducibility versus benchmark integrity

Publishing tasks and graders improves auditability but can enable contamination,
grader gaming, or disclosure of security-sensitive behavior. A public corpus
and a private holdout may serve different purposes, but that split has not been
approved.

### Rich platform versus minimal owned evidence

Harbor and Inspect offer deep execution and telemetry. Promptfoo offers a
lighter app-path regression workflow. Hosted platforms add experiment views and
observability. Each reduces some implementation work while adding integration,
version, data-governance, or portability costs.

## Questions that require more research

- Which OpenBoa task families are representative enough to prevent optimizing
  only the current 12 decision cases or one CLI canary?
- How should planning, implementation, review, recovery, GitHub operations, and
  delivery observation be graded without forcing one exact workflow?
- Can a full Codex plugin be evaluated faithfully through existing skill-only
  adapters, or is a dedicated plugin adapter necessary?
- Which Codex JSONL events and usage fields remain stable across versions?
- How should active execution time, provider wait, CI wait, and human review wait
  be separated?
- How should token counts be compared across different tokenizers and model families?
- Which cost sources are observable: model, tool calls, sandboxes, CI, and human attention?
- How should model judges be calibrated, blinded, and checked for disagreement?
- Which raw traces are safe to publish after redaction?
- What evidence is needed to detect reward hacking or accidental grader leakage?

## Questions that require a human decision later

- What kinds of quality or safety regression are never acceptable for an
  efficiency gain?
- Should public transparency or private holdout integrity take priority for each
  task family?
- Which tools and hosted services are acceptable from cost, data, and lock-in perspectives?
- What minimum evidence is required before Hydra adopts an optimized skill or
  releases a new plugin version?
- Who may change benchmark tasks, graders, thresholds, and historical result presentation?

No answer in this file is an approved design decision.
