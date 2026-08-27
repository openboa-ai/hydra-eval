#!/usr/bin/env bash
set -u

answer_path="${HYDRA_EVAL_ANSWER_PATH:-/app/answer.txt}"
reward_dir="${HYDRA_EVAL_REWARD_DIR:-/logs/verifier}"
reward_path="${reward_dir}/reward.json"

mkdir -p "${reward_dir}"

if [[ -f "${answer_path}" ]] && cmp -s "${answer_path}" <(printf '42\n'); then
  printf '%s\n' '{"answer_exact":1,"reward":1}' > "${reward_path}"
  printf '%s\n' "answer_exact=1"
else
  printf '%s\n' '{"answer_exact":0,"reward":0}' > "${reward_path}"
  printf '%s\n' "answer_exact=0"
fi
