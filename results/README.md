# Results

This directory stores reviewed and sanitized evidence, not live job output.

Use this layout for a real Hydra evaluation:

```text
results/hydra/<version>/<result-id>/
├── README.md
├── scorecard.md       # reviewed claims and separate measures
├── scorecard.json     # only when the reviewed run already has a stable JSON result
├── checksums.txt      # hashes for preserved artifacts
└── artifacts/         # sanitized Harbor-native evidence, when allowed
```

The exact Harbor `config.json`, `result.json`, trial/trajectory files, and verifier output remain the source evidence. The files above are a small reviewed presentation of that evidence, not a replacement schema. If a future Harbor version changes its native output, record the version and preserve the original shape rather than silently translating it.

Each result must state the Hydra revision, evaluation revision, task/dataset, client and version, model, environment, job/trial identifiers, verifier/reviewer, and time/token/cost/safety observations. Keep private inputs, credentials, sensitive traces, and holdout data outside this public repository.

Results are append-only. A flawed result gets an invalidation record; it is not edited in place and not deleted merely because a later candidate is better.
