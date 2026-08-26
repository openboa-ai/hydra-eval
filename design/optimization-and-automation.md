# Optimization and automation

## 1. Optimization objective

Hydra optimization is not prompt polishing for its own sake. It is a controlled
learning loop that improves a collaborating agent's ability to deliver accepted
software outcomes inside a safe boundary.

The optimizer should lead routine investigation and experimentation. It should
not require the human to approve every trial, and it must not achieve autonomy
by quietly weakening the evaluator, removing necessary decisions, or spending
without bounds.

## 2. Agent-led optimization loop

```text
Measured failure or inefficiency
-> classify the failure
-> freeze stable/configuration
-> write one falsifiable hypothesis
-> make one hypothesis-driven change
-> targeted smoke
-> full public regression
-> paired private validation
-> freeze the candidate
-> one-time sealed holdout
-> private GitHub canary
-> exact-revision release decision
-> post-release observation
-> durable regression or next hypothesis
```

### Step 1 — select evidence, not an intuition

The optimizer selects one attributable cluster from a failed gate, paired
efficiency regression, grader disagreement, canary failure, or field
observation. It links the exact runs and separates product failure from
evaluator or infrastructure failure.

### Step 2 — freeze the comparison

Record stable and candidate bases, task and grader versions, model and Codex
configuration, environment, budgets, primary metric, guardrails, repetition
rule, and stop condition before editing Hydra.

### Step 3 — state one hypothesis

The hypothesis names:

- the observed failure;
- the likely cause;
- one causal behavior to change;
- the task family expected to improve;
- the quality and safety properties that must not regress;
- the minimum result worth continuing for.

“One change” means one causal idea, not one file. A complete routing change may
need metadata, tests, and documentation together. Routing and recovery changes
are separate experiments because they make different causal claims.

### Step 4 — choose the smallest durable change

| Observed problem | First lever to test |
| --- | --- |
| Missed or false trigger | Skill name and description boundary |
| Correct trigger, wrong judgment | Skill entrypoint or relevant playbook |
| Excess context or token overhead | Progressive disclosure and reference routing |
| Repeated deterministic manual work | Small tested script |
| Repository-specific misunderstanding | Nearest `AGENTS.md`, not the shared plugin |
| Permission or enforcement gap | GitHub/system control, not stronger prose |
| Resume or duplicate-effect failure | Recovery workflow plus fault-injection case |
| Model capability or effort limit | Separate model/effort experiment |
| Broken task, grader, or runner | Fix Hydra Eval; do not change Hydra to game it |

Recurring failure becomes a test, evaluator, script, control, or local
instruction at the smallest layer that can prevent it. Adding more general
doctrine is the last resort, not the default optimization.

### Step 5 — run from cheap to realistic

1. Targeted deterministic and direct-Codex smoke.
2. Affected public routing, behavior, outcome, or recovery suite.
3. Full stable/candidate public regression if the smoke passes.
4. Blind private validation with the fixed comparison rule during bounded
   iteration.
5. Freeze the exact candidate and open the sealed confirmatory holdout once.
6. Run the real synthetic GitHub canary on that same candidate.

A public or validation failure returns to diagnosis. A holdout failure blocks
that candidate; changing it requires a new confirmatory cycle and a retired or
rotated holdout. No failure triggers endless self-editing.

### Step 6 — decide and learn

The machine may reject, mark inconclusive, or mark the exact candidate eligible
using the approved gates. After release, monitoring either confirms the result
or opens recovery and creates a regression case. Historical evidence remains
attributed to the original candidate and is never rewritten to match the fix.

## 3. Optimizer authority and isolation

The optimizer may:

- read public evaluation evidence and bounded private-validation failure
  categories;
- create an isolated Hydra candidate branch or worktree;
- change Hydra inside an outcome-sized Issue boundary;
- run declared experiments within token, time, cost, retry, and side-effect
  budgets;
- reject its own candidate and try the next hypothesis within the iteration cap;
- propose a reviewed change and a clear evidence report.

The optimizer may not:

- read private prompts, hidden grader internals, attestation keys, or unrelated
  raw traces;
- write accepted result ledgers or grade itself;
- edit the task, grader, eligibility margin, and candidate in the same experiment;
- grant credentials, broaden network access, weaken CI, or change rulesets;
- keep rerunning until a favorable random result appears;
- merge, release, deploy, or change public evidence history.

Private validation may return criterion-level results and a bounded failure
category, not hidden task or grader bytes. The sealed holdout returns only the
confirmatory eligibility decision to the release controller; it is not optimizer
feedback.

## 4. Budgets and stop conditions

Every experiment declares maximum:

