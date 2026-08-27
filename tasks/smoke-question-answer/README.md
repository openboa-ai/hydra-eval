# Question-answer smoke task

This task proves that Hydra Eval can run one agent trial end to end. It is deliberately trivial: the agent answers a fixed arithmetic question by writing the answer to a file, and a deterministic verifier checks the file.

Passing this task is evidence that the evaluation plumbing works. It is not evidence that Hydra improves an agent and it is not a Hydra benchmark score.

The task uses Harbor's native task layout and terminology. Its Ubuntu base image is pinned by digest so the same task revision does not silently receive a different filesystem. Run the reference solution with the Oracle agent before spending an agent run.
