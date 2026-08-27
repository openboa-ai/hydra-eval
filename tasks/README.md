# Tasks

Tasks are the unit of whole-agent evaluation. A task should describe work a capable agent could actually receive, not a trivia question designed to make a grader easy.

Use Harbor's task layout when adding the first task:

```text
tasks/<task-name>/
├── README.md
├── instruction.md
├── task.toml
├── environment/
├── tests/test.sh
└── solution/              # optional reference material
```

- `instruction.md` is the work request. It can describe a request, situation, event, or alert; it is the task's trigger and immediate goal.
- `environment/` is the managed input and context: files, repository state, configuration, fixtures, and permitted tools.
- `tests/test.sh` is the deterministic verifier. It should check the intended outcome and important safety properties, not a preferred wording.
- `task.toml` is Harbor metadata and resource configuration. Follow Harbor's documented fields; do not invent a Hydra task schema.
- `solution/` is optional reference material for task authors or a known-good fixture. It is not automatically shown to the agent.

Keep tasks small enough to run repeatedly but rich enough to expose whether the candidate improves useful autonomy. Start with two or three tasks, run baseline and candidate conditions, then refine assertions from observed outputs.
