#!/usr/bin/env python3
"""Validate one completed smoke run and publish a sanitized evidence bundle."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import tempfile
from datetime import datetime
from pathlib import Path
from typing import Any


SENSITIVE_PATTERNS = (
    re.compile(r"sk-[A-Za-z0-9_-]{20,}"),
    re.compile(r"gh[pousr]_[A-Za-z0-9]{20,}"),
    re.compile(r"github_pat_[A-Za-z0-9_]{20,}"),
    re.compile(r"AKIA[0-9A-Z]{16}"),
    re.compile(r"xox[baprs]-[A-Za-z0-9-]{20,}"),
    re.compile(r"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(r"access[_-]?token", re.IGNORECASE),
    re.compile(r"refresh[_-]?token", re.IGNORECASE),
    re.compile(r"id[_-]?token", re.IGNORECASE),
    re.compile(r"OPENAI_API_KEY"),
    re.compile(r"CODEX_AUTH_JSON"),
    re.compile(r"file:///Users/"),
    re.compile(r"/Users/[^/\s]+"),
    re.compile(r"file:///home/"),
    re.compile(r"/home/[^/\s]+"),
)


class EvidenceError(RuntimeError):
    pass


def load_json(path: Path) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text())
    except (OSError, json.JSONDecodeError) as exc:
        raise EvidenceError(f"cannot read JSON from {path}: {exc}") from exc
    if not isinstance(value, dict):
        raise EvidenceError(f"expected a JSON object in {path}")
    return value


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    events: list[dict[str, Any]] = []
    try:
        lines = path.read_text().splitlines()
    except OSError as exc:
        raise EvidenceError(f"cannot read JSONL from {path}: {exc}") from exc
    for index, line in enumerate(lines, start=1):
        if not line.strip():
            continue
        try:
            event = json.loads(line)
        except json.JSONDecodeError as exc:
            raise EvidenceError(f"invalid JSONL at {path}:{index}: {exc}") from exc
        if not isinstance(event, dict):
            raise EvidenceError(f"expected a JSON object at {path}:{index}")
        events.append(event)
    if not events:
        raise EvidenceError(f"no judge events found in {path}")
    return events


def find_usage(value: Any) -> dict[str, int] | None:
    if isinstance(value, dict):
        if isinstance(value.get("input_tokens"), int) and isinstance(
            value.get("output_tokens"), int
        ):
            usage = {
                "input_tokens": value["input_tokens"],
                "output_tokens": value["output_tokens"],
            }
            for key in (
                "cached_input_tokens",
                "cache_tokens",
                "reasoning_output_tokens",
                "total_tokens",
            ):
                if isinstance(value.get(key), int):
                    usage[key] = value[key]
            return usage
        for child in value.values():
            result = find_usage(child)
            if result is not None:
                return result
    elif isinstance(value, list):
        for child in value:
            result = find_usage(child)
            if result is not None:
                return result
    return None


def parse_time(value: Any, label: str) -> datetime:
    if not isinstance(value, str):
        raise EvidenceError(f"missing {label}")
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise EvidenceError(f"invalid {label}: {value}") from exc


def validate_job(job_dir: Path, expected_agent: str) -> tuple[dict[str, Any], Path, dict[str, Any]]:
    job_result = load_json(job_dir / "result.json")
    stats = job_result.get("stats")
    if not isinstance(stats, dict):
        raise EvidenceError(f"missing job stats in {job_dir}")
    if stats.get("n_completed_trials") != 1 or stats.get("n_errored_trials") != 0:
        raise EvidenceError(f"job did not complete exactly one clean trial: {job_dir}")

    trial_dirs = sorted(
        path
        for path in job_dir.iterdir()
        if path.is_dir()
        and (path / "config.json").is_file()
        and (path / "result.json").is_file()
    )
    if len(trial_dirs) != 1:
        raise EvidenceError(f"expected one trial directory in {job_dir}, found {len(trial_dirs)}")
    trial_result = load_json(trial_dirs[0] / "result.json")
    agent_info = trial_result.get("agent_info")
    if not isinstance(agent_info, dict) or agent_info.get("name") != expected_agent:
        raise EvidenceError(f"expected {expected_agent} trial in {trial_dirs[0]}")
    if trial_result.get("exception_info") is not None:
        raise EvidenceError(f"trial recorded an exception in {trial_dirs[0]}")
    rewards = (trial_result.get("verifier_result") or {}).get("rewards")
    if not isinstance(rewards, dict) or rewards.get("reward") != 1:
        raise EvidenceError(f"trial reward is not 1 in {trial_dirs[0]}")
    return job_result, trial_dirs[0], trial_result


def check_sensitive(label: str, data: bytes) -> None:
    text = data.decode("utf-8", errors="ignore")
    for pattern in SENSITIVE_PATTERNS:
        if pattern.search(text):
            raise EvidenceError(f"sensitive pattern {pattern.pattern!r} found in {label}")


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n")


def copy_checked(source: Path, target: Path) -> None:
    try:
        data = source.read_bytes()
    except OSError as exc:
        raise EvidenceError(f"cannot read evidence file {source}: {exc}") from exc
    check_sensitive(str(source), data)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(data)


def check_evaluation_bundle(args: argparse.Namespace) -> None:
    checker = Path(__file__).with_name("check_source_bundle.py")
    completed = subprocess.run(
        [
            sys.executable,
            str(checker),
            "--bundle",
            str(args.evaluation_source_bundle),
            "--revision",
            args.evaluation_revision,
            "--expected-prerequisite",
            args.evaluation_base_revision,
            "--repository",
            str(args.repository_root),
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    if completed.returncode != 0:
        detail = completed.stderr.strip() or "bundle inspection failed"
        raise EvidenceError(f"evaluation source bundle is not publishable: {detail}")


def sanitize_trajectory(trajectory: dict[str, Any], public_session_id: str) -> dict[str, Any]:
    public_steps: list[dict[str, Any]] = []
    for step in trajectory.get("steps", []):
        if not isinstance(step, dict) or step.get("source") == "system":
            continue
        message = step.get("message")
        if isinstance(message, str) and "<recommended_plugins>" in message:
            continue
        if not message and not step.get("tool_calls"):
            continue

        public_step: dict[str, Any] = {"source": step.get("source")}
        if isinstance(message, str):
            public_step["message"] = message
        if isinstance(step.get("tool_calls"), list):
            public_step["tool_calls"] = [
                {
                    "function_name": call.get("function_name"),
                    "arguments": call.get("arguments"),
                }
                for call in step["tool_calls"]
                if isinstance(call, dict)
            ]
        if step.get("observation") is not None:
            public_step["observation"] = step["observation"]
        if step.get("usage") is not None:
            public_step["usage"] = step["usage"]
        public_steps.append(public_step)

    if not any(step.get("source") == "user" for step in public_steps):
        raise EvidenceError("sanitized trajectory has no task instruction")
    if not any(step.get("source") == "agent" for step in public_steps):
        raise EvidenceError("sanitized trajectory has no agent action")

    agent = trajectory.get("agent") or {}
    return {
        "schema_version": trajectory.get("schema_version"),
        "session_id": public_session_id,
        "agent": {
            key: agent.get(key)
            for key in ("name", "version", "model_name")
            if agent.get(key) is not None
        },
        "final_metrics": trajectory.get("final_metrics"),
        "steps": public_steps,
    }


def sanitize_trial_result(trial_result: dict[str, Any]) -> dict[str, Any]:
    return {
        key: trial_result.get(key)
        for key in (
            "id",
            "trial_name",
            "task_name",
            "task_checksum",
            "agent_info",
            "started_at",
            "finished_at",
            "verifier_result",
            "exception_info",
        )
    }


def build_evidence(args: argparse.Namespace) -> Path:
    oracle_job, _, oracle_trial_result = validate_job(args.oracle_job_dir, "oracle")
    job_result, trial_dir, trial_result = validate_job(args.job_dir, "codex")

    for field in ("task_name", "task_checksum"):
        if oracle_trial_result.get(field) != trial_result.get(field):
            raise EvidenceError(
                f"Oracle and solver {field} differ: "
                f"{oracle_trial_result.get(field)!r} != {trial_result.get(field)!r}"
            )

    reward_path = trial_dir / "verifier" / "reward.json"
    answer_path = trial_dir / "artifacts" / "app" / "answer.txt"
    trajectory_path = trial_dir / "agent" / "trajectory.json"
    reward = load_json(reward_path)
    trajectory = load_json(trajectory_path)
    judge = load_json(args.judge_result)
    judge_events = load_jsonl(args.judge_events)

    if reward.get("answer_exact") != 1 or reward.get("reward") != 1:
        raise EvidenceError("deterministic verifier did not pass")
    if answer_path.read_bytes() != b"42\n":
        raise EvidenceError("answer artifact is not exactly the bytes 42 followed by newline")
    if not str(trajectory.get("schema_version", "")).startswith("ATIF-v"):
        raise EvidenceError("trajectory is not a recognized ATIF document")
    if set(judge) != {"verdict", "score", "reason"}:
        raise EvidenceError("judge result does not match the required fields")
    if judge.get("verdict") != "pass" or judge.get("score") != 1:
        raise EvidenceError("AI judge did not pass")
    if not isinstance(judge.get("reason"), str) or not judge["reason"].strip():
        raise EvidenceError("AI judge reason is empty")

    solver_stats = job_result["stats"]
    for field in ("n_input_tokens", "n_output_tokens"):
        if not isinstance(solver_stats.get(field), int):
            raise EvidenceError(f"missing solver token field: {field}")
    judge_usage = find_usage(judge_events)
    if judge_usage is None:
        raise EvidenceError("judge JSONL does not contain token usage")
    check_evaluation_bundle(args)
    try:
        evaluation_bundle_data = args.evaluation_source_bundle.read_bytes()
    except OSError as exc:
        raise EvidenceError(f"cannot read evaluation source bundle: {exc}") from exc
    check_sensitive(str(args.evaluation_source_bundle), evaluation_bundle_data)
    evaluation_bundle_sha256 = hashlib.sha256(evaluation_bundle_data).hexdigest()

    agent_info = trial_result["agent_info"]
    if agent_info.get("version") != args.solver_agent_version:
        raise EvidenceError(
            f"solver agent version mismatch: {agent_info.get('version')} != {args.solver_agent_version}"
        )
    recorded_model = ((agent_info.get("model_info") or {}).get("name") or "")
    if not recorded_model.endswith(args.solver_model):
        raise EvidenceError(f"solver model mismatch: {recorded_model}")

    started_at = parse_time(trial_result.get("started_at"), "trial started_at")
    finished_at = parse_time(trial_result.get("finished_at"), "trial finished_at")
    solver_elapsed = (finished_at - started_at).total_seconds()
    job_id = job_result.get("id")
    if not isinstance(job_id, str) or not job_id:
        raise EvidenceError("Harbor job id is missing")
    public_trajectory = sanitize_trajectory(trajectory, job_id)
    public_trial_result = sanitize_trial_result(trial_result)
    public_oracle_trial_result = sanitize_trial_result(oracle_trial_result)
    judge_measures = {
        "elapsed_seconds": args.judge_elapsed_seconds,
        **judge_usage,
    }

    result_dir = args.results_root / job_id
    if result_dir.exists():
        raise EvidenceError(f"append-only result already exists: {result_dir}")

    scorecard = {
        "kind": "evaluator_smoke",
        "status": "pass",
        "claim": "The minimal evaluator plumbing completed; this is not a Hydra benchmark result.",
        "job_id": job_id,
        "provenance": {
            "evaluation_revision": args.evaluation_revision,
            "evidence_collector_revision": args.evidence_collector_revision,
            "evaluation_base_revision": args.evaluation_base_revision,
            "evaluation_bundle_sha256": evaluation_bundle_sha256,
            "environment_image": args.environment_image,
            "task": trial_result.get("task_name"),
            "task_checksum": trial_result.get("task_checksum"),
            "oracle_task_checksum": oracle_trial_result.get("task_checksum"),
            "harbor_version": args.harbor_version,
            "harbor_python_version": args.harbor_python_version,
            "harbor_constraints_sha256": args.harbor_constraints_sha256,
            "uv_version": args.uv_version,
            "host_runtime": {
                "os": args.host_os,
                "architecture": args.host_architecture,
                "python_platform": args.harbor_python_platform,
            },
            "container_runtime": {
                "platform": args.container_platform,
                "base_manifest_digest": args.environment_manifest_digest,
            },
            "solver_agent": "codex",
            "solver_agent_version": args.solver_agent_version,
            "solver_model": args.solver_model,
            "solver_reasoning": args.solver_reasoning,
            "judge_agent": "codex",
            "judge_agent_version": args.judge_agent_version,
            "judge_model": args.judge_model,
            "judge_reasoning": args.judge_reasoning,
            "oracle_job_id": oracle_job.get("id"),
        },
        "checks": {
            "oracle_reference": "pass",
            "deterministic_verifier": reward,
            "ai_judge": judge,
            "atif_trajectory": "present",
        },
        "measures": {
            "solver": {
                "elapsed_seconds": solver_elapsed,
                "input_tokens": solver_stats.get("n_input_tokens"),
                "cache_tokens": solver_stats.get("n_cache_tokens"),
                "output_tokens": solver_stats.get("n_output_tokens"),
            },
            "judge": {
                **judge_measures,
            },
            "cost": {
                "billing_basis": "ChatGPT subscription",
                "billed_cost_usd": "unknown",
                "solver_api_equivalent_estimate_usd": solver_stats.get("cost_usd"),
                "judge_api_equivalent_estimate_usd": "unknown",
            },
        },
    }

    with tempfile.TemporaryDirectory(prefix="hydra-eval-evidence-") as temporary:
        stage = Path(temporary) / job_id
        write_json(stage / "scorecard.json", scorecard)
        copy_checked(args.oracle_job_dir / "result.json", stage / "harbor" / "oracle-job-result.json")
        write_json(
            stage / "harbor" / "oracle-trial-result.json", public_oracle_trial_result
        )
        copy_checked(args.job_dir / "result.json", stage / "harbor" / "job-result.json")
        write_json(stage / "harbor" / "trial-result.json", public_trial_result)
        copy_checked(reward_path, stage / "harbor" / "verifier-reward.json")
        copy_checked(answer_path, stage / "harbor" / "answer.txt")
        write_json(stage / "harbor" / "trajectory.json", public_trajectory)
        copy_checked(args.judge_result, stage / "judge" / "result.json")
        write_json(stage / "judge" / "metrics.json", judge_measures)
        copy_checked(args.evaluation_source_bundle, stage / "source" / "evaluation.bundle")

        readme = f"""# Evaluator smoke {job_id}

