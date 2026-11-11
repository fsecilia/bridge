#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -euo pipefail

usage() {
    printf 'usage: %s --image <OCI image@sha256:digest> --workspace <absolute-directory> [--dependency-prefix <absolute-directory>] (--shell | -- <command> [args...])\n' "$0" >&2
    exit 2
}

image=''
workspace=''
dependency_prefix=''
mode=command
while (($#)); do
    case "$1" in
        --image|--workspace|--dependency-prefix)
            (($# >= 2)) || usage
            case "$1" in
                --image) image=$2 ;;
                --workspace) workspace=$2 ;;
                --dependency-prefix) dependency_prefix=$2 ;;
            esac
            shift 2
            ;;
        --shell)
            mode=shell
            shift
            break
            ;;
        --)
            shift
            break
            ;;
        *) usage ;;
    esac
done

[[ -n "$image" && -n "$workspace" ]] || usage
if [[ "$mode" == shell ]]; then
    (($# == 0)) || usage
else
    (($# > 0)) || usage
fi
# A floating image tag can change the libc/compiler baseline between builds.
if [[ ! "$image" =~ @sha256:[[:xdigit:]]{64}$ ]]; then
    printf 'error: Steam Runtime SDK image must be pinned with an OCI sha256 digest: %s\n' "$image" >&2
    exit 2
fi
if [[ "$workspace" != /* || ! -d "$workspace" ]]; then
    printf 'error: Steam Runtime SDK workspace must be an existing absolute directory: %s\n' "$workspace" >&2
    exit 2
fi
workspace=$(cd -- "$workspace" && pwd -P)

podman=${BRIDGE_PODMAN_EXECUTABLE:-podman}
if ! command -v "$podman" >/dev/null 2>&1; then
    printf 'error: Steam Runtime SDK execution requires Podman: %s\n' "$podman" >&2
    exit 1
fi

options=(
    run --rm --pull=missing --userns=keep-id
    --user "$(id -u):$(id -g)"
    --mount "type=bind,source=${workspace},target=${workspace}"
    --workdir "$workspace"
    # Keep compiler and Mesa caches in the ignored build tree rather than the source root.
    --env "XDG_CACHE_HOME=${workspace}/build/.cache/steamrt4"
    --env "CCACHE_DIR=${workspace}/build/.cache/steamrt4/ccache"
)
if [[ -n "$dependency_prefix" ]]; then
    if [[ "$dependency_prefix" != /* || ! -d "$dependency_prefix" ]]; then
        printf 'error: SDK dependency prefix must be an existing absolute directory: %s\n' "$dependency_prefix" >&2
        exit 2
    fi
    dependency_prefix=$(cd -- "$dependency_prefix" && pwd -P)
    if [[ "$dependency_prefix" == "$workspace" || "$dependency_prefix" == "$workspace/"* || \
        "$workspace" == "$dependency_prefix/"* ]]; then
        printf 'error: SDK dependency prefix must not contain or be contained by the workspace: %s\n' "$dependency_prefix" >&2
        exit 2
    fi
    options+=(
        --mount "type=bind,source=${dependency_prefix},target=${dependency_prefix}"
        --env "CMAKE_PREFIX_PATH=${dependency_prefix}"
    )
fi

if [[ "$mode" == shell ]]; then
    options+=(--interactive --tty --env HISTFILE=/dev/null --env LESSHISTFILE=-)
    exec "$podman" "${options[@]}" "$image" /bin/bash
fi
exec "$podman" "${options[@]}" "$image" "$@"
