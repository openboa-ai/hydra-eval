#!/usr/bin/env bash
set -euo pipefail

source_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
fixture_repo="$(mktemp -d /tmp/hydra-eval-results-repo.XXXXXX)"

cleanup() {
  rm -rf -- "${fixture_repo}"
}
trap cleanup EXIT

git -C "${fixture_repo}" init -q
git -C "${fixture_repo}" config user.name hydra-eval-test
git -C "${fixture_repo}" config user.email hydra-eval-test@example.invalid

printf '%s\n' 'repository base' > "${fixture_repo}/repository-base.txt"
git -C "${fixture_repo}" add repository-base.txt
git -C "${fixture_repo}" commit -q -m repository-base
repository_base_revision="$(git -C "${fixture_repo}" rev-parse HEAD)"

printf '%s\n' 'evaluator source' > "${fixture_repo}/evaluator-source.txt"
mkdir -p "${fixture_repo}/config"
cp "${source_root}/config/harbor-0.22.0.constraints" \
  "${fixture_repo}/config/harbor-0.22.0.constraints"
fixture_constraints_sha256="$(shasum -a 256 "${fixture_repo}/config/harbor-0.22.0.constraints" | awk '{print $1}')"
fixture_environment_manifest="${fixture_repo}/fixture-environment-manifest.json"
jq -c -n '{
  schemaVersion: 2,
  mediaType: "application/vnd.oci.image.index.v1+json",
  manifests: [{
    mediaType: "application/vnd.oci.image.manifest.v1+json",
    size: 424,
    digest: ("sha256:" + ("e" * 64)),
    platform: {architecture: "arm64", os: "linux", variant: "v8"}
  }]
}' > "${fixture_environment_manifest}"
fixture_environment_index_digest="$(shasum -a 256 "${fixture_environment_manifest}" | awk '{print $1}')"
fixture_environment_image="ubuntu:24.04@sha256:${fixture_environment_index_digest}"
mkdir -p "${fixture_repo}/tasks"
cp -R "${source_root}/tasks/smoke-question-answer" \
  "${fixture_repo}/tasks/smoke-question-answer"
printf 'FROM %s\n\nWORKDIR /app\n' "${fixture_environment_image}" \
  > "${fixture_repo}/tasks/smoke-question-answer/environment/Dockerfile"
git -C "${fixture_repo}" add \
  evaluator-source.txt \
  config/harbor-0.22.0.constraints \
  tasks/smoke-question-answer
git -C "${fixture_repo}" commit -q -m evaluator-source
evaluation_revision="$(git -C "${fixture_repo}" rev-parse HEAD)"
fixture_verifier_sha256="$(shasum -a 256 "${fixture_repo}/tasks/smoke-question-answer/tests/test.sh" | awk '{print $1}')"
fixture_task_checksum="$(python3 - "${source_root}" "${fixture_repo}" "${evaluation_revision}" <<'PY'
import importlib.util
import sys
from pathlib import Path

module_path = Path(sys.argv[1]) / "scripts" / "check_source_bundle.py"
spec = importlib.util.spec_from_file_location("check_source_bundle", module_path)
assert spec and spec.loader
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
print(module.harbor_task_checksum(Path(sys.argv[2]), sys.argv[3], "tasks/smoke-question-answer"))
PY
)"

write_smoke_checksums() {
  local directory="$1"
  (
    cd "${directory}"
    for path in \
      README.md \
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
      source/evaluation.bundle \
      scorecard.json; do
      shasum -a 256 "${path}"
    done > checksums.txt
  )
}

write_hydra_checksums() {
  local directory="$1"
  (
    cd "${directory}"
    for path in \
      README.md \
      artifacts/job-result.json \
      artifacts/output.txt \
      artifacts/trial-lock.json \
      artifacts/trial-result.json \
      artifacts/verifier.json \
      scorecard.json \
      source/evaluation.bundle \
      source/hydra.bundle; do
      shasum -a 256 "${path}"
    done > checksums.txt
  )
}

job_id="00000000-0000-0000-0000-000000000001"
result_dir="${fixture_repo}/results/smoke/${job_id}"
mkdir -p "${result_dir}/harbor"
printf '%s\n' '# Fixture' > "${result_dir}/README.md"
printf '%s\n' '42' > "${result_dir}/harbor/answer.txt"
printf '%s\n' '{"kind":"evaluator_smoke","status":"pass","claim":"The minimal evaluator plumbing completed; this is not a Hydra benchmark result.","job_id":"00000000-0000-0000-0000-000000000001","provenance":{"evaluation_revision":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","evidence_collector_revision":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","environment_image":"ubuntu:24.04@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc","task":"openboa/hydra-eval-smoke-question-answer","task_checksum":"task-checksum","oracle_task_checksum":"task-checksum","harbor_version":"0.22.0","harbor_python_version":"3.12.11","harbor_constraints_sha256":"dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd","uv_version":"0.8.3","host_runtime":{"os":"darwin","architecture":"arm64","python_platform":"macosx-11.0-arm64"},"container_runtime":{"platform":"linux/arm64/v8","base_manifest_digest":"sha256:eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee"},"solver_agent":"codex","solver_agent_version":"0.147.0","solver_model":"gpt-5.6-luna","solver_reasoning":"low","judge_agent":"codex","judge_agent_version":"0.144.5","judge_model":"gpt-5.6-luna","judge_reasoning":"low","oracle_job_id":"00000000-0000-0000-0000-000000000010"},"checks":{"oracle_reference":"pass","deterministic_verifier":{"answer_exact":1,"reward":1},"ai_judge":{"verdict":"pass","score":1,"reason":"The answer is correct."},"atif_trajectory":"present"},"measures":{"solver":{"elapsed_seconds":1.5,"input_tokens":10,"cache_tokens":3,"output_tokens":2},"judge":{"elapsed_seconds":0.5,"input_tokens":8,"output_tokens":2},"cost":{"billing_basis":"ChatGPT subscription","billed_cost_usd":"unknown","solver_api_equivalent_estimate_usd":0.001,"judge_api_equivalent_estimate_usd":"unknown"}}}' > "${result_dir}/scorecard.json"
mkdir -p "${result_dir}/source"
git -C "${fixture_repo}" bundle create "${result_dir}/source/evaluation.bundle" \
  HEAD "^${repository_base_revision}"
