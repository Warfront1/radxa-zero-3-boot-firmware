#!/usr/bin/env bash
# Asserts both rk3566-radxa-zero-3w.dtb and rk3566-radxa-zero-3e.dtb are
# present in the build output. A missing DTB means the OF_LIST or build
# itself diverged from upstream — fail hard.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/out}"

for dtb in rk3566-radxa-zero-3w.dtb rk3566-radxa-zero-3e.dtb; do
    if [ ! -s "${OUT_DIR}/${dtb}" ]; then
        echo "FAIL: ${dtb} missing or empty in ${OUT_DIR}" >&2
        exit 1
    fi
    echo "ok: ${dtb} present ($(stat -c%s "${OUT_DIR}/${dtb}") bytes)"
done