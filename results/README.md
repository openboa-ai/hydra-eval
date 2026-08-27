# Results

This directory stores reviewed and sanitized evidence, not live job output.

Evaluator plumbing evidence belongs under `results/smoke/<harbor-job-id>/`. It proves only that the runner, agent, verifier, trajectory capture, judge, and evidence path worked. Hydra evaluation evidence remains separate under `results/hydra/<version>/<result-id>/`.

Use this layout for a real Hydra evaluation:

```text
results/hydra/<version>/<result-id>/
├── README.md
├── scorecard.md       # optional human-readable claims and separate measures
├── scorecard.json     # required machine-readable identity and provenance
├── checksums.txt      # hashes for preserved artifacts
├── source/
│   ├── evaluation.bundle  # evaluator source; exact recorded base is its prerequisite
│   └── hydra.bundle       # self-contained Hydra candidate source
└── artifacts/         # sanitized Harbor-native evidence, when allowed
```

The exact Harbor `config.json`, `result.json`, trial/trajectory files, verifier output, and raw judge events remain the local source evidence in ignored `jobs/`. Public files are a small reviewed presentation: keep the native job result and sanitized judge metrics where safe, remove host paths and unrelated agent context from the public trial and ATIF trajectory, retain the original schema version, and preserve the exact evaluation commit in `source/evaluation.bundle`. A real Hydra result must also preserve the exact candidate revision in a self-contained `source/hydra.bundle`; a 40-character revision string alone is not retrievable evidence. If a future Harbor version changes its native output, record the version rather than silently claiming equivalence.

Each Hydra `scorecard.json` must state the Hydra version and revision, result ID, evaluation revision, task, client and version, model, environment fingerprint, job ID, and verifier identity before CI will accept and permanently protect it. It must also contain at least one deterministic, model, or human assertion linked to a checksummed file under `artifacts/`, plus non-empty separate measures. A `pass` is accepted only when every recorded assertion passed. Reviewed time/token/cost/safety observations remain separate measures rather than one opaque score. A smoke result has no Hydra revision and must say so through its `evaluator_smoke` kind and non-benchmark claim; it must preserve the complete task, Harbor, solver, judge, host/container platform, resolved image manifest, environment, and measure provenance emitted by the collector.

Result bundles must contain regular files and directories only. Symlinks are rejected because their targets are outside the bundle checksum and can change independently. Before publication, Git bundle headers, prerequisites, advertised revisions, and every introduced Git object are inspected; this catches credentials left in deleted files as well as current files. Keep private inputs, credentials, sensitive traces, and holdout data outside this public repository.

Smoke and Hydra results are append-only. CI compares the pull request base and head to reject any change or deletion inside an already published `results/smoke/<job-id>/` or `results/hydra/<version>/<result-id>/` directory, verifies that the recorded evaluation commit is recoverable from a checksummed Git bundle whose exact prerequisite equals the recorded base, requires a self-contained candidate bundle for Hydra results, cross-checks smoke solver and judge measures against preserved evidence, and verifies that each checksum manifest covers the exact public file set. A flawed result gets an invalidation record; it is not edited in place and not deleted merely because a later candidate is better.
