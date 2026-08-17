#!/usr/bin/env bash
# Builds U-Boot for Radxa ZERO 3E/3W (rk3566) with deterministic flags.
# Consumes build/tfa/bl31.elf produced by tfa.sh (run all.sh to do both in order).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "${SCRIPT_DIR}/common.sh"

UBOOT_TAG="$(cat "${REPO_ROOT}/pins/uboot/tag")"
UBOOT_COMMIT="$(cat "${REPO_ROOT}/pins/uboot/commit")"
RKBIN_COMMIT="$(cat "${REPO_ROOT}/pins/rkbin/commit")"
DDR_REL="$(cat "${REPO_ROOT}/pins/rkbin/ddr")"

UBOOT_SRC="${BUILD_DIR}/u-boot"
RKBIN_SRC="${BUILD_DIR}/rkbin"
BL31_ELF="${BUILD_DIR}/tfa/bl31.elf"

ensure_build_dir

# --- 1. Verify TF-A bl31.elf exists (tfa.sh must run first) ---
assert_file_exists "${BL31_ELF}" "TF-A bl31.elf (run scripts/build/tfa.sh first)"

# --- 2. Fetch U-Boot at pinned commit (fail if pin mismatches tag) ---
echo "=== U-Boot: cloning ${UBOOT_TAG} (${UBOOT_COMMIT}) ==="
clone_pinned "${UBOOT_SRC}" "https://github.com/u-boot/u-boot" "${UBOOT_COMMIT}"
verify_commit_matches "${UBOOT_SRC}" "${UBOOT_COMMIT}"
verify_tag_of_commit "${UBOOT_SRC}" "${UBOOT_COMMIT}" "${UBOOT_TAG}"
git -C "${UBOOT_SRC}" submodule update --init --recursive

# --- 3. Fetch rkbin at pinned commit ---
echo "=== rkbin: cloning ${RKBIN_COMMIT} ==="
clone_pinned "${RKBIN_SRC}" "https://github.com/rockchip-linux/rkbin" "${RKBIN_COMMIT}"
verify_commit_matches "${RKBIN_SRC}" "${RKBIN_COMMIT}"

DDR="${RKBIN_SRC}/${DDR_REL}"
assert_file_exists "${DDR}" "rkbin DDR blob"

# --- 4. Reproducible env (pinned to U-Boot commit time) ---
echo "=== U-Boot: setting reproducible env ==="
set_reproducible_env "${UBOOT_SRC}" "${UBOOT_COMMIT}"

# --- 5. Configure & build ---
echo "=== U-Boot: defconfig + make (BL31=TF-A, ROCKCHIP_TPL=rkbin DDR) ==="
make -C "${UBOOT_SRC}" CROSS_COMPILE=aarch64-linux-gnu- mrproper
make -C "${UBOOT_SRC}" CROSS_COMPILE=aarch64-linux-gnu- radxa-zero-3-rk3566_defconfig
make -C "${UBOOT_SRC}" \
    CROSS_COMPILE=aarch64-linux-gnu- \
    BL31="${BL31_ELF}" \
    ROCKCHIP_TPL="${DDR}" \
    SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH}" \
    KBUILD_BUILD_TIMESTAMP="${KBUILD_BUILD_TIMESTAMP}" \
    KBUILD_BUILD_USER=builder \
    KBUILD_BUILD_HOST=build

# --- 6. Copy artifacts out ---
cp "${UBOOT_SRC}/u-boot-rockchip.bin" "${OUT_DIR}/u-boot-rockchip.bin"
cp "${UBOOT_SRC}/u-boot.itb"        "${OUT_DIR}/u-boot.itb"
# DTBs are under dts/upstream/src/arm64/ rather than the older dts/ path.
# Try both for forward-compatibility.
for dtb in rk3566-radxa-zero-3w rk3566-radxa-zero-3e; do
    for prefix in "dts/upstream/src/arm64/rockchip" "dts"; do
        src="${UBOOT_SRC}/${prefix}/${dtb}.dtb"
        if [ -f "${src}" ]; then
            cp "${src}" "${OUT_DIR}/${dtb}.dtb"
            break
        fi
    done
    assert_file_exists "${OUT_DIR}/${dtb}.dtb" "DTB ${dtb}"
done

# --- 7. Emit sha256sums for everything (build-internal; verify/reproducibility.sh
#       compares these across two builds) ---
( cd "${OUT_DIR}" && sha256sum u-boot-rockchip.bin u-boot.itb \
    rk3566-radxa-zero-3w.dtb rk3566-radxa-zero-3e.dtb > sha256sums.txt )

echo "=== U-Boot build complete. Artifacts in ${OUT_DIR}/ ==="