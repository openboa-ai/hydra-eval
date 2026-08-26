# Experiments, metrics, and release eligibility

## 1. Decision the experiment must support

Each experiment answers a bounded question such as:

> Does this exact Hydra candidate preserve or improve accepted outcomes and
> safety compared with the released Hydra configuration, while materially
> improving at least one targeted efficiency measure without an unacceptable
> regression elsewhere?

“It used fewer tokens once” and “the average score went up” are not sufficient
decisions. The comparison must use the same tasks and starting states, expose
uncertainty, and keep important task families visible.

## 2. Comparison arms

### Required arms

- **Stable:** exact released Hydra artifact and installation digest.
- **Candidate:** exact proposed Hydra artifact and installation digest.

These arms run as pairs on identical task IDs and fixture states. Stable is run
at the same time as candidate so model, provider, Codex, and environment drift
do not turn an old result into a false baseline.

### Periodic control

- **No plugin:** the same agent configuration without Hydra.

This control measures whether Hydra adds value rather than merely whether one
Hydra version beats another. It runs during initial calibration, major releases,
and periodic value checks; it need not add cost to every small candidate run.
All other plugins, tools, and settings remain fixed. Outcome comparison uses a
plugin-neutral grader; Hydra-attribution fields are not required from the
no-plugin arm. Before the trial, readback confirms that Hydra's plugin,
marketplace entry, managed instruction block, trusted hook, schedule, and adapter
state are absent while the rest of the environment is unchanged.

The no-plugin result has a declared maximum age and becomes stale immediately
after a material model, Codex, tool, permission, or environment change. Release
eligibility requires a fresh value check when either condition applies. The
maximum age is chosen with the operating cadence during calibration rather than
assumed here.

### Diagnostic ablation

A focused experiment may disable only the suspected component, for example:

- metadata or description change only;
- skill body or reference change only;
- hook disabled;
- target script or playbook removed.

Ablations explain causality. They are not the release baseline. A model,
reasoning, Codex-version, or tool change is a separate experiment and must not be
mixed into a Hydra optimization claim.

## 3. Fair trial design

For every stable/candidate pair, hold constant:

- task, fixture, and grader versions;
- model snapshot, reasoning setting, and Codex version;
- image, resources, network, permissions, timeouts, and budgets;
- initial repository and external-service state;
- solver and grader limits.

Each trial starts in a clean isolated context. Pair order is block-randomized so
one arm does not consistently benefit from provider load or cache order. Graders
that see subjective artifacts are blinded to the arm and presentation order.

Model output remains variable even with a seed or temperature setting. Trials
are repeated and joined by task and repetition. The ledger keeps every valid
trial, not just the best run.

The independent unit is the task or independently sampled routing intent, not
each repetition or paraphrase. Repeated runs and paraphrases are nested
observations used to measure reliability within that unit. Task families and
their weights are fixed before the candidate is examined.

By default, a claim applies only to the named versioned suite. A claim about a
wider population of OpenBoa work requires a documented sampling frame and
representative task selection; repetition of a small fixed suite does not create
that generalization.

## 4. Calibration before thresholds

Numeric release thresholds should not be guessed from the existing v0.1 `r13`
result. It is historical evidence for a different candidate and does not provide
a v0.2 baseline.

Before judging a candidate:

1. Validate each grader on known accepted, rejected, forbidden, and
   infrastructure-failure examples.
2. Run stable-versus-stable A/A trials to measure harness noise, task flake,
   provider variance, and timing variance.
3. Run stable versus no-plugin to estimate Hydra's current marginal value.
4. Estimate variance and disagreement per task family.
5. Define the practical non-inferiority margin from product consequence and the
   smallest quality loss that would be unacceptable—not from statistical noise.
6. Before viewing the candidate result, record that margin, the minimum
   meaningful efficiency improvement, confidence rule, maximum independent task
   count, repetitions, and budget.

A useful calibration start is roughly five repeated stable trials per task and
about twenty realistic positive and near-miss routing queries. These are pilot
sizes, not permanent release requirements. Confirmatory sample size is chosen
from observed variance and the smallest effect worth acting on. Variance decides
whether the chosen margin is measurable and how many independent tasks are
needed; it does not decide how much quality loss is acceptable.

Pilot, development, private validation, and sealed confirmatory-holdout results
remain separate. Private validation may guide bounded iteration. The holdout is
opened once for a frozen candidate and supplies an eligibility result, not tuning
feedback. If it is opened and the candidate is then changed, that holdout is
retired or rotated before the successor makes a confirmatory claim.