evaluation_bundle_sha256="$(shasum -a 256 "${result_dir}/source/evaluation.bundle" | awk '{print $1}')"
scorecard_tmp="${result_dir}/scorecard.json.tmp"
jq --arg revision "${evaluation_revision}" \
  --arg base_revision "${repository_base_revision}" \
  --arg bundle_sha256 "${evaluation_bundle_sha256}" \
  --arg constraints_sha256 "${fixture_constraints_sha256}" \
  --arg environment_image "${fixture_environment_image}" \
  --arg task_checksum "${fixture_task_checksum}" '
    .provenance.evaluation_revision = $revision
    | .provenance.evidence_collector_revision = $revision
    | .provenance.evaluation_base_revision = $base_revision
    | .provenance.evaluation_bundle_sha256 = $bundle_sha256
    | .provenance.harbor_constraints_sha256 = $constraints_sha256
    | .provenance.environment_image = $environment_image
    | .provenance.task_checksum = $task_checksum
    | .provenance.oracle_task_checksum = $task_checksum
  ' \
  "${result_dir}/scorecard.json" > "${scorecard_tmp}"
mv "${scorecard_tmp}" "${result_dir}/scorecard.json"
printf '%s\n' '{"id":"00000000-0000-0000-0000-000000000001","stats":{"n_completed_trials":1,"n_errored_trials":0,"n_input_tokens":10,"n_cache_tokens":3,"n_output_tokens":2,"cost_usd":0.001}}' > "${result_dir}/harbor/job-result.json"
printf '%s\n' '{"id":"00000000-0000-0000-0000-000000000010","stats":{"n_completed_trials":1,"n_errored_trials":0}}' > "${result_dir}/harbor/oracle-job-result.json"
printf '%s\n' '{"task_name":"openboa/hydra-eval-smoke-question-answer","task_checksum":"task-checksum","agent_info":{"name":"codex","version":"0.147.0","model_info":{"name":"gpt-5.6-luna"}},"started_at":"2026-08-27T00:00:00Z","finished_at":"2026-08-27T00:00:01.500000Z","verifier_result":{"rewards":{"reward":1}},"exception_info":null}' \
  | jq --arg checksum "${fixture_task_checksum}" '.task_checksum = $checksum' \
  > "${result_dir}/harbor/trial-result.json"
printf '%s\n' '{"task_name":"openboa/hydra-eval-smoke-question-answer","task_checksum":"task-checksum","agent_info":{"name":"oracle"},"verifier_result":{"rewards":{"reward":1}},"exception_info":null}' \
  | jq --arg checksum "${fixture_task_checksum}" '.task_checksum = $checksum' \
  > "${result_dir}/harbor/oracle-trial-result.json"
printf '%s\n' '{"schema_version":"ATIF-v1.7","steps":[{"source":"user","message":"What is 19 + 23?"},{"source":"agent","message":"Writing 42.","tool_calls":[{"function_name":"exec","arguments":{"input":"write 42"}}]}]}' > "${result_dir}/harbor/trajectory.json"
cp "${fixture_environment_manifest}" "${result_dir}/harbor/environment-manifest.json"
printf '%s\n' '{"answer_exact":1,"reward":1}' > "${result_dir}/harbor/verifier-reward.json"
mkdir -p "${result_dir}/judge"
printf '%s\n' '{"agent":"codex","agent_version":"0.144.5","model":"gpt-5.6-luna","reasoning":"low","ephemeral":true,"ignore_user_config":true,"ignore_rules":true,"sandbox":"read-only"}' > "${result_dir}/judge/invocation.json"
printf '%s\n' '{"elapsed_seconds":0.5,"input_tokens":8,"output_tokens":2}' > "${result_dir}/judge/metrics.json"
printf '%s\n' '{"verdict":"pass","score":1,"reason":"The answer is correct."}' > "${result_dir}/judge/result.json"
write_smoke_checksums "${result_dir}"

