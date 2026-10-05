#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -eu

fail()
{
    printf '%s\n' "bridge-android: $*" >&2
    exit 1
}

if [ "$#" -lt 3 ]; then
    fail "usage: bridge-android.sh <adb> <abi> <program> [args...]"
fi

adb=$1
abi=$2
shift 2
program=$1
shift

if [ ! -x "$adb" ]; then
    fail "adb executable is not executable: $adb"
fi
if [ ! -f "$program" ]; then
    fail "target executable does not exist: $program"
fi

case $abi in
    x86_64|arm64-v8a) ;;
    *) fail "unsupported Android ABI: $abi" ;;
esac

device_supports_abi()
{
    serial=$1
    abi_list=$("$adb" -s "$serial" shell getprop ro.product.cpu.abilist 2>/dev/null | tr -d '\r') || abi_list=
    if [ -z "$abi_list" ]; then
        abi_list=$("$adb" -s "$serial" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r') || abi_list=
    fi

    case ,$abi_list, in
        *,"$abi",*) return 0 ;;
        *) return 1 ;;
    esac
}

select_device()
{
    if [ -n "${BRIDGE_ANDROID_SERIAL:-}" ]; then
        state=$("$adb" -s "$BRIDGE_ANDROID_SERIAL" get-state 2>/dev/null) || \
            fail "BRIDGE_ANDROID_SERIAL=$BRIDGE_ANDROID_SERIAL is not available"
        if [ "$state" != device ]; then
            fail "BRIDGE_ANDROID_SERIAL=$BRIDGE_ANDROID_SERIAL is not online"
        fi
        if ! device_supports_abi "$BRIDGE_ANDROID_SERIAL"; then
            fail "BRIDGE_ANDROID_SERIAL=$BRIDGE_ANDROID_SERIAL does not support Android ABI $abi"
        fi
        printf '%s\n' "$BRIDGE_ANDROID_SERIAL"
        return
    fi

    devices=$("$adb" devices) || fail "adb devices failed"
    serials=$(printf '%s\n' "$devices" | awk '$2 == "device" { print $1 }') || \
        fail "could not parse adb devices output"
    compatible=
    compatible_count=0

    for serial in $serials; do
        if device_supports_abi "$serial"; then
            compatible_count=$((compatible_count + 1))
            if [ -z "$compatible" ]; then
                compatible=$serial
            else
                compatible="$compatible, $serial"
            fi
        fi
    done

    if [ "$compatible_count" -eq 0 ]; then
        fail "no online adb device supports Android ABI $abi"
    fi
    if [ "$compatible_count" -ne 1 ]; then
        fail "multiple adb devices support Android ABI $abi: $compatible; set BRIDGE_ANDROID_SERIAL"
    fi

    printf '%s\n' "$compatible"
}

serial=$(select_device)
program_key=$(printf '%s\n' "$program" | cksum | awk '{ print $1 }') || \
    fail "could not determine deployment key"
if [ -z "$program_key" ]; then
    fail "could not determine deployment key"
fi

remote_dir=/data/local/tmp/bridge-$program_key
remote_program=$remote_dir/program

"$adb" -s "$serial" shell mkdir -p "$remote_dir" >/dev/null || \
    fail "could not create Android deployment directory: $remote_dir"
"$adb" -s "$serial" push "$program" "$remote_program" >/dev/null || \
    fail "could not deploy target executable to $serial"
"$adb" -s "$serial" shell chmod 700 "$remote_program" >/dev/null || \
    fail "could not make deployed target executable"

exec "$adb" -s "$serial" shell "$remote_program" "$@"
