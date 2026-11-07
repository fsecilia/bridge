#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -euo pipefail

fail() {
    printf 'bridge-wine-validation: %s\n' "$*" >&2
    exit 1
}

usage='usage: bridge-wine-validation.sh --output <validation/wine directory> [--keep-prefix] -- <test command> [args...]'
output=''
keep_prefix=false
while (($#)); do
    case "$1" in
        --output)
            (($# >= 2)) || fail "$usage"
            output=$2
            shift 2
            ;;
        --keep-prefix)
            keep_prefix=true
            shift
            ;;
        --)
            shift
            break
            ;;
        *) fail "unknown option: $1; $usage" ;;
    esac
done
[[ -n "$output" && $# -gt 0 ]] || fail "$usage"
[[ "$output" = /* ]] || fail '--output must be an absolute path'
[[ -n "${WAYLAND_DISPLAY:-}" ]] || fail 'native Wayland is required (WAYLAND_DISPLAY is unset)'

if [[ "$WAYLAND_DISPLAY" = /* ]]; then
    wayland_socket=$WAYLAND_DISPLAY
else
    [[ -n "${XDG_RUNTIME_DIR:-}" ]] || fail 'relative WAYLAND_DISPLAY requires XDG_RUNTIME_DIR'
    wayland_socket=$XDG_RUNTIME_DIR/$WAYLAND_DISPLAY
fi
[[ -S "$wayland_socket" ]] || fail "Wayland socket is unavailable: $wayland_socket"
for tool in wine wineboot wineserver; do
    command -v "$tool" >/dev/null 2>&1 || fail "required Wine command is unavailable: $tool"
done

mkdir -p "$output/prefixes" "$output/logs" "$output/results"
prefix=$(mktemp -d "$output/prefixes/session-XXXXXXXX") || fail 'could not create isolated Wine prefix'
name=${prefix##*/}
log=$output/logs/$name.log
result=$output/results/$name.txt

printf 'bridge-wine-validation: prefix: %s\n' "$prefix"
printf 'bridge-wine-validation: log: %s\n' "$log"

# The entire test command, including every installation lifecycle operation,
# shares one prefix. DISPLAY is removed to prevent an X11 fallback.
status=0
if (
    set -euo pipefail
    export WINEPREFIX="$prefix"
    export WINEARCH=win64
    unset DISPLAY
    wineboot --init
    wine reg add 'HKCU\Software\Wine\Drivers' /v Graphics /t REG_SZ /d wayland /f
    registry=$(wine reg query 'HKCU\Software\Wine\Drivers' /v Graphics)
    printf '%s\n' "$registry"
    printf '%s\n' "$registry" | grep -Eiq 'Graphics[[:space:]]+REG_SZ[[:space:]]+wayland([[:space:]]|$)' || {
        printf '%s\n' 'bridge-wine-validation: Wine registry did not confirm Graphics=wayland' >&2
        exit 1
    }
    "$@"
) >"$log" 2>&1; then
    :
else
    status=$?
fi

cat "$log"

# Always stop this prefix's Wine server before deleting it or preserving it for
# investigation. Shutdown errors cannot turn a failed test into a pass.
if ! WINEPREFIX="$prefix" wineserver -k >>"$log" 2>&1; then
    printf '%s\n' 'bridge-wine-validation: wineserver shutdown failed (see log)' >&2
    if ((status == 0)); then status=1; fi
fi
if ! WINEPREFIX="$prefix" wineserver -w >>"$log" 2>&1; then
    printf '%s\n' 'bridge-wine-validation: wineserver wait failed (see log)' >&2
    if ((status == 0)); then status=1; fi
fi

cleanup_failed=false
if ((status == 0)) && [[ "$keep_prefix" = false ]]; then
    if ! rm -rf -- "$prefix"; then
        status=1
        cleanup_failed=true
    fi
fi

if ((status == 0)); then
    outcome=passed
else
    outcome=failed
fi
printf 'result=%s\nexit_code=%s\nprefix=%s\nlog=%s\n' "$outcome" "$status" "$prefix" "$log" >"$result"

if [[ "$cleanup_failed" = true ]]; then
    fail "tests passed, but prefix cleanup failed; prefix may be incomplete: $prefix"
fi
if ((status != 0)); then
    printf 'bridge-wine-validation: failed (exit %s); prefix preserved: %s\n' "$status" "$prefix" >&2
    exit "$status"
fi
if [[ "$keep_prefix" = true ]]; then
    printf 'bridge-wine-validation: passed; prefix retained: %s\n' "$prefix"
else
    printf 'bridge-wine-validation: passed; prefix removed: %s\n' "$prefix"
fi
