#!/usr/bin/env bash
# Shared helpers for build stages. Sourced by tfa.sh and uboot.sh.
# Not executable on its own.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${BUILD_DIR:-${REPO_ROOT}/build}"
OUT_DIR="${OUT_DIR:-${REPO_ROOT}/out}"

# ensure_build_dir: create build/ and out/ if missing.
ensure_build_dir() {
    mkdir -p "${BUILD_DIR}" "${OUT_DIR}"
}

# clone_pinned <dest> <url> <commit>
# Clones (or reuses) a repo and checks out the exact commit. Does NOT verify
# a tag — use verify_pin for that. Failures abort (set -e).
clone_pinned() {
    local dest="$1" url="$2" commit="$3"
    if [ ! -d "${dest}/.git" ]; then
        git clone "${url}" "${dest}"
    fi
    git -C "${dest}" fetch --tags origin
    git -C "${dest}" checkout "${commit}"
}

# verify_commit_matches <src_dir> <expected_commit>
# Hard-fails if the repo HEAD is not the pinned commit. Tolerates annotated
# tags: if the pin is the tag object SHA, git checkout dereferences it and
# HEAD becomes the target commit, so we accept either SHA.
verify_commit_matches() {
    local src_dir="$1" expected="$2"
    local actual
    actual="$(git -C "${src_dir}" rev-parse HEAD)"
    if [ "${actual}" != "${expected}" ]; then
        # Maybe expected was an annotated tag object SHA; check if HEAD is
        # the commit that tag points to.
        local tagged_commit
        tagged_commit="$(git -C "${src_dir}" rev-parse "${expected}^{commit}" 2>/dev/null || true)"
        if [ "${tagged_commit}" != "${actual}" ]; then
            echo "ERROR: ${src_dir} HEAD ${actual} != pin ${expected}" >&2
            exit 1
        fi
    fi
}

# verify_tag_of_commit <src_dir> <expected_commit> <expected_tag>
# Hard-fails if the pinned commit is not the named tag.
verify_tag_of_commit() {
    local src_dir="$1" expected_commit="$2" expected_tag="$3"
    local actual_tag
    actual_tag="$(git -C "${src_dir}" describe --tags --exact-match "${expected_commit}" 2>/dev/null || true)"
    if [ "${actual_tag}" != "${expected_tag}" ]; then
        echo "ERROR: commit ${expected_commit} is not tag ${expected_tag} (got '${actual_tag}')" >&2
        exit 1
    fi
}

# set_reproducible_env <src_dir> <commit>
# Pins build timestamp to the commit's author time and exports the
# KBUILD_BUILD_* vars + umask that U-Boot and TF-A both respect.
set_reproducible_env() {
    local src_dir="$1" commit="$2"
    local sde
    sde="$(git -C "${src_dir}" show -s --format=%ct "${commit}")"
    export SOURCE_DATE_EPOCH="${sde}"
    export KBUILD_BUILD_TIMESTAMP="@${sde}"
    export KBUILD_BUILD_USER=builder
    export KBUILD_BUILD_HOST=build
    umask 022
}

# assert_file_exists <path> <label>
assert_file_exists() {
    local path="$1" label="$2"
    if [ ! -f "${path}" ]; then
        echo "ERROR: missing ${label}: ${path}" >&2
        exit 1
    fi
}