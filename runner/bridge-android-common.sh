# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

bridge_android_fail()
{
    printf '%s\n' "${BRIDGE_ANDROID_COMMAND_NAME:-bridge-android}: $*" >&2
    exit 1
}

bridge_android_validate_adb()
{
    if [ "$bridge_android_adb" = --adb-unavailable ]; then
        bridge_android_fail "adb is unavailable; install Android SDK platform-tools or set BRIDGE_ANDROID_SDK_ROOT"
    fi
    if [ ! -x "$bridge_android_adb" ]; then
        bridge_android_fail "adb executable is not executable: $bridge_android_adb"
    fi
}

bridge_android_validate_abi()
{
    case $bridge_android_abi in
        x86_64|arm64-v8a) ;;
        *) bridge_android_fail "unsupported Android ABI: $bridge_android_abi" ;;
    esac
}

bridge_android_device_supports_abi()
{
    serial=$1
    abi_list=$("$bridge_android_adb" -s "$serial" shell getprop ro.product.cpu.abilist 2>/dev/null | tr -d '\r') || abi_list=
    if [ -z "$abi_list" ]; then
        abi_list=$("$bridge_android_adb" -s "$serial" shell getprop ro.product.cpu.abi 2>/dev/null | tr -d '\r') || abi_list=
    fi

    case ,$abi_list, in
        *,"$bridge_android_abi",*) return 0 ;;
        *) return 1 ;;
    esac
}

bridge_android_select_device()
{
    if [ -n "${BRIDGE_ANDROID_SERIAL:-}" ]; then
        state=$("$bridge_android_adb" -s "$BRIDGE_ANDROID_SERIAL" get-state 2>/dev/null) || \
            bridge_android_fail "BRIDGE_ANDROID_SERIAL=$BRIDGE_ANDROID_SERIAL is not available"
        if [ "$state" != device ]; then
            bridge_android_fail "BRIDGE_ANDROID_SERIAL=$BRIDGE_ANDROID_SERIAL is not online"
        fi
        if ! bridge_android_device_supports_abi "$BRIDGE_ANDROID_SERIAL"; then
            bridge_android_fail "BRIDGE_ANDROID_SERIAL=$BRIDGE_ANDROID_SERIAL does not support Android ABI $bridge_android_abi"
        fi
        printf '%s\n' "$BRIDGE_ANDROID_SERIAL"
        return
    fi

    devices=$("$bridge_android_adb" devices) || bridge_android_fail "adb devices failed"
    serials=$(printf '%s\n' "$devices" | awk '$2 == "device" { print $1 }') || \
        bridge_android_fail "could not parse adb devices output"
    compatible=
    compatible_count=0

    for serial in $serials; do
        if bridge_android_device_supports_abi "$serial"; then
            compatible_count=$((compatible_count + 1))
            if [ -z "$compatible" ]; then
                compatible=$serial
            else
                compatible="$compatible, $serial"
            fi
        fi
    done

    if [ "$compatible_count" -eq 0 ]; then
        bridge_android_fail "no online adb device supports Android ABI $bridge_android_abi"
    fi
    if [ "$compatible_count" -ne 1 ]; then
        bridge_android_fail "multiple adb devices support Android ABI $bridge_android_abi: $compatible; set BRIDGE_ANDROID_SERIAL"
    fi

    printf '%s\n' "$compatible"
}
