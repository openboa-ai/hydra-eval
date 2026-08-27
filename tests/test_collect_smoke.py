import importlib.util
import hashlib
import json
import subprocess
import tempfile
import types
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "scripts" / "collect_smoke.py"
SPEC = importlib.util.spec_from_file_location("collect_smoke", MODULE_PATH)
assert SPEC and SPEC.loader
collect_smoke = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(collect_smoke)
SMOKE_ENVIRONMENT_IMAGE = "ubuntu:24.04@sha256:" + "e" * 64


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value) + "\n")


class CollectSmokeTest(unittest.TestCase):
    def test_rejects_common_credentials(self) -> None:
        credentials = (
            b"sk-" + (b"a" * 24),
            b"gh" + b"p_" + (b"a" * 24),
            b"github_" + b"pat_" + (b"a" * 24),
            b"AKIA" + (b"A" * 16),
            b"ASIA" + (b"A" * 16),
            b"xoxb-" + (b"a" * 24),
            b"-----BEGIN " + b"PRIVATE KEY-----",
            b'{"access_' + b'token":"' + (b"a" * 24) + b'"}',
        )
        for credential in credentials:
            with self.subTest(prefix=credential[:8]):
                with self.assertRaises(collect_smoke.EvidenceError):
                    collect_smoke.check_sensitive("fixture", credential)

    def test_rejects_trajectory_without_instruction_and_action(self) -> None:
        invalid_trajectories = (
            {"schema_version": "ATIF-v1.7", "steps": []},
            {
                "schema_version": "ATIF-v1.7",
                "steps": [
                    {"source": "user", "message": "What is 19 + 23?"},
                    {"source": "agent", "message": "The answer is 42."},
                ],
            },
        )
        for trajectory in invalid_trajectories:
            with self.subTest(trajectory=trajectory):
                with self.assertRaises(collect_smoke.EvidenceError):
                    collect_smoke.sanitize_trajectory(trajectory, "public-session")

    def make_evaluation_bundle(
        self, root: Path
    ) -> tuple[Path, Path, str, str]:
        repository = root / "evaluation-source"
        bundle = root / "evaluation.bundle"

        def git(*arguments: str) -> str:
            return subprocess.run(
                ["git", "-C", str(repository), *arguments],
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
            ).stdout.strip()

        repository.mkdir()
        git("init", "--quiet")
        git("config", "user.name", "hydra-eval-test")
        git("config", "user.email", "hydra-eval-test@example.invalid")
        (repository / "base.txt").write_text("base\n")
        git("add", "base.txt")
        git("commit", "--quiet", "-m", "base")
        base_revision = git("rev-parse", "HEAD")
        (repository / "evaluator.txt").write_text("evaluator\n")
        (repository / "config").mkdir()
        (repository / "config" / "harbor-0.22.0.constraints").write_text(
            "harbor==0.22.0\n"
        )
        dockerfile = (
            repository
            / "tasks"
            / "smoke-question-answer"
            / "environment"
            / "Dockerfile"
        )
        dockerfile.parent.mkdir(parents=True)
        dockerfile.write_text(f"FROM {SMOKE_ENVIRONMENT_IMAGE}\n\nWORKDIR /app\n")
        git(
            "add",
            "evaluator.txt",
            "config/harbor-0.22.0.constraints",
            "tasks/smoke-question-answer/environment/Dockerfile",
        )
        git("commit", "--quiet", "-m", "evaluator")
        evaluation_revision = git("rev-parse", "HEAD")
        git("bundle", "create", str(bundle), "HEAD", f"^{base_revision}")
        return repository, bundle, evaluation_revision, base_revision

    def make_job(
        self,
        root: Path,
        name: str,
        agent: str,
        job_id: str,
        *,
        include_cost: bool = True,
    ) -> Path:
        job_dir = root / name
        trial_dir = job_dir / "trial-1"
        rewards = {"answer_exact": 1, "reward": 1}
        trial_result = {
            "id": "trial-id",
            "trial_uri": "file:///Users/example/private/trial",
            "trial_name": "trial-1",
            "task_name": "openboa/hydra-eval-smoke-question-answer",
            "task_checksum": "task-checksum",
            "agent_info": {
                "name": agent,
                "version": "0.147.0" if agent == "codex" else "1.0.0",
                "model_info": {"name": "openai/gpt-5.6-luna"} if agent == "codex" else None,
            },
            "exception_info": None,
            "verifier_result": {"rewards": rewards},
            "started_at": "2026-08-27T00:00:00Z",
            "finished_at": "2026-08-27T00:00:02Z",
        }
        stats = {
            "n_completed_trials": 1,
            "n_errored_trials": 0,
            "n_input_tokens": 100,
            "n_cache_tokens": 10,
            "n_output_tokens": 20,
        }
        if include_cost:
            stats["cost_usd"] = 0.001
        job_result = {
            "id": job_id,
            "stats": stats,
        }
        write_json(job_dir / "result.json", job_result)
        write_json(trial_dir / "config.json", {"task": "smoke-question-answer"})
        write_json(trial_dir / "result.json", trial_result)
        write_json(trial_dir / "verifier" / "reward.json", rewards)
        write_json(
            trial_dir / "agent" / "trajectory.json",
            {
                "schema_version": "ATIF-v1.7",
                "session_id": "private-session-id",
                "agent": {
                    "name": "codex",
                    "version": "0.147.0",
                    "model_name": "gpt-5.6-luna",
                },
                "final_metrics": {"total_prompt_tokens": 100},
                "steps": [
                    {"source": "system", "message": "private-system-context"},
                    {
                        "source": "user",
                        "message": "<recommended_plugins>ambient catalog</recommended_plugins>",
                    },
                    {"source": "user", "message": "What is 19 + 23?"},
                    {
                        "source": "agent",
                        "message": "Writing the answer.",
                        "tool_calls": [
                            {
                                "tool_call_id": "private-call-id",
                                "function_name": "exec",
                                "arguments": {"input": "write 42"},
                            }
                        ],
                    },
                ],
            },
        )
        answer = trial_dir / "artifacts" / "app" / "answer.txt"
        answer.parent.mkdir(parents=True, exist_ok=True)
        answer.write_text("42\n")
        return job_dir

    def make_environment_manifest(self, root: Path) -> Path:
        manifest = root / "environment-manifest.json"
        write_json(
            manifest,
            {
                "schemaVersion": 2,
                "mediaType": "application/vnd.oci.image.index.v1+json",
                "manifests": [
                    {
                        "mediaType": "application/vnd.oci.image.manifest.v1+json",
                        "size": 424,
                        "digest": "sha256:" + "2" * 64,
                        "platform": {
                            "architecture": "arm64",
                            "os": "linux",
                            "variant": "v8",
                        },
                    }
                ],
            },
        )
        return manifest

    def test_builds_append_only_sanitized_result(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            oracle = self.make_job(
                root, "oracle", "oracle", "00000000-0000-0000-0000-000000000001"
            )
            codex = self.make_job(
                root,
                "codex",
                "codex",
                "00000000-0000-0000-0000-000000000002",
                include_cost=False,
            )
            judge_result = root / "judge-result.json"
            judge_events = root / "judge-events.jsonl"
            write_json(
                judge_result,
                {"verdict": "pass", "score": 1, "reason": "The answer is 42."},
            )
            judge_events.write_text(
                json.dumps(
                    {
                        "type": "turn.completed",
                        "usage": {"input_tokens": 30, "output_tokens": 8},
                    }
                )
                + "\n"
            )
            (
                repository_root,
                evaluation_source_bundle,
                evaluation_revision,
                evaluation_base_revision,
            ) = self.make_evaluation_bundle(root)
            harbor_constraints_sha256 = hashlib.sha256(
                (repository_root / "config" / "harbor-0.22.0.constraints").read_bytes()
            ).hexdigest()
            args = types.SimpleNamespace(
                oracle_job_dir=oracle,
                job_dir=codex,
                judge_result=judge_result,
                judge_events=judge_events,
                results_root=root / "results",
                evaluation_revision=evaluation_revision,
                evidence_collector_revision=evaluation_revision,
                evaluation_base_revision=evaluation_base_revision,
                evaluation_source_bundle=evaluation_source_bundle,
                repository_root=repository_root,
                environment_image=SMOKE_ENVIRONMENT_IMAGE,
                environment_manifest=self.make_environment_manifest(root),
                harbor_version="0.22.0",
                harbor_python_version="3.12.11",
                harbor_constraints_sha256=harbor_constraints_sha256,
                uv_version="0.8.3",
                host_os="darwin",
                host_architecture="arm64",
                harbor_python_platform="macosx-11.0-arm64",
                container_platform="linux/arm64/v8",
                environment_manifest_digest="sha256:" + "2" * 64,
                solver_agent_version="0.147.0",
                solver_model="gpt-5.6-luna",
                solver_reasoning="low",
                judge_model="gpt-5.6-luna",
                judge_reasoning="low",
                judge_agent_version="0.144.5",
                judge_elapsed_seconds=1.5,
            )

            result_dir = collect_smoke.build_evidence(args)
            scorecard = json.loads((result_dir / "scorecard.json").read_text())
            self.assertEqual(scorecard["status"], "pass")
            self.assertEqual(scorecard["provenance"]["solver_reasoning"], "low")
            self.assertEqual(scorecard["provenance"]["judge_agent_version"], "0.144.5")
            self.assertEqual(
                scorecard["provenance"]["evidence_collector_revision"],
                evaluation_revision,
            )
            self.assertEqual(
                scorecard["provenance"]["evaluation_base_revision"],
                evaluation_base_revision,
            )
            self.assertEqual(
                scorecard["provenance"]["evaluation_bundle_sha256"],
                hashlib.sha256(evaluation_source_bundle.read_bytes()).hexdigest(),
            )
            self.assertEqual(
                scorecard["provenance"]["environment_image"],
                SMOKE_ENVIRONMENT_IMAGE,
            )
            self.assertEqual(scorecard["provenance"]["harbor_python_version"], "3.12.11")
            self.assertEqual(
                scorecard["provenance"]["harbor_constraints_sha256"],
                harbor_constraints_sha256,
            )
            self.assertEqual(scorecard["provenance"]["uv_version"], "0.8.3")
            self.assertEqual(
                scorecard["provenance"]["host_runtime"],
                {
                    "architecture": "arm64",
                    "os": "darwin",
                    "python_platform": "macosx-11.0-arm64",
                },
            )
            self.assertEqual(
                scorecard["provenance"]["container_runtime"],
                {
                    "base_manifest_digest": "sha256:" + "2" * 64,
                    "platform": "linux/arm64/v8",
                },
            )
            self.assertEqual(scorecard["measures"]["judge"]["input_tokens"], 30)
            self.assertIsNone(
                scorecard["measures"]["cost"][
                    "solver_api_equivalent_estimate_usd"
                ]
            )
            self.assertTrue((result_dir / "harbor" / "trajectory.json").is_file())
            self.assertTrue(
                (result_dir / "harbor" / "environment-manifest.json").is_file()
            )
            self.assertTrue((result_dir / "harbor" / "oracle-trial-result.json").is_file())
            self.assertTrue((result_dir / "judge" / "metrics.json").is_file())
            self.assertEqual(
                json.loads((result_dir / "judge" / "metrics.json").read_text()),
                scorecard["measures"]["judge"],
            )
            self.assertTrue((result_dir / "source" / "evaluation.bundle").is_file())
            public_files = "\n".join(
                path.read_text(errors="ignore")
                for path in result_dir.rglob("*")
                if path.is_file()
            )
            self.assertNotIn("/Users/", public_files)
            self.assertNotIn("private-system-context", public_files)
            self.assertNotIn("recommended_plugins", public_files)
            self.assertNotIn("private-session-id", public_files)
            self.assertFalse((result_dir / "judge" / "events.jsonl").exists())
            self.assertTrue((result_dir / "checksums.txt").is_file())

            with self.assertRaises(collect_smoke.EvidenceError):
                collect_smoke.build_evidence(args)

    def test_rejects_mismatched_oracle_task(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            oracle = self.make_job(
                root, "oracle", "oracle", "00000000-0000-0000-0000-000000000005"
            )
            codex = self.make_job(
                root, "codex", "codex", "00000000-0000-0000-0000-000000000006"
            )
            oracle_trial = oracle / "trial-1" / "result.json"
            oracle_result = json.loads(oracle_trial.read_text())
            oracle_result["task_checksum"] = "different-task-checksum"
            write_json(oracle_trial, oracle_result)
            judge_result = root / "judge-result.json"
            judge_events = root / "judge-events.jsonl"
            write_json(
                judge_result,
                {"verdict": "pass", "score": 1, "reason": "The answer is 42."},
            )
            judge_events.write_text(
                json.dumps({"usage": {"input_tokens": 1, "output_tokens": 1}}) + "\n"
            )
            (
                repository_root,
                evaluation_source_bundle,
                evaluation_revision,
                evaluation_base_revision,
            ) = self.make_evaluation_bundle(root)
            harbor_constraints_sha256 = hashlib.sha256(
                (repository_root / "config" / "harbor-0.22.0.constraints").read_bytes()
            ).hexdigest()
            args = types.SimpleNamespace(
                oracle_job_dir=oracle,
                job_dir=codex,
                judge_result=judge_result,
                judge_events=judge_events,
                results_root=root / "results",
                evaluation_revision=evaluation_revision,
                evidence_collector_revision=evaluation_revision,
                evaluation_base_revision=evaluation_base_revision,
                evaluation_source_bundle=evaluation_source_bundle,
                repository_root=repository_root,
                environment_image=SMOKE_ENVIRONMENT_IMAGE,
                environment_manifest=self.make_environment_manifest(root),
                harbor_version="0.22.0",
                harbor_python_version="3.12.11",
                harbor_constraints_sha256=harbor_constraints_sha256,
                uv_version="0.8.3",
                host_os="darwin",
                host_architecture="arm64",
                harbor_python_platform="macosx-11.0-arm64",
                container_platform="linux/arm64/v8",
                environment_manifest_digest="sha256:" + "2" * 64,
                solver_agent_version="0.147.0",
                solver_model="gpt-5.6-luna",
                solver_reasoning="low",
                judge_model="gpt-5.6-luna",
                judge_reasoning="low",
                judge_agent_version="0.144.5",
                judge_elapsed_seconds=1.0,
            )

            with self.assertRaises(collect_smoke.EvidenceError):
                collect_smoke.build_evidence(args)

    def test_rejects_failed_judge(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            oracle = self.make_job(
                root, "oracle", "oracle", "00000000-0000-0000-0000-000000000003"
            )
            codex = self.make_job(
                root, "codex", "codex", "00000000-0000-0000-0000-000000000004"
            )
            judge_result = root / "judge-result.json"
            judge_events = root / "judge-events.jsonl"
            write_json(judge_result, {"verdict": "fail", "score": 0, "reason": "No."})
            judge_events.write_text(
                json.dumps({"usage": {"input_tokens": 1, "output_tokens": 1}}) + "\n"
            )
            (
                repository_root,
                evaluation_source_bundle,
                evaluation_revision,
                evaluation_base_revision,
            ) = self.make_evaluation_bundle(root)
            harbor_constraints_sha256 = hashlib.sha256(
                (repository_root / "config" / "harbor-0.22.0.constraints").read_bytes()
            ).hexdigest()
            args = types.SimpleNamespace(
                oracle_job_dir=oracle,
                job_dir=codex,
                judge_result=judge_result,
                judge_events=judge_events,
                results_root=root / "results",
                evaluation_revision=evaluation_revision,
                evidence_collector_revision=evaluation_revision,
                evaluation_base_revision=evaluation_base_revision,
                evaluation_source_bundle=evaluation_source_bundle,
                repository_root=repository_root,
                environment_image=SMOKE_ENVIRONMENT_IMAGE,
                environment_manifest=self.make_environment_manifest(root),
                harbor_version="0.22.0",
                harbor_python_version="3.12.11",
                harbor_constraints_sha256=harbor_constraints_sha256,
                uv_version="0.8.3",
                host_os="darwin",
                host_architecture="arm64",
                harbor_python_platform="macosx-11.0-arm64",
                container_platform="linux/arm64/v8",
                environment_manifest_digest="sha256:" + "2" * 64,
                solver_agent_version="0.147.0",
                solver_model="gpt-5.6-luna",
                solver_reasoning="low",
                judge_model="gpt-5.6-luna",
                judge_reasoning="low",
                judge_agent_version="0.144.5",
                judge_elapsed_seconds=1.0,
            )

            with self.assertRaises(collect_smoke.EvidenceError):
                collect_smoke.build_evidence(args)


if __name__ == "__main__":
    unittest.main()
