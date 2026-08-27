#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo_root="${HYDRA_EVAL_REPO_ROOT:-$(cd "${script_dir}/.." && pwd)}"
smoke_root="${repo_root}/results/smoke"
hydra_root="${repo_root}/results/hydra"
source_bundle_checker="${script_dir}/check_source_bundle.py"
codex_config="${repo_root}/config/codex-low-cost.toml"
base_sha="${1:-}"
head_sha="${2:-HEAD}"
temporary="$(mktemp -d /tmp/hydra-eval-results-validation.XXXXXX)"

cleanup() {
  rm -rf -- "${temporary}"
}
trap cleanup EXIT

fail() {
  printf 'validate-results: %s\n' "$*" >&2
  exit 1
}

[[ -f "${codex_config}" ]] || fail "missing Codex solver config"
[[ "$(grep -Ec '^[[:space:]]*model_reasoning_effort[[:space:]]*=' "${codex_config}")" == "1" ]] \
  || fail "Codex solver config must declare model_reasoning_effort exactly once"
grep -Eq '^[[:space:]]*model_reasoning_effort[[:space:]]*=[[:space:]]*"low"[[:space:]]*$' \
  "${codex_config}" || fail "Codex solver config must pin low reasoning"
codex_config_sha256="$(shasum -a 256 "${codex_config}" | awk '{print $1}')"

git -C "${repo_root}" rev-parse --verify "${head_sha}^{commit}" >/dev/null 2>&1 \
  || fail "head revision is unavailable: ${head_sha}"

if [[ -n "${base_sha}" && ! "${base_sha}" =~ ^0+$ ]]; then
  git -C "${repo_root}" rev-parse --verify "${base_sha}^{commit}" >/dev/null 2>&1 \
    || fail "base revision is unavailable: ${base_sha}"

  while IFS= read -r existing_result; do
    [[ -n "${existing_result}" ]] || continue
    if ! git -C "${repo_root}" diff --quiet "${base_sha}" "${head_sha}" -- "${existing_result}"; then
      fail "published result is append-only and changed: ${existing_result}"
    fi
  done < <(
    git -C "${repo_root}" ls-tree -r -d --name-only "${base_sha}" -- \
      results/smoke results/hydra \
      | awk -F/ '($1 == "results" && $2 == "smoke" && NF == 3) || ($1 == "results" && $2 == "hydra" && NF == 4)'
  )
fi

validation_index=0

validate_local_revision() {
  local revision="$1"
  local label="$2"

  git -C "${repo_root}" rev-parse --verify "${revision}^{commit}" >/dev/null 2>&1 \
    || fail "${label} does not resolve to a local commit: ${revision}"
  git -C "${repo_root}" merge-base --is-ancestor "${revision}" "${head_sha}" \
    || fail "${label} is not reachable from ${head_sha}: ${revision}"
}

validate_evaluation_bundle() {
  local result_dir="$1"
  local result_label="$2"
  local evaluation_revision="$3"
  local evaluation_base_revision="$4"
  local evaluation_bundle_sha256="$5"
  local expected_file_sha256="${6:-}"
  local expected_docker_image="${7:-}"
  local expected_task_checksum="${8:-}"
  local expected_constraint="${9:-}"
  local expected_codex_config_sha256="${10:-}"
  local bundle_path="${result_dir}/source/evaluation.bundle"
  local expected_prerequisite="${evaluation_base_revision}"
  local checker_args=()

  [[ -f "${bundle_path}" ]] || fail "missing source/evaluation.bundle in ${result_label}"
  [[ -x "${source_bundle_checker}" ]] || fail "missing executable source-bundle checker"
  if [[ "${evaluation_base_revision}" == "null" ]]; then
    expected_prerequisite="none"
  else
    validate_local_revision "${evaluation_base_revision}" "evaluation base revision in ${result_label}"
  fi
  [[ "$(shasum -a 256 "${bundle_path}" | awk '{print $1}')" == "${evaluation_bundle_sha256}" ]] \
    || fail "evaluation source bundle digest does not match the scorecard in ${result_label}"
  checker_args=(
    "${source_bundle_checker}"
    --bundle "${bundle_path}"
    --revision "${evaluation_revision}"
    --expected-prerequisite "${expected_prerequisite}"
    --repository "${repo_root}"
  )
  if [[ -n "${expected_file_sha256}" ]]; then
    checker_args+=(--expected-file-sha256 "${expected_file_sha256}")
  fi
  if [[ -n "${expected_docker_image}" ]]; then
    checker_args+=(--expected-docker-image "${expected_docker_image}")
  fi
  if [[ -n "${expected_task_checksum}" ]]; then
    checker_args+=(--expected-task-checksum "${expected_task_checksum}")
  fi
  if [[ -n "${expected_constraint}" ]]; then
    checker_args+=(--expected-constraint "${expected_constraint}")
  fi
  if [[ -n "${expected_codex_config_sha256}" ]]; then
    checker_args+=(
      --expected-file-sha256
      "config/codex-low-cost.toml=${expected_codex_config_sha256}"
    )
  fi
  python3 "${checker_args[@]}" >/dev/null \
    || fail "evaluation source bundle provenance or object safety failed in ${result_label}"
}

