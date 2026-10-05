#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -eu

BRIDGE_ANDROID_COMMAND_NAME=bridge-android
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
. "$script_dir/bridge-android-common.sh"

if [ "$#" -lt 3 ]; then
    bridge_android_fail "usage: bridge-android.sh <adb> <abi> <program> [args...]"
fi

bridge_android_adb=$1
bridge_android_abi=$2
shift 2
program=$1
shift

bridge_android_validate_adb
bridge_android_validate_abi
if [ ! -f "$program" ]; then
    bridge_android_fail "target executable does not exist: $program"
fi

serial=$(bridge_android_select_device)
program_key=$(printf '%s\n' "$program" | cksum | awk '{ print $1 }') || \
    bridge_android_fail "could not determine deployment key"
if [ -z "$program_key" ]; then
    bridge_android_fail "could not determine deployment key"
fi

remote_dir=/data/local/tmp/bridge-$program_key
remote_program=$remote_dir/program

"$bridge_android_adb" -s "$serial" shell mkdir -p "$remote_dir" >/dev/null || \
    bridge_android_fail "could not create Android deployment directory: $remote_dir"
"$bridge_android_adb" -s "$serial" push "$program" "$remote_program" >/dev/null || \
    bridge_android_fail "could not deploy target executable to $serial"
"$bridge_android_adb" -s "$serial" shell chmod 700 "$remote_program" >/dev/null || \
    bridge_android_fail "could not make deployed target executable"

quote_remote_argument()
{
    escaped=$(printf '%sX' "$1" | sed "s/'/'\\\\''/g") || \
        bridge_android_fail "could not quote Android target argument"
    escaped=${escaped%X}
    printf "'%s'" "$escaped"
}

remote_command=$(quote_remote_argument "$remote_program")
for argument in "$@"; do
    quoted_argument=$(quote_remote_argument "$argument")
    remote_command="$remote_command $quoted_argument"
done

exec "$bridge_android_adb" -s "$serial" shell "$remote_command"
