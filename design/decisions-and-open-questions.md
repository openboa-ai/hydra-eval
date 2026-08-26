# Design decisions and open questions

## Status language

- **Recommended:** part of this design and ready for whole-design review.
- **Conditional:** recommended only after named evidence is produced.
- **Pilot decision:** determined from calibration, not guessed now.
- **Human decision:** changes purpose, risk tolerance, authority, private access,
  or public effect and therefore cannot be chosen by the evaluator alone.

None of these entries means the software or GitHub control already exists.

## Recommended decisions

### D1 — Evaluate the collaborator, not isolated text

**Recommended.** Hydra is successful when an agent leads bounded real work to an
accepted and observed outcome, uses human attention for the right decisions,
and avoids forbidden effects. Answer style and playbook-name matching are
diagnostic telemetry, not the product objective.

### D2 — Keep evaluator authority outside Hydra

**Recommended.** Hydra owns the product and local deterministic validation.
`hydra-eval` owns public task meaning, adapters, graders, comparisons, and
sanitized append-only evidence. Protected private orchestration owns validation,
sealed holdouts, raw traces, and short-lived credentials. A separate synthetic
private repository is the canary target.

The candidate cannot change or sign the evidence used to accept it.

### D3 — Use direct Codex as the v1 CLI reference path

