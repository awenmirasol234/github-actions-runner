#!/usr/bin/env bash
set -euo pipefail

: "${ACCESS_TOKEN:?ACCESS_TOKEN is not set}"
: "${REPO_URL:?REPO_URL is not set}"
: "${RUNNER_NAME:?RUNNER_NAME is not set}"

runner_dir="${RUNNER_DIR:-/tmp/runner}"
runner_source_dir="${RUNNER_SOURCE_DIR:-/opt/actions-runner}"
repo_path="${REPO_URL#https://github.com/}"
repo_path="${repo_path%/}"

if [[ "${REPO_URL}" != https://github.com/* ||
      "${repo_path}" != */* ||
      "${repo_path}" == *:* ||
      "${repo_path}" == *"?"* ]]; then
    echo "REPO_URL must be a GitHub repository URL" >&2
    exit 1
fi

mkdir -p "${runner_dir}"
if [[ ! -x "${runner_dir}/run.sh" ]]; then
    cp -a "${runner_source_dir}/." "${runner_dir}/"
fi

cd "${runner_dir}"

if [[ ! -f .runner ]]; then
    registration_token="$(
        curl -fsSL \
            -X POST \
            -H "Accept: application/vnd.github+json" \
            -H "Authorization: Bearer ${ACCESS_TOKEN}" \
            -H "X-GitHub-Api-Version: 2022-11-28" \
            "https://api.github.com/repos/${repo_path}/actions/runners/registration-token" \
            | jq -er '.token'
    )"

    ./config.sh \
        --unattended \
        --url "${REPO_URL}" \
        --token "${registration_token}" \
        --name "${RUNNER_NAME}" \
        --labels "${LABELS:-ubuntu,docker}" \
        --work "${RUNNER_WORKDIR:-_work}" \
        --replace
fi

exec ./run.sh
