#!/usr/bin/env bash
# Reproducibility check: build the artifacts twice in isolated containers
# and compare sha256. Fails on any mismatch. This is a HARD CI gate.
#
# Why two containers, not two runs in one: a true reproducibility check must
# rule out shared state (build/ dir contents, .git, cached downloads).
# Each run gets a fresh container with only the pinned Dockerfile and scripts.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_TAG="radxa-zero3-boot-firmware-repro:latest"

# Build the image once (cache is fine — the image is itself the pinned input).
docker build -t "${IMAGE_TAG}" "${REPO_ROOT}"

# Two isolated runs with distinct output dirs mounted from host. Build dirs
# use Docker anonymous volumes (not host bind-mounts) because U-Boot's build
# creates symlinks inside the source tree, which Windows/virtiofs hosts don't
# permit. Only /out is bind-mounted so we can hash-compare the artifacts.
for run in 1 2; do
    rm -rf "/tmp/zero3-repro-run${run}"
    mkdir -p "/tmp/zero3-repro-run${run}/out"
    docker run --rm \
        -v "/tmp/zero3-repro-run${run}/out:/out" \
        -e BUILD_DIR=/build \
        -e OUT_DIR=/out \
        "${IMAGE_TAG}"
done

H1="$(sha256sum /tmp/zero3-repro-run1/out/u-boot-rockchip.bin | awk '{print $1}')"
H2="$(sha256sum /tmp/zero3-repro-run2/out/u-boot-rockchip.bin | awk '{print $1}')"

echo "run1 u-boot-rockchip.bin sha256: ${H1}"
echo "run2 u-boot-rockchip.bin sha256: ${H2}"

if [ "${H1}" != "${H2}" ]; then
    echo "FAIL: reproducibility broken — u-boot-rockchip.bin differs between runs" >&2
    diff <(sha256sum /tmp/zero3-repro-run1/out/* | sort) \
         <(sha256sum /tmp/zero3-repro-run2/out/* | sort) || true
    exit 1
fi

# Also assert all four artifacts match across runs.
for f in u-boot.itb rk3566-radxa-zero-3w.dtb rk3566-radxa-zero-3e.dtb; do
    a="$(sha256sum "/tmp/zero3-repro-run1/out/${f}" | awk '{print $1}')"
    b="$(sha256sum "/tmp/zero3-repro-run2/out/${f}" | awk '{print $1}')"
    [ "${a}" = "${b}" ] || { echo "FAIL: ${f} differs" >&2; exit 1; }
done

echo "PASS: all 4 artifacts byte-identical across two isolated builds"