**Recommended.** Install the exact full Hydra plugin into an isolated Codex home
and use direct [`codex exec --json`](https://learn.chatgpt.com/docs/non-interactive-mode)
trials as the CLI reference runner. This exercises the actual CLI plugin path
more faithfully than injecting one skill file into a generic harness. It does
not prove Desktop, Scheduled task, GitHub connector, or Actions behavior; those
require separate capability profiles and canaries.

### D4 — Use layers, not one benchmark

**Recommended.** Integrity, plugin install/upgrade/rollback, implicit routing,
loaded behavior, executable outcomes, recovery/fault injection, real GitHub
canaries, and post-release observation answer different questions. A pass in one
layer cannot stand in for another.

### D5 — Compare stable and candidate at the same time

**Recommended.** Release evidence is paired stable-versus-candidate on identical
tasks and states. No-plugin runs establish Hydra's marginal value at calibration,
major releases, and periodic checks. They expire after a declared age or any
material model, Codex, tool, permission, or environment change. Historical
`r13` remains evidence but is not the current baseline.

### D6 — Keep quality, safety, tokens, time, cost, and attention separate

**Recommended.** Integrity and critical safety are hard gates. Quality must be
superior or non-inferior within a predeclared practical margin. Only then are
tokens, time, cost, and human attention compared on a Pareto frontier. Hydra Eval
does not publish a universal combined score.

### D7 — Let agents run the routine loop

**Recommended.** Within approved budgets, agents may run evaluation, retry clear
infrastructure failures, diagnose, reject a candidate, try the next bounded
hypothesis, publish a redacted report inside the approved disclosure policy, and
advance through automated stages.

One trusted budget ledger atomically reserves global and per-run token, spend,
and concurrency capacity before any scheduled or on-demand dispatch.

The human is not recorded ceremonially on every run. Human attention is used
only for policy, a real trade-off, new authority or private access, an exception,
and the exact public release effect.

### D8 — Separate eligibility from release

**Recommended.** `eligible`, `human-approved`, `promoted`, and `observed` are
different states. A green check or eligible scorecard is never described
as merged, released, or successful in production.

### D9 — Make evidence attributable and append-only

**Recommended.** Every result names product, evaluator, model, Codex, task,
grader, installation/adoption profile, managed instructions, hook trust, Codex
surface, environment, network, permissions, limits, and price provenance.
Unknown, unsupported, invalid, and infrastructure-error states are retained.
Regrading or repricing creates linked derived evidence instead of rewriting a
historical run.

### D10 — Bind and isolate the candidate build

**Recommended.** The trusted evaluator fetches the exact Git tree and builds the
bundle; it does not trust a candidate-produced archive. The attestation binds
commit, tree, builder, bundle, marketplace, and installed digests. Candidate
scripts and hooks execute only in managed disposable containment with no host
socket, default-deny egress, and task-scoped model access.

### D11 — Treat GitHub checks as a security boundary

**Recommended.** A release-authoritative check must come from trusted
base-controlled evaluator code and bind source identity, evaluator revision,
candidate head, and artifact digest. Candidate-controlled CI is compatibility
evidence. A display name alone is not trust.

Every GitHub write also requires an atomic effect lease and append-only intent,
response, and readback records; a run identifier by itself is not idempotency.

### D12 — Publish summaries, protect raw material

**Recommended.** Public evidence includes reproducible configuration, criterion
results, uncertainty, metrics, checksums, and reviewed redacted examples. Hidden
tasks, graders, secrets, private repository data, and unreviewed raw traces stay
in a protected plane with retention and access controls.

A sealed holdout exposes only an overall signed or attested
`pass`/`fail`/`invalid` result. Per-case details, counts, examples, and timing or
token side channels remain private.

### D13 — Optimize one causal idea at a time

**Recommended.** Every optimization starts from measured evidence, makes one
hypothesis-driven change, declares the expected effect and guardrails, and runs
from cheap smoke to public regression to private validation. The frozen candidate
then receives one sealed-holdout check and a canary. A new candidate revision
starts a new experiment and cannot reuse an opened holdout for a confirmatory
claim.

## Conditional tool decisions

### T1 — Harbor outcome backend

**Conditional.** Adopt Harbor as the containerized repository-outcome backend
only after at least five representative task families prove interface
conformance with direct Codex for full-plugin installation, artifacts,
deterministic outcome, failure classification, and required trajectory fields.
Use repeated A/A runs to set per-dimension token and timing tolerances, and keep
direct-Codex sentinel comparisons for each authoritative task type. Five tasks
alone do not prove statistical equivalence. Pin Harbor's version, task archive
digest, image, resources, and explicit network policy. Use a separate verifier
environment.

If parity fails, keep direct Codex authoritative and use Harbor only for
non-authoritative portability experiments until the adapter is fixed.

### T2 — Inspect AI

**Conditional.** Add Inspect only if the first system has a demonstrated need
for richer resumable matrices, dataframe analysis, or a second portable runner.
It is not required merely because it provides useful telemetry. If added,
validate sandbox and external-agent side-effect visibility explicitly.

### T3 — Promptfoo

**Conditional.** Keep Promptfoo outside the core coding lifecycle evaluator. A
small spike may use it for app/API or description-routing regression if it
reduces maintenance without creating a second source of truth.

### T4 — Required GitHub check

**Conditional.** Run the new trusted evaluation check in shadow mode first.
Promote it to a ruleset requirement only after hostile-source tests, exact-head
checks, flake/error targets, private canary, credential isolation, and rollback
are demonstrated. Preserve the existing `openboa-governance` check throughout
the rollout.

## Pilot decisions

These are intentionally not fixed before measurement.

### P1 — Quality and routing margins

Use product consequence and the smallest unacceptable loss to propose:

- quality non-inferiority margin per task family;
- absolute quality floor;
- routing recall and false-positive margins;
- minimum meaningful quality improvement;
- maximum invalid and infrastructure-error rate.

Stable A/A estimates whether those margins are measurable and how many tasks are
needed; higher noise never justifies accepting more quality loss. The candidate
confirmatory result must remain unopened until these values and the analysis
rule are recorded.

### P2 — Efficiency budgets

Choose one primary optimization target per experiment, such as tokens per
accepted outcome or active time per accepted outcome. Define practical
improvement and guardrail budgets for the other token, time, cost, and attention
measures from operating consequences and constraints. Pilot variance determines
the sample needed to distinguish those bounds; it does not make a larger
regression acceptable.

### P3 — Sample size and confidence

Start with repeated stable calibration, then choose confirmatory sample size by
task-level variance, paired disagreement, minimum meaningful effect, and budget.
Independent tasks or routing intents determine generalization sample size;
language, paraphrase, and repeated runs are nested reliability observations. A
one-sided 95% confidence rule and 90% power are reasonable proposals, not
approved universal constants.

### P4 — First representative corpus

Begin small to validate the evaluator, then expand around real failures. The
pilot determines the balance across planning, diagnosis, implementation,
review/fix, recovery, cross-repository work, automation, and GitHub lifecycle.
Task diversity matters more than multiplying paraphrases of one task.

### P5 — Runner parity

Use five or more task families first for interface conformance, then repeated
per-dimension comparisons and ongoing direct-Codex sentinels before choosing
which task types Harbor may run authoritatively. Inspect remains a later secondary
candidate rather than a simultaneous competing rollout.

## Human decisions before implementation or activation

### H1 — Non-negotiable failure set

**Human decision.** Confirm which failures can never be traded for efficiency.
The recommended initial set is:

- forbidden or out-of-scope external effect;
- missing a necessary purpose, authority, credential, or release gate;
- exposing a secret or private data;
- weakening an evaluator, sandbox, required check, or ruleset;
- duplicate consequential write after an uncertain result;
- loss or overwrite of unrelated user work;
- false attribution or publication of unmeasured evidence as pass.

### H2 — Private control boundary

**Human decision.** Approve creation, ownership, access, and retention policy for
a private trusted-control surface and a separate private canary repository. A
recommended layout is:

- `hydra-eval-control`: protected orchestration, private validation, sealed
  holdouts, graders, raw traces, and publication attestations;
- `hydra-eval-canary`: disposable synthetic software project and bounded GitHub
  lifecycle target.

They should not be one repository because the evaluated agent may write to the
canary but must never read private validation, a sealed holdout, or its grader.

### H3 — Resource envelope

**Human decision.** Set the monthly and per-experiment token, time, configured
spend, concurrency, and private-storage limits. Automation enforces the envelope
through one trusted reservation ledger with leases, settlement, provider hard
caps, and a global kill switch. It stops rather than asking for a larger budget
mid-run unless a specific trade-off is worth considering.

### H4 — Public evidence and retention

**Human decision.** Approve what public transparency means for scorecards and
redacted examples, and how long encrypted raw traces and human labels are kept.

### H5 — Ruleset activation and release

**Human decision.** After shadow evidence exists, approve the exact ruleset
change that makes a trusted Hydra Eval check required. Each public Hydra release
remains an exact-effect decision; routine trials do not require repeated
accountability records.

## Research-to-design traceability

| Research finding | Design consequence |
| --- | --- |
| [Agent Skills](https://agentskills.io/skill-creation/evaluating-skills) separates triggering from post-trigger quality and recommends paired clean-context evaluation | Separate routing and loaded-behavior suites; stable/candidate/no-plugin arms |
| [OpenAI app evals](https://learn.chatgpt.com/use-cases/ai-app-evals) and [model guidance](https://developers.openai.com/api/docs/guides/latest-model) recommend baseline-first evaluation, one change at a time, and separate quality/tokens/time | Contemporary paired baseline; one causal hypothesis; no composite score |
| [Anthropic](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents) separates task, trial, trajectory, grader, harness, and infrastructure failure | Complete configuration identity; repetitions; separate run validity and outcome |
| [NVIDIA](https://developer.nvidia.com/blog/agentic-autonomy-levels-and-security/) connects autonomy with tool, permission, trust, and prompt-injection boundaries | Safety gates, candidate isolation, exact authority, protected graders |
| [Harbor](https://www.harborframework.com/docs/core-concepts) combines task, environment, verifier, repeated trials, and [ATIF evidence](https://www.harborframework.com/docs/agents/trajectory-format) | Conditional isolated outcome adapter with explicit network and verifier isolation |
| [Inspect](https://inspect.aisi.org.uk/) records rich usage/time/events but external-agent visibility and [sandbox boundaries](https://inspect.aisi.org.uk/sandboxing.html) require care | Optional analysis/portability adapter, not automatic source of truth |
| Hydra has attributable behavior ledgers but no v0.2 baseline, implicit routing, paired comparison, or accepted canary | Preserve provenance work; build missing layers before claiming optimization |

The supporting evidence and its fact/inference labels remain in
[the research index](../research/README.md),
[frontier lessons](../research/frontier-lessons.md),
[Agent Skills findings](../research/agent-skills.md),
[tool research](../research/evaluation-tools.md), and
[Hydra's pinned current-state audit](../research/hydra-current-state.md).

## Design acceptance check

The design is coherent only if a future implementation can answer all of these
without inventing missing state:

1. Which exact product and environment produced this result?
2. Did Hydra load when it should, and only then?
3. Did the agent complete an accepted outcome and stay inside its authority?
4. Is failure from Hydra, the model, the evaluator, or infrastructure?
5. Is the candidate better than both current stable and, periodically, no plugin?
6. Did it reduce tokens, time, cost, or unnecessary human attention without
   hiding a quality or safety regression?
7. Can the evaluator reject or continue routine work without a human, while
   stopping at the exact policy or release decision?
8. Can every external effect, retry, publication, and rollback be reconciled to
   live state and an exact revision?
9. Can a public reader reproduce the public evaluation slice and independently
   verify the provenance, signature, candidate binding, and policy version of
   the sealed-holdout attestation without receiving private material?
10. Can a failed release be rolled back and converted into durable regression
    evidence?

If any answer is no, the missing capability is a design gap rather than an
implementation detail.

## Next decision

Review this design as one system. If it is approved, the next artifact is an
implementation plan that breaks the rollout into verified milestones without
changing the durable core defined in the design overview or silently selecting
the unresolved numeric policy.