Repeatedly peeking and stopping when a preferred result appears is not allowed.
If an adaptive design is later needed, its checkpoints and stopping rule are
declared before the run.

## 5. Metric hierarchy

Hydra Eval reports a scorecard, not a composite score.

### 5.1 Integrity and safety gates

These are checked first:

- exact candidate, evaluator, task, and grader attribution;
- no forbidden authority expansion or external effect;
- no secret, untrusted-input, sandbox, or network-boundary violation;
- deterministic package and acceptance checks;
- no grader or holdout access by the candidate;
- required evidence is observed rather than unsupported or unmeasured.

One attributable critical violation rejects the candidate. Zero observed events
in a finite sample does not prove zero risk; reports include the sample count and
an upper uncertainty bound where useful.

### 5.2 Outcome quality

Quality measures include:

- accepted outcome rate;
- first-pass accepted outcome rate;
- required acceptance criteria satisfied;
- result by task family and difficulty;
- regressions on previously failed or incident-derived cases;
- reopen, escaped-defect, and review-fix rates;
- grader disagreement and invalid-trial rate.

An aggregate improvement cannot hide a critical family regression. Planning,
implementation, review, recovery, and GitHub-lifecycle results remain visible.

### 5.3 Routing quality

Routing is reported separately from loaded performance:

- positive recall;
- near-miss false-positive rate;
- adjacent-skill confusion;
- Korean/English and paraphrase robustness;
- unnecessary load rate and context cost.

High recall does not compensate for Hydra intruding on unrelated work, and a
low false-positive rate does not compensate for never loading when needed.

### 5.4 Reliability

- repeated-trial success and failure distribution;
- flake and arm-disagreement rates;
- infrastructure-error rate;
- retry, duplicate-effect, and recovery success;
- median and tail behavior rather than best-run behavior.

### 5.5 Tokens

Report input, cached input, reasoning, output, and total tokens separately for:

- the solving agent;
- model graders;
- discovery or routing overhead.

Primary accounting includes tokens consumed by every assigned valid trial,
including failed attempts and candidate-caused budget exhaustion. Tokens per
accepted outcome divide that complete resource total by accepted outcomes; if
none are accepted, the ratio is undefined and the quality gate already fails.
Paired token delta among tasks both arms accepted is useful secondary diagnostic
evidence, not the primary comparison. Token totals across different tokenizers
are not treated as directly equivalent without a stated normalization limit.

### 5.6 Time

Where observable, separate:

- model generation;
- active agent/tool work;
- queue and rate-limit wait;
- CI wait;
- review wait;
- total wall time.

Primary accounting includes time for every assigned valid trial. Candidate-caused
timeouts are charged at their trial limit and count as not accepted; unrelated
infrastructure interruption invalidates the pair under the declared retry rule.
Time per accepted outcome and paired active/wall time among mutually accepted
tasks are reported with that distinction. Concurrent provider load can distort
wall time, so both active and total time are retained.

### 5.7 Cost

Configured model cost is reported with the pricing table and effective date.
Model, grader, sandbox, CI, and other tool costs remain separate. A configured
estimate is not presented as invoice truth.

Cost per accepted outcome includes the cost of failed valid attempts because
cheap failures do not create value. Cost per assigned trial remains visible so
the denominator cannot hide survivor bias.

### 5.8 Human attention

Hydra should let a capable agent lead routine work without using the human as a
workflow engine. Record:

- active human attention minutes;
- intervention count and reason;
- unnecessary escalation;
- review/fix rounds;
- decisions correctly handed to the human;
- consequential decisions missed or incorrectly delegated.

A required purpose, authority, or release decision is correct collaboration,
not inefficiency. Reducing necessary human gates is not counted as an
optimization. Repeated ceremonial approval, preventable clarification, or
failure to reconcile live state is avoidable attention.

Before a confirmatory run, define an intervention event, its start and end, and
the taxonomy for necessary, unnecessary, and missed intervention. Active minutes
come from timestamped human actions, not total waiting time. Both arms use the
same review conditions. A calibrated independent evaluator labels all
consequential cases without seeing the arm, and sampled human audit plus a
second label measure disagreement; unresolved disagreement stays visible. A
missed necessary intervention is a safety or quality failure even if the
recorded attention is low.

Standardized suites use a scripted human-decision oracle with fixed responses at
the declared gates. They compare requests, missed gates, turns, and wait behavior;
they do not invent human minutes. Actual attention minutes come only from
opt-in, privacy-reviewed canary or field observation and are reported separately
from the synthetic benchmark.

## 6. Comparison and uncertainty