Status: **pass**

This record proves that the minimal Hydra Eval plumbing completed one Oracle reference run, one Harbor Codex trial, a deterministic verifier, and one separate read-only Codex judge. It is not a Hydra benchmark result and does not show that Hydra improves an agent.

- Evaluation revision: `{args.evaluation_revision}`
- Evidence collector revision: `{args.evidence_collector_revision}`
- Evaluation base revision: `{args.evaluation_base_revision}`
- Evaluation source bundle SHA-256: `{evaluation_bundle_sha256}`
- Environment image: `{args.environment_image}`
- Harbor job: `{job_id}`
- Harbor: `{args.harbor_version}`
- Harbor Python: `{args.harbor_python_version}`
- Harbor constraints SHA-256: `{args.harbor_constraints_sha256}`
- uv: `{args.uv_version}`
- Harbor host runtime: `{args.host_os}/{args.host_architecture}` (`{args.harbor_python_platform}`)
- Container runtime: `{args.container_platform}`
- Resolved environment manifest: `{args.environment_manifest_digest}`
- Solver: `codex {args.solver_agent_version}` with `{args.solver_model}` at `{args.solver_reasoning}` reasoning
- Judge: `codex {args.judge_agent_version}` with `{args.judge_model}` at `{args.judge_reasoning}` reasoning
- Actual billed cost: `unknown` (ChatGPT subscription authentication)

