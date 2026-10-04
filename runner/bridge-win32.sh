#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -eu

fail()
{
    printf '%s\n' "bridge-win32: $*" >&2
    exit 1
}

if [ "$#" -lt 4 ]; then
    fail "usage: bridge-win32.sh <wine> <winepath> <runtime-dir> <program> [args...]"
fi

wine=$1
winepath=$2
runtime_dir=$3
shift 3

if [ ! -x "$wine" ]; then
    fail "Wine executable is not executable: $wine"
fi
if [ ! -x "$winepath" ]; then
    fail "winepath executable is not executable: $winepath"
fi
if [ ! -d "$runtime_dir" ]; then
    fail "LLVM-MinGW runtime directory does not exist: $runtime_dir"
fi

# Wine's long-lived background processes can inherit a caller's captured pipes
# from the first Wine client. Keep a detached client alive so CTest can observe
# EOF as soon as the target process exits.
user_id=$(id -u) || fail "could not determine the host user id"
prefix=${WINEPREFIX:-${HOME:-}/.wine}
state_key=$(printf '%s\n%s\n' "$wine" "$prefix" | cksum | cut -d ' ' -f 1)
if [ -z "$state_key" ]; then
    fail "could not determine the Wine anchor state key"
fi

state_base=${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}
state_dir=${state_base}/bridge-win32-${user_id}-${state_key}
pid_file=${state_dir}/anchor.pid
umask 077
mkdir -p "$state_dir" || fail "could not create Wine anchor state directory: $state_dir"

anchor_alive()
{
    if [ ! -r "$pid_file" ]; then
        return 1
    fi

    anchor_pid=$(cat "$pid_file") || return 1
    case $anchor_pid in
        ''|*[!0-9]*) return 1 ;;
    esac

    kill -0 "$anchor_pid" 2>/dev/null
}

start_anchor()
{
    temporary_pid_file=${pid_file}.$$

    nohup "$wine" cmd /c "ping -n 301 127.0.0.1 >NUL" \
        </dev/null >/dev/null 2>&1 &
    anchor_pid=$!

    if ! printf '%s\n' "$anchor_pid" >"$temporary_pid_file"; then
        kill "$anchor_pid" 2>/dev/null || :
        fail "could not write Wine anchor pid file: $temporary_pid_file"
    fi
    if ! mv "$temporary_pid_file" "$pid_file"; then
        kill "$anchor_pid" 2>/dev/null || :
        rm -f "$temporary_pid_file"
        fail "could not publish Wine anchor pid file: $pid_file"
    fi

    # A detached Wine command is the readiness barrier. Even if it wins a cold
    # start race with the anchor, Wine still inherits /dev/null rather than the
    # caller's captured output descriptors.
    if ! "$wine" cmd /c exit </dev/null >/dev/null 2>&1; then
        kill "$anchor_pid" 2>/dev/null || :
        fail "Wine failed while preparing the detached execution environment"
    fi

    if ! kill -0 "$anchor_pid" 2>/dev/null; then
        fail "Wine anchor exited before the execution environment became ready"
    fi
}

if ! anchor_alive; then
    start_anchor
fi

runtime_wine_path=$("$winepath" -w "$runtime_dir") || \
    fail "winepath could not convert the LLVM-MinGW runtime directory"
if [ -z "$runtime_wine_path" ]; then
    fail "winepath returned an empty LLVM-MinGW runtime directory"
fi

if [ -n "${WINEPATH:-}" ]; then
    WINEPATH=${runtime_wine_path}\;${WINEPATH}
else
    WINEPATH=$runtime_wine_path
fi
export WINEPATH

exec "$wine" "$@"
