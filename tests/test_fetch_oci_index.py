import importlib.util
import json
import unittest
from pathlib import Path


MODULE_PATH = Path(__file__).parents[1] / "scripts" / "fetch_oci_index.py"
SPEC = importlib.util.spec_from_file_location("fetch_oci_index", MODULE_PATH)
assert SPEC and SPEC.loader
fetch_oci_index = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fetch_oci_index)


class FetchOciIndexTest(unittest.TestCase):
    def test_parses_docker_hub_reference_and_resolves_platform(self) -> None:
        digest = "sha256:" + "a" * 64
        repository, observed_digest = fetch_oci_index.docker_hub_repository(
            f"ubuntu:24.04@{digest}"
        )
        self.assertEqual(repository, "library/ubuntu")
        self.assertEqual(observed_digest, digest)

        raw = json.dumps(
            {
                "schemaVersion": 2,
                "manifests": [
                    {
                        "digest": "sha256:" + "b" * 64,
                        "platform": {
                            "os": "linux",
                            "architecture": "arm64",
                            "variant": "v8",
                        },
                    }
                ],
            }
        ).encode()
        self.assertEqual(
            fetch_oci_index.resolve_platform(raw, "linux", "arm64"),
            ("sha256:" + "b" * 64, "linux/arm64/v8"),
        )

    def test_rejects_unpinned_or_ambiguous_inputs(self) -> None:
        with self.assertRaises(fetch_oci_index.OciIndexError):
            fetch_oci_index.docker_hub_repository("ubuntu:24.04")
        duplicate = json.dumps(
            {
                "manifests": [
                    {
                        "digest": "sha256:" + value * 64,
                        "platform": {"os": "linux", "architecture": "arm64"},
                    }
                    for value in ("a", "b")
                ]
            }
        ).encode()
        with self.assertRaises(fetch_oci_index.OciIndexError):
            fetch_oci_index.resolve_platform(duplicate, "linux", "arm64")


if __name__ == "__main__":
    unittest.main()
