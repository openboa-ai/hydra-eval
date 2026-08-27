#!/usr/bin/env bash
set -euo pipefail

HARBOR_VERSION="0.22.0"
HARBOR_PYTHON_VERSION="3.12.11"
CODEX_AGENT_VERSION="0.147.0"
MODEL="gpt-5.6-luna"
REASONING="low"

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
task_dir="${repo_root}/tasks/smoke-question-answer"
jobs_dir="${repo_root}/jobs"
results_root="${repo_root}/results/smoke"
codex_config="${repo_root}/config/codex-low-cost.toml"
judge_prompt="${repo_root}/judges/smoke-question-answer.md"
judge_schema="${repo_root}/judges/smoke-question-answer.schema.json"
harbor_constraints="${repo_root}/config/harbor-0.22.0.constraints"
source_bundle_checker="${repo_root}/scripts/check_source_bundle.py"
oci_index_fetcher="${repo_root}/scripts/fetch_oci_index.py"
environment_image=""
environment_manifest_digest=""
environment_manifest_evidence=""
container_platform=""
host_os=""
host_architecture=""
harbor_python_platform=""
evaluation_source_bundle=""
compose_config_dir=""
judge_input=""

cleanup() {
  if [[ -n "${evaluation_source_bundle}" && -f "${evaluation_source_bundle}" ]]; then
    rm -f -- "${evaluation_source_bundle}"
  fi
  if [[ -n "${environment_manifest_evidence}" && -f "${environment_manifest_evidence}" ]]; then
    rm -f -- "${environment_manifest_evidence}"
  fi
  if [[ -n "${judge_input}" && -d "${judge_input}" ]]; then
    rm -rf -- "${judge_input}"
  fi
  if [[ -n "${compose_config_dir}" && -d "${compose_config_dir}" ]]; then
    rm -rf -- "${compose_config_dir}"
  fi
}
trap cleanup EXIT

fail() {
  printf 'run-smoke: %s\n' "$*" >&2
  exit 1
}

if [[ -n "$(git -C "${repo_root}" status --porcelain --untracked-files=all)" ]]; then
  fail "commit or remove tracked and untracked files before running so evidence can name an exact evaluation revision"
fi

for command_name in uv docker codex python3 curl jq; do
  command -v "${command_name}" >/dev/null 2>&1 || fail "missing command: ${command_name}"
done

[[ -f "${HOME}/.codex/auth.json" ]] || fail "missing Codex subscription auth at ${HOME}/.codex/auth.json"
[[ -f "${task_dir}/task.toml" ]] || fail "missing smoke task"
[[ -f "${codex_config}" ]] || fail "missing Codex config"
[[ -f "${harbor_constraints}" ]] || fail "missing Harbor constraints"
[[ -x "${source_bundle_checker}" ]] || fail "missing executable source-bundle checker"
[[ -x "${oci_index_fetcher}" ]] || fail "missing executable OCI index fetcher"
environment_image="$(awk 'toupper($1) == "FROM" {print $2; exit}' "${task_dir}/environment/Dockerfile")"
[[ "${environment_image}" =~ ^ubuntu:24\.04@sha256:[a-f0-9]{64}$ ]] || fail "smoke environment image is not pinned by digest"
harbor_constraints_sha256="$(shasum -a 256 "${harbor_constraints}" | awk '{print $1}')"
uv_version="$(uv --version | awk '{print $2}')"
harbor_runtime=(
  uvx
  --python "${HARBOR_PYTHON_VERSION}"
  --constraints "${harbor_constraints}"
  --from "harbor==${HARBOR_VERSION}"
)

ensure_docker() {
  if docker info >/dev/null 2>&1; then
    return
  fi

  if [[ "$(uname -s)" == "Darwin" && -d /Applications/Docker.app ]]; then
    open -a Docker
  elif command -v colima >/dev/null 2>&1; then
    colima start --cpu 2 --memory 4 --disk 20
  else
    fail "no running Docker-compatible daemon and no Docker Desktop or Colima installation found"
  fi

  for _ in $(seq 1 60); do
    if docker info >/dev/null 2>&1; then
      return
    fi
    sleep 2
  done
  fail "Docker-compatible daemon did not become ready within 120 seconds"
}

