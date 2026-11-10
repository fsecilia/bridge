#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -euo pipefail

image=${BRIDGE_STEAMRT4_SDK_IMAGE:-}
if [[ -z "$image" ]]; then
    printf 'error: set BRIDGE_STEAMRT4_SDK_IMAGE to a pinned Steam Linux Runtime 4 SDK image (@sha256:...)\n' >&2
    exit 2
fi

runner="${BASH_SOURCE[0]%/*}/bridge-steamrt4-sdk.sh"
options=(--image "$image" --workspace "$(pwd -P)")
if [[ -n "${BRIDGE_STEAMRT4_PREFIX:-}" ]]; then
    options+=(--dependency-prefix "$BRIDGE_STEAMRT4_PREFIX")
fi

if (($# == 0)); then
    exec "$runner" "${options[@]}" --shell
fi
if [[ "$1" == '--' ]]; then
    shift
    (($# > 0)) || { printf 'error: command required after --\n' >&2; exit 2; }
fi
exec "$runner" "${options[@]}" -- "$@"
