# Evaluation system

## 1. Boundary and ownership

Hydra is the product under evaluation. `hydra-eval` is the independent control
plane that defines task meaning, trusted graders, experiment identity, analysis,
and public evidence.

This separation prevents a Hydra candidate from changing both the behavior and
the test that decides whether that behavior is acceptable. A Hydra pull request
may carry candidate tests for development feedback, but release evidence must be
produced from evaluator code controlled by the trusted base revision of
`hydra-eval`.

Three other surfaces have narrower roles:

- A fixture repository is a disposable starting state for a task.
- A private canary repository is a synthetic target for real GitHub effects.
- A private validation set supports bounded iteration without exposing cases.
- A sealed private holdout is opened once for a frozen release candidate. It is
  not optimizer feedback or a second source of product policy.
- A private trusted-control repository or equivalent protected service holds
  private orchestration, short-lived credentials, raw traces, and holdout
  material. It publishes only signed or attested summaries to the public plane.

None of these surfaces owns Hydra's doctrine or release decision.

## 2. Evaluation object

Every result describes a complete tested configuration:

| Dimension | Required identity |
| --- | --- |
| Product | source repository, commit and tree, trusted builder, bundle and installation digests |
| Installation | marketplace source, plugin version and enabled state, managed `AGENTS.md` digest and precedence, hook definition/trust/execution state |
| Agent | Codex version and surface, new-task boundary, model snapshot, reasoning setting, agent adapter version |
| Evaluation | suite and case versions, grader digest, evaluator revision |
| Starting state | fixture commit or image digest, clean-state fingerprint |
| Environment | OS/image, CPU and memory bounds, sandbox, network policy |
| Tools | installed skills/plugins, available tools, permissions, connector or fake-service version |
| Limits | timeout, token, cost, retry, concurrency, and side-effect bounds |
| Economics | pricing table and effective date when cost is reported |

A moving model alias, unpinned container, or unattributable plugin installation
must be visible in the record. If a required identity is missing, the affected
claim is `unmeasured`; it is not silently filled with a default.

## 3. System planes

### Product plane

The trusted evaluator fetches an exact Hydra Git tree and produces an immutable
candidate bundle. A candidate-supplied archive and its self-reported digest are
untrusted. The attestation binds repository, commit, tree, trusted builder,
bundle digest, marketplace identity, and installed digest.

The bundle contains the plugin, skills, references, scripts, manifests, and
hooks that a real user would install. Evaluating copied skill text alone is
insufficient for a whole-plugin release claim.

### Evaluation control plane

`hydra-eval` owns:

- the suite registry and task versions;
- experiment records and predeclared comparison arms;
- execution-adapter interfaces;
- deterministic and independent graders;
- append-only trial records;
- aggregate reports and uncertainty estimates;
- the automated eligibility rules;
- public evidence publication.

### Execution plane

Execution is replaceable. Each adapter must emit the same minimum provenance,
outcome, usage, timing, error, and artifact references even when its native log
format differs.

### Observation plane

Post-release monitoring checks whether a released Hydra version continues to
produce accepted outcomes without new safety or collaboration failures. It
creates regression evidence; it does not rewrite historical benchmark results.

## 4. Execution adapters

No reviewed tool covers the complete Hydra product and real GitHub lifecycle.
The recommended design therefore owns one small control plane and uses focused
adapters.

| Adapter | Primary purpose | What it must not be used to claim |
| --- | --- | --- |
| Static validator | Code-free package layout, manifests, references, managed-contract and provenance checks | That candidate scripts are safe or an agent used Hydra well |
| Direct Codex | Install the exact whole plugin; test the declared CLI profile, local routing evidence, loaded behavior, hooks, instruction loading, and local tool use | Desktop, Scheduled tasks, connector, or real GitHub behavior |
| Harbor | Repeated containerized repository tasks, skill ablations, verifier-controlled final state, ATIF trajectories, resource limits, cross-agent comparisons | That Harbor's reward definition is OpenBoa's quality policy |
| Fake GitHub | Public deterministic regression for Issue, PR, review, CI, idempotency, and authority behavior without external effects | That live GitHub permissions and timing behave identically |
| Private GitHub canary | Bounded real Issue-to-PR lifecycle and exact-head readback in a synthetic private repository | Production safety or permission to merge/change settings |

