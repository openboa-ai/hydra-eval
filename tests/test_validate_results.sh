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
git -C "${fixture_repo}" add evaluator-source.txt
git -C "${fixture_repo}" commit -q -m evaluator-source
evaluation_revision="$(git -C "${fixture_repo}" rev-parse HEAD)"

write_smoke_checksums() {
  local directory="$1"
  (
    cd "${directory}"
    for path in \
      README.md \
      harbor/answer.txt \
      harbor/job-result.json \
      harbor/oracle-job-result.json \
      harbor/oracle-trial-result.json \
      harbor/trajectory.json \
      harbor/trial-result.json \
      harbor/verifier-reward.json \
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
      artifacts/output.txt \
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
  --arg bundle_sha256 "${evaluation_bundle_sha256}" '
    .provenance.evaluation_revision = $revision
    | .provenance.evidence_collector_revision = $revision
    | .provenance.evaluation_base_revision = $base_revision
    | .provenance.evaluation_bundle_sha256 = $bundle_sha256
  ' \
  "${result_dir}/scorecard.json" > "${scorecard_tmp}"
mv "${scorecard_tmp}" "${result_dir}/scorecard.json"
printf '%s\n' '{"id":"00000000-0000-0000-0000-000000000001","stats":{"n_completed_trials":1,"n_errored_trials":0,"n_input_tokens":10,"n_cache_tokens":3,"n_output_tokens":2,"cost_usd":0.001}}' > "${result_dir}/harbor/job-result.json"
printf '%s\n' '{"id":"00000000-0000-0000-0000-000000000010","stats":{"n_completed_trials":1,"n_errored_trials":0}}' > "${result_dir}/harbor/oracle-job-result.json"
printf '%s\n' '{"task_name":"openboa/hydra-eval-smoke-question-answer","task_checksum":"task-checksum","agent_info":{"name":"codex","version":"0.147.0","model_info":{"name":"gpt-5.6-luna"}},"started_at":"2026-08-27T00:00:00Z","finished_at":"2026-08-27T00:00:01.500000Z","verifier_result":{"rewards":{"reward":1}},"exception_info":null}' > "${result_dir}/harbor/trial-result.json"
printf '%s\n' '{"task_name":"openboa/hydra-eval-smoke-question-answer","task_checksum":"task-checksum","agent_info":{"name":"oracle"},"verifier_result":{"rewards":{"reward":1}},"exception_info":null}' > "${result_dir}/harbor/oracle-trial-result.json"
printf '%s\n' '{"schema_version":"ATIF-v1.7","steps":[]}' > "${result_dir}/harbor/trajectory.json"
printf '%s\n' '{"answer_exact":1,"reward":1}' > "${result_dir}/harbor/verifier-reward.json"
mkdir -p "${result_dir}/judge"
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
printf '%s\n' '{"kind":"hydra_evaluation","hydra_version":"0.1.0","result_id":"00000000-0000-0000-0000-000000000002","status":"pass","provenance":{"hydra_revision":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa","hydra_bundle_sha256":"ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff","evaluation_revision":"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb","task":"project-task","client":{"name":"codex","version":"0.147.0"},"model":{"name":"gpt-5.6-luna"},"environment":{"fingerprint":"sha256:environment"},"job_id":"harbor-job","verifier":{"name":"deterministic-tests","revision":"cccccccccccccccccccccccccccccccccccccccc"}}}' > "${hydra_result_dir}/scorecard.json"
hydra_scorecard_tmp="${hydra_result_dir}/scorecard.json.tmp"
jq --arg revision "${evaluation_revision}" \
  --arg base_revision "${repository_base_revision}" \
  --arg bundle_sha256 "${evaluation_bundle_sha256}" \
  --arg hydra_bundle_sha256 "${hydra_bundle_sha256}" '
    .provenance.hydra_revision = $revision
    | .provenance.hydra_bundle_sha256 = $hydra_bundle_sha256
    | .provenance.evaluation_revision = $revision
    | .provenance.evaluation_base_revision = $base_revision
    | .provenance.evaluation_bundle_sha256 = $bundle_sha256
  ' \
  "${hydra_result_dir}/scorecard.json" > "${hydra_scorecard_tmp}"
mv "${hydra_scorecard_tmp}" "${hydra_result_dir}/scorecard.json"
printf '%s\n' 'artifact' > "${hydra_result_dir}/artifacts/output.txt"
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