hydra_result_id="00000000-0000-0000-0000-000000000002"
hydra_result_dir="${fixture_repo}/results/hydra/0.1.0/${hydra_result_id}"
mkdir -p "${hydra_result_dir}/artifacts" "${hydra_result_dir}/source"
cp "${result_dir}/source/evaluation.bundle" "${hydra_result_dir}/source/evaluation.bundle"
git -C "${fixture_repo}" bundle create "${hydra_result_dir}/source/hydra.bundle" HEAD
hydra_bundle_sha256="$(shasum -a 256 "${hydra_result_dir}/source/hydra.bundle" | awk '{print $1}')"
printf '%s\n' '# Hydra fixture' > "${hydra_result_dir}/README.md"
printf '%s\n' '{"kind":"hydra_evaluation","hydra_version":"0.1.0","result_id":"00000000-0000-0000-0000-000000000002","status":"pass","provenance":{"hydra_revision":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","hydra_bundle_sha256":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","evaluation_revision":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","task":"project-task","client":{"name":"codex","version":"0.147.0"},"model":{"name":"gpt-5.6-luna"},"environment":{"fingerprint":"sha256:environment"},"job_id":"harbor-job","verifier":{"name":"deterministic-tests","revision":"cccccccccccccccccccccccccccccccccccccccc"}},"assertions":[{"name":"expected-output","type":"deterministic","passed":true,"evidence":"artifacts/verifier.json"}],"measures":{"elapsed_seconds":1.5}}' > "${hydra_result_dir}/scorecard.json"
hydra_scorecard_tmp="${hydra_result_dir}/scorecard.json.tmp"
jq --arg revision "${evaluation_revision}" \
  --arg base_revision "${repository_base_revision}" \
  --arg bundle_sha256 "${evaluation_bundle_sha256}" \
  --arg hydra_bundle_sha256 "${hydra_bundle_sha256}" \
  --arg verifier_sha256 "${fixture_verifier_sha256}" '
    .provenance.hydra_revision = $revision
    | .provenance.hydra_bundle_sha256 = $hydra_bundle_sha256
    | .provenance.evaluation_revision = $revision
    | .provenance.evaluation_base_revision = $base_revision
    | .provenance.evaluation_bundle_sha256 = $bundle_sha256
    | .provenance.task = "smoke-question-answer"
    | .provenance.verifier.name = "tasks/smoke-question-answer/tests/test.sh"
    | .provenance.verifier.revision = $revision
    | .provenance.verifier.sha256 = $verifier_sha256
    | .measures = {
        elapsed_seconds: 1.5,
        tokens: {input_tokens: 10, cache_tokens: 3, output_tokens: 2},
        cost_usd: 0.001
      }
  ' \
  "${hydra_result_dir}/scorecard.json" > "${hydra_scorecard_tmp}"
mv "${hydra_scorecard_tmp}" "${hydra_result_dir}/scorecard.json"
printf '%s\n' 'artifact' > "${hydra_result_dir}/artifacts/output.txt"
printf '%s\n' '{"passed":true,"name":"expected-output"}' > "${hydra_result_dir}/artifacts/verifier.json"
printf '%s\n' '{"id":"harbor-job","stats":{"n_completed_trials":1,"n_errored_trials":0}}' \
  > "${hydra_result_dir}/artifacts/job-result.json"
printf '%s\n' '{"task_name":"smoke-question-answer","config":{"job_id":"harbor-job"},"agent_info":{"name":"codex","version":"0.147.0","model_info":{"name":"gpt-5.6-luna"}},"agent_result":{"n_input_tokens":10,"n_cache_tokens":3,"n_output_tokens":2,"cost_usd":0.001},"started_at":"2026-08-27T00:00:00Z","finished_at":"2026-08-27T00:00:01.500000Z","exception_info":null}' \
  > "${hydra_result_dir}/artifacts/trial-result.json"
printf '%s\n' '{"task":{"name":"smoke-question-answer","digest":"sha256:environment"},"agent":{"name":"codex","model_name":"openai/gpt-5.6-luna","kwargs":{"version":"0.147.0"}},"environment":{"type":"docker"}}' \
  > "${hydra_result_dir}/artifacts/trial-lock.json"
write_hydra_checksums "${hydra_result_dir}"

git -C "${fixture_repo}" add results
git -C "${fixture_repo}" commit -q -m fixture
base_sha="$(git -C "${fixture_repo}" rev-parse HEAD)"

HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD

fixture_tree="$(git -C "${fixture_repo}" rev-parse "${base_sha}^{tree}")"
squash_sha="$(
  printf '%s\n' 'squashed result' \
    | git -C "${fixture_repo}" commit-tree "${fixture_tree}" -p "${repository_base_revision}"
)"
HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${repository_base_revision}" "${squash_sha}"

self_contained_job_id="00000000-0000-0000-0000-000000000013"
self_contained_dir="${fixture_repo}/results/smoke/${self_contained_job_id}"
cp -R "${result_dir}" "${self_contained_dir}"
git -C "${fixture_repo}" bundle create \
  "${self_contained_dir}/source/evaluation.bundle" HEAD
self_contained_bundle_sha256="$(shasum -a 256 "${self_contained_dir}/source/evaluation.bundle" | awk '{print $1}')"
self_contained_scorecard_tmp="${self_contained_dir}/scorecard.json.tmp"
jq --arg job_id "${self_contained_job_id}" \
  --arg revision "${base_sha}" \
  --arg bundle_sha256 "${self_contained_bundle_sha256}" '
  .job_id = $job_id
  | .provenance.evaluation_revision = $revision
  | .provenance.evidence_collector_revision = $revision
  | .provenance.evaluation_base_revision = null
  | .provenance.evaluation_bundle_sha256 = $bundle_sha256
' "${self_contained_dir}/scorecard.json" > "${self_contained_scorecard_tmp}"
mv "${self_contained_scorecard_tmp}" "${self_contained_dir}/scorecard.json"
self_contained_job_tmp="${self_contained_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${self_contained_job_id}" '.id = $job_id' \
  "${self_contained_dir}/harbor/job-result.json" > "${self_contained_job_tmp}"
mv "${self_contained_job_tmp}" "${self_contained_dir}/harbor/job-result.json"
write_smoke_checksums "${self_contained_dir}"
HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD
mv "${self_contained_dir}" "${fixture_repo}/self-contained-main-smoke-result"

unknown_cost_job_id="00000000-0000-0000-0000-000000000018"
unknown_cost_dir="${fixture_repo}/results/smoke/${unknown_cost_job_id}"
cp -R "${result_dir}" "${unknown_cost_dir}"
unknown_cost_scorecard_tmp="${unknown_cost_dir}/scorecard.json.tmp"
jq --arg job_id "${unknown_cost_job_id}" '
  .job_id = $job_id
  | .measures.cost.solver_api_equivalent_estimate_usd = null
' "${unknown_cost_dir}/scorecard.json" > "${unknown_cost_scorecard_tmp}"
mv "${unknown_cost_scorecard_tmp}" "${unknown_cost_dir}/scorecard.json"
unknown_cost_job_tmp="${unknown_cost_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${unknown_cost_job_id}" '
  .id = $job_id
  | del(.stats.cost_usd)
