# Evaluate the smoke answer

Inspect only these files in the current directory:

- `question.md`: the question and requested output contract;
- `answer.txt`: the agent's answer;
- `verifier-reward.json`: the deterministic verifier result.

Return `pass` with score `1` only when the answer correctly resolves the question and the deterministic verifier reports both `answer_exact` and `reward` as `1`. Otherwise return `fail` with score `0`. Keep the reason short and factual. Do not modify any file.