ensure_docker

ensure_docker_compose() {
  if docker compose version >/dev/null 2>&1; then
    return
  fi

  local compose_plugin=""
  local docker_host=""
  for candidate in /opt/homebrew/bin/docker-compose /usr/local/bin/docker-compose; do
    if [[ -x "${candidate}" ]]; then
      compose_plugin="${candidate}"
      break
    fi
  done

  [[ -n "${compose_plugin}" ]] || fail "Docker Compose plugin is unavailable"
  docker_host="$(docker context inspect --format '{{.Endpoints.docker.Host}}' 2>/dev/null || true)"
  [[ -n "${docker_host}" ]] || fail "could not resolve the active Docker daemon endpoint"

  compose_config_dir="$(mktemp -d /tmp/hydra-eval-docker-config.XXXXXX)"
  mkdir -p "${compose_config_dir}/cli-plugins"
  ln -s "${compose_plugin}" "${compose_config_dir}/cli-plugins/docker-compose"
  export DOCKER_CONFIG="${compose_config_dir}"
  export DOCKER_HOST="${docker_host}"

  docker compose version >/dev/null 2>&1 || fail "Docker Compose plugin could not be loaded"
}

validate_harbor_job() {
  local job_dir="$1"
  local require_reward="$2"
  python3 - "${job_dir}" "${require_reward}" <<'PY'
import json
import sys
from pathlib import Path

job_dir = Path(sys.argv[1])
require_reward = sys.argv[2] == "yes"
result_path = job_dir / "result.json"
if not result_path.is_file():
    raise SystemExit(f"missing Harbor job result: {result_path}")

job = json.loads(result_path.read_text())
stats = job.get("stats", {})
if stats.get("n_completed_trials") != 1 or stats.get("n_errored_trials") != 0:
    raise SystemExit(
        "Harbor job did not complete cleanly: "
        f"completed={stats.get('n_completed_trials')} errored={stats.get('n_errored_trials')}"
    )

trial_dirs = [
    path.parent
    for path in job_dir.glob("*/result.json")
    if (path.parent / "config.json").is_file()
]
if len(trial_dirs) != 1:
    raise SystemExit(f"expected exactly one Harbor trial, found {len(trial_dirs)}")

if require_reward:
    reward_path = trial_dirs[0] / "verifier" / "reward.json"
    if not reward_path.is_file():
        raise SystemExit(f"missing Oracle verifier reward: {reward_path}")
    reward = json.loads(reward_path.read_text())
    if reward.get("reward") != 1:
        raise SystemExit(f"Oracle verifier reward was not 1: {reward.get('reward')!r}")
PY
}

ensure_docker_compose

IFS=$'\t' read -r host_os host_architecture harbor_python_platform < <(
  "${harbor_runtime[@]}" python -c \
    'import platform, sysconfig; print(platform.system().lower(), platform.machine().lower(), sysconfig.get_platform(), sep="\t")'
)
[[ -n "${host_os}" && -n "${host_architecture}" && -n "${harbor_python_platform}" ]] \
  || fail "could not determine the Harbor host runtime platform"

docker_server_platform="$(docker version --format '{{.Server.Os}}/{{.Server.Arch}}')"
[[ "${docker_server_platform}" =~ ^[a-z0-9._-]+/[a-z0-9._-]+$ ]] \
  || fail "could not determine the Docker server platform"
docker_server_os="${docker_server_platform%%/*}"
docker_server_architecture="${docker_server_platform##*/}"

environment_manifest_evidence="$(mktemp /tmp/hydra-eval-environment-index.XXXXXX)"
manifest_match="$(python3 "${oci_index_fetcher}" \
  --image "${environment_image}" \
  --output "${environment_manifest_evidence}" \
  --os "${docker_server_os}" \
  --architecture "${docker_server_architecture}")" \
  || fail "could not preserve and resolve the registry-authenticated environment index"
