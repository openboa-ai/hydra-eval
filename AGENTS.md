# Hydra Eval contributor contract

- Read `EVALUATION.md` before adding a task or interpreting a result. Evaluation is independent of Hydra's implementation.
- Use Harbor's task and job conventions where they fit. Do not create a parallel task schema or hide native evidence behind a composite score.
- Keep baseline and candidate conditions comparable, freeze the task/verifier when comparing them, and record exact client, model, environment, and revisions.
- Add assertions from observed outputs and intended outcomes. Use deterministic checks first; label model or human review clearly.
- Keep public results sanitized, append-only, and reproducible. Never commit secrets, private holdouts, or unreviewed sensitive traces.
- Treat `0.0.0` as a foundation: do not claim a runner, score, support, or release until a real run provides evidence.
