import importlib.util
import subprocess
import tempfile
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "scripts" / "check_source_bundle.py"
SPEC = importlib.util.spec_from_file_location("check_source_bundle", MODULE_PATH)
assert SPEC and SPEC.loader
check_source_bundle = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(check_source_bundle)


class SourceBundleTest(unittest.TestCase):
    def make_repository(self, root: Path) -> tuple[Path, str]:
        repository = root / "repository"
        repository.mkdir()
        self.git(repository, "init", "--quiet")
        self.git(repository, "config", "user.name", "hydra-eval-test")
        self.git(
            repository,
            "config",
            "user.email",
            "hydra-eval-test@example.invalid",
        )
        (repository / "base.txt").write_text("base\n")
        self.git(repository, "add", "base.txt")
        self.git(repository, "commit", "--quiet", "-m", "base")
        return repository, self.git(repository, "rev-parse", "HEAD")

    def git(self, repository: Path, *arguments: str) -> str:
        return subprocess.run(
            ["git", "-C", str(repository), *arguments],
            check=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        ).stdout.strip()

    def test_checks_exact_prerequisite_and_revision(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repository, base_revision = self.make_repository(root)
            (repository / "evaluator.txt").write_text("safe evaluator\n")
            self.git(repository, "add", "evaluator.txt")
            self.git(repository, "commit", "--quiet", "-m", "evaluator")
            evaluation_revision = self.git(repository, "rev-parse", "HEAD")
            bundle = root / "evaluation.bundle"
            self.git(
                repository,
                "bundle",
                "create",
                str(bundle),
                "HEAD",
                f"^{base_revision}",
            )

            result = check_source_bundle.check_bundle(
                bundle, evaluation_revision, base_revision, repository
            )
            self.assertEqual(result["revision"], evaluation_revision)
            self.assertEqual(result["prerequisite"], base_revision)
            self.assertGreater(result["introduced_object_count"], 0)

            with self.assertRaises(check_source_bundle.BundleError):
                check_source_bundle.check_bundle(
                    bundle, evaluation_revision, evaluation_revision, repository
                )

    def test_rejects_secret_in_deleted_blob(self) -> None:
        secrets = (
            "sk-" + ("a" * 24),
            "ACCESS_" + "TOKEN=" + ("a" * 24),
        )
        for secret in secrets:
            with self.subTest(prefix=secret[:8]):
                with tempfile.TemporaryDirectory() as temporary:
                    root = Path(temporary)
                    repository, base_revision = self.make_repository(root)
                    (repository / "temporary-credential.txt").write_text(secret + "\n")
                    self.git(repository, "add", "temporary-credential.txt")
                    self.git(
                        repository,
                        "commit",
                        "--quiet",
                        "-m",
                        "temporary credential",
                    )
                    (repository / "temporary-credential.txt").unlink()
                    self.git(repository, "add", "-u")
                    self.git(repository, "commit", "--quiet", "-m", "remove credential")
                    evaluation_revision = self.git(repository, "rev-parse", "HEAD")
                    bundle = root / "evaluation.bundle"
                    self.git(
                        repository,
                        "bundle",
                        "create",
                        str(bundle),
                        "HEAD",
                        f"^{base_revision}",
                    )

                    with self.assertRaises(check_source_bundle.BundleError):
                        check_source_bundle.check_bundle(
                            bundle, evaluation_revision, base_revision, repository
                        )

    def test_accepts_self_contained_candidate_bundle(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            repository, _ = self.make_repository(root)
            (repository / "candidate.txt").write_text("safe candidate\n")
            self.git(repository, "add", "candidate.txt")
            self.git(repository, "commit", "--quiet", "-m", "candidate")
            candidate_revision = self.git(repository, "rev-parse", "HEAD")
            bundle = root / "hydra.bundle"
            self.git(repository, "bundle", "create", str(bundle), "HEAD")

            result = check_source_bundle.check_bundle(
                bundle, candidate_revision, None, None
            )
            self.assertEqual(result["revision"], candidate_revision)
            self.assertIsNone(result["prerequisite"])
            self.assertGreater(result["introduced_object_count"], 0)


if __name__ == "__main__":
    unittest.main()