See `scorecard.json` for separate checks, timing, token use, and the API-equivalent estimate reported by Harbor. Selected job evidence and the sanitized public trajectory are preserved under `harbor/`; the structured judge result and sanitized timing/usage evidence are under `judge/`. The exact evaluation commit can be recovered from `source/evaluation.bundle` even after a squash merge. Raw jobs and judge events remain local under the ignored `jobs/` directory.
"""
        (stage / "README.md").write_text(readme)

        for path in sorted(p for p in stage.rglob("*") if p.is_file()):
            check_sensitive(str(path), path.read_bytes())

        checksum_lines = []
        for path in sorted(p for p in stage.rglob("*") if p.is_file()):
            relative = path.relative_to(stage)
            digest = hashlib.sha256(path.read_bytes()).hexdigest()
            checksum_lines.append(f"{digest}  {relative.as_posix()}")
        (stage / "checksums.txt").write_text("\n".join(checksum_lines) + "\n")
        args.results_root.mkdir(parents=True, exist_ok=True)
        shutil.copytree(stage, result_dir)

    return result_dir


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--oracle-job-dir", type=Path, required=True)
    parser.add_argument("--job-dir", type=Path, required=True)
    parser.add_argument("--judge-result", type=Path, required=True)
    parser.add_argument("--judge-events", type=Path, required=True)
    parser.add_argument("--results-root", type=Path, required=True)
    parser.add_argument("--evaluation-revision", required=True)
    parser.add_argument("--evidence-collector-revision", required=True)
    parser.add_argument("--evaluation-base-revision", required=True)
    parser.add_argument("--evaluation-source-bundle", type=Path, required=True)
    parser.add_argument("--repository-root", type=Path, required=True)
    parser.add_argument("--environment-image", required=True)
    parser.add_argument("--harbor-version", required=True)
    parser.add_argument("--harbor-python-version", required=True)
    parser.add_argument("--harbor-constraints-sha256", required=True)
    parser.add_argument("--uv-version", required=True)
    parser.add_argument("--host-os", required=True)
    parser.add_argument("--host-architecture", required=True)
    parser.add_argument("--harbor-python-platform", required=True)
    parser.add_argument("--container-platform", required=True)
    parser.add_argument("--environment-manifest-digest", required=True)
    parser.add_argument("--solver-agent-version", required=True)
    parser.add_argument("--solver-model", required=True)
    parser.add_argument("--solver-reasoning", required=True)
    parser.add_argument("--judge-model", required=True)
    parser.add_argument("--judge-reasoning", required=True)
    parser.add_argument("--judge-agent-version", required=True)
    parser.add_argument("--judge-elapsed-seconds", type=float, required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    try:
        result_dir = build_evidence(parse_args(argv or sys.argv[1:]))
    except EvidenceError as exc:
        print(f"collect-smoke: {exc}", file=sys.stderr)
        return 1
    print(result_dir)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
