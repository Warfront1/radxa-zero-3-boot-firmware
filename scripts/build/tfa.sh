#!/usr/bin/env bash
# Builds TF-A (Trusted Firmware-A) BL31 for RK3566/RK3568.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/common.sh"

TFA_TAG="$(cat "${REPO_ROOT}/pins/tfa/tag")"
TFA_COMMIT="$(cat "${REPO_ROOT}/pins/tfa/commit")"
TFA_SRC="${BUILD_DIR}/arm-trusted-firmware"
TFA_OUT="${BUILD_DIR}/tfa"

ensure_build_dir
mkdir -p "${TFA_OUT}"

echo "=== TF-A: cloning ${TFA_TAG} (${TFA_COMMIT}) ==="
clone_pinned "${TFA_SRC}" "https://github.com/ARM-software/arm-trusted-firmware" "${TFA_COMMIT}"
verify_commit_matches "${TFA_SRC}" "${TFA_COMMIT}"
verify_tag_of_commit "${TFA_SRC}" "${TFA_COMMIT}" "${TFA_TAG}"

echo "=== TF-A: setting reproducible env (commit time) ==="
set_reproducible_env "${TFA_SRC}" "${TFA_COMMIT}"

echo "=== TF-A: make PLAT=rk3568 bl31 ==="
make -C "${TFA_SRC}" \
    CROSS_COMPILE=aarch64-linux-gnu- \
    PLAT=rk3568 \
    bl31

# Locate the built bl31.elf. TF-A places it at either:
#   build/rk3568/release/bl31/bl31.elf  (newer layout)
#   build/rk3568/release/bl31.bin       (older layout, some platforms)
BL31_ELF="${TFA_SRC}/build/rk3568/release/bl31/bl31.elf"
if [ ! -f "${BL31_ELF}" ]; then
    # Fallback: some TF-A versions produce bl31.bin at the release root.
    BL31_ELF="${TFA_SRC}/build/rk3568/release/bl31.bin"
fi
assert_file_exists "${BL31_ELF}" "TF-A bl31 output"

cp "${BL31_ELF}" "${TFA_OUT}/bl31.elf"
echo "=== TF-A: bl31.elf ready at ${TFA_OUT}/bl31.elf ==="