validate_hydra_bundle() {
  local result_dir="$1"
  local result_label="$2"
  local hydra_revision="$3"
  local hydra_bundle_sha256="$4"
  local bundle_path="${result_dir}/source/hydra.bundle"

  [[ -f "${bundle_path}" ]] || fail "missing source/hydra.bundle in ${result_label}"
  [[ -x "${source_bundle_checker}" ]] || fail "missing executable source-bundle checker"
  [[ "$(shasum -a 256 "${bundle_path}" | awk '{print $1}')" == "${hydra_bundle_sha256}" ]] \
    || fail "Hydra source bundle digest does not match the scorecard in ${result_label}"
  python3 "${source_bundle_checker}" \
    --bundle "${bundle_path}" \
    --revision "${hydra_revision}" \
    --expected-prerequisite none >/dev/null \
    || fail "Hydra source bundle provenance or object safety failed in ${result_label}"
}

validate_result() {
  local result_dir="$1"
  local result_kind="$2"
  local result_id=""
  local result_label=""
  local hydra_version=""
  local required_file=""
  local evaluation_revision=""
  local evidence_collector_revision=""
  local evaluation_base_revision=""
  local evaluation_bundle_sha256=""
  local hydra_revision=""
  local hydra_bundle_sha256=""
  local harbor_constraints_sha256=""
  local environment_image=""
  local verifier_name=""
  local verifier_sha256=""
  local task_name=""
  local task_checksum=""

  validation_index=$((validation_index + 1))
  result_id="$(basename "${result_dir}")"
  result_label="${result_dir#${repo_root}/}"
  [[ -f "${result_dir}/README.md" ]] || fail "missing README.md in ${result_label}"
  [[ -f "${result_dir}/checksums.txt" ]] || fail "missing checksums.txt in ${result_label}"

  if [[ "${result_kind}" == "smoke" ]]; then
    for required_file in \
      README.md \
      scorecard.json \
      harbor/answer.txt \
      harbor/environment-manifest.json \
      harbor/job-result.json \
      harbor/oracle-job-result.json \
      harbor/oracle-trial-result.json \
      harbor/trajectory.json \
      harbor/trial-result.json \
      harbor/verifier-reward.json \
      judge/invocation.json \
      judge/metrics.json \
      judge/result.json \
      source/evaluation.bundle; do
      [[ -f "${result_dir}/${required_file}" ]] \
        || fail "missing ${required_file} in ${result_label}"
    done
    jq -e --arg job_id "${result_id}" '
      def matches($pattern): type == "string" and test($pattern);
      def nonempty: type == "string" and test("\\S");
      def nonnegative_number: type == "number" and . >= 0;
      def nonnegative_integer: type == "number" and . >= 0 and floor == .;
      .kind == "evaluator_smoke"
      and .status == "pass"
      and .claim == "The minimal evaluator plumbing completed; this is not a Hydra benchmark result."
      and .job_id == $job_id
      and (.provenance.evaluation_revision | matches("^[0-9a-f]{40}$"))
      and (.provenance.evidence_collector_revision | matches("^[0-9a-f]{40}$"))
      and .provenance.evidence_collector_revision == .provenance.evaluation_revision
      and (
        .provenance.evaluation_base_revision == null
        or (.provenance.evaluation_base_revision | matches("^[0-9a-f]{40}$"))
      )
      and (.provenance.evaluation_bundle_sha256 | matches("^[0-9a-f]{64}$"))
      and (.provenance.environment_image | matches("@sha256:[0-9a-f]{64}$"))
      and (.provenance.task | nonempty)
      and (.provenance.task_checksum | nonempty)
      and .provenance.oracle_task_checksum == .provenance.task_checksum
      and (.provenance.harbor_version | matches("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
      and (.provenance.harbor_python_version | matches("^[0-9]+\\.[0-9]+\\.[0-9]+$"))
      and (.provenance.harbor_constraints_sha256 | matches("^[0-9a-f]{64}$"))
      and (.provenance.uv_version | nonempty)
      and (.provenance.host_runtime.os | matches("^[a-z0-9._-]+$"))
      and (.provenance.host_runtime.architecture | matches("^[a-z0-9._-]+$"))
      and (.provenance.host_runtime.python_platform | nonempty)
      and (.provenance.container_runtime.platform | matches("^[a-z0-9._-]+/[a-z0-9._-]+(/[a-z0-9._-]+)?$"))
      and (.provenance.container_runtime.base_manifest_digest | matches("^sha256:[0-9a-f]{64}$"))
      and .provenance.solver_agent == "codex"
      and (.provenance.solver_agent_version | nonempty)
      and (.provenance.solver_model | nonempty)
      and .provenance.solver_reasoning == "low"
      and .provenance.judge_agent == "codex"
      and (.provenance.judge_agent_version | nonempty)
      and (.provenance.judge_model | nonempty)
      and (.provenance.judge_reasoning | nonempty)
      and (.provenance.oracle_job_id | nonempty)
      and .checks.oracle_reference == "pass"
      and .checks.deterministic_verifier.answer_exact == 1
      and .checks.deterministic_verifier.reward == 1
      and .checks.ai_judge.verdict == "pass"
      and .checks.ai_judge.score == 1
      and (.checks.ai_judge.reason | nonempty)
      and .checks.atif_trajectory == "present"
      and (.measures.solver.elapsed_seconds | nonnegative_number)
      and (.measures.solver.input_tokens | nonnegative_integer)
      and (.measures.solver.cache_tokens | nonnegative_integer)
      and (.measures.solver.output_tokens | nonnegative_integer)
      and (.measures.judge.elapsed_seconds | nonnegative_number)
      and (.measures.judge.input_tokens | nonnegative_integer)
      and (.measures.judge.output_tokens | nonnegative_integer)
      and .measures.cost.billing_basis == "ChatGPT subscription"
      and .measures.cost.billed_cost_usd == "unknown"
      and (
        .measures.cost.solver_api_equivalent_estimate_usd == null
        or (.measures.cost.solver_api_equivalent_estimate_usd | nonnegative_number)
      )
      and .measures.cost.judge_api_equivalent_estimate_usd == "unknown"
    ' "${result_dir}/scorecard.json" >/dev/null \
      || fail "invalid scorecard provenance in ${result_label}"
    evaluation_revision="$(jq -r '.provenance.evaluation_revision' "${result_dir}/scorecard.json")"
    evidence_collector_revision="$(jq -r '.provenance.evidence_collector_revision' "${result_dir}/scorecard.json")"
    evaluation_base_revision="$(jq -r '.provenance.evaluation_base_revision' "${result_dir}/scorecard.json")"
    evaluation_bundle_sha256="$(jq -r '.provenance.evaluation_bundle_sha256' "${result_dir}/scorecard.json")"
    harbor_constraints_sha256="$(jq -r '.provenance.harbor_constraints_sha256' "${result_dir}/scorecard.json")"
    environment_image="$(jq -r '.provenance.environment_image' "${result_dir}/scorecard.json")"
    validate_evaluation_bundle "${result_dir}" "${result_label}" \
      "${evaluation_revision}" "${evaluation_base_revision}" "${evaluation_bundle_sha256}" \
      "config/harbor-0.22.0.constraints=${harbor_constraints_sha256}" \
      "tasks/smoke-question-answer/environment/Dockerfile=${environment_image}" \
      "tasks/smoke-question-answer=$(jq -r '.provenance.task_checksum' "${result_dir}/scorecard.json")" \
      "config/harbor-0.22.0.constraints:harbor=$(jq -r '.provenance.harbor_version' "${result_dir}/scorecard.json")" \
      "${codex_config_sha256}"
    cmp -s "${result_dir}/harbor/answer.txt" <(printf '42\n') \
      || fail "answer is not exactly 42 followed by newline in ${result_label}"
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      . == $scorecard[0].checks.deterministic_verifier
      and .answer_exact == 1
      and .reward == 1
    ' "${result_dir}/harbor/verifier-reward.json" >/dev/null \
      || fail "verifier evidence does not match the scorecard in ${result_label}"
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      (keys | sort) == ["reason", "score", "verdict"]
      and . == $scorecard[0].checks.ai_judge
    ' "${result_dir}/judge/result.json" >/dev/null \
      || fail "judge evidence does not match the scorecard in ${result_label}"
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      . == $scorecard[0].measures.judge
    ' "${result_dir}/judge/metrics.json" >/dev/null \
      || fail "judge measures do not match preserved evidence in ${result_label}"
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      (keys | sort) == [
        "agent",
        "agent_version",
        "ephemeral",
        "ignore_rules",
        "ignore_user_config",
        "model",
        "reasoning",
        "sandbox"
      ]
      and .agent == $scorecard[0].provenance.judge_agent
      and .agent_version == $scorecard[0].provenance.judge_agent_version
      and .model == $scorecard[0].provenance.judge_model
      and .reasoning == $scorecard[0].provenance.judge_reasoning
      and .ephemeral == true
      and .ignore_user_config == true
      and .ignore_rules == true
      and .sandbox == "read-only"
    ' "${result_dir}/judge/invocation.json" >/dev/null \
      || fail "judge identity or isolation does not match preserved invocation evidence in ${result_label}"
    jq -e '
      def nonempty: type == "string" and test("\\S");
      (.schema_version | type == "string" and startswith("ATIF-v"))
      and (.steps | type == "array")
      and any(.steps[];
        type == "object"
        and .source == "user"
        and (.message | nonempty)
      )
      and any(.steps[];
        type == "object"
        and .source == "agent"
        and (.tool_calls | type == "array" and length > 0)
        and any(.tool_calls[];
          type == "object"
          and (.function_name | nonempty)
          and has("arguments")
          and .arguments != null
        )
      )
    ' "${result_dir}/harbor/trajectory.json" >/dev/null \
      || fail "ATIF trajectory lacks a task instruction or agent action in ${result_label}"
    if ! python3 - "${result_dir}/scorecard.json" \
      "${result_dir}/harbor/environment-manifest.json" <<'PY'
import hashlib
import json
import sys
from pathlib import Path

scorecard = json.loads(Path(sys.argv[1]).read_text())
manifest_path = Path(sys.argv[2])
raw_manifest = manifest_path.read_bytes()
manifest = json.loads(raw_manifest)
runtime = scorecard["provenance"]["container_runtime"]
expected_platform = runtime["platform"]
expected_digest = runtime["base_manifest_digest"]
expected_index_digest = scorecard["provenance"]["environment_image"].rpartition("@")[2]
observed_index_digest = "sha256:" + hashlib.sha256(raw_manifest).hexdigest()
if observed_index_digest != expected_index_digest:
    raise SystemExit(
        f"environment index hashes to {observed_index_digest}, expected {expected_index_digest}"
    )
descriptors = manifest.get("manifests") if isinstance(manifest, dict) else None
if (
    not isinstance(manifest, dict)
    or manifest.get("schemaVersion") != 2
    or not isinstance(descriptors, list)
):
    raise SystemExit("environment manifest is not an OCI image index")

matches = []
for descriptor in descriptors:
    if not isinstance(descriptor, dict):
        continue
    platform = descriptor.get("platform")
    if not isinstance(platform, dict):
        continue
    observed_platform = f"{platform.get('os')}/{platform.get('architecture')}"
    variant = platform.get("variant")
    if isinstance(variant, str) and variant:
        observed_platform += f"/{variant}"
    if observed_platform == expected_platform:
        matches.append(descriptor)

if len(matches) != 1:
    raise SystemExit(
        f"expected one descriptor for {expected_platform}, found {len(matches)}"
    )
if matches[0].get("digest") != expected_digest:
    raise SystemExit("resolved environment descriptor digest does not match scorecard")
PY
    then
      fail "environment index does not support the recorded container runtime in ${result_label}"
    fi
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      .id == $scorecard[0].job_id
      and .stats.n_completed_trials == 1
      and .stats.n_errored_trials == 0
      and .stats.n_input_tokens == $scorecard[0].measures.solver.input_tokens
      and .stats.n_cache_tokens == $scorecard[0].measures.solver.cache_tokens
      and .stats.n_output_tokens == $scorecard[0].measures.solver.output_tokens
      and .stats.cost_usd == $scorecard[0].measures.cost.solver_api_equivalent_estimate_usd
    ' "${result_dir}/harbor/job-result.json" >/dev/null \
      || fail "solver job evidence does not match the scorecard in ${result_label}"
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      .id == $scorecard[0].provenance.oracle_job_id
      and .stats.n_completed_trials == 1
      and .stats.n_errored_trials == 0
    ' "${result_dir}/harbor/oracle-job-result.json" >/dev/null \
      || fail "Oracle job evidence does not match the scorecard in ${result_label}"
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      .task_name == $scorecard[0].provenance.task
      and .task_checksum == $scorecard[0].provenance.task_checksum
      and .agent_info.name == "codex"
      and .agent_info.version == $scorecard[0].provenance.solver_agent_version
      and .agent_info.model_info.name == $scorecard[0].provenance.solver_model
      and .verifier_result.rewards.reward == 1
      and .exception_info == null
    ' "${result_dir}/harbor/trial-result.json" >/dev/null \
      || fail "solver trial evidence does not match the scorecard in ${result_label}"
    if ! python3 - "${result_dir}/scorecard.json" "${result_dir}/harbor/trial-result.json" <<'PY'
import json
import math
import sys
from datetime import datetime
from pathlib import Path

scorecard = json.loads(Path(sys.argv[1]).read_text())
trial = json.loads(Path(sys.argv[2]).read_text())
started = datetime.fromisoformat(trial["started_at"].replace("Z", "+00:00"))
finished = datetime.fromisoformat(trial["finished_at"].replace("Z", "+00:00"))
observed = (finished - started).total_seconds()
recorded = scorecard["measures"]["solver"]["elapsed_seconds"]
if not math.isclose(observed, recorded, rel_tol=0.0, abs_tol=1e-6):
    raise SystemExit(f"solver elapsed mismatch: {observed} != {recorded}")
PY
    then
      fail "solver elapsed time does not match the trial timestamps in ${result_label}"
    fi
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      .task_name == $scorecard[0].provenance.task
      and .task_checksum == $scorecard[0].provenance.oracle_task_checksum
      and .agent_info.name == "oracle"
      and .verifier_result.rewards.reward == 1
      and .exception_info == null
    ' "${result_dir}/harbor/oracle-trial-result.json" >/dev/null \
      || fail "Oracle trial evidence does not match the scorecard in ${result_label}"
  else
    [[ -f "${result_dir}/scorecard.json" ]] \
      || fail "missing machine-readable scorecard.json in ${result_label}"
    [[ -f "${result_dir}/source/evaluation.bundle" ]] \
      || fail "missing source/evaluation.bundle in ${result_label}"
    [[ -f "${result_dir}/source/hydra.bundle" ]] \
      || fail "missing source/hydra.bundle in ${result_label}"
    for required_file in \
      artifacts/job-result.json \
      artifacts/trial-lock.json \
      artifacts/trial-result.json; do
      [[ -f "${result_dir}/${required_file}" ]] \
        || fail "missing ${required_file} in ${result_label}"
    done
    hydra_version="$(basename "$(dirname "${result_dir}")")"
    jq -e --arg hydra_version "${hydra_version}" --arg result_id "${result_id}" '
      def matches($pattern): type == "string" and test($pattern);
      def nonempty: type == "string" and length > 0;
      def nonnegative_number: type == "number" and . >= 0;
      def nonnegative_integer:
        type == "number" and . >= 0 and floor == .;
      def source_path:
        type == "string"
        and test("^[A-Za-z0-9._/-]+$")
        and startswith("/") == false
        and (contains("..") | not);
      def evidence_path:
        type == "string"
        and test("^artifacts/[A-Za-z0-9._/-]+$")
        and (contains("..") | not);
      .kind == "hydra_evaluation"
      and .hydra_version == $hydra_version
      and .result_id == $result_id
      and (.status == "pass" or .status == "fail")
      and (.provenance.hydra_revision | matches("^[0-9a-f]{40}$"))
      and (.provenance.hydra_bundle_sha256 | matches("^[0-9a-f]{64}$"))
      and (.provenance.evaluation_revision | matches("^[0-9a-f]{40}$"))
      and (
        .provenance.evaluation_base_revision == null
        or (.provenance.evaluation_base_revision | matches("^[0-9a-f]{40}$"))
      )
      and (.provenance.evaluation_bundle_sha256 | matches("^[0-9a-f]{64}$"))
      and (.provenance.task | matches("^[A-Za-z0-9._-]+$"))
      and (.provenance.task_checksum | matches("^[0-9a-f]{64}$"))
      and (.provenance.client.name | nonempty)
      and (.provenance.client.version | nonempty)
      and (.provenance.model.name | nonempty)
      and (.provenance.environment.fingerprint | nonempty)
      and (.provenance.job_id | nonempty)
      and (.provenance.verifier.name | source_path)
      and .provenance.verifier.name == (
        "tasks/" + .provenance.task + "/tests/test.sh"
      )
      and .provenance.verifier.revision == .provenance.evaluation_revision
      and (.provenance.verifier.sha256 | matches("^[0-9a-f]{64}$"))
      and (.assertions | type == "array" and length > 0)
      and ((.assertions | map(.name) | unique | length) == (.assertions | length))
      and ((.assertions | map(.evidence) | unique | length) == (.assertions | length))
      and all(.assertions[];
        (type == "object")
        and (.name | nonempty)
        and (.type == "deterministic" or .type == "model" or .type == "human")
        and (.passed | type == "boolean")
        and (.evidence | evidence_path)
        and (
          if .type == "model"
          then
            (.rubric | nonempty)
            and (.reason | nonempty)
            and (.grader | type == "object")
            and (.grader.name | nonempty)
            and (.grader.version | nonempty)
            and (.grader.model | nonempty)
          elif .type == "human"
          then
            (.rubric | nonempty)
            and (.reason | nonempty)
            and (.reviewer | type == "object")
            and (.reviewer.name | nonempty)
          else true
          end
        )
      )
      and (
        if .status == "pass"
        then all(.assertions[]; .passed)
        else any(.assertions[]; (.passed | not))
        end
      )
      and (
        .measures
        | type == "object"
        and length > 0
        and ((keys - ["cost_usd", "elapsed_seconds", "tokens"]) | length == 0)
        and (
          (has("elapsed_seconds") | not)
          or (.elapsed_seconds | nonnegative_number)
        )
        and (
          (has("tokens") | not)
          or (
            (.tokens | type == "object")
            and (
              (.tokens | keys - ["cache_tokens", "input_tokens", "output_tokens"])
              | length == 0
            )
            and (.tokens.input_tokens | nonnegative_integer)
            and (.tokens.output_tokens | nonnegative_integer)
            and ((.tokens | has("cache_tokens") | not) or (.tokens.cache_tokens | nonnegative_integer))
          )
        )
        and (
          (has("cost_usd") | not)
          or (.cost_usd | nonnegative_number)
        )
      )
    ' "${result_dir}/scorecard.json" >/dev/null \
      || fail "missing required Hydra provenance in ${result_label}"
    while IFS= read -r assertion_evidence; do
      [[ -f "${result_dir}/${assertion_evidence}" ]] \
        || fail "missing Hydra assertion evidence ${assertion_evidence} in ${result_label}"
      jq -e --arg evidence "${assertion_evidence}" \
        --slurpfile scorecard "${result_dir}/scorecard.json" '
        ($scorecard[0].assertions | map(select(.evidence == $evidence))) as $assertions
        | ($assertions | length) == 1
        and .name == $assertions[0].name
        and .passed == $assertions[0].passed
      ' "${result_dir}/${assertion_evidence}" >/dev/null \
        || fail "Hydra assertion evidence disagrees with the scorecard for ${assertion_evidence} in ${result_label}"
    done < <(jq -r '.assertions[].evidence' "${result_dir}/scorecard.json")
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      .id == $scorecard[0].provenance.job_id
      and (.stats | type == "object")
      and (.stats.n_completed_trials | type == "number" and floor == . and . >= 0)
      and (.stats.n_errored_trials | type == "number" and floor == . and . >= 0)
      and (
        if $scorecard[0].status == "pass"
        then .stats.n_completed_trials >= 1 and .stats.n_errored_trials == 0
        else true
        end
      )
    ' "${result_dir}/artifacts/job-result.json" >/dev/null \
      || fail "Hydra job result does not match execution provenance in ${result_label}"
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      .config.job_id == $scorecard[0].provenance.job_id
      and .task_name == $scorecard[0].provenance.task
      and .task_checksum == $scorecard[0].provenance.task_checksum
      and .agent_info.name == $scorecard[0].provenance.client.name
      and .agent_info.version == $scorecard[0].provenance.client.version
      and .agent_info.model_info.name == $scorecard[0].provenance.model.name
      and (
        if $scorecard[0].status == "pass"
        then .exception_info == null
        else true
        end
      )
    ' "${result_dir}/artifacts/trial-result.json" >/dev/null \
      || fail "Hydra trial result does not match execution provenance in ${result_label}"
    jq -e --slurpfile scorecard "${result_dir}/scorecard.json" '
      def nonempty: type == "string" and test("\\S");
      ($scorecard[0].provenance.model.name) as $model
      | .task.name == $scorecard[0].provenance.task
      and .task.digest == $scorecard[0].provenance.task_checksum
      and .agent.name == $scorecard[0].provenance.client.name
      and .agent.kwargs.version == $scorecard[0].provenance.client.version
      and (
        .agent.model_name == $model
        or (.agent.model_name | endswith("/" + $model))
      )
      and (.environment.type | nonempty)
    ' "${result_dir}/artifacts/trial-lock.json" >/dev/null \
      || fail "Hydra trial lock does not match execution provenance in ${result_label}"
    if ! python3 - "${result_dir}/scorecard.json" \
      "${result_dir}/artifacts/trial-result.json" <<'PY'
import json
import math
import sys
from datetime import datetime
from pathlib import Path

scorecard = json.loads(Path(sys.argv[1]).read_text())
trial = json.loads(Path(sys.argv[2]).read_text())
measures = scorecard["measures"]

if "elapsed_seconds" in measures:
    started = datetime.fromisoformat(trial["started_at"].replace("Z", "+00:00"))
    finished = datetime.fromisoformat(trial["finished_at"].replace("Z", "+00:00"))
    observed = (finished - started).total_seconds()
    if not math.isclose(
        observed, measures["elapsed_seconds"], rel_tol=0.0, abs_tol=1e-6
    ):
        raise SystemExit("Hydra elapsed_seconds does not match trial timestamps")

agent_result = trial.get("agent_result")
if not isinstance(agent_result, dict):
    raise SystemExit("Hydra trial result has no agent_result measures")
if "tokens" in measures:
    mapping = {
        "input_tokens": "n_input_tokens",
        "cache_tokens": "n_cache_tokens",
        "output_tokens": "n_output_tokens",
    }
    for public_name, native_name in mapping.items():
        if public_name in measures["tokens"]:
            if measures["tokens"][public_name] != agent_result.get(native_name):
                raise SystemExit(f"Hydra {public_name} does not match trial evidence")
if "cost_usd" in measures and measures["cost_usd"] != agent_result.get("cost_usd"):
    raise SystemExit("Hydra cost_usd does not match trial evidence")
PY
    then
      fail "Hydra measures do not match native trial evidence in ${result_label}"
    fi
    evaluation_revision="$(jq -r '.provenance.evaluation_revision' "${result_dir}/scorecard.json")"
    evaluation_base_revision="$(jq -r '.provenance.evaluation_base_revision' "${result_dir}/scorecard.json")"
    evaluation_bundle_sha256="$(jq -r '.provenance.evaluation_bundle_sha256' "${result_dir}/scorecard.json")"
    hydra_revision="$(jq -r '.provenance.hydra_revision' "${result_dir}/scorecard.json")"
    hydra_bundle_sha256="$(jq -r '.provenance.hydra_bundle_sha256' "${result_dir}/scorecard.json")"
    verifier_name="$(jq -r '.provenance.verifier.name' "${result_dir}/scorecard.json")"
    verifier_sha256="$(jq -r '.provenance.verifier.sha256' "${result_dir}/scorecard.json")"
    task_name="$(jq -r '.provenance.task' "${result_dir}/scorecard.json")"
    task_checksum="$(jq -r '.provenance.task_checksum' "${result_dir}/scorecard.json")"
    validate_evaluation_bundle "${result_dir}" "${result_label}" \
      "${evaluation_revision}" "${evaluation_base_revision}" "${evaluation_bundle_sha256}" \
      "${verifier_name}=${verifier_sha256}" \
      "" \
      "tasks/${task_name}=${task_checksum}"
    validate_hydra_bundle "${result_dir}" "${result_label}" \
      "${hydra_revision}" "${hydra_bundle_sha256}"
  fi

  if grep -Ev '^[0-9a-f]{64}  [^/].+$' "${result_dir}/checksums.txt" | grep -q .; then
    fail "invalid checksum manifest line in ${result_label}"
  fi
  if grep -E '  (\.\./|.*\/\.\./)' "${result_dir}/checksums.txt" | grep -q .; then
    fail "checksum manifest escapes its result directory in ${result_label}"
  fi

  (
    cd "${result_dir}"
    shasum -a 256 -c checksums.txt >/dev/null
    find . -type f ! -path './checksums.txt' -print \
      | sed 's#^\./##' \
      | LC_ALL=C sort > "${temporary}/${validation_index}.expected"
    sed -E 's/^[0-9a-f]{64}  //' checksums.txt \
      | LC_ALL=C sort > "${temporary}/${validation_index}.recorded"
  )
  diff -u "${temporary}/${validation_index}.expected" \
    "${temporary}/${validation_index}.recorded" >/dev/null \
    || fail "checksum manifest does not cover the exact file set in ${result_label}"
}

for result_root in "${smoke_root}" "${hydra_root}"; do
  [[ -d "${result_root}" ]] || continue
  if find "${result_root}" -type l -print -quit | grep -q .; then
    fail "result bundles must not contain symlinks: ${result_root#${repo_root}/}"
  fi
done

validate_component_name() {
  local path="$1"
  local label="$2"
  local name=""

  name="$(basename "${path}")"
  [[ "${name}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] \
    || fail "unsupported ${label} directory name: ${name}"
}

while IFS= read -r -d '' result_dir; do
  validate_component_name "${result_dir}" "smoke result"
  validate_result "${result_dir}" smoke
done < <(find "${smoke_root}" -mindepth 1 -maxdepth 1 -type d -print0)

if [[ -d "${hydra_root}" ]]; then
  while IFS= read -r -d '' version_dir; do
    validate_component_name "${version_dir}" "Hydra version"
    while IFS= read -r -d '' result_dir; do
      validate_component_name "${result_dir}" "Hydra result"
      validate_result "${result_dir}" hydra
    done < <(find "${version_dir}" -mindepth 1 -maxdepth 1 -type d -print0)
  done < <(find "${hydra_root}" -mindepth 1 -maxdepth 1 -type d -print0)
fi
