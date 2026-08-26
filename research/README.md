# Research index

This directory records the evidence gathered before Hydra Eval is designed.

## Documents

- [charter.md](charter.md) — purpose, questions, scope, and research method
- [source-register.csv](source-register.csv) — primary-source inventory and review status
- [claim-register.csv](claim-register.csv) — key claims mapped to sources, limits, and confidence
- [agent-skills.md](agent-skills.md) — skill triggering, outcome comparison, scripts, and context efficiency
- [frontier-lessons.md](frontier-lessons.md) — OpenAI, Anthropic, and related evaluation lessons
- [evaluation-tools.md](evaluation-tools.md) — Harbor, Inspect, Promptfoo, and adjacent tools
- [hydra-current-state.md](hydra-current-state.md) — dated read-only audit of existing Hydra evidence
- [findings-and-open-questions.md](findings-and-open-questions.md) — confirmed patterns, tensions, and unresolved choices

## Status labels

- **Documented fact** — directly supported by a cited primary source or observed artifact.
- **Vendor claim** — a company reports a result from its own system or experiment.
- **Inference** — a conclusion drawn by comparing facts; it is not stated directly by a source.
- **Open question** — evidence or a decision is still missing.
- **Decision** — an explicitly approved choice, with approval evidence and date. There are no evaluation-design decisions in this snapshot.

## Source levels

- **A** — reproducible implementation, schema, test, paper, or detailed technical documentation.
- **B** — official engineering guidance or a concrete operating case with useful detail.
- **C** — product announcement or self-reported performance claim.
- **D** — secondary commentary. D-level sources can help discovery but cannot establish a rule alone.

The current register favors A and B sources. A source level describes the source,
not the certainty of every interpretation made from it.

When a source does not state a publication date or expose a versioned document,
the register says `not_stated` or `versionless_live_docs` rather than inventing
precision. The access date then bounds the observation, while fixed repository
artifacts use a commit identifier.

## Research workflow

1. Record the source and access date before using it.
2. Extract only claims relevant to the research questions.
3. Label vendor results and separate them from general lessons.
4. Record prerequisites, failure modes, and missing evidence.
5. Compare sources for agreement and conflict.
6. Leave design choices open until the research corpus and trade-offs are reviewed.

The research snapshot date is **2026-08-26**.