' "${unknown_cost_dir}/harbor/job-result.json" > "${unknown_cost_job_tmp}"
mv "${unknown_cost_job_tmp}" "${unknown_cost_dir}/harbor/job-result.json"
write_smoke_checksums "${unknown_cost_dir}"
HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD
mv "${unknown_cost_dir}" "${fixture_repo}/unknown-cost-smoke-result"

ln -s /etc/passwd "${result_dir}/leaked-artifact"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: unchecksummed result symlink was accepted' >&2
  exit 1
fi
mv "${result_dir}/leaked-artifact" "${fixture_repo}/leaked-artifact"

invalid_smoke_dir="${fixture_repo}/results/smoke/00000000-0000-0000-0000-000000000004"
cp -R "${result_dir}" "${invalid_smoke_dir}"
printf '%s\n' '# Invalid smoke fixture' > "${invalid_smoke_dir}/README.md"
printf '%s\n' '{"kind":"evaluator_smoke","status":"pass","job_id":"00000000-0000-0000-0000-000000000004","provenance":{"evaluation_revision":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","evidence_collector_revision":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","environment_image":"ubuntu:24.04@sha256:cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc"}}' > "${invalid_smoke_dir}/scorecard.json"
write_smoke_checksums "${invalid_smoke_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: smoke result without a locked Harbor environment was accepted' >&2
  exit 1
fi
mv "${invalid_smoke_dir}" "${fixture_repo}/invalid-smoke-result"

unreachable_job_id="00000000-0000-0000-0000-000000000005"
unreachable_result_dir="${fixture_repo}/results/smoke/${unreachable_job_id}"
unreachable_revision="ffffffffffffffffffffffffffffffffffffffff"
cp -R "${result_dir}" "${unreachable_result_dir}"
unreachable_scorecard_tmp="${unreachable_result_dir}/scorecard.json.tmp"
jq --arg job_id "${unreachable_job_id}" --arg revision "${unreachable_revision}" '
  .job_id = $job_id
  | .provenance.evaluation_revision = $revision
  | .provenance.evidence_collector_revision = $revision
' "${unreachable_result_dir}/scorecard.json" > "${unreachable_scorecard_tmp}"
mv "${unreachable_scorecard_tmp}" "${unreachable_result_dir}/scorecard.json"
unreachable_job_tmp="${unreachable_result_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${unreachable_job_id}" '.id = $job_id' \
  "${unreachable_result_dir}/harbor/job-result.json" > "${unreachable_job_tmp}"
mv "${unreachable_job_tmp}" "${unreachable_result_dir}/harbor/job-result.json"
write_smoke_checksums "${unreachable_result_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: unreachable evaluation revision was accepted' >&2
  exit 1
fi
mv "${unreachable_result_dir}" "${fixture_repo}/unreachable-smoke-result"

wrong_base_job_id="00000000-0000-0000-0000-000000000009"
wrong_base_dir="${fixture_repo}/results/smoke/${wrong_base_job_id}"
cp -R "${result_dir}" "${wrong_base_dir}"
wrong_base_scorecard_tmp="${wrong_base_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_base_job_id}" --arg revision "${evaluation_revision}" '
  .job_id = $job_id
  | .provenance.evaluation_base_revision = $revision
' "${wrong_base_dir}/scorecard.json" > "${wrong_base_scorecard_tmp}"
mv "${wrong_base_scorecard_tmp}" "${wrong_base_dir}/scorecard.json"
wrong_base_job_tmp="${wrong_base_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_base_job_id}" '.id = $job_id' \
  "${wrong_base_dir}/harbor/job-result.json" > "${wrong_base_job_tmp}"
mv "${wrong_base_job_tmp}" "${wrong_base_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_base_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: recorded base diverging from bundle prerequisite was accepted' >&2
  exit 1
fi
mv "${wrong_base_dir}" "${fixture_repo}/wrong-base-smoke-result"

wrong_constraints_job_id="00000000-0000-0000-0000-000000000014"
wrong_constraints_dir="${fixture_repo}/results/smoke/${wrong_constraints_job_id}"
cp -R "${result_dir}" "${wrong_constraints_dir}"
wrong_constraints_scorecard_tmp="${wrong_constraints_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_constraints_job_id}" \
  '.job_id = $job_id | .provenance.harbor_constraints_sha256 = ("a" * 64)' \
  "${wrong_constraints_dir}/scorecard.json" > "${wrong_constraints_scorecard_tmp}"
mv "${wrong_constraints_scorecard_tmp}" "${wrong_constraints_dir}/scorecard.json"
wrong_constraints_job_tmp="${wrong_constraints_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_constraints_job_id}" '.id = $job_id' \
  "${wrong_constraints_dir}/harbor/job-result.json" > "${wrong_constraints_job_tmp}"
mv "${wrong_constraints_job_tmp}" "${wrong_constraints_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_constraints_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: constraints digest diverging from bundled source was accepted' >&2
  exit 1
fi
mv "${wrong_constraints_dir}" "${fixture_repo}/wrong-constraints-smoke-result"

wrong_harbor_version_job_id="00000000-0000-0000-0000-000000000026"
wrong_harbor_version_dir="${fixture_repo}/results/smoke/${wrong_harbor_version_job_id}"
cp -R "${result_dir}" "${wrong_harbor_version_dir}"
wrong_harbor_version_scorecard_tmp="${wrong_harbor_version_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_harbor_version_job_id}" '
  .job_id = $job_id
  | .provenance.harbor_version = "9.9.9"
