#!/bin/sh
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 Frank Secilia

set -eu

BRIDGE_ANDROID_COMMAND_NAME=bridge-android-app
script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd) || exit 1
. "$script_dir/bridge-android-common.sh"

if [ "$#" -ne 5 ]; then
    bridge_android_fail "usage: bridge-android-app.sh <adb> <abi> <apk> <application-id> <activity>"
fi

bridge_android_adb=$1
bridge_android_abi=$2
apk=$3
application_id=$4
activity=$5

bridge_android_validate_adb
bridge_android_validate_abi
if [ ! -f "$apk" ]; then
    bridge_android_fail "APK does not exist: $apk"
fi

serial=$(bridge_android_select_device)

printf '%s\n' "Bridge Android: installing $application_id on $serial"
"$bridge_android_adb" -s "$serial" install -r "$apk" || \
    bridge_android_fail "APK install failed for $application_id on $serial"

"$bridge_android_adb" -s "$serial" shell am force-stop "$application_id" >/dev/null || \
    bridge_android_fail "could not stop $application_id on $serial"

printf '%s\n' "Bridge Android: launching $application_id on $serial"
"$bridge_android_adb" -s "$serial" shell am start -n "$application_id/$activity" || \
    bridge_android_fail "could not launch $application_id/$activity on $serial"