- optimization iterations;
- trials and repetitions;
- solver and grader tokens;
- configured spend;
- wall time;
- concurrency;
- infrastructure retries;
- external effects.

A single trusted budget ledger coordinates PR, nightly, weekly, release, and
local dispatches. Before a run starts, it atomically reserves token, configured
spend, and concurrency capacity against both per-run and global envelopes. The
reservation has a lease and expiry; completion settles actual usage and returns
the remainder. Provider-side hard caps and a global kill switch remain the final
backstop. A dispatcher that cannot acquire a reservation does not start a
partial or unpaired experiment.

Stop immediately on:

- candidate, evaluator, grader, environment, or fixture provenance drift;
- a forbidden effect, authority violation, secret exposure, or control weakening;
- suspected grader leakage or reward hacking;
- repeated identical failure under the same hypothesis;
- unequal infrastructure that makes the arms incomparable;
- a global token, time, cost, retry, or iteration budget that prevents a fair
  comparison;
- a private holdout failure that cannot be safely explained without disclosure.

An infrastructure error may be retried once by default when classification is
clear and both arms remain fair. Before any external-effect retry, reconcile live
state. If an executing candidate consumes its own fair per-trial limit, record a
valid `not_accepted` outcome and charge its usage. If a global experiment limit
prevents a balanced pair, report that comparison as `inconclusive` or
`unmeasured`. Neither case becomes a pass.

## 5. Automation cadence

Automation separates fast feedback, routine drift detection, expensive proof,
and release evidence.

| Trigger | Work | Authority and output |
| --- | --- | --- |
| Hydra pull request | Free deterministic validation; trusted build/install provenance; changed-area lifecycle or direct-Codex smoke | Advisory until live-model flake is calibrated; report on exact head |
| Nightly | Latest Hydra main versus stable on repeated routing and behavior suites | Detect model/Codex/plugin drift; open or update one regression Issue |
| Weekly | Paired representative repository outcomes and recovery cases | Trend quality, reliability, tokens, time, cost, and attention |
| Release candidate | Full exact-SHA capability matrix; install/upgrade/uninstall/rollback; one-time sealed holdout; real GitHub canary; fresh discovery in a new Codex task | Produce release eligibility; never self-release |
| Post-release | Fresh install and bounded observation window | Confirm, recover, or roll back; feed failures into regression |

Live-model checks do not become required checks until their infrastructure
error and flake rates are measured and the trusted-source design is proven.
Candidate-controlled Hydra CI remains useful compatibility evidence, not the
only release authority.

## 6. Trusted GitHub workflow

### Candidate production

1. A trusted evaluator receives an exact Hydra repository, commit, and tree.
2. It builds the immutable bundle itself and attests repository, commit, tree,
   builder, bundle, marketplace, and installed digests.
3. Evaluator code is pinned to a protected `hydra-eval` revision or release.
4. Candidate execution runs in disposable managed containment without host
   sockets, controller credentials, or publication credentials.
5. A separate trusted grader verifies content-addressed artifacts.
6. A separate publisher attaches a signed or attested allowlisted summary to the exact
   Hydra head and proposes public evidence through review.

The run key contains suite, task, candidate, stable, model, Codex, evaluator,
environment, and repetition identity. It identifies duplicate intent and allows
precise recovery, but it is not a lock. The trusted controller uses an atomic
run lease before dispatch and a separate atomic effect lease plus append-only
intent record before each GitHub write.

### Credentials

- Prefer a narrowly installed GitHub App and short-lived OIDC credentials.
- The controller normally needs Hydra content read, pull-request read, and check
  write; canary write is a different installation limited to the synthetic repo.
- Candidate jobs receive no controller token and use
  `persist-credentials: false` where checkout is required.
- Model access is a task-scoped proxy or equivalent capability that cannot be
  reused outside the trial, not a key or login file in job-wide environment
  available to candidate-controlled code.
- Raw holdout and grader material is never mounted into the agent environment.

### Required checks and rulesets

A future `hydra-eval` check must be bound to a trusted source, workflow/app
identity, evaluator revision, and candidate head—not merely a display name.

It first runs in shadow mode through hostile and private canaries. Only after
reliability and rollback are proven may a human approve adding it to a Hydra
ruleset. The existing `openboa-governance` protection remains in place during
that rollout. Disabling an unstable new eval check is not permission to weaken
the existing baseline protections.

## 7. Codex Scheduled tasks

Codex Scheduled tasks are useful as recurring coordinators, not as the sole
source of release truth. Recommended tasks are:

- watch the latest result ledgers and identify a meaningful regression;
- update one outcome-sized GitHub Issue rather than creating duplicate alerts;
- propose the next falsifiable optimization hypothesis;
- check stalled experiments, missing evidence, and post-release observation;
- launch an already approved evaluator dispatch when that capability is
  available and then read back the trusted result.