IFS=$'\t' read -r environment_manifest_digest container_platform <<< "${manifest_match}"
[[ "${environment_manifest_digest}" =~ ^sha256:[a-f0-9]{64}$ ]] \
  || fail "resolved environment manifest digest is invalid"
[[ "${container_platform}" =~ ^[a-z0-9._-]+/[a-z0-9._-]+(/[a-z0-9._-]+)?$ ]] \
  || fail "resolved container platform is invalid"
export DOCKER_DEFAULT_PLATFORM="${container_platform}"

evaluation_revision="$(git -C "${repo_root}" rev-parse HEAD)"
evaluation_base_revision="$(git -C "${repo_root}" merge-base HEAD origin/main)"
evaluation_source_bundle="$(mktemp /tmp/hydra-eval-source-bundle.XXXXXX)"
if [[ "${evaluation_base_revision}" == "${evaluation_revision}" ]]; then
  evaluation_base_revision="none"
  git -C "${repo_root}" bundle create "${evaluation_source_bundle}" HEAD
else
  git -C "${repo_root}" bundle create "${evaluation_source_bundle}" \
    HEAD "^${evaluation_base_revision}"
fi
git -C "${repo_root}" bundle verify "${evaluation_source_bundle}" >/dev/null
git -C "${repo_root}" bundle list-heads "${evaluation_source_bundle}" \
  | awk -v revision="${evaluation_revision}" '$1 == revision && $2 == "HEAD" { found = 1 } END { exit !found }' \
  || fail "evaluation source bundle does not advertise the evaluation revision"
python3 "${source_bundle_checker}" \
  --bundle "${evaluation_source_bundle}" \
  --revision "${evaluation_revision}" \
  --expected-prerequisite "${evaluation_base_revision}" \
  --repository "${repo_root}" \
  --expected-file-sha256 "config/harbor-0.22.0.constraints=${harbor_constraints_sha256}" \
  --expected-constraint "config/harbor-0.22.0.constraints:harbor=${HARBOR_VERSION}" \
  --expected-docker-image "tasks/smoke-question-answer/environment/Dockerfile=${environment_image}" >/dev/null \
  || fail "evaluation source bundle failed object-level safety and provenance checks"
run_id="$(date -u +%Y%m%dT%H%M%SZ)-${evaluation_revision:0:12}"
oracle_job_name="smoke-oracle-${run_id}"
codex_job_name="smoke-codex-${run_id}"
oracle_job_dir="${jobs_dir}/${oracle_job_name}"
codex_job_dir="${jobs_dir}/${codex_job_name}"
judge_dir="${jobs_dir}/${codex_job_name}-judge"
judge_input="$(mktemp -d /tmp/hydra-eval-judge.XXXXXX)"
judge_codex_version="$(codex --version | awk '{print $NF}')"

[[ -n "${judge_codex_version}" ]] || fail "could not determine the host Codex CLI version"

mkdir -p "${jobs_dir}" "${judge_dir}"

harbor=("${harbor_runtime[@]}" harbor)
common=(
  run
  --path "${task_dir}"
  --jobs-dir "${jobs_dir}"
  --n-attempts 1
  --n-concurrent 1
  --max-retries 0
  --artifact /app/answer.txt
  --delete
  --yes
)

printf '%s\n' "[1/4] Oracle reference run"
"${harbor[@]}" "${common[@]}" --job-name "${oracle_job_name}" --agent oracle
validate_harbor_job "${oracle_job_dir}" yes

printf '%s\n' "[2/4] Codex solver run"
CODEX_FORCE_AUTH_JSON=1 "${harbor[@]}" "${common[@]}" \
  --job-name "${codex_job_name}" \
  --agent codex \
  --model "openai/${MODEL}" \
  --agent-kwarg "version=${CODEX_AGENT_VERSION}" \
  --agent-kwarg "config=${codex_config}"
validate_harbor_job "${codex_job_dir}" no

