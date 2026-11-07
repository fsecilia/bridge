#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -euo pipefail

usage() {
    cat <<'HELP'
Usage: scripts/setup-windows-build-deps.sh [--with-wine]

Install Arch host tools for Windows cross-compilation and packaging.
Runs a full pacman system update to avoid partial upgrades. Requires sudo.
Wine is optional and is installed only with --with-wine.
This does not build target SDL or other application dependencies.
HELP
}

packages=(cmake ninja python llvm-mingw nsis)
while (($# > 0)); do
    case "$1" in
        --with-wine) packages+=(wine) ;;
        --help|-h) usage; exit 0 ;;
        *) printf 'Unknown argument: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

if ! command -v pacman >/dev/null 2>&1 || ! command -v sudo >/dev/null 2>&1; then
    printf '%s\n' 'Arch setup requires pacman and sudo' >&2
    exit 1
fi

printf '%s\n' 'Updating Arch and installing Windows distribution tools...'
sudo pacman -Syu --needed "${packages[@]}"

for tool in cmake ninja python x86_64-w64-mingw32-clang++ x86_64-w64-mingw32-windres makensis; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        printf 'Required tool was not installed on PATH: %s\n' "$tool" >&2
        exit 1
    fi
done
printf '%s\n' 'Host Windows toolchain and packaging prerequisites are available.'
