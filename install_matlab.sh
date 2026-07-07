#!/usr/bin/env bash
# INSTALL_MATLAB  Provision MATLAB + required toolboxes onto the persistent
#   volume via MathWorks' mpm (MATLAB Package Manager), so a pod restart no
#   longer means redoing this install from scratch -- only the FIRST run on
#   a given PVC does real work; subsequent runs detect the existing install
#   and just print the PATH line to use.
#
#   Required products for this codebase (see run_combined.m header):
#     Optimization Toolbox         -- fmincon in +solver/bellman_step.m
#     Parallel Computing Toolbox   -- parfor/gcp/parpool
#
#   >>> EDIT MATLAB_RELEASE below to match the release your license/
#   >>> entitlement covers (e.g. R2024b). Valid product names for --products
#   >>> are listed at: https://github.com/mathworks-ref-arch/matlab-dockerfile
#
#   Required environment variables:
#     CGM_OUTPUT_DIR   Mount path of the attached PVC (same one
#                      +utility/output_dir.m and setup_cluster.sh use).
#                      MATLAB is installed to $CGM_OUTPUT_DIR/matlab.
#
#   This script does NOT handle license activation/network license manager
#   config (e.g. MLM_LICENSE_FILE) -- that's assumed to already be set at
#   the pod level, same as before. mpm only stages the product files; you
#   still need a valid license to run MATLAB against this install.
#
#   Usage:
#     export CGM_OUTPUT_DIR=/data
#     bash install_matlab.sh
#     export PATH="$CGM_OUTPUT_DIR/matlab/bin:$PATH"

set -euo pipefail

: "${CGM_OUTPUT_DIR:?CGM_OUTPUT_DIR must be set to the mounted PVC path}"

MATLAB_RELEASE="R2024b"   # <-- EDIT to match your license/entitlement
MATLAB_DEST="${CGM_OUTPUT_DIR}/matlab"
PRODUCTS=(MATLAB Optimization_Toolbox Parallel_Computing_Toolbox)

if [ -x "${MATLAB_DEST}/bin/matlab" ]; then
    echo "MATLAB already installed at ${MATLAB_DEST} -- skipping mpm install."
else
    echo "No existing install found at ${MATLAB_DEST} -- installing via mpm."
    echo "Release: ${MATLAB_RELEASE}  Products: ${PRODUCTS[*]}"

    if ! command -v mpm >/dev/null 2>&1; then
        echo "mpm not found on PATH -- downloading it."
        TMP_MPM="$(mktemp -d)/mpm"
        curl -fsSL -o "${TMP_MPM}" \
            "https://www.mathworks.com/mpm/glnxa64/mpm"
        chmod +x "${TMP_MPM}"
        MPM_BIN="${TMP_MPM}"
    else
        MPM_BIN="mpm"
    fi

    mkdir -p "${MATLAB_DEST}"
    "${MPM_BIN}" install \
        --release="${MATLAB_RELEASE}" \
        --destination="${MATLAB_DEST}" \
        --products "${PRODUCTS[@]}"
fi

echo ""
echo "Done. Add MATLAB to PATH for this session with:"
echo "  export PATH=\"${MATLAB_DEST}/bin:\$PATH\""
echo ""
echo "Then verify toolboxes are licensed and visible with:"
echo "  matlab -batch \"assert(license('test','Optimization_Toolbox'), 'Optimization Toolbox missing'); assert(license('test','Distrib_Computing_Toolbox'), 'Parallel Computing Toolbox missing'); disp('Toolboxes OK')\""
