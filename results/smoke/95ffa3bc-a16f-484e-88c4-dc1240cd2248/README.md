# Evaluator smoke 95ffa3bc-a16f-484e-88c4-dc1240cd2248

Status: **pass**

This record proves that the minimal Hydra Eval plumbing completed one Oracle reference run, one Harbor Codex trial, a deterministic verifier, and one separate read-only Codex judge. It is not a Hydra benchmark result and does not show that Hydra improves an agent.

- Evaluation revision: `eddb65f248bea1159c187c441a4c8ca29795ca57`
- Evidence collector revision: `eddb65f248bea1159c187c441a4c8ca29795ca57`
- Evaluation base revision: `7267bedd2671e56bcb2e9004510b513590afae94`
- Evaluation source bundle SHA-256: `99e7cb104d7b1170c762b48051e3ec28fcd63ecf03a20cc0c130950a2750099d`
- Environment image: `ubuntu:24.04@sha256:33ceb71981b602c1a7443a53469e4dba065f7503eab3078a2d7a57a2ab987517`
- Harbor job: `95ffa3bc-a16f-484e-88c4-dc1240cd2248`
- Harbor: `0.22.0`
- Harbor Python: `3.12.11`
- Harbor constraints SHA-256: `7d16a40fcd095a71d8f3eb102238898d700790230b450ff178d411a0ccf94a9f`
- uv: `0.8.3`
- Harbor host runtime: `darwin/arm64` (`macosx-11.0-arm64`)
- Container runtime: `linux/arm64/v8`
- Resolved environment manifest: `sha256:95fa486768020359141f1318720f43e7982ef926c792891d984aef9aaf05e7ea`
- Solver: `codex 0.147.0` with `gpt-5.6-luna` at `low` reasoning
- Judge: `codex 0.144.5` with `gpt-5.6-luna` at `low` reasoning
- Actual billed cost: `unknown` (ChatGPT subscription authentication)

See `scorecard.json` for separate checks, timing, token use, and the API-equivalent estimate reported by Harbor. Selected job evidence, the registry-authenticated native OCI image index, and the sanitized public trajectory are preserved under `harbor/`; the structured judge result, invocation metadata, and sanitized timing/usage evidence are under `judge/`. The exact evaluation commit can be recovered from `source/evaluation.bundle` even after a squash merge. Raw jobs and judge events remain local under the ignored `jobs/` directory.
