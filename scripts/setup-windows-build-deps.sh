#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -euo pipefail

usage() {
    cat <<'HELP'
Usage: scripts/setup-windows-build-deps.sh [--with-wine]

Install Linux host tools for Windows cross-compilation and packaging.
The Linux distribution is detected from os-release. Currently supports Arch
and Arch-compatible distributions. Wine is optional and is installed only
with --with-wine. Target SDL and other application dependencies are separate.
HELP
}

if (($# == 1)) && [[ "$1" == --help || "$1" == -h ]]; then
    usage
    exit 0
fi

if [[ "$(uname -s)" != Linux ]]; then
    printf '%s\n' 'Windows build dependency setup currently supports Linux hosts only' >&2
    exit 1
fi

if [[ ${BRIDGE_OS_RELEASE_FILE+x} ]]; then
    os_release_file=$BRIDGE_OS_RELEASE_FILE
    printf 'Using explicit OS release metadata: %s\n' "$os_release_file" >&2
elif [[ -r /etc/os-release ]]; then
    os_release_file=/etc/os-release
else
    os_release_file=/usr/lib/os-release
fi

if [[ ! -f "$os_release_file" || ! -r "$os_release_file" ]]; then
    printf 'Cannot read Linux distribution metadata: %s\n' "$os_release_file" >&2
    exit 1
fi

ID=
ID_LIKE=
# shellcheck source=/dev/null
source "$os_release_file"

read -r -a compatible_ids <<< "$ID_LIKE"
for distribution in "$ID" "${compatible_ids[@]}"; do
    case "$distribution" in
        arch|cachyos)
            script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
            exec "$script_dir/linux/arch/setup-windows-build-deps.sh" "$@"
            ;;
    esac
done

printf 'Unsupported Linux distribution for Windows build dependency setup: ID=%s ID_LIKE=%s\n' \
    "${ID:-unknown}" "${ID_LIKE:-none}" >&2
printf '%s\n' 'Supported distribution family: Arch' >&2
exit 1