' "${wrong_harbor_version_dir}/scorecard.json" > "${wrong_harbor_version_scorecard_tmp}"
mv "${wrong_harbor_version_scorecard_tmp}" "${wrong_harbor_version_dir}/scorecard.json"
wrong_harbor_version_job_tmp="${wrong_harbor_version_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_harbor_version_job_id}" '.id = $job_id' \
  "${wrong_harbor_version_dir}/harbor/job-result.json" > "${wrong_harbor_version_job_tmp}"
mv "${wrong_harbor_version_job_tmp}" "${wrong_harbor_version_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_harbor_version_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: Harbor version diverging from bundled constraints was accepted' >&2
  exit 1
fi
mv "${wrong_harbor_version_dir}" "${fixture_repo}/wrong-harbor-version-smoke-result"

wrong_task_job_id="00000000-0000-0000-0000-000000000021"
wrong_task_dir="${fixture_repo}/results/smoke/${wrong_task_job_id}"
cp -R "${result_dir}" "${wrong_task_dir}"
wrong_task_scorecard_tmp="${wrong_task_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_task_job_id}" --arg checksum "$(printf 'a%.0s' {1..64})" '
  .job_id = $job_id
  | .provenance.task_checksum = $checksum
  | .provenance.oracle_task_checksum = $checksum
' "${wrong_task_dir}/scorecard.json" > "${wrong_task_scorecard_tmp}"
mv "${wrong_task_scorecard_tmp}" "${wrong_task_dir}/scorecard.json"
for trial_result in harbor/trial-result.json harbor/oracle-trial-result.json; do
  wrong_task_trial_tmp="${wrong_task_dir}/${trial_result}.tmp"
  jq --arg checksum "$(printf 'a%.0s' {1..64})" '.task_checksum = $checksum' \
    "${wrong_task_dir}/${trial_result}" > "${wrong_task_trial_tmp}"
  mv "${wrong_task_trial_tmp}" "${wrong_task_dir}/${trial_result}"
done
wrong_task_job_tmp="${wrong_task_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_task_job_id}" '.id = $job_id' \
  "${wrong_task_dir}/harbor/job-result.json" > "${wrong_task_job_tmp}"
mv "${wrong_task_job_tmp}" "${wrong_task_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_task_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: task checksum diverging from bundled Harbor task was accepted' >&2
  exit 1
fi
mv "${wrong_task_dir}" "${fixture_repo}/wrong-task-smoke-result"

wrong_image_job_id="00000000-0000-0000-0000-000000000015"
wrong_image_dir="${fixture_repo}/results/smoke/${wrong_image_job_id}"
cp -R "${result_dir}" "${wrong_image_dir}"
wrong_image_scorecard_tmp="${wrong_image_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_image_job_id}" \
  '.job_id = $job_id | .provenance.environment_image = ("ubuntu:24.04@sha256:" + ("a" * 64))' \
  "${wrong_image_dir}/scorecard.json" > "${wrong_image_scorecard_tmp}"
mv "${wrong_image_scorecard_tmp}" "${wrong_image_dir}/scorecard.json"
wrong_image_job_tmp="${wrong_image_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_image_job_id}" '.id = $job_id' \
  "${wrong_image_dir}/harbor/job-result.json" > "${wrong_image_job_tmp}"
mv "${wrong_image_job_tmp}" "${wrong_image_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_image_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: environment image diverging from bundled Dockerfile was accepted' >&2
  exit 1
fi
mv "${wrong_image_dir}" "${fixture_repo}/wrong-image-smoke-result"

rewritten_index_job_id="00000000-0000-0000-0000-000000000022"
rewritten_index_dir="${fixture_repo}/results/smoke/${rewritten_index_job_id}"
cp -R "${result_dir}" "${rewritten_index_dir}"
printf '\n' >> "${rewritten_index_dir}/harbor/environment-manifest.json"
rewritten_index_scorecard_tmp="${rewritten_index_dir}/scorecard.json.tmp"
jq --arg job_id "${rewritten_index_job_id}" '.job_id = $job_id' \
  "${rewritten_index_dir}/scorecard.json" > "${rewritten_index_scorecard_tmp}"
mv "${rewritten_index_scorecard_tmp}" "${rewritten_index_dir}/scorecard.json"
rewritten_index_job_tmp="${rewritten_index_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${rewritten_index_job_id}" '.id = $job_id' \
  "${rewritten_index_dir}/harbor/job-result.json" > "${rewritten_index_job_tmp}"
mv "${rewritten_index_job_tmp}" "${rewritten_index_dir}/harbor/job-result.json"
write_smoke_checksums "${rewritten_index_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: OCI index bytes not matching the pinned digest were accepted' >&2
  exit 1
fi
mv "${rewritten_index_dir}" "${fixture_repo}/rewritten-index-smoke-result"

empty_trajectory_job_id="00000000-0000-0000-0000-000000000016"
empty_trajectory_dir="${fixture_repo}/results/smoke/${empty_trajectory_job_id}"
cp -R "${result_dir}" "${empty_trajectory_dir}"
empty_trajectory_scorecard_tmp="${empty_trajectory_dir}/scorecard.json.tmp"
jq --arg job_id "${empty_trajectory_job_id}" '.job_id = $job_id' \
  "${empty_trajectory_dir}/scorecard.json" > "${empty_trajectory_scorecard_tmp}"
mv "${empty_trajectory_scorecard_tmp}" "${empty_trajectory_dir}/scorecard.json"
empty_trajectory_job_tmp="${empty_trajectory_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${empty_trajectory_job_id}" '.id = $job_id' \
  "${empty_trajectory_dir}/harbor/job-result.json" > "${empty_trajectory_job_tmp}"
mv "${empty_trajectory_job_tmp}" "${empty_trajectory_dir}/harbor/job-result.json"
printf '%s\n' '{"schema_version":"ATIF-v1.7","steps":[]}' \
  > "${empty_trajectory_dir}/harbor/trajectory.json"
