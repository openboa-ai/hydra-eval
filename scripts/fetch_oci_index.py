#!/usr/bin/env python3
"""Fetch exact Docker Hub OCI index bytes and resolve one runtime platform."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import subprocess
import sys
import tempfile
import urllib.parse
from pathlib import Path


class OciIndexError(RuntimeError):
    pass


def docker_hub_repository(image: str) -> tuple[str, str]:
    reference, separator, digest = image.rpartition("@")
    if not separator or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
        raise OciIndexError("image must be pinned with an sha256 digest")
    parts = reference.split("/")
    if len(parts) > 1 and ("." in parts[0] or ":" in parts[0]):
        registry = parts.pop(0)
        if registry not in {"docker.io", "index.docker.io", "registry-1.docker.io"}:
            raise OciIndexError(f"unsupported registry for raw index fetch: {registry}")
    repository = "/".join(parts)
    last = repository.rsplit("/", 1)[-1]
    if ":" in last:
        repository = repository[: -(len(last))] + last.rsplit(":", 1)[0]
        repository = repository.rstrip("/")
    if "/" not in repository:
        repository = f"library/{repository}"
    if not re.fullmatch(r"[a-z0-9]+(?:[._-][a-z0-9]+)*(?:/[a-z0-9]+(?:[._-][a-z0-9]+)*)+", repository):
        raise OciIndexError(f"unsupported Docker Hub repository: {repository!r}")
    return repository, digest


def run_curl(arguments: list[str], *, input_data: bytes | None = None) -> bytes:
    completed = subprocess.run(
        ["curl", *arguments],
        input=input_data,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if completed.returncode != 0:
        detail = completed.stderr.decode("utf-8", errors="replace").strip()
        raise OciIndexError(f"curl failed: {detail}")
    return completed.stdout


def fetch_index(image: str, output: Path) -> bytes:
    repository, digest = docker_hub_repository(image)
    query = urllib.parse.urlencode(
        {"service": "registry.docker.io", "scope": f"repository:{repository}:pull"}
    )
    token_document = run_curl(
        ["--fail", "--silent", "--show-error", f"https://auth.docker.io/token?{query}"]
    )
    try:
        token = json.loads(token_document)["token"]
    except (KeyError, TypeError, json.JSONDecodeError) as exc:
        raise OciIndexError("Docker Hub returned no usable bearer token") from exc
    if not isinstance(token, str) or not token:
        raise OciIndexError("Docker Hub returned an empty bearer token")

    accept = ", ".join(
        (
            "application/vnd.oci.image.index.v1+json",
            "application/vnd.docker.distribution.manifest.list.v2+json",
            "application/vnd.oci.image.manifest.v1+json",
            "application/vnd.docker.distribution.manifest.v2+json",
        )
    )
    config = (
        f'url = "https://registry-1.docker.io/v2/{repository}/manifests/{digest}"\n'
        'fail\n'
        'silent\n'
        'show-error\n'
        f'header = "Authorization: Bearer {token}"\n'
        f'header = "Accept: {accept}"\n'
    ).encode()
    raw = run_curl(["--config", "-"], input_data=config)
    observed = f"sha256:{hashlib.sha256(raw).hexdigest()}"
    if observed != digest:
        raise OciIndexError(f"registry bytes hash to {observed}, expected {digest}")
    try:
        document = json.loads(raw)
    except json.JSONDecodeError as exc:
        raise OciIndexError("registry response is not JSON") from exc
    if not isinstance(document, dict) or not isinstance(document.get("manifests"), list):
        raise OciIndexError("registry response is not an OCI image index")

    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(dir=output.parent, delete=False) as temporary:
        temporary.write(raw)
        temporary_path = Path(temporary.name)
    temporary_path.replace(output)
    return raw


def resolve_platform(raw: bytes, expected_os: str, expected_architecture: str) -> tuple[str, str]:
    document = json.loads(raw)
    matches: list[tuple[str, str]] = []
    for descriptor in document.get("manifests", []):
        if not isinstance(descriptor, dict):
            continue
        platform = descriptor.get("platform")
        if not isinstance(platform, dict):
            continue
        if platform.get("os") != expected_os or platform.get("architecture") != expected_architecture:
            continue
        digest = descriptor.get("digest")
        if not isinstance(digest, str) or not re.fullmatch(r"sha256:[0-9a-f]{64}", digest):
            continue
        resolved = f"{expected_os}/{expected_architecture}"
        variant = platform.get("variant")
        if isinstance(variant, str) and variant:
            resolved += f"/{variant}"
        matches.append((digest, resolved))
    if len(matches) != 1:
        raise OciIndexError(
            f"expected one manifest for {expected_os}/{expected_architecture}, found {len(matches)}"
        )
    return matches[0]


def parse_args(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--image", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--os", required=True)
    parser.add_argument("--architecture", required=True)
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv or sys.argv[1:])
    try:
        raw = fetch_index(args.image, args.output)
        digest, platform = resolve_platform(raw, args.os, args.architecture)
    except (OciIndexError, OSError) as exc:
        print(f"fetch-oci-index: {exc}", file=sys.stderr)
        return 1
    print(f"{digest}\t{platform}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