### Tool choice

The authoritative v1 CLI profile should use:

1. owned static checks and direct [`codex exec --json`](https://learn.chatgpt.com/docs/non-interactive-mode)
   trials with the exact full plugin installed, because that most closely
   matches the CLI user path;
2. a purpose-built GitHub canary adapter for real external effects;
3. Harbor for isolated executable outcome tasks only after a small parity
   experiment shows that its full-plugin adapter preserves installation,
   behavior, final-state grading, and usage evidence.

Harbor is an execution substrate, not the definition of the benchmark. Its
network policy must be explicit because omitted networking can allow public
egress, and consequential tasks use a separate verifier environment. See the
official [network policy](https://www.harborframework.com/docs/tasks/network-policy)
and [task structure](https://www.harborframework.com/docs/tasks).

The first Harbor check uses at least five representative task families to prove
interface conformance: identical installation digest, artifacts, deterministic
verdict, failure class, and required trajectory fields. Repeated stable A/A runs
then set per-dimension tolerances for token and timing differences. This small
check does not prove general statistical equivalence. Harbor becomes
release-authoritative only for task types with demonstrated parity and ongoing
direct-Codex sentinel comparisons. A mismatch is investigated rather than
averaged away.

Inspect AI remains an optional analysis and secondary portability adapter if
Hydra Eval needs richer experiment matrices, resumable sets, or dataframe
analysis. See Inspect's [eval sets](https://inspect.aisi.org.uk/eval-sets.html)
and [dataframes](https://inspect.aisi.org.uk/dataframe.html). Promptfoo remains
an optional [app/API routing smoke adapter](https://www.promptfoo.dev/docs/guides/evaluate-coding-agents/).
Neither is a required v1 dependency, avoiding two competing harnesses before
the core task and evidence model are stable.

Native records are retained alongside a portable normalized record. Harbor's
ATIF is accepted for trajectories, but Hydra Eval does not make ATIF the only
historical evidence format.

### Codex capability profiles

A runner result applies only to the surface it actually exercised:

- **CLI:** direct `codex exec`, local tools, installed plugin, and supported hook
  lifecycle.
- **Desktop:** interactive task discovery, compaction, and visible app behavior.
- **Scheduled:** actual wakeup, reconstructed state, bounded recurrence, and stop
  behavior.
- **GitHub connector:** authenticated Issue, PR, review, and check readback.
- **GitHub Actions:** headless execution, secret isolation, artifacts, and trusted
  check publication.

CLI success does not fill an unmeasured Desktop, Scheduled, connector, or Actions
claim. Each release scorecard shows which capability profiles were observed,
unsupported, or unmeasured.

## 5. Suite structure

The evaluation suite is layered so a failure points to the smallest likely
cause while later layers prove real usefulness.

### Suite 0 — integrity and static checks

- artifact and installation digests match the candidate commit;
- plugin and marketplace manifests agree;
- referenced files exist and packaged scripts pass deterministic tests;
- managed instructions can be installed, checked, migrated, and rolled back
  without changing unrelated bytes;
- evaluator, case, and grader versions are attributable.

This suite runs on every relevant change. It is necessary but not evidence of
agent performance.

### Suite 1 — plugin lifecycle

This suite exercises the installed product rather than only its files:

- fresh marketplace install and enabled-state readback;
- stable-to-candidate upgrade from the public marketplace path;
- changed-hook skip before trust, explicit trust, and observed execution;
- managed-contract migration while preserving all unrelated repository bytes;
- interrupted upgrade recovery before removing the last working installation;
- uninstall and removal of stale plugin, hook, and managed state;
- discovery in a genuinely new Codex task;
- rollback to the previous release and marketplace/install readback;
- pause and safe resumption of schedules or local adapters around upgrade.

Release evidence covers both a clean plugin-only installation and the declared
fully adopted profile. A no-Hydra control contains no Hydra plugin, managed
instruction block, trusted hook, schedule, or adapter state. Other installed
plugins and tools remain identical.

Candidate scripts and hooks run only in a disposable VM or equivalent managed
containment with an unprivileged user, ephemeral home, no host socket, default-
deny egress, and a task-scoped model proxy rather than a reusable credential.
Static validation never executes candidate code on the evaluator host.

### Suite 2 — implicit routing

Test whether Codex loads Hydra when it should and stays out when it should not.
Cases include:

- realistic positive requests;
- close negative requests and adjacent-skill conflicts;
- Korean and English paraphrases;
- short, noisy, and context-rich requests;
- changed context order and follow-up turns.

Positive recall and near-miss false-positive rate remain separate. Explicit
`$openboa-ai-native-sdlc` invocation is a control, not a substitute for this
suite.

The preferred evidence is a pinned first-party loader or plugin event. If Codex
does not expose one on a capability profile, controlled sentinel behavior and a
no-plugin/stable/candidate ablation provide indirect attribution. A self-reported
skill name alone is not direct load evidence. The report labels indirect
attribution as inferred, and the actual loader claim remains `unmeasured`.

### Suite 3 — loaded behavior and judgment

Retain Hydra's existing 21 decision-policy cases as a public regression corpus,
then add cases for:

- outcome-sized planning and delegation;
- exact authority and human-gate decisions;
- PR review and current-head reconciliation;
- scheduled work and bounded retry;
- recovery, handoff, and context loss;
- untrusted Issue, review, and tool content;
- distinguishing unknown, unsupported, and observed state.

This suite checks required and forbidden decisions without forcing one cosmetic
answer or one exact valid method.

### Suite 4 — executable outcomes

The agent works in an isolated repository and must leave an accepted final
state. Initial task families are:

- shape and plan a non-trivial change;
- diagnose a repository failure;
- implement or repair code;
- review a change and converge on fixes;
- coordinate a bounded multi-repository outcome;
- deliver an artifact with evidence and observation instructions.

Tasks use deterministic acceptance criteria wherever possible: tests, file
state, revision identity, schema validation, security properties, or fake
service readback. A model grader is used only for qualities that cannot be
encoded safely, such as whether a plan identifies the real decision. Such a
grader is blinded to the comparison arm and calibrated against reviewed examples.

### Suite 5 — recovery and fault injection

Normal success hides many operational failures. This suite injects:

- stale handoff and changed repository head;
- an external write that succeeded before a client timeout;
- crash, compaction, or lost local session;
- a dirty worktree containing unrelated user work;
- late review findings after a green check;
- unavailable model transport, CI, or connector;
- retry exhaustion and budget termination.

The accepted outcome is safe reconciliation or a precise handoff, not merely
continuing execution.

### Suite 6 — GitHub lifecycle

The public part runs against a deterministic fake GitHub surface. A rotating
private canary then exercises real synthetic work:

`Issue -> isolated branch -> commit -> CI -> pull request -> independent review
-> fix/readback -> ready status`

The initial canary does not merge, publish, edit rulesets, access production
data, or use organization-wide credentials. Any expansion is a separate
authority decision. Every external write uses a run identifier and live
readback so retries cannot silently duplicate Issues, comments, branches, or
pull requests.

The evaluated agent uses the Codex GitHub connector as the default control plane
for Issue, pull-request, review, and check state, and local `git` for worktrees,
diffs, commits, and local evidence. The trusted controller uses its own narrowly
installed GitHub App or API identity for independent readback. A connected
account authenticates an action; the declared canary boundary supplies authority.

A run identifier alone is not atomic idempotency. Before any create or update,
the trusted controller acquires an atomic lease or unique claim keyed by target
repository, effect type, and resource/run identity. It writes an append-only
intent before the effect and later records the response and independent
readback. Failure to acquire or recover the lease stops the write.

The adapter also uses native idempotency support where available, deterministic
resource names or markers, conditional update against the observed revision,
and lookup after an uncertain response. If the external service cannot make the
effect safely idempotent, the run stops for reconciliation instead of retrying.

The fake surface includes hostile regressions: look-alike check names,
candidate-disabled validators, changed workflow permissions, stale review after
a new push, skipped or timed-out CI, base drift, fork behavior, a lost success
response after a write, and a check with the right display name but the wrong
trusted source or head.

### Post-release observation

Privacy-safe operational observations cover reopened work, review rounds,
escaped defects, unnecessary escalation, recovery, and outcome acceptance.
They are monitoring signals, not a leaderboard. A repeated field failure should
become a redacted regression case at the smallest durable layer.

## 6. Dataset partitions

- **Development set:** small public cases for fast diagnosis and iteration.
- **Public regression set:** stable, reviewable cases that prevent known failures
  from returning.
- **Private validation set:** unreleased cases that may guide bounded iteration;
  exposure and reuse are tracked, and cases rotate before repeated tuning makes
  them predictable.
- **Sealed private holdout:** unreleased confirmatory cases opened once for a
  frozen candidate. A failed/opened holdout is retired or rotated before a tuned
  successor can make a new confirmatory claim.
- **Private canary:** synthetic live-GitHub target, distinct from the holdout and
  from its grader.
- **Incident-derived set:** redacted failures promoted into regression after
  review.

An initial calibration may start with two or three cases per new family and
about twenty balanced routing prompts. That is a learning starting point, not a
claim of representative coverage. Expansion is driven by observed blind spots,
not by an arbitrary benchmark size.

## 7. Grading model

Graders are ordered by the strength of the claim they can support:

1. **Provenance and run validity:** was the intended immutable configuration
   actually tested?
2. **Deterministic final-state checks:** does the repository or external system
   satisfy the acceptance criteria?
3. **Safety and authority checks:** did the trajectory remain inside its
   delegated boundary and avoid forbidden effects?
4. **Independent qualitative review:** only for material qualities that are not
   directly testable.
5. **Sampled human audit:** calibrates graders, investigates disagreement, and
   checks reward hacking; it is not required on every routine trial.

A plausible trajectory cannot rescue a failed outcome. A correct final state
cannot rescue a forbidden external effect. Path grading is limited to actual
safety, authority, evidence, and non-duplication requirements; it must not
reject a valid alternative working method merely because it differs from a
reference trace.

A model grader receives candidate artifacts as typed, size-bounded data in a
no-tools, no-network environment. It does not execute links, commands, tool
requests, or instructions found in the artifact. Grader calibration includes
prompt-injection and output-format attacks. A single model grade cannot satisfy
a critical integrity, authority, privacy, or external-effect gate; those require
deterministic evidence or an independently controlled review path.

## 8. Trial and evidence record

Each trial records at least:

- experiment, arm, task, trial, and idempotency identifiers;
- all configuration identities in section 2;
- clean starting-state and final-state fingerprints;
- outcome criteria and grader results;
- forbidden and observed external effects;
- native trajectory and normalized event references;
- input, cached, reasoning, and output tokens by solver and grader;
- model, tool, active-work, queue, CI, review-wait, and wall time when observed;
- configured cost with price provenance;
- human interventions and active attention minutes;
- retries, tool errors, infrastructure errors, and budget terminations;
- checksums, timestamps, redaction state, and publication state.

These dimensions use separate states:

| Dimension | Examples |
| --- | --- |
| Run validity | `valid`, `invalid` |
| Execution | `completed`, `infrastructure_error`, `budget_exhausted`, `cancelled` |
| Outcome | `accepted`, `not_accepted`, `not_applicable` |
| Measurement | `observed`, `unmeasured`, `unsupported` |

Measurement state attaches to each claim or metric, not only to the whole trial;
token usage may be observed while cost or a particular external effect remains
unmeasured.

An infrastructure error is not a product failure unless the product caused it.
It is also not a pass. Invalid trials remain in the append-only ledger with the
reason and are excluded from confirmatory comparison.

`unsupported` describes a capability the evaluator or declared suite does not
provide. If a task requires a supported environment and the candidate cannot
operate in it, that is a valid `not_accepted` outcome rather than an unsupported
measurement.

Budget exhaustion has two meanings and must not be used to hide a weak
candidate:

- If an executing candidate consumes its fair per-trial token, time, or tool
  limit, the run remains valid, execution is `budget_exhausted`, and the outcome
  is `not_accepted`. The reason is candidate limit exceeded, and the consumed
  resources are charged to that arm; stable continues unless the shared
  experiment limit prevents a fair pair.
- If the independent grader consumes its limit, that grade is invalid or
  inconclusive and cannot be blamed on the candidate without other evidence.
- If a shared experiment budget, provider quota, or controller failure prevents
  a balanced pair from starting or finishing, the missing comparison is
  infrastructure-related and recorded as inconclusive or unmeasured.

Regrading creates a new record linked to the original immutable artifacts. It
never overwrites the original grader result.

## 9. Trust and disclosure boundaries

### Candidate boundary

- Candidate content, repository instructions, task output, Issue text, review
  text, and tool output are untrusted input.
- The optimizer and candidate job cannot browse private validation or holdout
  storage. A solving session receives only the current task instruction and
  fixture it needs, never the remaining pack or hidden grader, and cannot persist
  them back into the optimization loop.
- The candidate cannot write evaluator code, task definitions, graders,
  thresholds, the accepted ledger, or attestation keys.
- Candidate execution receives no publication credential and no secret that is
  unnecessary for its bounded task.

### Workflow boundary

- Trusted workflow code is loaded from the evaluator's protected base revision.
- Candidate bytes are downloaded by immutable digest and installed read-only.
- Evaluation and result publication are separate jobs with separate credentials.
- Exact candidate and evaluator heads are read back before a result is attached
  to a pull request or release decision.

### Public evidence

The public repository may contain experiment records, aggregate reports,
configuration fingerprints, checksums, redacted examples, and reviewed
trajectories. It must not contain secrets, private repository contents, personal
data, hidden tasks or graders, unreviewed raw prompts, or credential-bearing tool
logs.

Public and canary suites may publish reviewed criterion-level results. A sealed
holdout publishes only an overall `pass`, `fail`, or `invalid` attestation bound
to the exact candidate, evaluator, and policy version. Its per-case results,
failure categories, examples, task count, and token/time side channels stay
private.

Raw traces have restricted retention and are published only through an explicit
redaction review. Public summaries link to immutable artifacts rather than
copying unverifiable numbers into prose.

Holdout input and candidate output are both private-tainted. The publisher
accepts only an allowlisted, schema-validated summary from the trusted grader;
it never forwards candidate prose or raw holdout content automatically.

## 10. Failure handling

- Evaluator bug: mark affected trials invalid, retain them, fix the evaluator,
  and rerun or regrade from immutable artifacts.
- Model, network, or GitHub outage: record infrastructure error and preserve the
  partial evidence; do not mark the candidate eligible.
- Attribution drift: stop the experiment before comparison.
- Candidate per-trial budget overrun: stop that trial, charge its usage, and
  record a valid not-accepted outcome. Global experiment exhaustion: stop before
  an unbalanced comparison and record the missing pair as inconclusive.
- Suspected grader leak or reward hacking: freeze release eligibility, rotate the holdout,
  audit failures and surprising successes, and add a stronger independent check.
- Trace disclosure: stop publication, revoke accessible artifacts where
  possible, rotate exposed credentials, record the incident, and rerun safely.
- Duplicate external effect: stop the canary, reconcile live state by run ID,
  clean up only the synthetic target, and retain the failure as a recovery case.

Historical records are corrected by append-only invalidation or supersession,
never deletion or quiet editing.
