#!/usr/bin/env bash
# Top-level build orchestrator
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "########## Stage 1/2: TF-A bl31.elf ##########"
bash "${SCRIPT_DIR}/tfa.sh"

echo
echo "########## Stage 2/2: U-Boot (consuming TF-A bl31.elf) ##########"
bash "${SCRIPT_DIR}/uboot.sh"

echo
echo "=== all.sh: both stages complete ==="