write_smoke_checksums "${empty_trajectory_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: empty ATIF trajectory was accepted' >&2
  exit 1
fi
mv "${empty_trajectory_dir}" "${fixture_repo}/empty-trajectory-smoke-result"

wrong_runtime_job_id="00000000-0000-0000-0000-000000000017"
wrong_runtime_dir="${fixture_repo}/results/smoke/${wrong_runtime_job_id}"
cp -R "${result_dir}" "${wrong_runtime_dir}"
wrong_runtime_scorecard_tmp="${wrong_runtime_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_runtime_job_id}" '
  .job_id = $job_id
  | .provenance.container_runtime.platform = "linux/amd64"
  | .provenance.container_runtime.base_manifest_digest = ("sha256:" + ("f" * 64))
' "${wrong_runtime_dir}/scorecard.json" > "${wrong_runtime_scorecard_tmp}"
mv "${wrong_runtime_scorecard_tmp}" "${wrong_runtime_dir}/scorecard.json"
wrong_runtime_job_tmp="${wrong_runtime_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_runtime_job_id}" '.id = $job_id' \
  "${wrong_runtime_dir}/harbor/job-result.json" > "${wrong_runtime_job_tmp}"
mv "${wrong_runtime_job_tmp}" "${wrong_runtime_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_runtime_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: runtime absent from preserved OCI index was accepted' >&2
  exit 1
fi
mv "${wrong_runtime_dir}" "${fixture_repo}/wrong-runtime-smoke-result"

wrong_tokens_job_id="00000000-0000-0000-0000-000000000006"
wrong_tokens_dir="${fixture_repo}/results/smoke/${wrong_tokens_job_id}"
cp -R "${result_dir}" "${wrong_tokens_dir}"
wrong_tokens_scorecard_tmp="${wrong_tokens_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_tokens_job_id}" \
  '.job_id = $job_id | .measures.solver.input_tokens = 999' \
  "${wrong_tokens_dir}/scorecard.json" > "${wrong_tokens_scorecard_tmp}"
mv "${wrong_tokens_scorecard_tmp}" "${wrong_tokens_dir}/scorecard.json"
wrong_tokens_job_tmp="${wrong_tokens_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_tokens_job_id}" '.id = $job_id' \
  "${wrong_tokens_dir}/harbor/job-result.json" > "${wrong_tokens_job_tmp}"
mv "${wrong_tokens_job_tmp}" "${wrong_tokens_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_tokens_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: solver tokens diverging from Harbor were accepted' >&2
  exit 1
fi
mv "${wrong_tokens_dir}" "${fixture_repo}/wrong-token-smoke-result"

wrong_elapsed_job_id="00000000-0000-0000-0000-000000000007"
wrong_elapsed_dir="${fixture_repo}/results/smoke/${wrong_elapsed_job_id}"
cp -R "${result_dir}" "${wrong_elapsed_dir}"
wrong_elapsed_scorecard_tmp="${wrong_elapsed_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_elapsed_job_id}" \
  '.job_id = $job_id | .measures.solver.elapsed_seconds = 99' \
  "${wrong_elapsed_dir}/scorecard.json" > "${wrong_elapsed_scorecard_tmp}"
mv "${wrong_elapsed_scorecard_tmp}" "${wrong_elapsed_dir}/scorecard.json"
wrong_elapsed_job_tmp="${wrong_elapsed_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_elapsed_job_id}" '.id = $job_id' \
  "${wrong_elapsed_dir}/harbor/job-result.json" > "${wrong_elapsed_job_tmp}"
mv "${wrong_elapsed_job_tmp}" "${wrong_elapsed_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_elapsed_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: solver elapsed time diverging from trial timestamps was accepted' >&2
  exit 1
fi
mv "${wrong_elapsed_dir}" "${fixture_repo}/wrong-elapsed-smoke-result"

wrong_judge_job_id="00000000-0000-0000-0000-000000000008"
wrong_judge_dir="${fixture_repo}/results/smoke/${wrong_judge_job_id}"
cp -R "${result_dir}" "${wrong_judge_dir}"
wrong_judge_scorecard_tmp="${wrong_judge_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_judge_job_id}" \
  '.job_id = $job_id | .measures.judge.elapsed_seconds = 99 | .measures.judge.input_tokens = 999' \
  "${wrong_judge_dir}/scorecard.json" > "${wrong_judge_scorecard_tmp}"
mv "${wrong_judge_scorecard_tmp}" "${wrong_judge_dir}/scorecard.json"
wrong_judge_job_tmp="${wrong_judge_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_judge_job_id}" '.id = $job_id' \
  "${wrong_judge_dir}/harbor/job-result.json" > "${wrong_judge_job_tmp}"
mv "${wrong_judge_job_tmp}" "${wrong_judge_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_judge_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: judge measures diverging from preserved evidence were accepted' >&2
  exit 1
fi
mv "${wrong_judge_dir}" "${fixture_repo}/wrong-judge-smoke-result"

wrong_judge_identity_job_id="00000000-0000-0000-0000-000000000023"
wrong_judge_identity_dir="${fixture_repo}/results/smoke/${wrong_judge_identity_job_id}"
cp -R "${result_dir}" "${wrong_judge_identity_dir}"
wrong_judge_identity_scorecard_tmp="${wrong_judge_identity_dir}/scorecard.json.tmp"
jq --arg job_id "${wrong_judge_identity_job_id}" '
  .job_id = $job_id
  | .provenance.judge_agent_version = "9.9.9"
  | .provenance.judge_model = "different-model"
  | .provenance.judge_reasoning = "high"