The schedule reconstructs current state from GitHub and immutable run records
on every invocation. It does not rely on a long-lived chat memory. If no material
change exists, it exits quietly.

The schedule cannot become authoritative merely because it uses Codex. A
required result still comes from pinned evaluator code, exact artifacts,
independent grading, and a GitHub check or attested record.

## 8. Cron or launchd fallback

A generic host cron or launchd job is not a supported candidate-execution
environment. A process can detach descendants, outlive a lock, retain files or
credentials, and make a successful parent exit misleading. By default a local
schedule may only perform read-only monitoring or trigger a trusted remote
dispatch.

Private validation or direct Codex execution becomes a conditional local adapter
only after a managed VM or equivalent OS containment proves:

- explicit absolute project and image identity;
- an ephemeral workspace and fresh Codex home inside the containment boundary;
- `codex exec --json` with a pinned full-plugin installation inside that boundary;
- an unprivileged user, no host socket, and explicit network deny or allowlist;
- task-scoped model access rather than reusable host credentials;
- overlap and expiring canary locks;
- fixed timeout, concurrency, retry, token, and spend limits;
- hostile daemonization tests and termination of every descendant before lock
  release;
- filesystem, process, network, and credential cleanup with readback;
- append-only artifacts, trusted upload, checksum verification, and a rehearsed
  disable/rollback path.

Until those properties are canary-tested, local candidate execution is
`unsupported` and cannot produce release-authoritative evidence. It never uses
sandbox bypass or an interactive approval it cannot actually receive.
Registration, pause, upgrade, and removal of the managed service remain an
explicit adoption step.

## 9. Evidence publication and retention

Execution emits content-addressed raw artifacts. A trusted job validates,
grades, redacts, and publishes a small immutable summary.

Public evidence contains:

- candidate and evaluator revisions and digests;
- experiment and configuration identities;
- public-suite and canary criterion-level results and uncertainty;
- quality, safety, token, time, cost, and attention measures;
- invalid, unknown, unsupported, and infrastructure-error counts;
- checksums and references to reviewed redacted samples.

For the sealed holdout, public evidence is limited to an overall
`pass`, `fail`, or `invalid` attestation bound to candidate, evaluator, and
policy. Per-case results, failure categories, samples, task count, and token/time
side channels stay private.

Private evidence contains encrypted raw trajectories, private repository URLs,
hidden tasks and graders, human labels, and sensitive tool payloads. It has a
defined retention period and access log.

GitHub Actions artifacts are temporary transport, not the only durable evidence.
Small sanitized manifests are committed through a reviewed pull request or
attached to a signed release. A bot never overwrites an existing result.

## 10. Recovery and rollback

### Experiment recovery

- Reconcile the run key and live GitHub state before retrying.
- Resume only missing trials; retain completed and invalid trials.
- If candidate head, evaluator, grader, or task changes, start a new experiment.
- If only a grader changes, regrade both arms into new linked records.

### Automation rollback

- Pause schedules and local runners.
- Disable or revert only the new evaluator workflow or GitHub App installation.
- Revoke its credentials and verify it can no longer publish checks.
- Keep existing required protections and `openboa-governance` unchanged.
- Preserve all evidence and record why the run or check was invalidated.

### Product rollback

If a released Hydra version causes a critical safety event or breaches its
predeclared outcome guardrail:

1. stop further rollout and recurring automation that uses the candidate;
2. restore the previous exact verified Hydra artifact;
3. verify fresh installation and active version;
4. reconcile any real external effects;
5. retain the incident evidence and create a regression case;
6. require a new exact candidate and full affected evaluation before release.

Rollback success is verified state, not merely a revert command that exited
successfully.

## 11. Initial rollout order

The design implies this technical order without yet constituting an
implementation plan:

1. Qualify the direct-Codex runner and create a stable A/A baseline.
2. Qualify the trusted bundle builder, containment, and plugin lifecycle matrix.
3. Rerun the existing 21 cases for an attributable v0.2 CLI baseline.
4. Build implicit routing and fake-GitHub public regression suites.
5. Qualify one executable outcome and recovery family on stable Hydra.
6. Add normalized records, paired analysis, and scorecards.
7. Establish separate private validation, sealed-holdout, and trusted-control
   boundaries.
8. Run the private real-GitHub canary and the Desktop/Scheduled/connector
   capability canaries.
9. Perform the minimum five-family Harbor interface-conformance check, followed
   by repeated per-dimension parity and direct-Codex sentinels, before relying on
   Harbor for any release-authoritative task type.
10. Shadow the trusted GitHub check and rehearse rollback.
11. Only then begin candidate optimization and consider a required release gate.