trial_dir="$(find "${codex_job_dir}" -mindepth 1 -maxdepth 1 -type d -exec test -f '{}/result.json' ';' -print)"
[[ -n "${trial_dir}" && "$(printf '%s\n' "${trial_dir}" | wc -l | tr -d ' ')" == "1" ]] || fail "expected exactly one Codex trial directory"

answer_path="${trial_dir}/artifacts/app/answer.txt"
reward_path="${trial_dir}/verifier/reward.json"
trajectory_path="${trial_dir}/agent/trajectory.json"
[[ -f "${answer_path}" ]] || fail "missing answer artifact"
[[ -f "${reward_path}" ]] || fail "missing verifier reward"
[[ -f "${trajectory_path}" ]] || fail "missing ATIF trajectory"

cp "${task_dir}/instruction.md" "${judge_input}/question.md"
cp "${answer_path}" "${judge_input}/answer.txt"
cp "${reward_path}" "${judge_input}/verifier-reward.json"

printf '%s\n' "[3/4] Separate read-only Codex judge"
judge_invocation="${judge_dir}/invocation.json"
jq -n \
  --arg agent "codex" \
  --arg agent_version "${judge_codex_version}" \
  --arg model "${MODEL}" \
  --arg reasoning "${REASONING}" \
  '{
    agent: $agent,
    agent_version: $agent_version,
    model: $model,
    reasoning: $reasoning,
    ephemeral: true,
    ignore_user_config: true,
    ignore_rules: true,
    sandbox: "read-only"
  }' > "${judge_invocation}"
judge_started="$(python3 -c 'import time; print(time.time())')"
codex exec \
  --ephemeral \
  --ignore-user-config \
  --ignore-rules \
  --sandbox read-only \
  --skip-git-repo-check \
  --model "${MODEL}" \
  --config "model_reasoning_effort=\"${REASONING}\"" \
  --config 'model_verbosity="low"' \
  --output-schema "${judge_schema}" \
  --output-last-message "${judge_dir}/result.json" \
  --json \
  --cd "${judge_input}" \
  - < "${judge_prompt}" > "${judge_dir}/events.jsonl"
judge_finished="$(python3 -c 'import time; print(time.time())')"
judge_elapsed="$(python3 -c 'import sys; print(float(sys.argv[2]) - float(sys.argv[1]))' "${judge_started}" "${judge_finished}")"

printf '%s\n' "[4/4] Validate and publish sanitized smoke evidence"
result_dir="$(python3 "${repo_root}/scripts/collect_smoke.py" \
  --oracle-job-dir "${oracle_job_dir}" \
  --job-dir "${codex_job_dir}" \
  --judge-result "${judge_dir}/result.json" \
  --judge-events "${judge_dir}/events.jsonl" \
  --judge-invocation "${judge_invocation}" \
  --results-root "${results_root}" \
  --evaluation-revision "${evaluation_revision}" \
  --evidence-collector-revision "${evaluation_revision}" \
  --evaluation-base-revision "${evaluation_base_revision}" \
  --evaluation-source-bundle "${evaluation_source_bundle}" \
  --repository-root "${repo_root}" \
  --environment-image "${environment_image}" \
  --environment-manifest "${environment_manifest_evidence}" \
  --harbor-version "${HARBOR_VERSION}" \
  --harbor-python-version "${HARBOR_PYTHON_VERSION}" \
  --harbor-constraints-sha256 "${harbor_constraints_sha256}" \
  --uv-version "${uv_version}" \
  --host-os "${host_os}" \
  --host-architecture "${host_architecture}" \
  --harbor-python-platform "${harbor_python_platform}" \
  --container-platform "${container_platform}" \
  --environment-manifest-digest "${environment_manifest_digest}" \
  --solver-agent-version "${CODEX_AGENT_VERSION}" \
  --solver-model "${MODEL}" \
  --solver-reasoning "${REASONING}" \
  --judge-model "${MODEL}" \
  --judge-reasoning "${REASONING}" \
  --judge-agent-version "${judge_codex_version}" \
  --judge-elapsed-seconds "${judge_elapsed}")"

printf '%s\n' "smoke-pass: ${result_dir}"