' "${wrong_judge_identity_dir}/scorecard.json" > "${wrong_judge_identity_scorecard_tmp}"
mv "${wrong_judge_identity_scorecard_tmp}" "${wrong_judge_identity_dir}/scorecard.json"
wrong_judge_identity_job_tmp="${wrong_judge_identity_dir}/harbor/job-result.json.tmp"
jq --arg job_id "${wrong_judge_identity_job_id}" '.id = $job_id' \
  "${wrong_judge_identity_dir}/harbor/job-result.json" > "${wrong_judge_identity_job_tmp}"
mv "${wrong_judge_identity_job_tmp}" "${wrong_judge_identity_dir}/harbor/job-result.json"
write_smoke_checksums "${wrong_judge_identity_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: judge identity diverging from invocation evidence was accepted' >&2
  exit 1
fi
mv "${wrong_judge_identity_dir}" "${fixture_repo}/wrong-judge-identity-smoke-result"

invalid_result_dir="${fixture_repo}/results/hydra/0.1.0/00000000-0000-0000-0000-000000000003"
mkdir -p "${invalid_result_dir}/source"
cp "${result_dir}/source/evaluation.bundle" "${invalid_result_dir}/source/evaluation.bundle"
printf '%s\n' '# Invalid Hydra fixture' > "${invalid_result_dir}/README.md"
printf '%s\n' '{}' > "${invalid_result_dir}/scorecard.json"
(
  cd "${invalid_result_dir}"
  for path in README.md scorecard.json source/evaluation.bundle; do
    shasum -a 256 "${path}"
  done > checksums.txt
)
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: Hydra result without provenance was accepted' >&2
  exit 1
fi
mv "${invalid_result_dir}" "${fixture_repo}/invalid-hydra-result"

wrong_hydra_result_id="00000000-0000-0000-0000-000000000011"
wrong_hydra_dir="${fixture_repo}/results/hydra/0.1.0/${wrong_hydra_result_id}"
cp -R "${hydra_result_dir}" "${wrong_hydra_dir}"
wrong_hydra_scorecard_tmp="${wrong_hydra_dir}/scorecard.json.tmp"
jq --arg result_id "${wrong_hydra_result_id}" \
  --arg revision "ffffffffffffffffffffffffffffffffffffffff" '
  .result_id = $result_id
  | .provenance.hydra_revision = $revision
' "${wrong_hydra_dir}/scorecard.json" > "${wrong_hydra_scorecard_tmp}"
mv "${wrong_hydra_scorecard_tmp}" "${wrong_hydra_dir}/scorecard.json"
write_hydra_checksums "${wrong_hydra_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: Hydra revision absent from its source bundle was accepted' >&2
  exit 1
fi
mv "${wrong_hydra_dir}" "${fixture_repo}/wrong-hydra-revision-result"

wrong_execution_result_id="00000000-0000-0000-0000-000000000027"
wrong_execution_dir="${fixture_repo}/results/hydra/0.1.0/${wrong_execution_result_id}"
cp -R "${hydra_result_dir}" "${wrong_execution_dir}"
wrong_execution_scorecard_tmp="${wrong_execution_dir}/scorecard.json.tmp"
jq --arg result_id "${wrong_execution_result_id}" '
  .result_id = $result_id
  | .provenance.client = {name: "other-client", version: "9.9.9"}
  | .provenance.model.name = "different-model"
  | .provenance.environment.fingerprint = "sha256:different-environment"
  | .provenance.job_id = "different-job"
' "${wrong_execution_dir}/scorecard.json" > "${wrong_execution_scorecard_tmp}"
mv "${wrong_execution_scorecard_tmp}" "${wrong_execution_dir}/scorecard.json"
write_hydra_checksums "${wrong_execution_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: Hydra execution provenance diverging from native evidence was accepted' >&2
  exit 1
fi
mv "${wrong_execution_dir}" "${fixture_repo}/wrong-hydra-execution-result"

wrong_verifier_result_id="00000000-0000-0000-0000-000000000028"
wrong_verifier_dir="${fixture_repo}/results/hydra/0.1.0/${wrong_verifier_result_id}"
cp -R "${hydra_result_dir}" "${wrong_verifier_dir}"
wrong_verifier_scorecard_tmp="${wrong_verifier_dir}/scorecard.json.tmp"
jq --arg result_id "${wrong_verifier_result_id}" '
  .result_id = $result_id
  | .provenance.verifier.name = "tasks/smoke-question-answer/tests/other.sh"
  | .provenance.verifier.revision = "ffffffffffffffffffffffffffffffffffffffff"
  | .provenance.verifier.sha256 = ("f" * 64)
' "${wrong_verifier_dir}/scorecard.json" > "${wrong_verifier_scorecard_tmp}"
mv "${wrong_verifier_scorecard_tmp}" "${wrong_verifier_dir}/scorecard.json"
write_hydra_checksums "${wrong_verifier_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: Hydra verifier diverging from task and bundled source was accepted' >&2
  exit 1
fi
mv "${wrong_verifier_dir}" "${fixture_repo}/wrong-hydra-verifier-result"

unsupported_pass_result_id="00000000-0000-0000-0000-000000000012"
unsupported_pass_dir="${fixture_repo}/results/hydra/0.1.0/${unsupported_pass_result_id}"
cp -R "${hydra_result_dir}" "${unsupported_pass_dir}"
unsupported_pass_scorecard_tmp="${unsupported_pass_dir}/scorecard.json.tmp"
jq --arg result_id "${unsupported_pass_result_id}" '
  .result_id = $result_id
  | del(.assertions, .measures)
' "${unsupported_pass_dir}/scorecard.json" > "${unsupported_pass_scorecard_tmp}"
mv "${unsupported_pass_scorecard_tmp}" "${unsupported_pass_dir}/scorecard.json"
write_hydra_checksums "${unsupported_pass_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: Hydra pass without assertions and measures was accepted' >&2
  exit 1
fi
mv "${unsupported_pass_dir}" "${fixture_repo}/unsupported-hydra-pass-result"

