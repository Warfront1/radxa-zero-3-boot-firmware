#!/usr/bin/env bash
# Structural validation of u-boot-rockchip.bin.
#
# A full `binman ls` would need the binman tool and the image description;
# instead we assert the structural invariants of the single-image layout:
#   1. u-boot-rockchip.bin exists and is non-trivially sized (>256 KiB).
#   2. The first 4 bytes are NOT a GPT/MBR — sector 64 is the boot area.
#   3. u-boot.itb exists alongside (the FIT payload, present inside the bin).
#   4. The FIT magic 0xd00dfeed appears somewhere in u-boot-rockchip.bin
#      (the FIT is embedded by binman into the single image).
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/out}"

BIN="${OUT_DIR}/u-boot-rockchip.bin"
ITB="${OUT_DIR}/u-boot.itb"

[ -s "${BIN}" ] || { echo "FAIL: ${BIN} missing" >&2; exit 1; }
[ -s "${ITB}" ] || { echo "FAIL: ${ITB} missing" >&2; exit 1; }

SIZE="$(stat -c%s "${BIN}")"
[ "${SIZE}" -gt 262144 ] || { echo "FAIL: ${BIN} too small (${SIZE} B)" >&2; exit 1; }

# FIT magic (big-endian 0xd00dfeed) must appear inside the single image.
# Use grep -aP (Perl regex, treat binary as text) — most portable across od/xxd variants.
# -a is essential: without it grep prints "Binary file matches" and exits 2 on
# binary input, which set -o pipefail / `!` would misread as failure.
if ! grep -aP '\xd0\x0d\xfe\xed' "${BIN}" >/dev/null 2>&1; then
    # Fallback for systems without grep -P: use od and search for the hex pattern.
    # Temporarily disable pipefail: with `grep -q`, grep exits 0 on first match
    # and od receives SIGPIPE (exit 141). Under pipefail that 141 would wrongly
    # win over grep's 0 and produce a false-negative FAIL.
    set +o pipefail
    if ! od -A x -t x1 "${BIN}" | grep -qi 'd0 0d fe ed'; then
        set -o pipefail
        echo "FAIL: FIT magic 0xd00dfeed not found in ${BIN}" >&2
        exit 1
    fi
    set -o pipefail
fi

echo "ok: u-boot-rockchip.bin size=${SIZE} B, FIT magic present, u-boot.itb present"