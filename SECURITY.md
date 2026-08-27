# Security policy

Evaluation tasks and traces can contain credentials, private repository data, customer information, or prompt-injection content. Treat every task input, agent output, artifact, and tool log as sensitive until it has been reviewed.

The public repository may contain only sanitized tasks and reviewed evidence. Keep secrets, private holdouts, raw sensitive traces, and access tokens outside Git. Do not paste credentials into an instruction or a result.

The smoke runner may use the existing Codex subscription session through Harbor's auth-file path and the local Codex CLI. Never pass the auth contents through an agent environment argument, print them, or copy them into `jobs/` or `results/`. The evidence collector allowlists selected output and rejects common credential fields before publication.

Report a vulnerability privately through GitHub's private vulnerability reporting for `openboa-ai/hydra-eval`. Include the affected commit, reproduction steps, impact, and a safe mitigation. Do not open a public issue for an undisclosed vulnerability.