unsupported_model_result_id="00000000-0000-0000-0000-000000000024"
unsupported_model_dir="${fixture_repo}/results/hydra/0.1.0/${unsupported_model_result_id}"
cp -R "${hydra_result_dir}" "${unsupported_model_dir}"
unsupported_model_scorecard_tmp="${unsupported_model_dir}/scorecard.json.tmp"
jq --arg result_id "${unsupported_model_result_id}" '
  .result_id = $result_id
  | .assertions[0].type = "model"
' "${unsupported_model_dir}/scorecard.json" > "${unsupported_model_scorecard_tmp}"
mv "${unsupported_model_scorecard_tmp}" "${unsupported_model_dir}/scorecard.json"
write_hydra_checksums "${unsupported_model_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: model assertion without rubric and grader context was accepted' >&2
  exit 1
fi
mv "${unsupported_model_dir}" "${fixture_repo}/unsupported-model-assertion-result"

mismatched_assertion_result_id="00000000-0000-0000-0000-000000000019"
mismatched_assertion_dir="${fixture_repo}/results/hydra/0.1.0/${mismatched_assertion_result_id}"
cp -R "${hydra_result_dir}" "${mismatched_assertion_dir}"
mismatched_assertion_scorecard_tmp="${mismatched_assertion_dir}/scorecard.json.tmp"
jq --arg result_id "${mismatched_assertion_result_id}" '.result_id = $result_id' \
  "${mismatched_assertion_dir}/scorecard.json" > "${mismatched_assertion_scorecard_tmp}"
mv "${mismatched_assertion_scorecard_tmp}" "${mismatched_assertion_dir}/scorecard.json"
printf '%s\n' '{"passed":false,"name":"different-assertion"}' \
  > "${mismatched_assertion_dir}/artifacts/verifier.json"
write_hydra_checksums "${mismatched_assertion_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: assertion evidence disagreeing with its scorecard was accepted' >&2
  exit 1
fi
mv "${mismatched_assertion_dir}" "${fixture_repo}/mismatched-assertion-result"

composite_measure_result_id="00000000-0000-0000-0000-000000000020"
composite_measure_dir="${fixture_repo}/results/hydra/0.1.0/${composite_measure_result_id}"
cp -R "${hydra_result_dir}" "${composite_measure_dir}"
composite_measure_scorecard_tmp="${composite_measure_dir}/scorecard.json.tmp"
jq --arg result_id "${composite_measure_result_id}" '
  .result_id = $result_id
  | .measures = {score: 1}
' "${composite_measure_dir}/scorecard.json" > "${composite_measure_scorecard_tmp}"
mv "${composite_measure_scorecard_tmp}" "${composite_measure_dir}/scorecard.json"
write_hydra_checksums "${composite_measure_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: composite-only Hydra measures were accepted' >&2
  exit 1
fi
mv "${composite_measure_dir}" "${fixture_repo}/composite-measure-result"

nested_composite_result_id="00000000-0000-0000-0000-000000000025"
nested_composite_dir="${fixture_repo}/results/hydra/0.1.0/${nested_composite_result_id}"
cp -R "${hydra_result_dir}" "${nested_composite_dir}"
nested_composite_scorecard_tmp="${nested_composite_dir}/scorecard.json.tmp"
jq --arg result_id "${nested_composite_result_id}" '
  .result_id = $result_id
  | .measures = {elapsed_seconds: 1.5, tokens: {composite_score: 1}}
' "${nested_composite_dir}/scorecard.json" > "${nested_composite_scorecard_tmp}"
mv "${nested_composite_scorecard_tmp}" "${nested_composite_dir}/scorecard.json"
write_hydra_checksums "${nested_composite_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: nested composite-only Hydra measures were accepted' >&2
  exit 1
fi
mv "${nested_composite_dir}" "${fixture_repo}/nested-composite-measure-result"

wrong_measure_result_id="00000000-0000-0000-0000-000000000029"
wrong_measure_dir="${fixture_repo}/results/hydra/0.1.0/${wrong_measure_result_id}"
cp -R "${hydra_result_dir}" "${wrong_measure_dir}"
wrong_measure_scorecard_tmp="${wrong_measure_dir}/scorecard.json.tmp"
jq --arg result_id "${wrong_measure_result_id}" '
  .result_id = $result_id
  | .measures.elapsed_seconds = 99
  | .measures.tokens.input_tokens = 999
  | .measures.cost_usd = 99
' "${wrong_measure_dir}/scorecard.json" > "${wrong_measure_scorecard_tmp}"
mv "${wrong_measure_scorecard_tmp}" "${wrong_measure_dir}/scorecard.json"
write_hydra_checksums "${wrong_measure_dir}"
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: Hydra measures diverging from native trial evidence were accepted' >&2
  exit 1
fi
mv "${wrong_measure_dir}" "${fixture_repo}/wrong-hydra-measure-result"

printf '%s\n' '41' > "${result_dir}/harbor/answer.txt"
git -C "${fixture_repo}" add results
git -C "${fixture_repo}" commit -q -m modified
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: modified published result was accepted' >&2
  exit 1
fi

git -C "${fixture_repo}" switch -q --detach "${base_sha}"
git -C "${fixture_repo}" switch -q -c deletion-case
git -C "${fixture_repo}" rm -q -r "results/hydra/0.1.0/${hydra_result_id}"
git -C "${fixture_repo}" commit -q -m deleted
if HYDRA_EVAL_REPO_ROOT="${fixture_repo}" \
  "${source_root}/scripts/validate-results.sh" "${base_sha}" HEAD >/dev/null 2>&1; then
  printf '%s\n' 'test_validate_results: deleted published Hydra result was accepted' >&2
  exit 1
fi

printf '%s\n' 'append-only-results: pass'