Reports lead with raw paired counts and practical effect size:

- candidate win, stable win, and tie on each task;
- accepted and rejected counts by family;
- paired absolute and relative change;
- median, tail, and confidence interval;
- invalid, infrastructure-error, and budget-exhausted counts.

Analyses treat task or independently sampled query intent as the generalization
unit and repetitions or paraphrases as nested observations. Appropriate methods
include task-level exact McNemar or a paired hierarchical binary analysis,
task-clustered bootstrap intervals for rates and aggregate differences, and
task-level paired signed-rank analysis for skewed continuous measures. A
trial-row analysis that treats repetitions as independent is invalid.
Sample-size calculations count independent tasks or query intents; extra
repetitions and paraphrases improve reliability estimates but do not manufacture
task diversity. Statistical significance does not replace practical
significance.

A one-sided 95% confidence rule is a reasonable starting proposal for
non-inferiority, but it is not fixed by this design. Product consequence defines
the margin; pilot variance determines feasibility and sample size. The rule and
margin are recorded before the candidate result is opened.

## 7. Release eligibility rules

Eligibility here means permission to proceed to release review, not merge or
release.

### Gate 1 — valid evidence

The candidate and stable arms are attributable and comparable. Required
measurements are present. Otherwise the result is inconclusive and the system
requests or schedules more evidence.

A candidate that consumes its fair per-trial budget has valid negative outcome
evidence, not missing evidence. Only a global budget that prevents a balanced
pair from running is inconclusive for that comparison.

### Gate 2 — integrity and safety

Any critical attributable violation rejects the candidate. No efficiency gain
can offset it.

### Gate 3 — quality

The candidate must meet the absolute quality floor and remain non-inferior to
stable within the predeclared practical margin. Task-family and
incident-regression budgets apply as well as the aggregate. A meaningful quality
improvement is recorded here but does not erase an efficiency guardrail.

### Gate 4 — efficiency frontier

Only candidates that pass quality and safety enter the efficiency comparison.
Tokens, time, cost, and human attention remain separate. A candidate that is no
better on any target and worse on at least one is dominated and can be rejected
automatically.

“Better” and “worse” mean that the paired effect and its uncertainty cross a
predeclared practical bound. A smaller noisy difference is a tie or
inconclusive—not automatic rejection.

Eligibility requires one of two predeclared paths:

- meaningful quality superiority while every efficiency measure stays inside
  its regression budget; or
- quality and safety non-inferiority plus a meaningful improvement in the one
  primary efficiency target, with all other measures inside their guardrails.

There is no universal winner when one passing candidate is faster but more
expensive, or cheaper but requires more human attention. A trade-off outside a
preapproved budget becomes one explicit human decision.

### Gate 5 — sealed holdout and canary

The exact frozen candidate passes the one-time sealed private holdout and bounded
GitHub canary without new forbidden effects, unexplained regressions, or
attribution drift. Changing the candidate after opening the holdout starts a new
confirmatory cycle with a retired or rotated holdout.

### Decision states

| State | Meaning | Next authority |
| --- | --- | --- |
| Rejected | A hard gate failed or the candidate is clearly dominated | Agent diagnoses or abandons |
| Inconclusive | Evidence is missing, invalid, too noisy, or a global budget prevented a balanced comparison | Agent reruns within bounds or hands off the exact blocker |
| Eligible | All preapproved machine gates passed | Release workflow may proceed |
| Trade-off decision | Multiple acceptable outcomes cross a policy boundary | Human chooses the product trade-off |
| Approved | The exact release effect was approved | Release automation executes and reads back |
| Observed | Delivery and the observation window were verified | Keep, recover, or roll back |

Eligible is not approved, promoted, merged, released, or observed.

## 8. What is automated and what is not

The evaluator may automatically:

- reject hard-gate failures;
- retry infrastructure failures inside declared limits;
- continue from smoke to regression to private validation, then freeze the
  candidate and run the sealed holdout when gates pass;
- stop dominated experiments and stop globally over-budget experiments; a
  candidate that consumes its own fair trial limit remains a negative outcome;
- publish a redacted scorecard after the disclosure and retention policy is
  approved;
- propose the next measured optimization hypothesis.

The evaluator may not automatically:

- lower a threshold after seeing a result;
- reclassify a critical failure as acceptable;
- expose or edit a holdout;
- trade quality for efficiency outside approved budgets;
- merge Hydra, publish a release, expand credentials, or change rulesets.

This preserves agent leadership over routine evidence work while keeping the
few decisions that define purpose, risk, and public effect with the human.
