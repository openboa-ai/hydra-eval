#!/usr/bin/env python3
"""Verify that a Git bundle is complete, correctly described, and safe to publish."""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path


SHA1 = re.compile(r"^[0-9a-f]{40}$")
SECRET_PATTERNS = (
    ("OpenAI-style token", re.compile(rb"sk-[A-Za-z0-9_-]{20,}")),
    ("GitHub token", re.compile(rb"gh[pousr]_[A-Za-z0-9]{20,}")),
    ("GitHub fine-grained token", re.compile(rb"github_pat_[A-Za-z0-9_]{20,}")),
    ("AWS access key", re.compile(rb"AKIA[0-9A-Z]{16}")),
    ("Slack token", re.compile(rb"xox[baprs]-[A-Za-z0-9-]{20,}")),
    (
        "private key",
        re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    ),
    (
        "assigned authentication token",
        re.compile(
            rb"(?:access|refresh|id)[_-]?token[\"']?\s*[:=]\s*[\"'][A-Za-z0-9._~-]{16,}",
            re.IGNORECASE,
        ),
    ),
    (
        "assigned OpenAI API key",
        re.compile(rb"OPENAI_API_KEY\s*=\s*[\"']?[^\s\"']{16,}"),
    ),
)


class BundleError(RuntimeError):
    pass


def run_git(
    args: list[str], *, repository: Path | None = None, input_data: bytes | None = None
) -> bytes:
    command = ["git"]
    if repository is not None:
        command.extend(["-C", str(repository)])
    command.extend(args)
    completed = subprocess.run(
        command,
        input=input_data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        detail = completed.stderr.decode("utf-8", errors="replace").strip()
        raise BundleError(f"git command failed ({' '.join(command)}): {detail}")
    return completed.stdout


def check_secrets(label: str, data: bytes) -> None:
    for name, pattern in SECRET_PATTERNS:
        if pattern.search(data):
            raise BundleError(f"{name} found in {label}")


def read_header(bundle: Path) -> tuple[list[str], dict[str, str], bytes]:
    prerequisites: list[str] = []
    references: dict[str, str] = {}
    header_lines: list[bytes] = []
    try:
        with bundle.open("rb") as stream:
            signature = stream.readline()
            if signature not in (b"# v2 git bundle\n", b"# v3 git bundle\n"):
                raise BundleError("unsupported or invalid Git bundle signature")
            header_lines.append(signature)
            while True:
                line = stream.readline()
                if line in (b"", b"\n"):
                    break
                header_lines.append(line)
                if line.startswith(b"@"):  # v3 capability
                    continue
                text = line.decode("utf-8", errors="strict").rstrip("\n")
                if text.startswith("-"):
                    revision = text[1:].split(" ", 1)[0]
                    if not SHA1.fullmatch(revision):
                        raise BundleError(f"invalid prerequisite revision: {revision!r}")
                    prerequisites.append(revision)
                    continue
                revision, separator, reference = text.partition(" ")
                if not separator or not SHA1.fullmatch(revision) or not reference:
                    raise BundleError(f"invalid bundle reference line: {text!r}")
                if reference in references:
                    raise BundleError(f"duplicate bundle reference: {reference}")
                references[reference] = revision
    except (OSError, UnicodeDecodeError) as exc:
        raise BundleError(f"cannot read bundle header: {exc}") from exc
    header = b"".join(header_lines)
    check_secrets("bundle header", header)
    return prerequisites, references, header


def all_objects(repository: Path) -> set[str]:
    output = run_git(
        ["cat-file", "--batch-all-objects", "--batch-check=%(objectname)"],
        repository=repository,
    )
    return {line for line in output.decode().splitlines() if SHA1.fullmatch(line)}


def inspect_objects(repository: Path, object_ids: set[str]) -> None:
    if not object_ids:
        raise BundleError("bundle introduced no Git objects")
    for object_id in sorted(object_ids):
        object_type = run_git(["cat-file", "-t", object_id], repository=repository)
        kind = object_type.decode().strip()
        content = run_git(["cat-file", "-p", object_id], repository=repository)
        check_secrets(f"bundled {kind} object {object_id}", content)


def check_bundle(
    bundle: Path,
    revision: str,
    expected_prerequisite: str | None,
    repository: Path | None,
) -> dict[str, object]:
    if not bundle.is_file():
        raise BundleError(f"bundle does not exist: {bundle}")
    if not SHA1.fullmatch(revision):
        raise BundleError(f"invalid expected revision: {revision!r}")
    if expected_prerequisite is not None and not SHA1.fullmatch(expected_prerequisite):
        raise BundleError(f"invalid expected prerequisite: {expected_prerequisite!r}")

    prerequisites, references, _ = read_header(bundle)
    expected_prerequisites = [] if expected_prerequisite is None else [expected_prerequisite]
    if prerequisites != expected_prerequisites:
        raise BundleError(
            "bundle prerequisites do not match the recorded base: "
            f"expected {expected_prerequisites}, found {prerequisites}"
        )
    if references != {"HEAD": revision}:
        raise BundleError(
            f"bundle must advertise only HEAD={revision}; found {references}"
        )
    if expected_prerequisite is not None and repository is None:
        raise BundleError("a repository is required for a bundle with a prerequisite")

    with tempfile.TemporaryDirectory(prefix="hydra-eval-bundle-check-") as temporary:
        inspection_repo = Path(temporary) / "objects.git"
        run_git(["init", "--quiet", "--bare", str(inspection_repo)])
        if expected_prerequisite is not None:
            assert repository is not None
            run_git(
                [
                    "fetch",
                    "--quiet",
                    "--no-tags",
                    str(repository.resolve()),
                    f"{expected_prerequisite}:refs/prerequisites/base",
                ],
                repository=inspection_repo,
            )
            resolved_base = run_git(
                ["rev-parse", "refs/prerequisites/base^{commit}"],
                repository=inspection_repo,
            ).decode().strip()
            if resolved_base != expected_prerequisite:
                raise BundleError(
                    f"repository resolved prerequisite as {resolved_base}, expected {expected_prerequisite}"
                )

        before = all_objects(inspection_repo)
        run_git(["bundle", "verify", str(bundle.resolve())], repository=inspection_repo)
        run_git(
            [
                "fetch",
                "--quiet",
                "--no-tags",
                str(bundle.resolve()),
                "HEAD:refs/heads/evaluation",
            ],
            repository=inspection_repo,
        )
        resolved_revision = run_git(
            ["rev-parse", "refs/heads/evaluation^{commit}"], repository=inspection_repo
        ).decode().strip()
        if resolved_revision != revision:
            raise BundleError(
                f"bundle resolved HEAD as {resolved_revision}, expected {revision}"
            )
        after = all_objects(inspection_repo)
        introduced = after - before
        inspect_objects(inspection_repo, introduced)

    return {
        "revision": revision,
        "prerequisite": expected_prerequisite,
        "introduced_object_count": len(introduced),
    }


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--bundle", type=Path, required=True)
    parser.add_argument("--revision", required=True)
    parser.add_argument(
        "--expected-prerequisite",
        required=True,
        help="The exact prerequisite SHA, or 'none' for a self-contained bundle.",
    )
    parser.add_argument("--repository", type=Path)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    prerequisite = (
        None if args.expected_prerequisite == "none" else args.expected_prerequisite
    )
    try:
        result = check_bundle(args.bundle, args.revision, prerequisite, args.repository)
    except BundleError as exc:
        print(f"check-source-bundle: {exc}", file=sys.stderr)
        return 1
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
