# Hydra Eval

Hydra Eval is the public research and evidence repository for evaluating
[Hydra](https://github.com/openboa-ai/hydra) and the
`openboa-ai-native-sdlc` plugin.

The repository starts with a question, not a benchmark score:

> Does the plugin help an agent produce a better accepted outcome, with a
> responsible use of tokens and elapsed time?

Quality, tokens, and time all matter. They are recorded separately because a
fast, cheap failure is not a good result. Cost is also useful, but it depends on
pricing and infrastructure that can change.

## Current status

**Research phase.** No evaluation architecture, tool, task suite, scoring rule,
or release gate has been selected. No Hydra version has a Hydra Eval benchmark
score yet.

The first research snapshot contains:

- a [research charter](research/charter.md);
- a reviewable [source register](research/source-register.csv) and
  [claim register](research/claim-register.csv);
- notes on [evaluating Agent Skills](research/agent-skills.md);
- lessons from [frontier-lab evaluation guidance](research/frontier-lessons.md);
- a factual [evaluation-tool landscape](research/evaluation-tools.md);
- a read-only [audit of Hydra's current evaluation coverage](research/hydra-current-state.md);
- [findings, tensions, and open questions](research/findings-and-open-questions.md).

## Current scope

- `hydra-eval` is an independent public research repository.
- This work observes Hydra but does not change the plugin, its CI, or its releases.

The future ownership of tasks, runners, results, and canary environments remains
an open design question.

## Evidence policy

Every material claim should identify whether it is a documented fact, a vendor
claim, an inference, an open question, or an approved decision. Public evidence
must not contain secrets, private repository content, personal data, hidden
grader material, or raw traces that have not been reviewed for disclosure.

See [research/README.md](research/README.md) for the working method and status
labels.

## License

Apache-2.0. See [LICENSE](LICENSE).
