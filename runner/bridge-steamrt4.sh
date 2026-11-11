#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -euo pipefail

# The consumer pins its SDK image in a committed file so every checkout builds
# against the same baseline. BRIDGE_STEAMRT4_SDK_IMAGE overrides it, visibly.
workspace=$(pwd -P)
image_file="$workspace/steamrt4-sdk.image"
image=${BRIDGE_STEAMRT4_SDK_IMAGE:-}
if [[ -n "$image" ]]; then
    printf 'Steam Runtime SDK image: %s (BRIDGE_STEAMRT4_SDK_IMAGE override)\n' "$image" >&2
elif [[ -f "$image_file" ]]; then
    entries=()
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"
        [[ -z "$line" || "$line" == \#* ]] && continue
        entries+=("$line")
    done < "$image_file"
    if ((${#entries[@]} != 1)); then
        printf 'error: %s must contain exactly one image reference; found %d\n' "$image_file" "${#entries[@]}" >&2
        exit 2
    fi
    image=${entries[0]}
else
    printf 'error: no Steam Runtime SDK image: commit %s or set BRIDGE_STEAMRT4_SDK_IMAGE (@sha256:...)\n' \
        "$image_file" >&2
    exit 2
fi

runner="${BASH_SOURCE[0]%/*}/bridge-steamrt4-sdk.sh"
options=(--image "$image" --workspace "$workspace")
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
