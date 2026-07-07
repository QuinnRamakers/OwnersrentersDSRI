#!/usr/bin/env bash
# SETUP_CLUSTER  Bootstrap script for a fresh/restarted DSRI OpenShift pod.
#
#   Clones (or updates) this repo onto the mounted persistent volume, so
#   the CODE survives a pod restart the same way run outputs already do via
#   +utility/output_dir.m -- not just the .mat/.png artifacts. Run this once
#   after the pod (re)starts and before launching MATLAB.
#
#   Required environment variables (set as pod env vars backed by an
#   OpenShift Secret -- never hardcode these in the script or commit them):
#     CGM_OUTPUT_DIR  Mount path of the attached PVC (see
#                     +utility/output_dir.m). The repo is cloned to
#                     $CGM_OUTPUT_DIR/OwnersrentersDSRI.
#     GITHUB_TOKEN    A GitHub Personal Access Token (repo read scope) for
#                     QuinnRamakers/OwnersrentersDSRI (private repo). Passed
#                     via `-c http.extraHeader` so it is used only for this
#                     invocation and never written into .git/config.
#
#   Usage:
#     export CGM_OUTPUT_DIR=/data          # match the PVC mount path
#     export GITHUB_TOKEN=<your PAT>       # from an OpenShift Secret
#     bash setup_cluster.sh
#     cd "$CGM_OUTPUT_DIR/OwnersrentersDSRI"

set -euo pipefail

: "${CGM_OUTPUT_DIR:?CGM_OUTPUT_DIR must be set to the mounted PVC path}"
: "${GITHUB_TOKEN:?GITHUB_TOKEN must be set (GitHub PAT with repo read access)}"

REPO_URL="https://github.com/QuinnRamakers/OwnersrentersDSRI.git"
REPO_DIR="${CGM_OUTPUT_DIR}/OwnersrentersDSRI"
AUTH_HEADER="Authorization: Bearer ${GITHUB_TOKEN}"

mkdir -p "${CGM_OUTPUT_DIR}"

if [ -d "${REPO_DIR}/.git" ]; then
    echo "Repo already present at ${REPO_DIR} -- pulling latest main."
    git -C "${REPO_DIR}" -c http.extraHeader="${AUTH_HEADER}" pull origin main
else
    echo "Cloning repo onto persistent volume at ${REPO_DIR}."
    git -c http.extraHeader="${AUTH_HEADER}" clone "${REPO_URL}" "${REPO_DIR}"
fi

echo "Repo ready at: ${REPO_DIR}"
echo "Run outputs will land in: ${CGM_OUTPUT_DIR} (via CGM_OUTPUT_DIR)"
