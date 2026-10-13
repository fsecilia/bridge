#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -eu

BRIDGE_ANDROID_COMMAND_NAME=bridge-android
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
. "$script_dir/bridge-android-common.sh"

if [ "$#" -lt 3 ]; then
    bridge_android_fail "usage: bridge-android.sh <adb> <abi> [--library FILE ...] [--assets DIR] -- <program> [args...]"
fi

bridge_android_adb=$1
bridge_android_abi=$2
shift 2

# Stage only the explicitly declared runtime libraries and asset tree.
# Newlines in paths cannot be represented in this POSIX shell list.
staged_libraries=
asset_directory=
while [ "$#" -gt 0 ]; do
    case $1 in
        --library)
            if [ "$#" -lt 2 ]; then
                bridge_android_fail "--library requires a local file path"
            fi
            case $2 in
                *'
'*) bridge_android_fail "library path contains a newline: $2" ;;
            esac
            if [ ! -f "$2" ]; then
                bridge_android_fail "runtime library does not exist: $2"
            fi
            staged_libraries="$staged_libraries
$2"
            shift 2
            ;;
        --assets)
            if [ "$#" -lt 2 ]; then
                bridge_android_fail "--assets requires a local directory"
            fi
            if [ -n "$asset_directory" ]; then
                bridge_android_fail "--assets specified more than once"
            fi
            case $2 in
                *'
'*) bridge_android_fail "asset directory path contains a newline: $2" ;;
            esac
            if [ ! -d "$2" ]; then
                bridge_android_fail "asset directory does not exist: $2"
            fi
            asset_directory=$2
            shift 2
            ;;
        --)
            shift
            break
            ;;
        -*) bridge_android_fail "unknown staging option: $1" ;;
        *) break ;;
    esac
done
if [ "$#" -eq 0 ]; then
    bridge_android_fail "target executable is required"
fi
program=$1
shift

bridge_android_validate_adb
bridge_android_validate_abi
if [ ! -f "$program" ]; then
    bridge_android_fail "target executable does not exist: $program"
fi

serial=$(bridge_android_select_device)
program_key=$(printf '%s\n%s\n' "$program" "$$" | cksum | awk '{ print $1 }') || \
    bridge_android_fail "could not determine deployment key"
if [ -z "$program_key" ]; then
    bridge_android_fail "could not determine deployment key"
fi

remote_dir=/data/local/tmp/bridge-$program_key
remote_program=$remote_dir/program

# Never reuse stale dependencies from a previous test run.
"$bridge_android_adb" -s "$serial" shell rm -rf "$remote_dir" >/dev/null || \
    bridge_android_fail "could not clear Android deployment directory: $remote_dir"
"$bridge_android_adb" -s "$serial" shell mkdir -p "$remote_dir" >/dev/null || \
    bridge_android_fail "could not create Android deployment directory: $remote_dir"
"$bridge_android_adb" -s "$serial" push "$program" "$remote_program" >/dev/null || \
    bridge_android_fail "could not deploy target executable to $serial"
"$bridge_android_adb" -s "$serial" shell chmod 700 "$remote_program" >/dev/null || \
    bridge_android_fail "could not make deployed target executable"

# Reject filename collisions rather than allowing a later push to overwrite a
# library or the executable. The assets tree occupies its own subdirectory.
staged_names='
program
assets
'
old_ifs=$IFS
IFS='
'
for file in $staged_libraries; do
    if [ -z "$file" ]; then
        continue
    fi
    name=${file##*/}
    case $staged_names in
        *"
$name
"*) bridge_android_fail "duplicate Android staged file name: $name" ;;
    esac
    staged_names="$staged_names$name
"
    "$bridge_android_adb" -s "$serial" push "$file" "$remote_dir/$name" >/dev/null || \
        bridge_android_fail "could not deploy Android library: $file"
done
IFS=$old_ifs

working_directory=$remote_dir
if [ -n "$asset_directory" ]; then
    # Push the directory as 'assets', preserving relative paths inside it.
    "$bridge_android_adb" -s "$serial" push "$asset_directory" "$remote_dir/assets" >/dev/null || \
        bridge_android_fail "could not deploy Android assets: $asset_directory"
    working_directory=$remote_dir/assets
fi

quote_remote_argument()
{
    escaped=$(printf '%sX' "$1" | sed "s/'/'\\\\''/g") || \
        bridge_android_fail "could not quote Android target argument"
    escaped=${escaped%X}
    printf "'%s'" "$escaped"
}

remote_command="cd $(quote_remote_argument "$working_directory") && "
if [ -n "$staged_libraries" ]; then
    remote_command="${remote_command}LD_LIBRARY_PATH=$(quote_remote_argument "$remote_dir") "
fi
remote_command="${remote_command}exec $(quote_remote_argument "$remote_program")"
for argument in "$@"; do
    quoted_argument=$(quote_remote_argument "$argument")
    remote_command="$remote_command $quoted_argument"
done

if "$bridge_android_adb" -s "$serial" shell "$remote_command"; then
    result=0
else
    result=$?
fi
"$bridge_android_adb" -s "$serial" shell rm -rf "$remote_dir" >/dev/null || \
    bridge_android_fail "could not clean Android deployment directory: $remote_dir"
exit "$result"
